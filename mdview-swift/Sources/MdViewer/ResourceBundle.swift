import Foundation

/// Resolves the resource bundle, checking both the SPM default location
/// and Contents/Resources/ inside an app bundle (where bundle.sh places it).
let resourceBundle: Bundle = {
    let bundleName = "MdViewer_MdViewer"

    // 1. SPM default: next to the executable / Bundle.main root
    let mainPath = Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle").path
    if let bundle = Bundle(path: mainPath) {
        return bundle
    }

    // 2. App bundle: Contents/Resources/
    if let resourceURL = Bundle.main.resourceURL {
        let resourcePath = resourceURL.appendingPathComponent("\(bundleName).bundle").path
        if let bundle = Bundle(path: resourcePath) {
            return bundle
        }
    }

    // 3. Fallback to Bundle.module (SPM auto-generated, includes hardcoded build path)
    return Bundle.module
}()
