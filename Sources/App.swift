import SwiftUI
import AppKit
import Combine

@main
enum Monggle {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)   // Dock 아이콘 없이 메뉴바에만
        app.run()
    }
}

/// 팝오버를 밖에서 닫아야 할 때 쓰는 통로 (설정 창 열 때 등)
enum PopoverBridge {
    @MainActor static var close: (() -> Void)?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let state = AppState()
    private let prefs = Prefs()
    private let updater = Updater()

    private var item: NSStatusItem!
    private var popover: NSPopover!
    private var bar: MenuBarController!
    private var bag: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover)

        let host = NSHostingController(
            rootView: CalendarPopover()
                .environmentObject(state)
                .environmentObject(prefs)
                .environmentObject(updater)
        )
        // 이게 없으면 팝오버가 SwiftUI 실제 높이를 몰라서 위아래가 잘림
        host.sizingOptions = [.preferredContentSize]

        popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = host

        bar = MenuBarController(item: item, state: state, prefs: prefs)
        bar.start()

        PopoverBridge.close = { [weak self] in self?.popover.performClose(nil) }

        applySkin()
        prefs.objectWillChange
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.applySkin() }
            }
            .store(in: &bag)

        updater.start()
    }

    /// 어두운 스킨이면 팝오버 외형까지 다크로 — 화살표와 모서리가 같이 어두워짐
    private func applySkin() {
        popover.appearance = prefs.skin.isDark ? NSAppearance(named: .darkAqua) : nil
    }

    @objc private func togglePopover() {
        guard let button = item.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
