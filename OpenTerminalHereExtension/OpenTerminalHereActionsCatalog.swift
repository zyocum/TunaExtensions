import AppKit
import Foundation
import TunaKit

public final class OpenTerminalHereActionsCatalog: ActionCatalog {
  public let identifier: String
  public let name: String

  public private(set) lazy var actions: [CatalogAction] = TerminalApp.all.map(Self.makeAction)

  public required init(definition: ActionCatalogDefinition) {
    identifier = definition.identifier
    name = definition.name
  }

  private static func makeAction(for app: TerminalApp) -> CatalogAction {
    let action = PredicateAwareAction(
      id: app.actionID,
      title: "Open in \(app.name)",
      headlessEligibility: .guaranteed
    ) { subject, _ in
      await open([subject], in: app)
    }
    action.batchCallback = { subjects, _ in
      await open(subjects, in: app)
    }
    action.systemSymbolName = "terminal"
    action.supportedSubjectTypes = [.file, .directory, .textSnippet]
    action.subjectPredicate = { item in
      guard let item, app.applicationURL != nil else { return false }
      return folder(for: item) != nil
    }
    action.executionPolicy = .dismiss
    return action
  }

  @MainActor
  static func open(_ subjects: [CatalogItem], in app: TerminalApp) async -> ActionResult {
    guard let applicationURL = app.applicationURL else {
      return .failure("\(app.name) is not installed")
    }
    var folders: [URL] = []
    for folder in subjects.compactMap(folder(for:)) where !folders.contains(folder) {
      folders.append(folder)
    }
    guard !folders.isEmpty else {
      return .failure("Choose a file, a folder, or the text of an existing path")
    }

    if let message = await app.open(folders, applicationURL: applicationURL) {
      return .failure("\(app.name) could not open the folder: \(message)")
    }
    return .success
  }

  /// The subject itself when it is a folder, otherwise the folder that contains it.
  static func folder(for item: CatalogItem) -> URL? {
    guard let path = path(of: item) else { return nil }
    let url = URL(fileURLWithPath: path).standardizedFileURL
    var isDirectory: ObjCBool = false
    guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
      return nil
    }
    return isDirectory.boolValue ? url : url.deletingLastPathComponent()
  }

  /// A file or folder subject's path, or text that is an absolute, `~`, or `file:` path.
  private static func path(of item: CatalogItem) -> String? {
    let registry = TypeRegistry.shared
    if registry.inherits(item.typeID, from: .file) || registry.inherits(item.typeID, from: .directory),
      let path = (item as? CatalogEntity)?.path
    {
      return path
    }

    guard let text = item.textInputValue()?.trimmingCharacters(in: .whitespacesAndNewlines),
      !text.isEmpty
    else { return nil }
    if let url = URL(string: text), url.isFileURL {
      return url.path
    }
    let expanded = (text as NSString).expandingTildeInPath
    return expanded.hasPrefix("/") ? expanded : nil
  }
}
