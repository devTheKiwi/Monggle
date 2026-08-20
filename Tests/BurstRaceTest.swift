import Foundation

// 반짝임을 끄는 순간 메뉴바 광택이 그대로 얼어붙던 회귀 (v1.3 에서 수정).
//
// MenuBarController 의 버스트 타이머 구조만 그대로 옮겨 온 것이다.
// 원본은 NSStatusItem 에 그리기 때문에 헤드리스로 돌릴 수 없어서, paint() 를
// "무엇을 그렸는지 기록만" 하도록 바꿔 마지막에 무엇이 남는지를 본다.
//
// ⚠️ 이건 로직 '사본' 이라 MenuBar.swift 가 예전 방식으로 되돌아가도 여기선 안 잡힌다.
//    진짜 소스를 지키는 건 MenuBarSourceGuard 쪽이다. 둘이 한 쌍으로 동작한다.

@MainActor
enum BurstRaceTest {

    /// 예전 코드(비동기 홉)는 광택을 남긴 채 멈추고, 지금 코드는 항상 깨끗이 지워져야 한다.
    static func run() -> Bool {
        let oldFroze = (0..<5).contains { _ in scenario(asyncHop: true).last != .clear }
        let newFroze = (0..<5).contains { _ in scenario(asyncHop: false).last != .clear }

        print("    예전 방식(Task 홉)  마지막 3프레임: \(describe(scenario(asyncHop: true)))")
        print("    지금 방식(동기 처리) 마지막 3프레임: \(describe(scenario(asyncHop: false)))")

        if !oldFroze {
            print("    ⚠️ 재현이 안 됨 — 이 테스트가 더 이상 레이스를 만들어내지 못한다는 뜻")
            return false
        }
        if newFroze {
            print("    ⚠️ 지금 코드에서 광택이 남았다 — 회귀!")
            return false
        }
        return true
    }

    // MARK: 재현

    private enum Painted: Equatable { case clear, shine(Double) }

    private static func describe(_ log: [Painted]) -> String {
        log.suffix(3).map {
            if case .shine(let p) = $0 { return String(format: "광택%.2f", p) }
            return "지움"
        }.joined(separator: " → ")
    }

    /// 반짝임이 도는 도중에 '끔' 을 누르는 상황을 한 번 재현하고, 그린 순서를 돌려준다.
    private static func scenario(asyncHop: Bool) -> [Painted] {
        let rig = Rig(asyncHop: asyncHop)
        rig.runBurst()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))   // 반짝임 진행 중

        // Prefs.objectWillChange -> DispatchQueue.main.async { scheduleBursts() } 와 같은 경로
        DispatchQueue.main.async { rig.stopBurst() }
        // 클릭 처리로 메인스레드가 잠깐 바쁜 상황. 그 사이 프레임 타이머가 만기된다.
        let busyUntil = Date().addingTimeInterval(0.06)
        while Date() < busyUntil { }

        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        return rig.log
    }

    @MainActor
    private final class Rig {
        private let asyncHop: Bool
        private var frameTimer: Timer?
        private var frame = 0
        private let total = 30
        private(set) var log: [Painted] = []

        init(asyncHop: Bool) { self.asyncHop = asyncHop }

        func paint(_ p: Double?) { log.append(p.map(Painted.shine) ?? .clear) }

        func runBurst() {
            frameTimer?.invalidate()
            frame = 0
            let asyncHop = self.asyncHop
            frameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24, repeats: true) { [weak self] t in
                if asyncHop {
                    Task { @MainActor in
                        guard let self else { t.invalidate(); return }
                        self.tick(t)
                    }
                } else {
                    MainActor.assumeIsolated {
                        guard let self else { t.invalidate(); return }
                        self.tick(t)
                    }
                }
            }
        }

        private func tick(_ t: Timer) {
            frame += 1
            if frame >= total { t.invalidate(); stopBurst() }
            else { paint(Double(frame) / Double(total)) }
        }

        func stopBurst() {
            frameTimer?.invalidate()
            frameTimer = nil
            paint(nil)
        }
    }
}
