import SwiftUI
import AppKit

// MARK: - 설정 창 (메뉴바 앱이라 NSWindow 를 직접 띄움)

@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    static let shared = SettingsWindow()
    private var window: NSWindow?

    func show(state: AppState, prefs: Prefs) {
        if window == nil {
            let root = SettingsView()
                .environmentObject(state)
                .environmentObject(prefs)
            let w = NSWindow(contentViewController: NSHostingController(rootView: root))
            w.title = "몽글 설정"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.titlebarAppearsTransparent = true
            w.isReleasedWhenClosed = false
            w.delegate = self
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - 본체

struct SettingsView: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                PreviewStrip()
                Card("메뉴바 표시") { StyleSection() }
                Card("색과 반짝임") { SparkleSection() }
                Card("이모지") { EmojiSection() }
                Card("달력") { CalendarSection() }
                Card("일반") { GeneralSection() }
            }
            .padding(20)
        }
        .frame(width: 460, height: 660)
        .fontDesign(.rounded)
        .tint(prefs.theme.accent)
    }
}

/// 카드 한 장
struct Card<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 11.5, weight: .heavy))
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

// MARK: - 미리보기 (가짜 메뉴바)

struct PreviewStrip: View {
    @EnvironmentObject private var prefs: Prefs
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "wifi").opacity(0.35)
                Image(systemName: "battery.75").opacity(0.35)
                MenuBarPreview(prefs: prefs, date: state.today)
                Image(systemName: "magnifyingglass").opacity(0.35)
                Image(systemName: "switch.2").opacity(0.35)
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(prefs.theme.gradient.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(prefs.theme.accent.opacity(0.35), lineWidth: 1)
            )

            Text("메뉴바에 이렇게 보여요")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - 표시 형식

struct StyleSection: View {
    @EnvironmentObject private var prefs: Prefs
    @EnvironmentObject private var state: AppState

    var body: some View {
        VStack(spacing: 4) {
            ForEach(LabelStyle.allCases) { s in
                StyleRow(style: s, sample: sample(for: s))
            }

            if prefs.style == .custom {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("예: yyyy년 M월 d일 (E)", text: $prefs.customPattern)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12.5, design: .monospaced))
                    Text("yyyy 연도 · M 월 · d 일 · E 요일 · a 오전/오후 · h:mm 시각")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 6)
            }
        }
    }

    private func sample(for s: LabelStyle) -> String {
        s == .icon ? "" : s.text(for: state.today, custom: prefs.customPattern)
    }
}

struct StyleRow: View {
    @EnvironmentObject private var prefs: Prefs
    @EnvironmentObject private var state: AppState
    let style: LabelStyle
    let sample: String
    @State private var hovering = false

