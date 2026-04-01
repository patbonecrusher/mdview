import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    let config = AppConfig.shared
    var windows: [NSWindow: DocumentWindow] = [:]

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Parse CLI arguments
        var file: URL?
        let args = CommandLine.arguments
        var i = 1
        while i < args.count {
            let arg = args[i]
            switch arg {
            case "-t", "--theme":
                if i + 1 < args.count {
                    config.theme = Theme.fromName(args[i + 1])
                    i += 1
                }
            case "--font":
                if i + 1 < args.count {
                    config.fontFamily = args[i + 1]
                    i += 1
                }
            case "--font-size":
                if i + 1 < args.count {
                    if let v = UInt32(args[i + 1]) { config.fontSize = v }
                    i += 1
                }
            default:
                if !arg.hasPrefix("-") && !arg.hasPrefix("--") {
                    let absPath: String
                    if arg.hasPrefix("/") {
                        absPath = arg
                    } else {
                        absPath = (FileManager.default.currentDirectoryPath as NSString).appendingPathComponent(arg)
                    }
                    let url = URL(fileURLWithPath: absPath).standardized
                    if FileManager.default.fileExists(atPath: url.path) {
                        file = url
                    }
                }
            }
            i += 1
        }

        setupMenuBar()
        createWindow(file: file)
    }

    // Called when files are opened via Finder double-click or "Open With"
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let ext = url.pathExtension.lowercased()
            if ext == "md" || ext == "markdown" {
                openFileURL(url)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createWindow(file: nil)
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    // MARK: - Window Management

    @discardableResult
    func createWindow(file: URL?) -> NSWindow {
        let doc = DocumentWindow(file: file, config: config)

        let contentView = DocumentContentView(
            document: doc,
            onNavigate: { [weak self] url in
                self?.handleNavigation(url: url, from: doc)
            },
            onIPC: { [weak self] message in
                self?.handleIPC(message: message, from: doc)
            }
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.title = doc.windowTitle
        window.contentView = NSHostingView(rootView: contentView)
        window.delegate = self

        // Restore saved frame or position with cascade offset
        if let filePath = file?.path, let savedFrame = WindowFrameStore.shared.frame(for: filePath) {
            window.setFrame(savedFrame, display: true)
        } else {
            window.center()
            cascadeFromExistingWindows(window)
        }

        windows[window] = doc

        // Observe title changes
        doc.$htmlContent.receive(on: RunLoop.main).sink { [weak window, weak doc] _ in
            guard let window = window, let doc = doc else { return }
            window.title = doc.windowTitle
        }.store(in: &doc.cancellables)

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        return window
    }

    private func cascadeFromExistingWindows(_ window: NSWindow) {
        // Find the topmost existing window to cascade from
        let otherWindows = windows.keys.filter { $0 !== window && $0.isVisible }
        guard let topWindow = otherWindows.max(by: { $0.orderedIndex > $1.orderedIndex }) else { return }
        let offset: CGFloat = 26
        let origin = NSPoint(
            x: topWindow.frame.origin.x + offset,
            y: topWindow.frame.origin.y - offset
        )
        window.setFrameOrigin(origin)
    }

    func openFileURL(_ url: URL) {
        let resolved = url.standardized

        // Reuse a welcome window if available
        if let (window, doc) = windows.first(where: { $0.value.isWelcome }) {
            doc.openFile(resolved)
            window.title = doc.windowTitle
            // Restore saved frame for this file
            if let savedFrame = WindowFrameStore.shared.frame(for: resolved.path) {
                window.setFrame(savedFrame, display: true)
            }
            window.makeKeyAndOrderFront(nil)
            return
        }

        createWindow(file: resolved)
    }

    private func handleNavigation(url: URL, from doc: DocumentWindow) {
        if FileManager.default.fileExists(atPath: url.path) {
            doc.openFile(url)
            // Update window title
            if let (window, _) = windows.first(where: { $0.value.id == doc.id }) {
                window.title = doc.windowTitle
            }
        }
    }

    private func handleIPC(message: String, from doc: DocumentWindow) {
        if message.hasPrefix("settings:") {
            let json = String(message.dropFirst("settings:".count))
            doc.applySettings(json: json)

            // Refresh all other windows too
            for (window, otherDoc) in windows where otherDoc.id != doc.id {
                otherDoc.reload()
                window.title = otherDoc.windowTitle
            }

            // Update this window's title
            if let (window, _) = windows.first(where: { $0.value.id == doc.id }) {
                window.title = doc.windowTitle
            }
        }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About MdViewer", action: #selector(showAbout), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings...", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        let servicesMenu = NSMenu(title: "Services")
        let servicesItem = appMenu.addItem(withTitle: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide MdViewer", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit MdViewer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "New Window", action: #selector(newWindow), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open...", action: #selector(openFile), keyEquivalent: "o")
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        mainMenu.addItem(fileMenuItem)

        // Edit menu
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenu = NSMenu(title: "View")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Reload", action: #selector(reloadView), keyEquivalent: "r")
        viewMenu.addItem(.separator())
        viewMenu.addItem(withTitle: "Zoom In", action: #selector(zoomIn), keyEquivalent: "=")
        viewMenu.addItem(withTitle: "Zoom Out", action: #selector(zoomOut), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Actual Size", action: #selector(zoomReset), keyEquivalent: "0")
        viewMenu.addItem(.separator())
        let fullScreenItem = viewMenu.addItem(withTitle: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        fullScreenItem.keyEquivalentModifierMask = [.command, .control]
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
    }

    // MARK: - Menu Actions

    private var focusedDocument: DocumentWindow? {
        guard let window = NSApp.keyWindow else { return nil }
        return windows[window]
    }

    @objc func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "MdViewer",
            .applicationVersion: "0.1.0",
            .version: "0.1.0",
            .credits: NSAttributedString(string: "A markdown viewer with diagram support"),
        ])
    }

    @objc func showSettings() {
        SettingsWindowController.shared.show(config: config) { [weak self] in
            self?.refreshAllWindows()
        }
    }

    private func refreshAllWindows() {
        for (window, doc) in windows {
            doc.reload()
            window.title = doc.windowTitle
        }
    }

    @objc func newWindow() {
        createWindow(file: nil)
    }

    @objc func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            .init(filenameExtension: "md")!,
            .init(filenameExtension: "markdown")!,
        ]
        panel.allowsMultipleSelection = false
        panel.title = "Open Markdown File"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFileURL(url)
    }

    @objc func reloadView() {
        focusedDocument?.reload()
        if let window = NSApp.keyWindow {
            window.title = focusedDocument?.windowTitle ?? "MdViewer"
        }
    }

    @objc func zoomIn() {
        guard let doc = focusedDocument else { return }
        doc.zoomLevel = min(doc.zoomLevel * 1.1, 5.0)
    }

    @objc func zoomOut() {
        guard let doc = focusedDocument else { return }
        doc.zoomLevel = max(doc.zoomLevel / 1.1, 0.3)
    }

    @objc func zoomReset() {
        focusedDocument?.zoomLevel = 1.0
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if let doc = windows[window] {
            saveWindowFrame(window)
            doc.fileWatcher?.stop()
            doc.cancellables.removeAll()
        }
        window.delegate = nil
        // Defer removal so the window stays alive through the close animation;
        // releasing it synchronously causes a use-after-free in _NSWindowTransformAnimation.
        DispatchQueue.main.async { [weak self] in
            self?.windows.removeValue(forKey: window)
        }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              windows[window] != nil else { return }
        saveWindowFrame(window)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              windows[window] != nil else { return }
        saveWindowFrame(window)
    }

    private func saveWindowFrame(_ window: NSWindow) {
        guard let doc = windows[window],
              let filePath = doc.currentFile?.path else { return }
        WindowFrameStore.shared.save(frame: window.frame, for: filePath)
    }
}
