import SwiftUI
import AppKit

// MARK: - 팝오버 전체

struct CalendarPopover: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(spacing: 10) {
            HeaderView()
            WeekdayRow()
            MonthGridView()
            Divider().opacity(0.4)
            EventListView()
        }
        .padding(14)
        .frame(width: 300)
        .fontDesign(.rounded)
    }
}

// MARK: - 헤더 (달 이동 · 오늘 · 설정)

struct HeaderView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        HStack(spacing: 2) {
            VStack(alignment: .leading, spacing: -1) {
                Text(DateUtil.string("yyyy", state.visibleMonth))
                    .font(.system(size: 9.5, weight: .heavy))
                    .foregroundStyle(prefs.theme.accent)
                Text(DateUtil.string("M월", state.visibleMonth))
                    .font(.system(size: 17, weight: .heavy))
            }
            Spacer(minLength: 0)
            iconButton("chevron.left", color: .secondary) { state.changeMonth(-1) }
            iconButton("smallcircle.filled.circle", color: prefs.theme.accent) { state.goToday() }
            iconButton("chevron.right", color: .secondary) { state.changeMonth(1) }
            iconButton("gearshape.fill", color: .secondary) {
                PopoverBridge.close?()
                SettingsWindow.shared.show(state: state, prefs: prefs)
            }
        }
    }

    private func iconButton(_ name: String, color: Color, _ action: @escaping () -> Void) -> some View {
        HoverButton(action: action) {
            Image(systemName: name)
                .font(.system(size: 13, weight: .bold))
                .frame(width: 26, height: 26)
                .foregroundStyle(color)
        }
    }
}

/// 살짝 배경이 뜨는 아이콘 버튼
struct HoverButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            label
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(hovering ? Color.primary.opacity(0.09) : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

// MARK: - 요일

struct WeekdayRow: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        HStack(spacing: 0) {
            let syms = DateUtil.weekdaySymbols(firstWeekday: prefs.firstWeekday)
            ForEach(Array(syms.enumerated()), id: \.offset) { i, s in
                let wd = DateUtil.weekday(column: i, firstWeekday: prefs.firstWeekday)
                Text(s)
                    .font(.system(size: 11, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(wd == 1 ? Palette.sunday : (wd == 7 ? Palette.saturday : Color.secondary))
            }
        }
    }
}

// MARK: - 달력 그리드

struct MonthGridView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs
    private let cols = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        LazyVGrid(columns: cols, spacing: 2) {
            ForEach(DateUtil.gridDays(for: state.visibleMonth, firstWeekday: prefs.firstWeekday), id: \.self) { day in
                DayCell(day: day)
            }
        }
        .animation(.easeOut(duration: 0.16), value: state.visibleMonth)
    }
}

