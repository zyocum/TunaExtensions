import AppKit
import Foundation

/// How a terminal app is told which folder to start in.
enum TerminalLaunchMethod: Sendable, Equatable {
  /// The app declares folders as a document type and opens a shell in the folder it is handed.
  case openFolder
  /// The app opens a URL built from this prefix and a percent-encoded folder path.
  case url(prefix: String)
  /// The app is launched as a new process with these arguments followed by the folder path.
  case arguments([String])
  /// Like `.arguments`, but first asks a running instance to open the window over its socket.
  case messageThenArguments(executable: String, message: [String], arguments: [String])
}

struct TerminalApp: Sendable {
  let actionID: String
  let name: String
  let bundleIdentifier: String
  let launchMethod: TerminalLaunchMethod

  static let alacritty = TerminalApp(
    actionID: "open-in-alacritty",
    name: "Alacritty",
    bundleIdentifier: "org.alacritty",
    launchMethod: .messageThenArguments(
      executable: "alacritty",
      message: ["msg", "create-window", "--working-directory"],
      arguments: ["--working-directory"]
    )
  )
  static let ghostty = TerminalApp(
    actionID: "open-in-ghostty", name: "Ghostty", bundleIdentifier: "com.mitchellh.ghostty",
    launchMethod: .openFolder)
  static let iTerm2 = TerminalApp(
    actionID: "open-in-iterm2", name: "iTerm2", bundleIdentifier: "com.googlecode.iterm2",
    launchMethod: .openFolder)
  static let kitty = TerminalApp(
    actionID: "open-in-kitty", name: "kitty", bundleIdentifier: "net.kovidgoyal.kitty",
    launchMethod: .openFolder)
  static let terminal = TerminalApp(
    actionID: "open-in-terminal", name: "Terminal", bundleIdentifier: "com.apple.Terminal",
    launchMethod: .openFolder)
  static let warp = TerminalApp(
    actionID: "open-in-warp", name: "Warp", bundleIdentifier: "dev.warp.Warp-Stable",
    launchMethod: .url(prefix: "warp://action/new_window?path="))
  // `wezterm-gui start` hands the window to a running WezTerm unless the configs differ.
  // Opening a folder would instead type its path into a new shell.
  static let wezTerm = TerminalApp(
    actionID: "open-in-wezterm", name: "WezTerm", bundleIdentifier: "com.github.wez.wezterm",
    launchMethod: .arguments(["start", "--cwd"]))

  static let all = [alacritty, ghostty, iTerm2, kitty, terminal, warp, wezTerm]

  var applicationURL: URL? {
    NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
  }

  /// Opens one window per folder. Returns an error message, or nil on success.
  @MainActor
  func open(_ folders: [URL], applicationURL: URL) async -> String? {
    switch launchMethod {
    case .openFolder:
      let configuration = NSWorkspace.OpenConfiguration()
      configuration.activates = true
      do {
        _ = try await NSWorkspace.shared.open(
          folders, withApplicationAt: applicationURL, configuration: configuration)
      } catch {
        return error.localizedDescription
      }
    case .url(let prefix):
      for folder in folders {
        guard let url = Self.url(prefix: prefix, folder: folder) else {
          return "Could not build a \(name) link for \(folder.path)"
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        do {
          _ = try await NSWorkspace.shared.open(
            [url], withApplicationAt: applicationURL, configuration: configuration)
        } catch {
          return error.localizedDescription
        }
      }
    case .arguments(let arguments):
      for folder in folders {
        if let message = await launchNewInstance(
          applicationURL, arguments: arguments + [folder.path])
        {
          return message
        }
      }
    case .messageThenArguments(let executable, let message, let arguments):
      let executableURL = applicationURL.appendingPathComponent("Contents/MacOS/\(executable)")
      for folder in folders {
        if await Self.run(executableURL, arguments: message + [folder.path]) {
          NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .first?.activate()
          continue
        }
        if let message = await launchNewInstance(
          applicationURL, arguments: arguments + [folder.path])
        {
          return message
        }
      }
    }
    return nil
  }

  @MainActor
  private func launchNewInstance(_ applicationURL: URL, arguments: [String]) async -> String? {
    let configuration = NSWorkspace.OpenConfiguration()
    configuration.activates = true
    configuration.createsNewApplicationInstance = true
    configuration.arguments = arguments
    do {
      _ = try await NSWorkspace.shared.openApplication(
        at: applicationURL, configuration: configuration)
      return nil
    } catch {
      return error.localizedDescription
    }
  }

  static func url(prefix: String, folder: URL) -> URL? {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&=+?#")
    guard let path = folder.path.addingPercentEncoding(withAllowedCharacters: allowed) else {
      return nil
    }
    return URL(string: prefix + path)
  }

  /// Runs a command and reports whether it exited with status 0.
  private static func run(_ executableURL: URL, arguments: [String]) async -> Bool {
    await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = executableURL
      process.arguments = arguments
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      process.terminationHandler = { process in
        continuation.resume(returning: process.terminationStatus == 0)
      }
      do {
        try process.run()
      } catch {
        continuation.resume(returning: false)
      }
    }
  }
}
