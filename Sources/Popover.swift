import SwiftUI
import AppKit

// MARK: - 팝오버 전체

struct CalendarPopover: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs
    @EnvironmentObject private var updater: Updater

    var body: some View {
        VStack(spacing: 10) {
            if updater.showsBanner { UpdateBanner() }
            HeaderView()
            WeekdayRow()
            MonthGridView()
            Rectangle()
                .fill(prefs.skin.hairline)
                .frame(height: 1)
            EventListView()
        }
        .padding(14)
        .frame(width: 300)
        .fontDesign(.rounded)
        .background(
            SkinBackground(skin: prefs.skin, theme: prefs.theme, animate: prefs.sparkle.on)
        )
    }
}

// MARK: - 업데이트 배너

struct UpdateBanner: View {
    @EnvironmentObject private var updater: Updater
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        Group {
            switch updater.phase {
            case .available(let r): available(r)
            case .downloading:      busy("새 버전 내려받는 중…")
            case .installing:       busy("설치하고 곧 다시 켜질 거예요…")
            default:                EmptyView()
            }
        }
    }

    private func available(_ r: Release) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(prefs.theme.gradient)
                .autoShimmer(active: prefs.sparkle.on, period: 2.6, dur: 0.9, strength: 0.6)

            VStack(alignment: .leading, spacing: 0) {
                Text("새 버전 \(r.version)")
                    .font(.system(size: 12.5, weight: .heavy))
                Text("지금 업데이트할 수 있어요")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)

            Button("업데이트") { updater.install(r) }
                .buttonStyle(.borderedProminent)
                .tint(prefs.theme.accent)
                .controlSize(.small)
                .font(.system(size: 11, weight: .bold))

            Button { updater.dismissed = true } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(3)
            }
            .buttonStyle(.plain)
            .help("나중에")
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(prefs.theme.accent.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(prefs.theme.accent.opacity(0.4), lineWidth: 1)
        )
    }

    private func busy(_ label: String) -> some View {
        HStack(spacing: 9) {
            ProgressView().controlSize(.small)
            Text(label).font(.system(size: 11.5, weight: .semibold))
            Spacer(minLength: 0)
        }
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }
}

// MARK: - 헤더 (달 이동 · 오늘 · 설정)

struct HeaderView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs
    @EnvironmentObject private var updater: Updater

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
                SettingsWindow.shared.show(state: state, prefs: prefs, updater: updater)
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
    @State private var composing = false

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
                if state.calendarAuthorized {
                    HoverButton {
                        withAnimation(.easeOut(duration: 0.15)) { composing.toggle() }
                    } label: {
                        Image(systemName: composing ? "xmark" : "plus")
                            .font(.system(size: 11, weight: .heavy))
                            .frame(width: 22, height: 22)
                            .foregroundStyle(prefs.theme.accent)
                    }
                    .help(composing ? "취소" : "일정 추가")
                }
            }

            if let holiday {
                Label(holiday, systemImage: "flag.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Palette.sunday)
            }

            if composing {
                ComposeEventView(day: sel) {
                    withAnimation(.easeOut(duration: 0.15)) { composing = false }
                }
            } else if empty {
                EmptyDayView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(events) { EventRow(event: $0) }
                        ForEach(reminders) { ReminderRow(reminder: $0) }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxHeight: 168)
            }
        }
        .onChange(of: state.selected) { composing = false }
    }
}

// MARK: - 일정 추가 폼

