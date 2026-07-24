import SwiftUI
import EventKit
import ServiceManagement
import AppKit

struct EventItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let color: Color
    let itemID: String
    /// 이 일정이 속한 캘린더(카테고리) 이름
    let category: String

    /// 시작과 끝이 사실상 같으면 종료 시각을 굳이 안 보여줌
    var hasDuration: Bool { end.timeIntervalSince(start) > 60 }
}

/// 새 일정을 넣을 캘린더 고를 때 쓰는 값 (뷰가 EventKit 을 몰라도 되게)
struct CalendarChoice: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
}

struct ReminderItem: Identifiable {
    let id: String
    let title: String
    let color: Color
    /// 이 할 일이 속한 목록(카테고리) 이름
    let category: String
    let ek: EKReminder
}

@MainActor
final class AppState: ObservableObject {
    @Published var today = DateUtil.startOfDay(Date())
    @Published var visibleMonth = DateUtil.startOfMonth(Date())
    @Published var selected = DateUtil.startOfDay(Date())

    @Published var eventsByDay: [Date: [EventItem]] = [:]
    @Published var remindersByDay: [Date: [ReminderItem]] = [:]

    @Published var calendarAuthorized = false
    @Published var reminderAuthorized = false
    @Published var launchAtLogin = false

    private let store = EKEventStore()
    private var started = false
    private var midnightTimer: Timer?

