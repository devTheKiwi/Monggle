import SwiftUI
import AppKit

// MARK: - 릴리스 정보

struct Release: Equatable {
    let version: String     // "v" 뗀 버전. 예: "1.1"
    let notes: String
    let page: URL
    let asset: URL?         // 첨부된 Monggle.zip
}

// MARK: - 업데이터
//
// GitHub Releases 를 확인해서 새 버전이 있으면 알려주고,
// 눌렀을 때 zip 을 받아 자기 자신을 교체한 뒤 새 버전으로 재실행한다.
//
// 공증(notarize)이 안 된 앱이라 "처음" 받을 때는 macOS 경고가 뜨지만,
// 업데이트 때는 새로 깐 앱의 격리 속성(quarantine)을 직접 벗겨서 경고 없이 실행된다.

@MainActor
final class Updater: ObservableObject {
    /// devTheKiwi/Monggle
    static let repo = "devTheKiwi/Monggle"

    enum Phase: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading
        case installing
        case failed(String)
    }

    @Published var phase: Phase = .idle
    @Published var dismissed = false     // 이번 세션에서 배너를 닫았는지
    @Published var autoCheck: Bool { didSet { UserDefaults.standard.set(autoCheck, forKey: "autoCheckUpdates") } }

    private var timer: Timer?

    init() {
        UserDefaults.standard.register(defaults: ["autoCheckUpdates": true])
        autoCheck = UserDefaults.standard.bool(forKey: "autoCheckUpdates")
    }

    var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    /// 배너에 띄울 새 버전 (있을 때만)
    var pending: Release? {
        if case .available(let r) = phase { return r }
        return nil
    }

    var showsBanner: Bool {
        switch phase {
        case .available:               return !dismissed
        case .downloading, .installing: return true
        default:                       return false
        }
    }

    // MARK: 시작

    func start() {
        if autoCheck { Task { await check(manual: false) } }
        // 오래 켜져 있어도 놓치지 않도록 6시간마다 한 번씩
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.autoCheck else { return }
                await self.check(manual: false)
            }
        }
    }

    // MARK: 확인

    func check(manual: Bool) async {
        switch phase {
        case .checking, .downloading, .installing: return
        default: break
        }
        phase = .checking
        do {
            if let release = try await fetchLatest(), isNewer(release.version, than: currentVersion) {
                dismissed = false
                phase = .available(release)
            } else {
                phase = manual ? .upToDate : .idle
            }
        } catch {
            phase = manual ? .failed(friendly(error)) : .idle
        }
    }

    private func fetchLatest() async throws -> Release? {
        let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.setValue("Monggle", forHTTPHeaderField: "User-Agent")   // GitHub 은 UA 없으면 거절
        req.cachePolicy = .reloadIgnoringLocalCacheData

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { return nil }
        if http.statusCode == 404 { return nil }        // 아직 릴리스가 하나도 없음
        guard http.statusCode == 200 else {
            throw Fail("서버 응답 \(http.statusCode)")
        }
        return parse(data)
    }

    private func parse(_ data: Data) -> Release? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let tag = (json["tag_name"] as? String) ?? ""
        let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        guard !version.isEmpty else { return nil }

        let notes = (json["body"] as? String) ?? ""
        let page = URL(string: (json["html_url"] as? String) ?? "")
            ?? URL(string: "https://github.com/\(Self.repo)/releases")!

        var asset: URL?
        if let assets = json["assets"] as? [[String: Any]] {
            let zip = assets.first { ($0["name"] as? String)?.hasSuffix(".zip") == true }
            asset = URL(string: (zip?["browser_download_url"] as? String) ?? "")
        }
        return Release(version: version, notes: notes, page: page, asset: asset)
    }

    /// "1.2.0" > "1.1.5" 같은 숫자 비교
    func isNewer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }
        let y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let xi = i < x.count ? x[i] : 0
            let yi = i < y.count ? y[i] : 0
            if xi != yi { return xi > yi }
        }
        return false
    }

    // MARK: 설치

    func install(_ release: Release) {
        guard let asset = release.asset else {
            // 첨부 zip 이 없으면 릴리스 페이지라도 열어줌
            NSWorkspace.shared.open(release.page)
            return
        }
        Task {
            phase = .downloading
            do {
                let zip = try await download(asset)
                phase = .installing
                try swap(zip: zip)
                // 성공하면 헬퍼가 앱을 종료시키고 새 버전을 띄우므로 여기 아래로 안 옴
            } catch {
                phase = .failed(friendly(error))
            }
        }
    }

    private func download(_ url: URL) async throws -> URL {
        var req = URLRequest(url: url)
        req.setValue("Monggle", forHTTPHeaderField: "User-Agent")

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
            throw Fail("다운로드에 실패했어요")
        }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MonggleUpdate-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let zip = dir.appendingPathComponent("Monggle.zip")
        try data.write(to: zip)
        return zip
    }

    private func swap(zip: URL) throws {
        let fm = FileManager.default
        let dir = zip.deletingLastPathComponent()
        let unpack = dir.appendingPathComponent("unpacked")

        // ditto 로 압축 해제 (앱 번들·서명 보존)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, unpack.path]
        try ditto.run()
        ditto.waitUntilExit()
        guard ditto.terminationStatus == 0 else { throw Fail("압축을 풀지 못했어요") }

        guard let newApp = findApp(in: unpack) else { throw Fail("업데이트 안에 앱이 없어요") }
        let newExec = newApp.appendingPathComponent("Contents/MacOS/Monggle")
        guard fm.fileExists(atPath: newExec.path) else { throw Fail("업데이트 파일이 손상됐어요") }

        let dest = Bundle.main.bundleURL      // 지금 실행 중인 위치
        let pid = ProcessInfo.processInfo.processIdentifier

        // 앱이 꺼지길 기다렸다가 교체하고 다시 켜는 헬퍼.
        // quarantine 을 벗겨서 공증 안 된 새 버전도 경고 없이 열리게 함.
        let script = """
        #!/bin/sh
        trap "" HUP
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        sleep 0.3
        rm -rf "$2"
        cp -R "$3" "$2" || exit 1
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        open "$2"
        """
        let scriptURL = dir.appendingPathComponent("swap.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = [scriptURL.path, String(pid), dest.path, newApp.path]
        try task.run()

        // 종료 → 헬퍼가 교체 후 새 버전 실행
        NSApp.terminate(nil)
    }

    private func findApp(in dir: URL) -> URL? {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return nil }
        if let app = items.first(where: { $0.pathExtension == "app" }) { return app }
        // __MACOSX 등 한 겹 더 들어간 경우
        for sub in items where (try? sub.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
            if let inner = try? fm.contentsOfDirectory(at: sub, includingPropertiesForKeys: nil),
               let app = inner.first(where: { $0.pathExtension == "app" }) {
                return app
            }
        }
        return nil
    }

    private func friendly(_ error: Error) -> String {
        if let f = error as? Fail { return f.message }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return "네트워크에 연결할 수 없어요" }
        return ns.localizedDescription
    }

    private struct Fail: Error { let message: String; init(_ m: String) { message = m } }
}
