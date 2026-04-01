import SwiftUI

class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(config: AppConfig, onSave: @escaping () -> Void) {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let settingsView = SettingsView(config: config, onSave: onSave)
        let hostingView = NSHostingView(rootView: settingsView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MdViewer Settings"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        self.window = window
    }

    func close() {
        window?.close()
        window = nil
    }
}

struct SettingsView: View {
    @ObservedObject var config: AppConfig
    let onSave: () -> Void

    @State private var selectedTheme: Theme
    @State private var fontFamily: String
    @State private var fontSize: String
    @State private var codeFontFamily: String
    @State private var codeFontSize: String

    init(config: AppConfig, onSave: @escaping () -> Void) {
        self.config = config
        self.onSave = onSave
        _selectedTheme = State(initialValue: config.theme)
        _fontFamily = State(initialValue: config.fontFamily)
        _fontSize = State(initialValue: String(config.fontSize))
        _codeFontFamily = State(initialValue: config.codeFontFamily)
        _codeFontSize = State(initialValue: String(config.codeFontSize))
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            // Theme picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Theme").font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Theme.allCases, id: \.self) { theme in
                        ThemeCard(theme: theme, isSelected: selectedTheme == theme) {
                            selectedTheme = theme
                        }
                    }
                }
            }

            Divider()

            // Font settings
            VStack(alignment: .leading, spacing: 10) {
                Text("Fonts").font(.headline)

                HStack {
                    Text("Body Font:")
                        .frame(width: 90, alignment: .trailing)
                    TextField("System default", text: $fontFamily)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Body Size:")
                        .frame(width: 90, alignment: .trailing)
                    TextField("16", text: $fontSize)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("px")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("Code Font:")
                        .frame(width: 90, alignment: .trailing)
                    TextField("System default", text: $codeFontFamily)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Code Size:")
                        .frame(width: 90, alignment: .trailing)
                    TextField("14", text: $codeFontSize)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                    Text("px")
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Buttons
            HStack {
                Spacer()
                Button("Cancel") {
                    SettingsWindowController.shared.close()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    config.theme = selectedTheme
                    config.fontFamily = fontFamily
                    config.fontSize = UInt32(fontSize) ?? 16
                    config.codeFontFamily = codeFontFamily
                    config.codeFontSize = UInt32(codeFontSize) ?? 14
                    config.save()
                    onSave()
                    SettingsWindowController.shared.close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 380, minHeight: 300)
    }
}

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                previewRect
                    .frame(height: 40)
                    .cornerRadius(6)

                Text(theme.label)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewRect: some View {
        switch theme {
        case .auto:
            HStack(spacing: 0) {
                Color.white
                Color(nsColor: NSColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 1))
            }
            .overlay(Text("Auto").font(.caption2).foregroundColor(.gray))
        case .light:
            Color.white
                .border(Color.gray.opacity(0.2))
                .overlay(Text("Aa").foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.18)))
        case .dark:
            Color(nsColor: NSColor(red: 0.03, green: 0.07, blue: 0.11, alpha: 1))
                .overlay(Text("Aa").foregroundColor(Color(red: 0.89, green: 0.91, blue: 0.94)))
        case .modest:
            Color.white
                .border(Color.gray.opacity(0.1))
                .overlay(Text("Aa").font(.system(size: 11, weight: .light)).foregroundColor(Color(red: 0.27, green: 0.27, blue: 0.27)))
        case .modestDark:
            Color(nsColor: NSColor(red: 0.12, green: 0.12, blue: 0.12, alpha: 1))
                .overlay(Text("Aa").font(.system(size: 11, weight: .light)).foregroundColor(Color(red: 0.78, green: 0.78, blue: 0.78)))
        }
    }
}

private extension Theme {
    var label: String {
        switch self {
        case .auto: return "Auto (System)"
        case .light: return "Light"
        case .dark: return "Dark"
        case .modest: return "Modest"
        case .modestDark: return "Modest Dark"
        }
    }
}
