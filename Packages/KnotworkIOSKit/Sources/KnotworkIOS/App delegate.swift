import UI
import UIKit

/// Owns the model, and starts the command inbox when asked to.
///
/// The inbox starts here rather than in a view's `.task`, so that a script
/// can drive the app from launch, whatever is or is not on screen.
@MainActor
public final class KnotworkAppDelegate: NSObject, UIApplicationDelegate {
    public let model = AppModel()

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if ProcessInfo.processInfo.arguments.contains(CommandInbox.launchArgument) {
            CommandInbox.shared.start(model: model)
        }
        return true
    }
}
