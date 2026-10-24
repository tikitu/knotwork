import CommandInbox
import UI
import UIKit

/// Owns the model, and starts the command inbox when asked to.
///
/// The inbox starts here rather than in a view's `.task`, so that a script
/// can drive the app from launch, whatever is or is not on screen.
@MainActor
public final class KnotworkAppDelegate: NSObject, UIApplicationDelegate {
    public let model = AppModel()

    /// Commands from scripts, only under `--accept-commands`, so the app on a
    /// phone never listens (docs/commands.md). Held here for the app's
    /// lifetime: the inbox stops hearing its notification once released.
    private var commandInbox: CommandInbox<AppCommand>?

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if ProcessInfo.processInfo.arguments.contains("--accept-commands") {
            let model = model
            commandInbox = CommandInbox(
                directory: InboxDirectory.applicationSupport,
                notificationName: "org.logophile.Knotwork.commands"
            ) { CommandReply(try model.perform($0)) }
            commandInbox?.start()
        }
        return true
    }
}
