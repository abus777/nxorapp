import SwiftUI

@main
struct NXORApp: App {
    @State private var model = AppModel()

    init() {
        Fonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .tint(NX.C.accent)
        }
    }
}
