import Foundation

// BurstRaceTest 는 로직 사본을 돌리는 거라, 진짜 MenuBar.swift 가 예전 방식으로
// 되돌아가도 잡지 못한다. 그 구멍을 막는 게 이 가드다.
//
// 버스트 타이머 콜백을 Task 로 넘기면 invalidate() 가 이미 큐에 올라간 프레임을
// 막지 못해서, 반짝임을 끈 뒤에 광택이 다시 칠해지고 그대로 얼어붙는다.
// 타이머는 어차피 메인 런루프에서 도니 홉 없이 그 자리에서 처리해야 한다.

@MainActor
enum MenuBarSourceGuard {

    static func run() -> Bool {
        let path = MonggleTests.repoRoot + "/Sources/MenuBar.swift"
        guard let source = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("    ⚠️ \(path) 를 읽지 못함 — 저장소 루트에서 실행해야 한다")
            return false
        }

        guard let region = burstRegion(in: source) else {
            print("    ⚠️ scheduleBursts()~stopBurst() 구간을 찾지 못함 — 테스트를 손봐야 한다")
            return false
        }

        var ok = true

        if region.contains("Task {") {
            print("    ❌ 버스트 타이머가 Task 로 넘기고 있다 — 광택이 얼어붙는 회귀")
            ok = false
        }
        if !region.contains("MainActor.assumeIsolated") {
            print("    ❌ 타이머 콜백을 메인 액터에서 동기로 처리하고 있지 않다")
            ok = false
        }

        // paint() 는 반짝임이 꺼져 있으면 어떤 경로로 들어와도 광택을 얹지 않아야 한다
        if !source.contains("prefs.sparkle.on ? progress : nil") {
            print("    ❌ paint() 의 안전장치가 사라졌다")
            ok = false
        }

        if ok { print("    Task 홉 없음 · 동기 처리 · paint() 안전장치 모두 확인") }
        return ok
    }

    /// scheduleBursts() 선언부터 stopBurst() 선언 직전까지
    private static func burstRegion(in source: String) -> String? {
        guard let start = source.range(of: "private func scheduleBursts()"),
              let end = source.range(of: "private func stopBurst()"),
              start.upperBound < end.lowerBound else { return nil }
        return String(source[start.upperBound..<end.lowerBound])
    }
}
