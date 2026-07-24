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
    private var burst: Double?
    private var bag: Set<AnyCancellable> = []

    private let frameRate = 24.0
    private let burstLength = 1.25   // 한 번 반짝이는 데 걸리는 시간(초)

    init(item: NSStatusItem, state: AppState, prefs: Prefs) {
        self.item = item
        self.state = state
        self.prefs = prefs
    }

    func start() {
        render()

        // 설정이나 날짜가 바뀌면 다시 그림
        prefs.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.render()
                    self?.scheduleBursts()
                }
            }
            .store(in: &bag)

        state.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.render() }
            }
            .store(in: &bag)

        scheduleBursts()
    }

    // MARK: 그리기

    private func render() {
        guard let button = item.button else { return }

        let view = MenuBarLabel(prefs: prefs, date: state.today, burst: burst)
        let appearance = button.effectiveAppearance
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua

        let renderer = ImageRenderer(
            content: view.environment(\.colorScheme, isDark ? .dark : .light)
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        var cg: CGImage?
        // 동적 컬러(라이트/다크)가 메뉴바 외형에 맞게 풀리도록
        appearance.performAsCurrentDrawingAppearance {
            cg = renderer.cgImage
        }
        guard let cg else { return }

        let size = NSSize(width: CGFloat(cg.width) / renderer.scale,
                          height: CGFloat(cg.height) / renderer.scale)
        let image = NSImage(cgImage: cg, size: size)
        // 이게 핵심 — 템플릿이 아니어야 색이 그대로 나옴
        image.isTemplate = !prefs.colorful
        button.image = image
    }

    // MARK: 반짝임

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
                    self.burst = Double(frame) / Double(total)
                    self.render()
                }
            }
        }
    }

    private func stopBurst() {
        frameTimer?.invalidate()
        frameTimer = nil
        burst = nil
        render()
    }
}
