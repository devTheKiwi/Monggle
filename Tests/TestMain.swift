import Foundation

// 몽글 회귀 테스트 — `make test`
//
// Xcode 프로젝트 없이 swiftc 로만 굽는 구조라 XCTest 를 쓸 수 없다.
// 대신 실패하면 0 이 아닌 코드로 끝나는 작은 실행 파일로 만들어 뒀다.
// 새 테스트는 Tests/ 에 파일을 하나 더 놓고 아래 check(...) 에 한 줄 추가하면 된다.

@main
enum MonggleTests {
    static func main() {
        MainActor.assumeIsolated {
            var failed: [String] = []

            func check(_ name: String, _ body: () -> Bool) {
                print("▶ \(name)")
                if body() {
                    print("  ✅ 통과\n")
                } else {
                    print("  ❌ 실패\n")
                    failed.append(name)
                }
            }

            check("반짝임을 끄면 메뉴바에 광택이 남지 않는다", BurstRaceTest.run)
            check("버스트 타이머가 비동기 홉을 쓰지 않는다", MenuBarSourceGuard.run)

            if failed.isEmpty {
                print("전부 통과 ✨")
                exit(0)
            }
            print("실패 \(failed.count)개 — \(failed.joined(separator: " / "))")
            exit(1)
        }
    }

    /// 테스트가 저장소 루트를 기준으로 소스를 읽을 수 있게. `make test` 는 루트에서 돈다.
    static var repoRoot: String {
        CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : FileManager.default.currentDirectoryPath
    }
}
