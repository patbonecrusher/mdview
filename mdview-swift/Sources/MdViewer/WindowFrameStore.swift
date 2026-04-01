import AppKit

/// Persists window frames (position + size) keyed by file path.
/// Stored as JSON in ~/.config/mdviewer/window_frames.json
class WindowFrameStore {
    static let shared = WindowFrameStore()

    private var frames: [String: [String: CGFloat]] = [:]
    private let path: URL

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".config/mdviewer")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.path = dir.appendingPathComponent("window_frames.json")
        load()
    }

    private func load() {
        guard let data = try? Data(contentsOf: path),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: [String: CGFloat]] else {
            return
        }
        frames = dict
    }

    private func persist() {
        guard let data = try? JSONSerialization.data(withJSONObject: frames, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? data.write(to: path, options: .atomic)
    }

    func save(frame: NSRect, for filePath: String) {
        frames[filePath] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "w": frame.size.width,
            "h": frame.size.height,
        ]
        persist()
    }

    func frame(for filePath: String) -> NSRect? {
        guard let dict = frames[filePath],
              let x = dict["x"], let y = dict["y"],
              let w = dict["w"], let h = dict["h"] else {
            return nil
        }
        return NSRect(x: x, y: y, width: w, height: h)
    }
}
