import Foundation
import TunaKit

@objc(OpenTerminalHereExtension)
public final class OpenTerminalHereExtension: Extension {
  public override var declaration: ExtensionDeclaration? {
    ExtensionDeclaration(
      metadata: ExtensionMetadata(
        displayName: "Open Terminal Here",
        author: "Zachary Yocum",
        description: "Open a folder, or the folder containing a file, in your terminal.",
        iconName: "terminal"
      ),
      compatibility: ExtensionDeclarationCompatibility(minTuna: "0.108", minTunaKit: "1.22.0"),
      actionCatalogs: [
        ActionCatalogDeclaration(
          id: "open-terminal-here.actions",
          type: OpenTerminalHereActionsCatalog.self,
          name: "Open Terminal Here Actions"
        )
      ]
    )
  }
}