struct DayCell: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs
    let day: Date
    @State private var hovering = false

    var body: some View {
        let inMonth = DateUtil.isSameMonth(day, state.visibleMonth)
        let isToday = DateUtil.isSameDay(day, state.today)
        let isSel = DateUtil.isSameDay(day, state.selected)
        let wd = DateUtil.weekday(day)
        let isHoliday = prefs.holiday(state.holiday(on: day)) != nil
        let dots = prefs.showDots ? dotColors() : []

        Button {
            state.select(day)
        } label: {
            VStack(spacing: 2) {
                Text("\(DateUtil.day(day))")
                    .font(.system(size: 13.5, weight: isToday ? .heavy : .semibold))
                    .foregroundStyle(numberColor(inMonth: inMonth, isToday: isToday, isHoliday: isHoliday, wd: wd))
                DotRow(colors: dots, onAccent: isToday)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background {
                if isToday {
                    ZStack {
                        // 뒤에 은은하게 번지는 빛
                        Circle()
                            .fill(prefs.theme.accent.opacity(0.28))
                            .frame(width: 40, height: 40)
                            .blur(radius: 7)
                        Circle()
                            .fill(prefs.theme.gradient)
                            .frame(width: 34, height: 34)
                            .shadow(color: prefs.theme.accent.opacity(0.45), radius: 5, y: 2)
                            .autoShimmer(active: prefs.sparkle.on,
                                         period: prefs.sparkle == .lively ? 2.6 : 5.0,
                                         dur: 0.9, strength: 0.55)
                        if prefs.sparkle.on {
                            AnimatedTwinkles(spots: Sparkle.aroundDay,
                                             color: prefs.theme.accent2,
                                             period: prefs.sparkle == .lively ? 2.6 : 5.0)
                        }
                    }
                } else if isSel {
                    Circle().stroke(prefs.theme.accent, lineWidth: 2).frame(width: 34, height: 34)
                } else if hovering {
                    Circle().fill(Color.primary.opacity(0.08)).frame(width: 34, height: 34)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }

    private func numberColor(inMonth: Bool, isToday: Bool, isHoliday: Bool, wd: Int) -> Color {
        if isToday { return .white }
        if !inMonth { return Color.secondary.opacity(0.4) }
        if isHoliday || wd == 1 { return Palette.sunday }
        if wd == 7 { return Palette.saturday }
        return .primary
    }

    private func dotColors() -> [Color] {
        var colors = state.events(on: day).prefix(3).map { $0.color }
        if colors.count < 3 && !state.reminders(on: day).isEmpty {
            colors.append(prefs.theme.accent)
        }
        return Array(colors.prefix(3))
    }
}

struct DotRow: View {
    let colors: [Color]
    let onAccent: Bool

    var body: some View {
        HStack(spacing: 3) {
            ForEach(Array(colors.enumerated()), id: \.offset) { _, c in
                Circle()
                    .fill(onAccent ? Color.white.opacity(0.9) : c)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 6)
    }
}

// MARK: - 선택한 날의 일정 · 할 일

struct EventListView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        let sel = state.selected
        let holiday = prefs.holiday(state.holiday(on: sel))
        let events = state.events(on: sel)
        let reminders = state.reminders(on: sel)
        let isToday = DateUtil.isSameDay(sel, state.today)
        let empty = events.isEmpty && reminders.isEmpty && holiday == nil

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(DateUtil.dayHeader.string(from: sel))
                    .font(.system(size: 13.5, weight: .heavy))
                if isToday { TodayPill() }
                Spacer(minLength: 0)
            }

            if let holiday {
                Label(holiday, systemImage: "flag.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.sunday)
            }

            if empty {
                Text(state.calendarAuthorized ? "일정이 없어요 ✨" : "캘린더를 허용하면 일정이 보여요")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(events) { EventRow(event: $0) }
                        ForEach(reminders) { ReminderRow(reminder: $0) }
                    }
                }
                .frame(maxHeight: 148)
            }
        }
    }
}

struct TodayPill: View {
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        Text("오늘")
            .font(.system(size: 10.5, weight: .heavy))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(prefs.theme.gradient))
            .autoShimmer(active: prefs.sparkle.on,
                         period: prefs.sparkle == .lively ? 2.6 : 5.0,
                         dur: 0.8, strength: 0.6)
    }
}

struct EventRow: View {
    @EnvironmentObject private var prefs: Prefs
    let event: EventItem

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(event.color)
                .frame(width: 8, height: 8)
                .shadow(color: event.color.opacity(0.4), radius: 2)
            Text(event.isAllDay ? "종일" : DateUtil.timeFmt.string(from: event.start))
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(event.isAllDay ? prefs.theme.accent : Color.secondary)
                .frame(width: 58, alignment: .leading)
            Text(event.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
    }
}

struct ReminderRow: View {
    @EnvironmentObject private var state: AppState
    let reminder: ReminderItem

    var body: some View {
        HStack(spacing: 9) {
            Button {
                state.toggleReminder(reminder)
            } label: {
                Image(systemName: "circle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(reminder.color)
            }
            .buttonStyle(.plain)
            .help("완료로 표시")
            Text("할 일")
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)
            Text(reminder.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .padding(.horizontal, 6)
    }
}
