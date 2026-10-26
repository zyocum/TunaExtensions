import Foundation
import TunaKit
import XCTest

@testable import OpenTerminalHereExtension

final class OpenTerminalHereExtensionTests: XCTestCase {
  private var directory: URL!
  private var file: URL!

  override func setUpWithError() throws {
    directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
      .standardizedFileURL
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    file = directory.appendingPathComponent("notes.txt")
    try Data().write(to: file)
  }

  override func tearDownWithError() throws {
    try FileManager.default.removeItem(at: directory)
  }

  @MainActor
  func testFolderOpensItselfAndFileOpensItsEnclosingFolder() {
    XCTAssertEqual(folder(ofText: directory.path), directory)
    XCTAssertEqual(folder(ofText: file.path), directory)
    XCTAssertEqual(folder(ofText: file.absoluteString), directory)
    XCTAssertEqual(folder(ofText: "  \(file.path)\n"), directory)
  }

  @MainActor
  func testFileAndFolderEntitiesAreSupportedSubjects() throws {
    let catalog = OpenTerminalHereActionsCatalog(
      definition: ActionCatalogDefinition(identifier: "test.open-terminal-here.actions", name: "Actions")
    )
    let terminal = try XCTUnwrap(catalog.actions.first { $0.id == "open-in-terminal" } as? PredicateAwareAction)
    let predicate = try XCTUnwrap(terminal.subjectPredicate)
    let fileEntity = FileSystemEntity(displayName: "notes.txt", url: file, kind: .file)
    let folderEntity = FileSystemEntity(displayName: "folder", url: directory, kind: .directory)

    for (entity, expected) in [(fileEntity, directory), (folderEntity, directory)] {
      XCTAssertTrue(terminal.supportsSubject(type: entity.typeID), "\(entity.typeID)")
      XCTAssertTrue(predicate(entity), "\(entity.typeID)")
      XCTAssertEqual(OpenTerminalHereActionsCatalog.folder(for: entity), expected)
    }
  }

  @MainActor
  func testTildePathExpandsToHome() {
    let home = URL(fileURLWithPath: NSHomeDirectory()).standardizedFileURL
    XCTAssertEqual(folder(ofText: "~"), home)
  }

  @MainActor
  func testTextThatIsNotAnExistingPathHasNoFolder() {
    XCTAssertNil(folder(ofText: ""))
    XCTAssertNil(folder(ofText: "hello world"))
    XCTAssertNil(folder(ofText: "relative/path"))
    XCTAssertNil(folder(ofText: directory.appendingPathComponent("missing").path))
  }

  @MainActor
  func testActionsCoverEveryTerminalForFilesFoldersAndText() throws {
    let catalog = OpenTerminalHereActionsCatalog(
      definition: ActionCatalogDefinition(identifier: "test.open-terminal-here.actions", name: "Actions")
    )

    XCTAssertEqual(
      catalog.actions.map(\.title),
      [
        "Open in Alacritty", "Open in Ghostty", "Open in iTerm2", "Open in kitty", "Open in Terminal",
        "Open in Warp", "Open in WezTerm",
      ])
    XCTAssertEqual(Set(catalog.actions.map(\.id)).count, catalog.actions.count)
    for action in catalog.actions {
      XCTAssertEqual(action.supportedSubjectTypes, [.file, .directory, .textSnippet])
      XCTAssertNotNil(action.batchCallback)
      XCTAssertEqual(action.headlessEligibility, .guaranteed)
    }
  }

  func testLaunchMethodsAndBundleIdentifiers() {
    let byName = Dictionary(uniqueKeysWithValues: TerminalApp.all.map { ($0.name, $0) })

    XCTAssertEqual(byName["Alacritty"]?.bundleIdentifier, "org.alacritty")
    XCTAssertEqual(byName["Ghostty"]?.bundleIdentifier, "com.mitchellh.ghostty")
    XCTAssertEqual(byName["iTerm2"]?.bundleIdentifier, "com.googlecode.iterm2")
    XCTAssertEqual(byName["kitty"]?.bundleIdentifier, "net.kovidgoyal.kitty")
    XCTAssertEqual(byName["Terminal"]?.bundleIdentifier, "com.apple.Terminal")
    XCTAssertEqual(byName["Warp"]?.bundleIdentifier, "dev.warp.Warp-Stable")
    XCTAssertEqual(byName["WezTerm"]?.bundleIdentifier, "com.github.wez.wezterm")

    for name in ["Ghostty", "iTerm2", "kitty", "Terminal"] {
      XCTAssertEqual(byName[name]?.launchMethod, .openFolder, name)
    }
    XCTAssertEqual(byName["WezTerm"]?.launchMethod, .arguments(["start", "--cwd"]))
    XCTAssertEqual(
      byName["Alacritty"]?.launchMethod,
      .messageThenArguments(
        executable: "alacritty",
        message: ["msg", "create-window", "--working-directory"],
        arguments: ["--working-directory"]))
  }

  func testWarpLinkPercentEncodesThePath() throws {
    let folder = URL(fileURLWithPath: "/Users/me/A & B/c=d+e?#", isDirectory: true)
    let url = try XCTUnwrap(
      TerminalApp.url(prefix: "warp://action/new_window?path=", folder: folder))

    XCTAssertEqual(
      url.absoluteString, "warp://action/new_window?path=/Users/me/A%20%26%20B/c%3Dd%2Be%3F%23")
    let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
    XCTAssertEqual(components.queryItems?.first?.value, folder.path)
  }

  @MainActor
  func testTerminalPredicateAcceptsPathsOnly() throws {
    let catalog = OpenTerminalHereActionsCatalog(
      definition: ActionCatalogDefinition(identifier: "test.open-terminal-here.actions", name: "Actions")
    )
    let terminal = try XCTUnwrap(catalog.actions.first { $0.id == "open-in-terminal" } as? PredicateAwareAction)
    let predicate = try XCTUnwrap(terminal.subjectPredicate)

    XCTAssertTrue(predicate(TextSnippetItem(text: file.path)))
    XCTAssertFalse(predicate(TextSnippetItem(text: "hello world")))
    XCTAssertFalse(predicate(nil))
  }

  @MainActor
  func testExtensionDeclarationIsValid() throws {
    let extensionInstance = try OpenTerminalHereExtension(
      bundle: Bundle(for: OpenTerminalHereExtension.self))
    let declaration = try XCTUnwrap(extensionInstance.declaration)

    try declaration.validate()
    let compatibility = try XCTUnwrap(declaration.compatibility)
    XCTAssertEqual(compatibility.minTuna, "0.108")
    XCTAssertEqual(compatibility.minTunaKit, "1.22.0")
  }

  @MainActor
  private func folder(ofText text: String) -> URL? {
    OpenTerminalHereActionsCatalog.folder(for: TextSnippetItem(text: text))
  }
}
