import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {

  override func applicationDidFinishLaunching(_ notification: Notification) {
    // Ignore SIGPIPE — when launched via Finder/Dock there is no terminal
    // to receive stdout/stderr, so writes to those file descriptors raise
    // SIGPIPE and kill the process. This is a well-known macOS issue with
    // headless GUI apps that write to stdout.
    signal(SIGPIPE, SIG_IGN)
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
