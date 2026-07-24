import SwiftUI
import EventKit
import ServiceManagement
import AppKit

struct EventItem: Identifiable {
    let id: String
    let title: String
    let start: Date
    let isAllDay: Bool
    let color: Color
}

struct ReminderItem: Identifiable {
    let id: String
    let title: String
    let color: Color
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
            let item = EventItem(
                id: e.eventIdentifier ?? UUID().uuidString,
                title: name,
                start: e.startDate,
                isAllDay: e.isAllDay,
                color: Color(nsColor: e.calendar.color)
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
