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
        installEditMenu()   // 이게 있어야 텍스트 칸에서 Cmd+C/V/X 가 먹음

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

    /// accessory 앱은 기본 메뉴바가 없어서 Cmd+C/V/X/A·실행취소가 텍스트 칸에 안 먹는다.
    /// 화면엔 안 보이지만 편집 메뉴를 심어두면 단축키가 응답 체인으로 전달됨.
    private func installEditMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        appMenu.addItem(withTitle: "몽글 종료",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "편집")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "실행 취소", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "실행 복귀", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "잘라내기", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "복사", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "붙여넣기", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "전체 선택", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        NSApp.mainMenu = mainMenu
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
