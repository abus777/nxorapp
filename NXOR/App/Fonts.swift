import CoreText
import Foundation

enum Fonts {
    /// Registers the bundled Archivo and IBM Plex Mono faces (OFL) so `Font.custom` can use them.
    static func register() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