    init() {
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: store, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.reload() }
        }
        Task { @MainActor in await self.start() }
    }

    // MARK: 시작

    func start() async {
        guard !started else { return }
        started = true
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
        await requestAccess()
        reload()
        scheduleMidnight()
    }

    func requestAccess() async {
        calendarAuthorized = (try? await store.requestFullAccessToEvents()) ?? false
        reminderAuthorized = (try? await store.requestFullAccessToReminders()) ?? false
    }

    // MARK: 데이터 로드

    func reload() {
        loadEvents()
        loadReminders()
    }

    private func visibleRange() -> (Date, Date) {
        let days = DateUtil.gridDays(for: visibleMonth)
        let start = days.first ?? visibleMonth
        let end = DateUtil.cal.date(byAdding: .day, value: 1, to: days.last ?? visibleMonth) ?? visibleMonth
        return (start, end)
    }

    private func loadEvents() {
        guard calendarAuthorized else { eventsByDay = [:]; return }
        let (start, end) = visibleRange()
        let pred = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        var map: [Date: [EventItem]] = [:]
        for e in store.events(matching: pred) {
            let day = DateUtil.startOfDay(e.startDate)
            let name = (e.title ?? "").isEmpty ? "(제목 없음)" : (e.title ?? "")
            let place = (e.location ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let item = EventItem(
                id: e.eventIdentifier ?? UUID().uuidString,
                title: name,
                start: e.startDate,
                end: e.endDate ?? e.startDate,
                isAllDay: e.isAllDay,
                location: place.isEmpty ? nil : place,
                color: Color(nsColor: e.calendar.color),
                itemID: e.calendarItemIdentifier,
                category: e.calendar.title
            )
            map[day, default: []].append(item)
        }
        for key in map.keys {
            map[key]?.sort {
                ($0.isAllDay ? 0 : 1, $0.start) < ($1.isAllDay ? 0 : 1, $1.start)
            }
        }
        eventsByDay = map
    }

    private func loadReminders() {
        guard reminderAuthorized else { remindersByDay = [:]; return }
        let (start, end) = visibleRange()
        let pred = store.predicateForIncompleteReminders(
            withDueDateStarting: start, ending: end, calendars: nil)
        store.fetchReminders(matching: pred) { [weak self] reminders in
            let list = reminders ?? []
            Task { @MainActor in
                guard let self else { return }
                var map: [Date: [ReminderItem]] = [:]
                for r in list {
                    guard let comps = r.dueDateComponents,
                          let due = DateUtil.cal.date(from: comps) else { continue }
                    let day = DateUtil.startOfDay(due)
                    let name = (r.title ?? "").isEmpty ? "(제목 없음)" : (r.title ?? "")
                    map[day, default: []].append(ReminderItem(
                        id: r.calendarItemIdentifier,
                        title: name,
                        color: Color(nsColor: r.calendar.color),
                        category: r.calendar.title,
                        ek: r))
                }
                self.remindersByDay = map
            }
        }
    }

    // MARK: 조회

    func events(on day: Date) -> [EventItem] { eventsByDay[DateUtil.startOfDay(day)] ?? [] }
    func reminders(on day: Date) -> [ReminderItem] { remindersByDay[DateUtil.startOfDay(day)] ?? [] }
    func holiday(on day: Date) -> String? { Holidays.name(for: day) }

    // MARK: 조작

    func select(_ day: Date) { selected = DateUtil.startOfDay(day) }

    func changeMonth(_ n: Int) {
        visibleMonth = DateUtil.addMonths(n, to: visibleMonth)
        reload()
    }

    func goToday() {
        today = DateUtil.startOfDay(Date())
        visibleMonth = DateUtil.startOfMonth(Date())
        selected = today
        reload()
    }

    func toggleReminder(_ item: ReminderItem) {
        item.ek.isCompleted = true
        try? store.save(item.ek, commit: true)
        loadReminders()
    }

    // MARK: 캘린더 앱으로 넘기기

    /// 캘린더 앱을 열어 그 일정으로 이동.
    /// `ical://ekevent/` 는 애플이 문서화한 스킴은 아니지만 Itsycal 등이 오래 쓰고 있는 방식.
    func openInCalendar(_ event: EventItem) {
        let stamp = DateUtil.icalStamp.string(from: event.start)
        let id = event.itemID.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed) ?? event.itemID

        let target = id.isEmpty
            ? "ical://"
            : "ical://ekevent/\(stamp)/\(id)?method=show&options=more"

        guard let url = URL(string: target) else { return }
        if !NSWorkspace.shared.open(url), let fallback = URL(string: "ical://") {
            NSWorkspace.shared.open(fallback)
        }
    }

    // MARK: 일정 추가

    /// 쓸 수 있는(읽기 전용이 아닌) 캘린더들
    var eventCalendars: [CalendarChoice] {
        guard calendarAuthorized else { return [] }
        return store.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .map { CalendarChoice(id: $0.calendarIdentifier,
                                  title: $0.title,
                                  color: Color(nsColor: $0.color)) }
            .sorted { $0.title < $1.title }
    }

    var defaultCalendarID: String? {
        store.defaultCalendarForNewEvents?.calendarIdentifier ?? eventCalendars.first?.id
    }

    /// 새 일정 저장. 실패하면 사용자에게 보여줄 메시지를 돌려줌.
    func addEvent(title: String, start: Date, end: Date,
                  allDay: Bool, calendarID: String?) -> String? {
        guard calendarAuthorized else { return "캘린더 권한이 없어요" }

        let target = store.calendars(for: .event).first {
            $0.calendarIdentifier == calendarID && $0.allowsContentModifications
        } ?? store.defaultCalendarForNewEvents
        guard let target else { return "쓸 수 있는 캘린더가 없어요" }

        let e = EKEvent(eventStore: store)
        e.title = title
        e.calendar = target
        e.isAllDay = allDay
        if allDay {
            e.startDate = DateUtil.startOfDay(start)
            e.endDate = DateUtil.startOfDay(start)
        } else {
            e.startDate = start
            // 종료가 시작보다 이르면 자정을 넘긴 걸로 봄
            e.endDate = end > start
                ? end
                : (DateUtil.cal.date(byAdding: .day, value: 1, to: end) ?? start)
        }

        do {
            try store.save(e, span: .thisEvent, commit: true)
            reload()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func setLaunchAtLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("몽글 로그인 시작 설정 실패: \(error.localizedDescription)")
        }
        launchAtLogin = (SMAppService.mainApp.status == .enabled)
    }

    // MARK: 자정 갱신

    private func scheduleMidnight() {
        midnightTimer?.invalidate()
        guard let next = DateUtil.cal.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 5),
            matchingPolicy: .nextTime
        ) else { return }
        let timer = Timer(fire: next, interval: 86400, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.today = DateUtil.startOfDay(Date())
                self.reload()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        midnightTimer = timer
    }
}
