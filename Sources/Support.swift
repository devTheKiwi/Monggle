import SwiftUI
import AppKit

// MARK: - 색 (라이트/다크 자동 대응)

extension Color {
    init(hex: UInt) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: 1)
    }

    /// 라이트/다크에서 각각 다른 색을 쓰는 동적 컬러
    static func dynamic(light: UInt, dark: UInt) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: 1)
        })
    }
}

/// 포인트 색 테마 — 설정에서 고를 수 있어.
enum Theme: String, CaseIterable, Identifiable {
    case coral, lavender, mint, sky, butter
    case peach, cherry, lime, mocha, slate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .coral:    return "코랄"
        case .lavender: return "라벤더"
        case .mint:     return "민트"
        case .sky:      return "하늘"
        case .butter:   return "버터"
        case .peach:    return "피치"
        case .cherry:   return "체리"
        case .lime:     return "라임"
        case .mocha:    return "모카"
        case .slate:    return "슬레이트"
        }
    }

    var accent: Color {
        switch self {
        case .coral:    return .dynamic(light: 0xFF7E9D, dark: 0xFF90AC)
        case .lavender: return .dynamic(light: 0x9B7EF0, dark: 0xB49BFF)
        case .mint:     return .dynamic(light: 0x27B99A, dark: 0x4FD9B8)
        case .sky:      return .dynamic(light: 0x3E9BFF, dark: 0x6FB6FF)
        case .butter:   return .dynamic(light: 0xE8A317, dark: 0xF5C24D)
        case .peach:    return .dynamic(light: 0xFF8F5E, dark: 0xFFA579)
        case .cherry:   return .dynamic(light: 0xE8453D, dark: 0xF56A62)
        case .lime:     return .dynamic(light: 0x86B82C, dark: 0xA6D94A)
        case .mocha:    return .dynamic(light: 0xB07B54, dark: 0xC79B76)
        case .slate:    return .dynamic(light: 0x6E7A8A, dark: 0x93A0B0)
        }
    }

    var accent2: Color {
        switch self {
        case .coral:    return .dynamic(light: 0xFF9D84, dark: 0xFFAB93)
        case .lavender: return .dynamic(light: 0xC58BF0, dark: 0xD5A6FF)
        case .mint:     return .dynamic(light: 0x5FCB92, dark: 0x86E3A2)
        case .sky:      return .dynamic(light: 0x5FC8EE, dark: 0x8ADCFF)
        case .butter:   return .dynamic(light: 0xF2C14E, dark: 0xFFD97A)
        case .peach:    return .dynamic(light: 0xFFB07A, dark: 0xFFC199)
        case .cherry:   return .dynamic(light: 0xF56A4E, dark: 0xFF897A)
        case .lime:     return .dynamic(light: 0xAAD24E, dark: 0xC6E86E)
        case .mocha:    return .dynamic(light: 0xC99B6E, dark: 0xDBB68E)
        case .slate:    return .dynamic(light: 0x8A94A2, dark: 0xAAB4C2)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

enum Palette {
    static let sunday   = Color.dynamic(light: 0xFF5D72, dark: 0xFF8090) // 일요일·공휴일 빨강
    static let saturday = Color.dynamic(light: 0x3E7DFF, dark: 0x82B0FF) // 토요일 파랑
}

// MARK: - 날짜 유틸

enum DateUtil {
    static var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "ko_KR")
        c.timeZone = .current
        c.firstWeekday = 1
        return c
    }()

    static func startOfDay(_ d: Date) -> Date { cal.startOfDay(for: d) }

    static func startOfMonth(_ d: Date) -> Date {
        cal.date(from: cal.dateComponents([.year, .month], from: d)) ?? d
    }

    static func addMonths(_ n: Int, to d: Date) -> Date {
        cal.date(byAdding: .month, value: n, to: d) ?? d
    }

    /// 그 달을 감싸는 6주(42칸). `firstWeekday` 는 1=일 … 7=토.
    static func gridDays(for month: Date, firstWeekday: Int = 1) -> [Date] {
        let first = startOfMonth(month)
        let wd = cal.component(.weekday, from: first)
        let offset = (wd - firstWeekday + 7) % 7
        let start = cal.date(byAdding: .day, value: -offset, to: first) ?? first
        return (0..<42).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    /// 시작 요일에 맞춰 회전한 요일 문자
    static func weekdaySymbols(firstWeekday: Int) -> [String] {
        let base = ["일", "월", "화", "수", "목", "금", "토"]
        let i = (firstWeekday - 1) % 7
        return Array(base[i...] + base[..<i])
    }

    /// 그리드 열 번호 → 실제 요일 (1=일 … 7=토)
    static func weekday(column: Int, firstWeekday: Int) -> Int {
        ((firstWeekday - 1 + column) % 7) + 1
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool { cal.isDate(a, inSameDayAs: b) }

    static func isSameMonth(_ a: Date, _ b: Date) -> Bool {
        cal.component(.year, from: a) == cal.component(.year, from: b) &&
        cal.component(.month, from: a) == cal.component(.month, from: b)
    }

    static func day(_ d: Date) -> Int { cal.component(.day, from: d) }
    static func weekday(_ d: Date) -> Int { cal.component(.weekday, from: d) } // 1=일 … 7=토

    static let monthTitle: DateFormatter = fmt("yyyy년 M월")
    static let dayHeader: DateFormatter = fmt("M월 d일 EEEE")
    static let timeFmt: DateFormatter = fmt("a h:mm")

    /// 캘린더 앱 `ical://` 링크에 쓰는 UTC 타임스탬프
    static let icalStamp: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return f
    }()

    /// 사용자 지정 패턴용 — 만든 포매터는 재사용하려고 캐시해 둠.
    private static var cache: [String: DateFormatter] = [:]

    static func string(_ pattern: String, _ date: Date) -> String {
        if let f = cache[pattern] { return f.string(from: date) }
        let f = fmt(pattern)
        cache[pattern] = f
        return f.string(from: date)
    }

    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.timeZone = .current
        f.dateFormat = pattern
        return f
    }
}

