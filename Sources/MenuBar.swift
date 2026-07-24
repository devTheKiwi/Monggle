import SwiftUI
import AppKit
import Combine

// MARK: - 메뉴바에 그려지는 라벨

struct MenuBarLabel: View {
    @ObservedObject var prefs: Prefs
    let date: Date
    /// 반짝임 진행도 0…1. nil 이면 가만히 있음.
    let burst: Double?

    /// 메뉴바 반짝임 위치 — 글자 위아래로 살짝 걸치게
    private let spots: [Spot] = [
        Spot(x: -3, y: -7, size: 7, phase: 0.05, dur: 0.5),
        Spot(x: 14, y:  7, size: 5, phase: 0.30, dur: 0.5),
        Spot(x: -18, y:  6, size: 4.5, phase: 0.5, dur: 0.5),
    ]

    var body: some View {
        let text = prefs.style.text(for: date, custom: prefs.customPattern)
        let bg = prefs.effectiveBackground

        HStack(spacing: 3.5) {
            if !prefs.emoji.isEmpty {
                Text(prefs.emoji).font(.system(size: 12.5))
            }
            if prefs.style == .icon {
                Image(systemName: "\(DateUtil.day(date)).square")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(paint(bg))
            } else if text.isEmpty {
                Image(systemName: "calendar")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(paint(bg))
            } else {
                Text(text)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(paint(bg))
            }
        }
        .padding(.horizontal, bg == .none ? 0 : 8)
        .padding(.vertical, bg == .none ? 0 : 2)
        .background(backdrop(bg))
        .shimmer(burst, strength: prefs.colorful ? 0.9 : 0.75)
        .overlay {
            if let b = burst {
                TwinkleField(spots: spots,
                             color: twinkleColor(bg),
                             progress: b)
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 22)
    }

    /// 글자·아이콘 색
    private func paint(_ bg: LabelBackground) -> AnyShapeStyle {
        // 템플릿(단색) 모드에서는 어차피 색이 무시되니 흰색으로 그려 둠
        guard prefs.colorful else { return AnyShapeStyle(Color.white) }
        return bg == .filled
            ? AnyShapeStyle(Color.white)
            : AnyShapeStyle(prefs.theme.gradient)
    }

    /// 글자 뒤에 깔리는 알약
    @ViewBuilder
    private func backdrop(_ bg: LabelBackground) -> some View {
        switch bg {
        case .none:
            Color.clear
        case .soft:
            Capsule().fill(prefs.theme.accent.opacity(0.22))
        case .outline:
            Capsule().stroke(prefs.theme.accent.opacity(0.8), lineWidth: 1.4)
        case .filled:
            Capsule().fill(prefs.theme.gradient)
        }
    }

    /// 꽉 채운 배경 위에서는 흰 반짝임이 잘 보임
    private func twinkleColor(_ bg: LabelBackground) -> Color {
        guard prefs.colorful else { return .white }
        return bg == .filled ? .white : prefs.theme.accent2
    }
}

/// 설정 창 미리보기용 — 스스로 반짝임
struct MenuBarPreview: View {
    @ObservedObject var prefs: Prefs
    let date: Date

    var body: some View {
        if let period = prefs.sparkle.period {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period)
                MenuBarLabel(prefs: prefs, date: date, burst: t < 1.25 ? t / 1.25 : nil)
            }
        } else {
            MenuBarLabel(prefs: prefs, date: date, burst: nil)
        }
    }
}

// MARK: - 상태바 아이템 관리 (직접 그려야 색이 살아남음)

@MainActor
final class MenuBarController {
    private let item: NSStatusItem
    private let state: AppState
    private let prefs: Prefs

    private var burstTimer: Timer?
    private var frameTimer: Timer?
    private var bag: Set<AnyCancellable> = []

    /// 반짝임 없는 라벨을 한 번만 구워 둠 — 매 프레임 SwiftUI 를 다시 굽는 건 너무 비쌌음
    private var base: CGImage?
    private var signature = ""
    private var canvasCache: CGContext?
    private var scale: CGFloat = 2
    private var twinkleColor: CGColor = NSColor.white.cgColor

    private let frameRate = 24.0
    private let burstLength = 1.25   // 한 번 반짝이는 데 걸리는 시간(초)

    /// 반짝임 위치 — 라벨 중심 기준 (pt)
    private let spots: [Spot] = [
        Spot(x: -3,  y: -7, size: 7,   phase: 0.05, dur: 0.5),
        Spot(x: 14,  y:  7, size: 5,   phase: 0.30, dur: 0.5),
        Spot(x: -18, y:  6, size: 4.5, phase: 0.50, dur: 0.5),
    ]

    init(item: NSStatusItem, state: AppState, prefs: Prefs) {
        self.item = item
        self.state = state
        self.prefs = prefs
    }

