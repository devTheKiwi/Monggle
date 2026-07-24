import SwiftUI

// MARK: - 메뉴바 표시 형식

enum LabelStyle: String, CaseIterable, Identifiable {
    case icon           // 숫자 사각형 아이콘
    case day            // 24
    case korDay         // 24일 (금)
    case korMonthDay    // 7월 24일
    case korFull        // 7월 24일 (금)
    case slash          // 7/24 (금)
    case dotted         // 2026.07.24
    case compact        // 20260724
    case custom         // 사용자 지정

    var id: String { rawValue }

    var label: String {
        switch self {
        case .icon:        return "아이콘"
        case .day:         return "일자만"
        case .korDay:      return "일 + 요일"
        case .korMonthDay: return "월 · 일"
        case .korFull:     return "월 · 일 + 요일"
        case .slash:       return "슬래시"
        case .dotted:      return "점 구분"
        case .compact:     return "붙여쓰기"
        case .custom:      return "사용자 지정"
        }
    }

    var pattern: String {
        switch self {
        case .icon:        return ""
        case .day:         return "d"
        case .korDay:      return "d일 (E)"
        case .korMonthDay: return "M월 d일"
        case .korFull:     return "M월 d일 (E)"
        case .slash:       return "M/d (E)"
        case .dotted:      return "yyyy.MM.dd"
        case .compact:     return "yyyyMMdd"
        case .custom:      return ""
        }
    }

    /// 이 형식으로 그린 문자열. `.icon` 은 문자열이 없으니 빈 값.
    func text(for date: Date, custom: String) -> String {
        let p = (self == .custom) ? custom : pattern
        guard !p.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        return DateUtil.string(p, date)
    }
}

// MARK: - 메뉴바 배경

enum LabelBackground: String, CaseIterable, Identifiable {
    case none, soft, outline, filled

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none:    return "없음"
        case .soft:    return "연하게"
        case .outline: return "테두리"
        case .filled:  return "꽉 채우기"
        }
    }
}

// MARK: - 반짝임 세기

enum SparkleLevel: String, CaseIterable, Identifiable {
    case off, gentle, lively

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off:    return "끔"
        case .gentle: return "은은하게"
        case .lively: return "반짝반짝"
        }
    }

    /// 메뉴바에서 몇 초마다 한 번 반짝일지. nil 이면 안 반짝임.
    var period: Double? {
        switch self {
        case .off:    return nil
        case .gentle: return 7.5
        case .lively: return 3.2
        }
    }

    var on: Bool { self != .off }
}

// MARK: - 설정 값 (UserDefaults 에 바로 저장)

final class Prefs: ObservableObject {
    private let d = UserDefaults.standard

    @Published var style: LabelStyle { didSet { d.set(style.rawValue, forKey: K.style) } }
    @Published var customPattern: String { didSet { d.set(customPattern, forKey: K.custom) } }
    @Published var emoji: String { didSet { d.set(emoji, forKey: K.emoji) } }
    @Published var theme: Theme { didSet { d.set(theme.rawValue, forKey: K.theme) } }
    @Published var mondayFirst: Bool { didSet { d.set(mondayFirst, forKey: K.monday) } }
    @Published var showHolidays: Bool { didSet { d.set(showHolidays, forKey: K.holidays) } }
    @Published var showDots: Bool { didSet { d.set(showDots, forKey: K.dots) } }
    @Published var colorful: Bool { didSet { d.set(colorful, forKey: K.colorful) } }
    @Published var sparkle: SparkleLevel { didSet { d.set(sparkle.rawValue, forKey: K.sparkle) } }
    @Published var background: LabelBackground { didSet { d.set(background.rawValue, forKey: K.bg) } }
    @Published var skin: Skin { didSet { d.set(skin.rawValue, forKey: K.skin) } }
    // 투명도 — 뺐음 (Skin.swift 주석 참고)
    // @Published var transparency: Double { didSet { d.set(transparency, forKey: K.alpha) } }

    private enum K {
        static let style = "labelStyle"
        static let custom = "customPattern"
        static let emoji = "menuEmoji"
        static let theme = "theme"
        static let monday = "mondayFirst"
        static let holidays = "showHolidays"
        static let dots = "showDots"
        static let colorful = "colorfulMenuBar"
        static let sparkle = "sparkleLevel"
        static let bg = "labelBackground"
        static let skin = "skin"
        // static let alpha = "transparency"
    }

    init() {
        d.register(defaults: [K.holidays: true, K.dots: true, K.colorful: true])
        style = LabelStyle(rawValue: d.string(forKey: K.style) ?? "") ?? .icon
        customPattern = d.string(forKey: K.custom) ?? "M월 d일 (E)"
        emoji = d.string(forKey: K.emoji) ?? ""
        theme = Theme(rawValue: d.string(forKey: K.theme) ?? "") ?? .coral
        mondayFirst = d.bool(forKey: K.monday)
        showHolidays = d.bool(forKey: K.holidays)
        showDots = d.bool(forKey: K.dots)
        colorful = d.bool(forKey: K.colorful)
        sparkle = SparkleLevel(rawValue: d.string(forKey: K.sparkle) ?? "") ?? .gentle
        background = LabelBackground(rawValue: d.string(forKey: K.bg) ?? "") ?? .none
        skin = Skin(rawValue: d.string(forKey: K.skin) ?? "") ?? .plain
        // transparency = min(max(d.double(forKey: K.alpha), 0), 1)
    }

    var firstWeekday: Int { mondayFirst ? 2 : 1 }

    /// 흑백(템플릿) 모드에서는 배경을 칠하면 글자가 묻히니 무시함
    var effectiveBackground: LabelBackground { colorful ? background : .none }

    func holiday(_ name: String?) -> String? { showHolidays ? name : nil }
}