// MARK: - 한국 공휴일

enum Holidays {
    /// 매년 같은 양력 공휴일
    private static let fixed: [String: String] = [
        "01-01": "신정",
        "03-01": "삼일절",
        "05-05": "어린이날",
        "06-06": "현충일",
        "08-15": "광복절",
        "10-03": "개천절",
        "10-09": "한글날",
        "12-25": "성탄절",
    ]

    /// 음력·대체공휴일·선거일 — 연도별 표. 틀린 게 있으면 여기 한 줄만 고치면 돼.
    private static let table: [String: String] = [
        // 2026
        "2026-02-16": "설날 연휴", "2026-02-17": "설날", "2026-02-18": "설날 연휴",
        "2026-03-02": "삼일절 대체공휴일",
        "2026-05-24": "부처님오신날", "2026-05-25": "부처님오신날 대체공휴일",
        "2026-06-03": "지방선거일",
        "2026-08-17": "광복절 대체공휴일",
        "2026-09-24": "추석 연휴", "2026-09-25": "추석", "2026-09-26": "추석 연휴",
        "2026-10-05": "개천절 대체공휴일",
        // 2027
        "2027-02-06": "설날 연휴", "2027-02-07": "설날", "2027-02-08": "설날 연휴", "2027-02-09": "설날 대체공휴일",
        "2027-05-13": "부처님오신날",
        "2027-08-16": "광복절 대체공휴일",
        "2027-09-14": "추석 연휴", "2027-09-15": "추석", "2027-09-16": "추석 연휴",
        "2027-10-04": "개천절 대체공휴일", "2027-10-11": "한글날 대체공휴일",
        "2027-12-27": "성탄절 대체공휴일",
        // 2028
        "2028-01-26": "설날 연휴", "2028-01-27": "설날", "2028-01-28": "설날 연휴",
        "2028-04-12": "국회의원선거일",
        "2028-05-02": "부처님오신날",
        // 추석과 개천절이 같은 날(10/3)이라 대체공휴일이 연휴 끝난 뒤 첫 평일인 10/5 로 밀린다
        "2028-10-02": "추석 연휴", "2028-10-03": "추석 · 개천절", "2028-10-04": "추석 연휴",
        "2028-10-05": "개천절 대체공휴일",
    ]

    private static let fullFmt = fmt("yyyy-MM-dd")
    private static let mdFmt = fmt("MM-dd")

    static func name(for date: Date) -> String? {
        if let n = table[fullFmt.string(from: date)] { return n }
        return fixed[mdFmt.string(from: date)]
    }

    private static func fmt(_ pattern: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = pattern
        return f
    }
}
