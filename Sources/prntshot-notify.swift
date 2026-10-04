// prntshot-notify — post a single macOS notification and exit.
//
// Why this exists: `osascript -e 'display notification'` run from an Automator
// Quick Action is attributed to Automator, which never registers with the
// notification system, so the banner is silently dropped (osascript still exits
// 0, so it looks like it worked). A real app bundle with its own bundle
// identifier registers properly and can be enabled in System Settings.
//
// Usage:  open -a prntshot-notify.app --args "Title" "Message"
//
// Launched via LaunchServices on purpose: executing the binary directly would
// inherit the calling process' identity and reintroduce the same problem.

import Foundation
import UserNotifications

let args = Array(CommandLine.arguments.dropFirst())
let title = args.first ?? "prnt.li"
let message = args.count > 1 ? args[1] : ""

func fail(_ code: Int32, _ note: String) -> Never {
    FileHandle.standardError.write("prntshot-notify: \(note)\n".data(using: .utf8)!)
    exit(code)
}

let center = UNUserNotificationCenter.current()

var done = false
func finish(_ code: Int32) {
    if done { return }
    done = true
    exit(code)
}

center.requestAuthorization(options: [.alert, .sound]) { granted, error in
    if let error {
        fail(3, "authorization error: \(error.localizedDescription)")
    }
    guard granted else {
        // The user has not allowed notifications for this app yet.
        fail(4, "not authorized")
    }

    let content = UNMutableNotificationContent()
    content.title = title
    content.body = message
    content.sound = .default

    let request = UNNotificationRequest(
        identifier: UUID().uuidString,
        content: content,
        trigger: nil
    )
    center.add(request) { addError in
        if let addError {
            fail(5, "could not post: \(addError.localizedDescription)")
        }
        finish(0)
    }
}

// The callbacks above are asynchronous; keep the process alive long enough to
// run them, but never hang indefinitely.
RunLoop.main.run(until: Date().addingTimeInterval(10))
fail(6, "timed out")
