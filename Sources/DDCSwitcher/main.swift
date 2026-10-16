import AppKit
import Foundation

if CommandLine.arguments.contains("--self-test") { exit(runSelfTest()) }
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
let delegate = AppDelegate()
application.delegate = delegate
application.run()
