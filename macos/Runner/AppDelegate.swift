import Cocoa
import FlutterMacOS
import Sparkle

@main
class AppDelegate: FlutterAppDelegate {

  private var updaterController: SPUStandardUpdaterController!

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Ignore SIGPIPE — when launched via Finder/Dock there is no terminal
    // to receive stdout/stderr, so writes to those file descriptors raise
    // SIGPIPE and kill the process. This is a well-known macOS issue with
    // headless GUI apps that write to stdout.
    signal(SIGPIPE, SIG_IGN)
    super.applicationDidFinishLaunching(notification)

    // Initialize Sparkle updater (checks for updates automatically on launch)
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )

    // Add "Check for Updates…" menu item to the app menu
    if let appMenu = NSApp.mainMenu?.items.first?.submenu {
      let updateItem = NSMenuItem(
        title: "Check for Updates…",
        action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
        keyEquivalent: ""
      )
      updateItem.target = updaterController
      // Insert after "About" (index 1 = separator after About)
      let insertIndex = min(2, appMenu.items.count)
      appMenu.insertItem(updateItem, at: insertIndex)
      appMenu.insertItem(NSMenuItem.separator(), at: insertIndex + 1)
    }
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