struct ComposeEventView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs
    let day: Date
    let done: () -> Void

    @State private var title = ""
    @State private var allDay = false
    @State private var start = Date()
    @State private var end = Date()
    @State private var calendarID: String?
    @State private var error: String?
    @State private var loaded = false
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            TextField("무슨 일정인가요?", text: $title)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12.5))
                .focused($focused)
                .onSubmit(save)

            Toggle("종일", isOn: $allDay)
                .toggleStyle(.checkbox)
                .font(.system(size: 11.5, weight: .semibold))

            if !allDay {
                // 애플 캘린더처럼 직접 타이핑하거나 화살표로 올리고 내림
                timeField("시작", $start)
                timeField("종료", $end)
            }

            HStack(spacing: 6) {
                Menu {
                    ForEach(state.eventCalendars) { c in
                        Button {
                            calendarID = c.id
                        } label: {
                            Label(c.title, systemImage: "circle.fill")
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(selectedCalendar?.color ?? prefs.theme.accent)
                            .frame(width: 7, height: 7)
                        Text(selectedCalendar?.title ?? "캘린더")
                            .font(.system(size: 11.5, weight: .semibold))
                            .lineLimit(1)
                    }
                }
                .menuStyle(.button)
                .buttonStyle(.borderless)
                .frame(maxWidth: 130, alignment: .leading)

                Spacer(minLength: 0)

                Button("추가", action: save)
                    .font(.system(size: 12, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .tint(prefs.theme.accent)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let error {
                Text(error)
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Palette.sunday)
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            let s = defaultStart()
            start = s
            end = s.addingTimeInterval(3600)
            calendarID = state.defaultCalendarID
            focused = true
            // onAppear 에서 넣은 값 때문에 아래 onChange 가 도는 걸 피하려고 한 박자 뒤에
            DispatchQueue.main.async { loaded = true }
        }
        .onChange(of: start) { old, new in
            // 시작을 옮기면 길이를 유지한 채 종료도 같이 옮김 (애플 캘린더와 같은 동작)
            guard loaded, old != new else { return }
            end = end.addingTimeInterval(new.timeIntervalSince(old))
        }
    }

    private func timeField(_ label: String, _ value: Binding<Date>) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, alignment: .leading)
            DatePicker("", selection: value, displayedComponents: .hourAndMinute)
                .datePickerStyle(.stepperField)
                .labelsHidden()
                .font(.system(size: 12))
            Spacer(minLength: 0)
        }
    }

    private var selectedCalendar: CalendarChoice? {
        state.eventCalendars.first { $0.id == calendarID }
    }

    /// 오늘이면 다음 정각/30분, 다른 날이면 오전 9시
    private func defaultStart() -> Date {
        let cal = DateUtil.cal
        if DateUtil.isSameDay(day, state.today) {
            let now = Date()
            let m = cal.component(.minute, from: now)
            let bump = m < 30 ? 30 - m : 60 - m
            return cal.date(bySetting: .second, value: 0,
                            of: cal.date(byAdding: .minute, value: bump, to: now) ?? now) ?? now
        }
        return cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
    }

    /// 시/분만 떼어내 선택한 날짜에 붙임
    private func onSelectedDay(_ time: Date) -> Date {
        let hm = DateUtil.cal.dateComponents([.hour, .minute], from: time)
        return DateUtil.cal.date(bySettingHour: hm.hour ?? 9, minute: hm.minute ?? 0,
                                 second: 0, of: day) ?? day
    }

    private func save() {
        let name = title.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        // 시각 피커는 시/분만 고르니 날짜는 선택한 날로 옮겨 붙임
        let from = onSelectedDay(start)
        let to = onSelectedDay(end)

        if let message = state.addEvent(title: name, start: from, end: to,
                                        allDay: allDay, calendarID: calendarID) {
            error = message
        } else {
            done()
        }
    }
}

struct EmptyDayView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(prefs.theme.accent.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: state.calendarAuthorized ? "cup.and.saucer.fill" : "lock.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(prefs.theme.accent)
            }
            .autoShimmer(active: prefs.sparkle.on, period: 5.0, dur: 0.9, strength: 0.5)

            Text(state.calendarAuthorized ? "오늘은 비어 있어요" : "캘린더를 허용하면 일정이 보여요")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
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
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs
    let event: EventItem
    @State private var hovering = false

    var body: some View {
        Button {
            PopoverBridge.close?()
            state.openInCalendar(event)
        } label: {
            content
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("캘린더 앱에서 열기")
    }

    private var content: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(event.color)
                .frame(width: 3.5)
                .shadow(color: event.color.opacity(0.5), radius: 2)

            if event.isAllDay {
                Text("종일")
                    .font(.system(size: 10.5, weight: .heavy))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(event.color))
                    .frame(width: 52, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    Text(DateUtil.timeFmt.string(from: event.start))
                        .font(.system(size: 11.5, weight: .bold))
                    if event.hasDuration {
                        Text(DateUtil.timeFmt.string(from: event.end))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.secondary)
                .frame(width: 52, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    CategoryTag(name: event.category, color: event.color)
                    if let place = event.location {
                        Text("·").foregroundStyle(.quaternary)
                        Label(place, systemImage: "mappin")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.forward.app")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .opacity(hovering ? 1 : 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(hovering ? prefs.theme.accent.opacity(0.14) : prefs.skin.rowFill)
        )
        .contentShape(Rectangle())
    }
}

/// 일정이 속한 캘린더(카테고리)를 색 점과 함께
struct CategoryTag: View {
    let name: String
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 5, height: 5)
            Text(name)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
                .lineLimit(1)
        }
    }
}

struct ReminderRow: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var prefs: Prefs
    let reminder: ReminderItem
    @State private var done = false

    var body: some View {
        HStack(spacing: 9) {
            Capsule()
                .fill(reminder.color.opacity(0.55))
                .frame(width: 3.5)

            Button {
                withAnimation(.easeOut(duration: 0.2)) { done = true }
                state.toggleReminder(reminder)
            } label: {
                Image(systemName: done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(reminder.color)
            }
            .buttonStyle(.plain)
            .help("완료로 표시")

            VStack(alignment: .leading, spacing: 1) {
                Text(reminder.title)
                    .font(.system(size: 13, weight: .semibold))
                    .strikethrough(done, color: .secondary)
                    .opacity(done ? 0.45 : 1)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("할 일")
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(.tertiary)
                    Text("·").foregroundStyle(.quaternary)
                    CategoryTag(name: reminder.category, color: reminder.color)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous).fill(prefs.skin.rowFill)
        )
    }
}