    var body: some View {
        let on = prefs.style == style

        Button {
            prefs.style = style
        } label: {
            HStack(spacing: 10) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(on ? prefs.theme.accent : Color.secondary.opacity(0.5))

                Text(style.label)
                    .font(.system(size: 12.5, weight: on ? .bold : .medium))

                Spacer(minLength: 8)

                if style == .icon {
                    Image(systemName: "\(DateUtil.day(state.today)).square")
                        .font(.system(size: 14, weight: .semibold))
                } else if !sample.isEmpty {
                    Text(sample)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(on ? prefs.theme.accent.opacity(0.12)
                             : (hovering ? Color.primary.opacity(0.05) : Color.clear))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 색과 반짝임

struct SparkleSection: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("메뉴바에 색 입히기", isOn: $prefs.colorful)
                .font(.system(size: 12.5, weight: .medium))

            Text(prefs.colorful
                 ? "포인트 색 그라데이션으로 표시돼요. 이모지도 원래 색으로 나와요."
                 : "macOS 기본대로 흑백으로 표시돼요.")
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)

            Divider().opacity(0.4)

            HStack {
                Text("배경").font(.system(size: 12.5, weight: .medium))
                Spacer()
                Picker("", selection: $prefs.background) {
                    ForEach(LabelBackground.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
            }
            .disabled(!prefs.colorful)
            .opacity(prefs.colorful ? 1 : 0.4)

            Divider().opacity(0.4)

            HStack {
                Text("반짝임").font(.system(size: 12.5, weight: .medium))
                Spacer()
                Picker("", selection: $prefs.sparkle) {
                    ForEach(SparkleLevel.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 220)
            }

            if prefs.sparkle.on {
                Text(prefs.sparkle == .lively
                     ? "3초마다 한 번씩 반짝여요."
                     : "7.5초마다 한 번씩 은은하게 반짝여요.")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 이모지

struct EmojiSection: View {
    @EnvironmentObject private var prefs: Prefs

    private let choices = ["📅", "🗓️", "✨", "🌸", "🍡", "🐣", "🌙", "☕️", "🧸", "🍀", "⭐️", "🫧"]
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: cols, spacing: 6) {
                EmojiChip(value: "", display: "없음")
                ForEach(choices, id: \.self) { EmojiChip(value: $0, display: $0) }
            }

            HStack(spacing: 8) {
                Text("직접 입력")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                TextField("", text: $prefs.emoji)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)
                    .font(.system(size: 13))
            }
        }
    }
}

struct EmojiChip: View {
    @EnvironmentObject private var prefs: Prefs
    let value: String
    let display: String

    var body: some View {
        let on = prefs.emoji == value

        Button {
            prefs.emoji = value
        } label: {
            Text(display)
                .font(.system(size: value.isEmpty ? 10.5 : 16, weight: .bold))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(on ? prefs.theme.accent.opacity(0.18) : Color.primary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(prefs.theme.accent, lineWidth: on ? 1.5 : 0)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 달력

struct CalendarSection: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("주 시작 요일").font(.system(size: 12.5, weight: .medium))
                Spacer()
                Picker("", selection: $prefs.mondayFirst) {
                    Text("일요일").tag(false)
                    Text("월요일").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 160)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("포인트 색").font(.system(size: 12.5, weight: .medium))
                HStack(spacing: 8) {
                    ForEach(Theme.allCases) { ThemeChip(theme: $0) }
                }
            }

            Toggle("공휴일 표시", isOn: $prefs.showHolidays)
                .font(.system(size: 12.5, weight: .medium))
            Toggle("날짜 아래 일정 점 표시", isOn: $prefs.showDots)
                .font(.system(size: 12.5, weight: .medium))
        }
    }
}

struct ThemeChip: View {
    @EnvironmentObject private var prefs: Prefs
    let theme: Theme

    var body: some View {
        let on = prefs.theme == theme

        Button {
            prefs.theme = theme
        } label: {
            VStack(spacing: 5) {
                Circle()
                    .fill(theme.gradient)
                    .frame(width: 26, height: 26)
                    .overlay(
                        Circle().stroke(Color.primary.opacity(on ? 0.85 : 0), lineWidth: 2)
                            .padding(-3)
                    )
                Text(theme.label)
                    .font(.system(size: 10, weight: on ? .heavy : .medium))
                    .foregroundStyle(on ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 일반

struct GeneralSection: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("로그인 시 자동 시작", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }
            ))
            .font(.system(size: 12.5, weight: .medium))

            Divider().opacity(0.4)

            AccessRow(title: "캘린더", ok: state.calendarAuthorized)
            AccessRow(title: "미리 알림", ok: state.reminderAuthorized)

            if !state.calendarAuthorized || !state.reminderAuthorized {
                Button("시스템 설정에서 권한 열기") {
                    let url = "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars"
                    if let u = URL(string: url) { NSWorkspace.shared.open(u) }
                }
                .font(.system(size: 12, weight: .semibold))
            }

            Divider().opacity(0.4)

            HStack {
                Text("몽글 \(version)")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("새로고침") { state.reload() }
                    .font(.system(size: 12, weight: .semibold))
                Button("몽글 종료") { NSApplication.shared.terminate(nil) }
                    .font(.system(size: 12, weight: .semibold))
            }
        }
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }
}

struct AccessRow: View {
    let title: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
                .font(.system(size: 12))
            Text(title).font(.system(size: 12.5, weight: .medium))
            Spacer()
            Text(ok ? "허용됨" : "허용 안 됨")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}
