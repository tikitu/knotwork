import KnotworkIOS
import SwiftUI

/// The entire app target. Everything it does lives in `KnotworkIOS`, in the
/// package, where it can be built without the Xcode project.
@main
struct KnotworkApp: App {
    @UIApplicationDelegateAdaptor(KnotworkAppDelegate.self)
    private var delegate

    var body: some Scene { WindowGroup { RootView(model: delegate.model) } }
}
