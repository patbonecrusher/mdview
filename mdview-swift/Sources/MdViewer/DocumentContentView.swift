import SwiftUI

struct DocumentContentView: View {
    @ObservedObject var document: DocumentWindow
    let onNavigate: (URL) -> Void
    let onIPC: (String) -> Void

    var body: some View {
        MarkdownWebView(
            document: document,
            onNavigate: onNavigate,
            onIPC: onIPC
        )
        .frame(minWidth: 600, minHeight: 400)
    }
}
