import AppKit
import SpacestratorKit

// Handle terminal subcommands first (these print and exit without launching the UI).
let args = Array(CommandLine.arguments.dropFirst())
if args.contains("--help") || args.contains("-h") { CLI.printHelp(); exit(0) }
if args.contains("--version") || args.contains("-v") { CLI.printVersion(); exit(0) }
if args.contains("--status") { CLI.printStatus(); exit(0) }

// Normal launch: print the banner (styled when run from a terminal), then run the
// menu-bar app. As a .app bundle there's no TTY, so the banner output just goes
// nowhere and Spacestrator simply appears in the menu bar.
CLI.printBanner()

// Menu-bar-only agent: no Dock icon, no main window.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
