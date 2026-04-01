import SwiftUI
import WebKit

struct MarkdownWebView: NSViewRepresentable {
    @ObservedObject var document: DocumentWindow
    let onNavigate: (URL) -> Void
    let onIPC: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "ipc")
        config.userContentController = userContentController

        // Allow file:// access for local images
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        webView.loadHTMLString(document.htmlContent, baseURL: nil)
        context.coordinator.lastHTML = document.htmlContent

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onNavigate = onNavigate
        context.coordinator.onIPC = onIPC

        // Reload HTML if content changed
        if context.coordinator.lastHTML != document.htmlContent {
            context.coordinator.lastHTML = document.htmlContent
            webView.loadHTMLString(document.htmlContent, baseURL: nil)
            // Re-apply zoom after page loads
            context.coordinator.pendingZoom = document.zoomLevel
        }

        // Apply zoom immediately (also handles zoom-only changes)
        webView.pageZoom = document.zoomLevel
    }

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(onNavigate: onNavigate, onIPC: onIPC)
    }
}

class WebViewCoordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var onNavigate: (URL) -> Void
    var onIPC: (String) -> Void
    var lastHTML: String = ""
    var pendingZoom: Double?
    weak var webView: WKWebView?

    init(onNavigate: @escaping (URL) -> Void, onIPC: @escaping (String) -> Void) {
        self.onNavigate = onNavigate
        self.onIPC = onIPC
    }

    // MARK: - WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Re-apply zoom after page finishes loading (loadHTMLString resets it)
        if let zoom = pendingZoom {
            webView.pageZoom = zoom
            pendingZoom = nil
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if url.scheme == "mdview" {
            if url.host == "open",
               let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let fileParam = components.queryItems?.first(where: { $0.name == "file" })?.value {
                let fileURL = URL(fileURLWithPath: fileParam)
                onNavigate(fileURL)
            }
            decisionHandler(.cancel)
            return
        }

        if url.scheme == "about" || url.scheme == "data" || url.scheme == "file" {
            decisionHandler(.allow)
            return
        }

        if url.scheme == "http" || url.scheme == "https" {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == "ipc", let body = message.body as? String else { return }
        onIPC(body)
    }
}
