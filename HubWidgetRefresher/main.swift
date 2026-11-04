import Foundation

// The app and widget are sandboxed and cannot signal other processes, so this does it for them once
// after an update: macOS re-reads the app's icon, and the widget host restarts on the new code.
let app = Bundle.main.bundleURL
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

func run(_ path: String, _ arguments: String...) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = arguments
    try? process.run()
    process.waitUntilExit()
}

run("/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", "-f", app.path)
run("/usr/bin/touch", app.path)
run("/usr/bin/killall", "NotificationCenter")
run("/usr/bin/killall", "chronod")
