import SwiftUI

// MARK: - 반짝임 모양 (네 갈래 별)

struct TwinkleShape: Shape {
    /// 0에 가까울수록 뾰족해짐
    var waist: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let k = r * waist
        var p = Path()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }
}

// MARK: - 반짝임 배치

struct Spot: Hashable {
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    /// 0…1 주기 안에서 언제 켜질지
    var phase: Double
    /// 켜져 있는 길이 (0…1 비율)
    var dur: Double = 0.42
}

enum Sparkle {
    /// `start` 부터 `dur` 동안 뾰족하게 켜졌다 꺼지는 0…1 값
    static func flash(_ p: Double, start: Double, dur: Double) -> Double {
        let x = (p - start) / dur
        guard x > 0, x < 1 else { return 0 }
        return pow(sin(x * .pi), 1.6)
    }

    /// `TwinkleShape` 과 같은 모양을 Core Graphics 로 (메뉴바 합성용)
    static func twinklePath(center c: CGPoint, radius r: CGFloat) -> CGPath {
        let k = r * 0.28
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x, y: c.y - r))
        p.addQuadCurve(to: CGPoint(x: c.x + r, y: c.y), control: CGPoint(x: c.x + k, y: c.y - k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y + r), control: CGPoint(x: c.x + k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x - r, y: c.y), control: CGPoint(x: c.x - k, y: c.y + k))
        p.addQuadCurve(to: CGPoint(x: c.x, y: c.y - r), control: CGPoint(x: c.x - k, y: c.y - k))
        p.closeSubpath()
        return p
    }

    /// 오늘 동그라미 주변에 뿌릴 기본 배치
    static let aroundDay: [Spot] = [
        Spot(x: -16, y: -13, size: 8,   phase: 0.00),
        Spot(x:  15, y: -10, size: 6,   phase: 0.22),
        Spot(x:  12, y:  14, size: 6.5, phase: 0.46),
        Spot(x: -13, y:  13, size: 5,   phase: 0.66),
    ]
}

/// 진행도를 직접 받아서 한 프레임을 그림 (메뉴바 렌더링에도 씀)
struct TwinkleField: View {
    let spots: [Spot]
    var color: Color = .white
    /// 0…1 을 반복하는 진행도
    let progress: Double

    var body: some View {
        ZStack {
            ForEach(spots, id: \.self) { s in
                let k = Sparkle.flash(progress, start: s.phase, dur: s.dur)
                if k > 0.002 {
                    TwinkleShape()
                        .fill(color)
                        .frame(width: s.size, height: s.size)
                        .scaleEffect(0.4 + 0.7 * k)
                        .opacity(k)
                        .offset(x: s.x, y: s.y)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// 스스로 시간을 흘려보내는 버전 (팝오버용)
struct AnimatedTwinkles: View {
    let spots: [Spot]
    var color: Color = .white
    var period: Double = 3.4

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
            TwinkleField(spots: spots, color: color,
                         progress: t.truncatingRemainder(dividingBy: period) / period)
        }
    }
}

// MARK: - 훑고 지나가는 광택

struct ShimmerOverlay: ViewModifier {
    /// 0…1 위치. nil 이면 광택 없음.
    let progress: Double?
    var color: Color = .white
    var strength: Double = 0.85

    @ViewBuilder
    func body(content: Content) -> some View {
        if let p = progress {
            content
                .overlay {
                    GeometryReader { g in
                        let w = g.size.width
                        LinearGradient(
                            colors: [color.opacity(0), color.opacity(strength), color.opacity(0)],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: max(w * 0.45, 20))
                        .offset(x: -w * 0.6 + p * w * 1.6)
                    }
                    .allowsHitTesting(false)
                }
                .mask(content)
        } else {
            content
        }
    }
}

struct AutoShimmer: ViewModifier {
    let active: Bool
    var period: Double = 3.4
    var dur: Double = 1.0
    var color: Color = .white
    var strength: Double = 0.85

    @ViewBuilder
    func body(content: Content) -> some View {
        if active {
            TimelineView(.animation) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: period)
                content.shimmer(t < dur ? t / dur : nil, color: color, strength: strength)
            }
        } else {
            content
        }
    }
}

extension View {
    func shimmer(_ progress: Double?, color: Color = .white, strength: Double = 0.85) -> some View {
        modifier(ShimmerOverlay(progress: progress, color: color, strength: strength))
    }

    func autoShimmer(active: Bool, period: Double = 3.4, dur: Double = 1.0,
                     color: Color = .white, strength: Double = 0.85) -> some View {
        modifier(AutoShimmer(active: active, period: period, dur: dur, color: color, strength: strength))
    }
}