    func start() {
        rebuild()

        // 설정이나 날짜가 바뀔 때만 베이스를 다시 구움
        prefs.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.rebuild()
                    self?.scheduleBursts()
                }
            }
            .store(in: &bag)

        state.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.rebuild() }
            }
            .store(in: &bag)

        scheduleBursts()
    }

    // MARK: 베이스 굽기 (설정이 바뀔 때만)

    private func rebuild() {
        guard let button = item.button else { return }

        let appearance = button.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        // 메뉴바와 무관한 설정(스킨·투명도 등)이 바뀔 때 굽지 않도록.
        // 슬라이더를 드래그하면 초당 수십 번 들어오는데 굽는 건 ~48ms 짜리라 꼭 필요함.
        let sig = [
            prefs.style.rawValue, prefs.customPattern, prefs.emoji,
            prefs.theme.rawValue, String(prefs.colorful),
            prefs.effectiveBackground.rawValue,
            String(DateUtil.day(state.today)), String(isDark),
        ].joined(separator: "|")
        guard sig != signature || base == nil else { return }
        signature = sig

        let view = MenuBarLabel(prefs: prefs, date: state.today, burst: nil)

        let renderer = ImageRenderer(
            content: view.environment(\.colorScheme, isDark ? .dark : .light)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        scale = renderer.scale

        // 동적 컬러(라이트/다크)가 메뉴바 외형에 맞게 풀리도록
        appearance.performAsCurrentDrawingAppearance {
            base = renderer.cgImage
            let c = prefs.colorful && prefs.effectiveBackground != .filled
                ? NSColor(prefs.theme.accent2)
                : NSColor.white
            twinkleColor = (c.usingColorSpace(.sRGB) ?? .white).cgColor
        }
        paint(nil)
    }

    // MARK: 한 프레임 합성 (베이스 위에 광택과 별만 얹음)

    private func paint(_ progress: Double?) {
        guard let base, let button = item.button else { return }
        let w = base.width, h = base.height
        guard let ctx = canvas(w, h) else { return }

        let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        ctx.draw(base, in: rect)

        if let p = progress {
            drawShine(ctx, rect, p)
            drawTwinkles(ctx, rect, p)
        }

        guard let cg = ctx.makeImage() else { return }
        let image = NSImage(cgImage: cg,
                            size: NSSize(width: CGFloat(w) / scale, height: CGFloat(h) / scale))
        // 이게 핵심 — 템플릿이 아니어야 색이 그대로 나옴
        image.isTemplate = !prefs.colorful
        button.image = image
    }

    /// 프레임마다 비트맵을 새로 잡지 않도록 재사용
    private func canvas(_ w: Int, _ h: Int) -> CGContext? {
        let rect = CGRect(x: 0, y: 0, width: CGFloat(w), height: CGFloat(h))
        if let c = canvasCache, c.width == w, c.height == h {
            c.clear(rect)
            return c
        }
        canvasCache = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        return canvasCache
    }

    /// 훑고 지나가는 광택. sourceAtop 이라 라벨이 있는 자리에만 칠해짐.
    private func drawShine(_ ctx: CGContext, _ rect: CGRect, _ p: Double) {
        let a = prefs.colorful ? 0.9 : 0.75
        let colors = [
            NSColor.white.withAlphaComponent(0).cgColor,
            NSColor.white.withAlphaComponent(a).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
        ] as CFArray
        guard let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors, locations: [0, 0.5, 1]) else { return }

        let band = max(rect.width * 0.45, 20 * scale)
        let x = -rect.width * 0.6 + CGFloat(p) * rect.width * 1.6

        ctx.saveGState()
        ctx.setBlendMode(.sourceAtop)
        ctx.drawLinearGradient(grad,
                               start: CGPoint(x: x, y: 0),
                               end: CGPoint(x: x + band, y: 0),
                               options: [])
        ctx.restoreGState()
    }

    private func drawTwinkles(_ ctx: CGContext, _ rect: CGRect, _ p: Double) {
        ctx.saveGState()
        ctx.setFillColor(twinkleColor)
        for s in spots {
            let k = Sparkle.flash(p, start: s.phase, dur: s.dur)
            guard k > 0.002 else { continue }
            // CGContext 는 아래가 원점이라 y 를 뒤집어 줌
            let c = CGPoint(x: rect.midX + s.x * scale,
                            y: rect.midY - s.y * scale)
            let r = s.size * scale / 2 * (0.4 + 0.7 * k)
            ctx.setAlpha(k)
            ctx.addPath(Sparkle.twinklePath(center: c, radius: r))
            ctx.fillPath()
        }
        ctx.restoreGState()
    }

    // MARK: 반짝임 주기

    /// 상시 애니메이션 대신, 주기마다 짧게 한 번만 반짝이게 해서 CPU를 아낌
    private func scheduleBursts() {
        burstTimer?.invalidate()
        burstTimer = nil

        guard let period = prefs.sparkle.period else {
            stopBurst()
            return
        }
        burstTimer = Timer.scheduledTimer(withTimeInterval: period, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.runBurst() }
        }
        runBurst()
    }

    private func runBurst() {
        frameTimer?.invalidate()
        let total = Int(burstLength * frameRate)
        var frame = 0

        frameTimer = Timer.scheduledTimer(withTimeInterval: 1 / frameRate, repeats: true) { [weak self] t in
            Task { @MainActor in
                guard let self else { t.invalidate(); return }
                frame += 1
                if frame >= total {
                    t.invalidate()
                    self.stopBurst()
                } else {
                    self.paint(Double(frame) / Double(total))
                }
            }
        }
    }

    private func stopBurst() {
        frameTimer?.invalidate()
        frameTimer = nil
        paint(nil)
    }
}
