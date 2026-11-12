import SwiftUI

@main
struct NXORApp: App {
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(NX.C.accent)
        }
    }
}
