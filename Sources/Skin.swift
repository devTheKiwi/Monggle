import SwiftUI
import AppKit

// MARK: - 뒤가 비쳐 보이는 블러 층
//
// 투명도 기능에 쓰던 것. 실제로 써 보니 스킨과 눈에 띄는 차이가 없어서 뺐음.
// 되살리려면 이 struct 와 아래 SkinBackground 의 주석 처리된 부분,
// Prefs.transparency, Settings 의 슬라이더를 같이 살리면 됨.
//
// struct VisualEffect: NSViewRepresentable {
//     var material: NSVisualEffectView.Material
//     /// `.behindWindow` 라야 창 뒤에 있는 게 비쳐 보임
//     var blending: NSVisualEffectView.BlendingMode = .behindWindow
//
//     func makeNSView(context: Context) -> NSVisualEffectView {
//         let v = NSVisualEffectView()
//         v.state = .active
//         v.material = material
//         v.blendingMode = blending
//         return v
//     }
//
//     func updateNSView(_ v: NSVisualEffectView, context: Context) {
//         v.material = material
//         v.blendingMode = blending
//     }
// }

// MARK: - 팝오버 스킨

enum Skin: String, CaseIterable, Identifiable {
    case plain, candy, glass, night, aurora

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain:  return "기본"
        case .candy:  return "솜사탕"
        case .glass:  return "유리"
        case .night:  return "밤하늘"
        case .aurora: return "오로라"
        }
    }

    /// 어두운 스킨은 팝오버 외형까지 다크로 바꿔서 글자·화살표를 맞춤
    var isDark: Bool {
        switch self {
        case .night, .aurora: return true
        default:              return false
        }
    }

    /// 어두운 배경 위에서는 구분선을 밝게
    var hairline: Color {
        isDark ? .white.opacity(0.16) : .primary.opacity(0.12)
    }

    /// 일정 줄 뒤에 깔 카드 색
    var rowFill: Color {
        isDark ? .white.opacity(0.07) : .primary.opacity(0.045)
    }
}

// MARK: - 스킨별 배경

struct SkinBackground: View {
    let skin: Skin
    let theme: Theme
    /// 움직이는 스킨을 멈춰 둘지 (설정 미리보기는 false)
    var animate: Bool = true

    // 투명도용 — 뺐음 (위 VisualEffect 주석 참고)
    // /// 0 = 불투명, 1 = 가장 투명
    // var transparency: Double = 0
    // /// 썸네일은 창 안에서만 블렌딩 (바탕화면이 비치면 이상하니까)
    // var behindWindow: Bool = true

    @ViewBuilder
    var body: some View {
        switch skin {
        case .plain:  Color.clear
        case .candy:  CandyBackground(theme: theme)
        case .glass:  GlassBackground(theme: theme)
        case .night:  NightBackground(animate: animate)
        case .aurora: AuroraBackground(theme: theme, animate: animate)
        }

        // 투명도가 있던 시절의 본문 — 되살리려면 위를 지우고 이걸 쓰면 됨
        // ZStack {
        //     // 뒤가 비치는 블러는 항상 깔아 두고,
        //     VisualEffect(material: skin.isDark ? .hudWindow : .popover,
        //                  blending: behindWindow ? .behindWindow : .withinWindow)
        //     // 그 위 불투명한 층을 투명도만큼 걷어냄
        //     ZStack {
        //         Color(nsColor: .windowBackgroundColor)
        //         layer
        //     }
        //     .compositingGroup()
        //     // 어두운 스킨은 너무 옅어지면 흰 글자가 안 읽혀서 덜 걷어냄
        //     .opacity(1 - transparency * (skin.isDark ? 0.7 : 0.9))
        // }
    }
}

/// 파스텔 그라데이션 + 부드러운 빛 덩어리
struct CandyBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.accent.opacity(0.20), theme.accent2.opacity(0.09)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(theme.accent2.opacity(0.30))
                .frame(width: 150).blur(radius: 42)
                .offset(x: 105, y: -130)
            Circle()
                .fill(theme.accent.opacity(0.22))
                .frame(width: 130).blur(radius: 40)
                .offset(x: -110, y: 150)
        }
    }
}

/// 반투명 유리
struct GlassBackground: View {
    let theme: Theme

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            LinearGradient(colors: [.white.opacity(0.20), .clear, theme.accent.opacity(0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

/// 짙은 남보라 하늘에 별이 총총
struct NightBackground: View {
    var animate: Bool = true

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x151533), Color(hex: 0x2B1B49), Color(hex: 0x161634)],
                startPoint: .top, endPoint: .bottom)
            if animate {
                AnimatedTwinkles(spots: Self.stars, color: .white, period: 6.5)
            } else {
                TwinkleField(spots: Self.stars, color: .white.opacity(0.55), progress: 0.5)
            }
        }
    }

    /// 매번 같은 자리에 뜨도록 좌표를 계산해 둠 (난수 안 씀)
    static let stars: [Spot] = (0..<30).map { i in
        Spot(x: CGFloat(Skin.noise(i, 1.7) - 0.5) * 292,
             y: CGFloat(Skin.noise(i, 9.3) - 0.5) * 400,
             size: 3 + CGFloat(Skin.noise(i, 4.1)) * 5,
             phase: Skin.noise(i, 6.6),
             dur: 0.3 + Skin.noise(i, 2.2) * 0.3)
    }
}

/// 천천히 흐르는 오로라 — 제일 화려한 쪽
struct AuroraBackground: View {
    let theme: Theme
    var animate: Bool = true

    var body: some View {
        if animate {
            TimelineView(.animation(minimumInterval: 1.0 / 20)) { ctx in
                blobs(ctx.date.timeIntervalSinceReferenceDate)
            }
        } else {
            blobs(0)
        }
    }

    private func blobs(_ t: Double) -> some View {
        ZStack {
            Color(hex: 0x0D1130)
            blob(theme.accent,  w: 210, x: sin(t * 0.23) * 70,       y: cos(t * 0.17) * 85 - 70)
            blob(theme.accent2, w: 190, x: cos(t * 0.19) * 80 + 45,  y: sin(t * 0.21) * 70 + 90)
            blob(Color(hex: 0x3FE0C8), w: 160, x: sin(t * 0.15 + 2) * 90, y: cos(t * 0.25 + 1) * 65)
        }
    }

    private func blob(_ color: Color, w: CGFloat, x: Double, y: Double) -> some View {
        Ellipse()
            .fill(color.opacity(0.55))
            .frame(width: w, height: w * 0.72)
            .blur(radius: 38)
            .offset(x: x, y: y)
    }
}

extension Skin {
    /// 0…1 사이 값을 인덱스로부터 뽑아냄 (별 위치를 고정하려고)
    static func noise(_ i: Int, _ seed: Double) -> Double {
        let v = sin(Double(i) * 12.9898 + seed * 78.233) * 43758.5453
        return abs(v - v.rounded(.down))
    }
}
