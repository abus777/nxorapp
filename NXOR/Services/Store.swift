import Foundation
import StoreKit
import Observation

/// App Store purchases (StoreKit 2). Credits on iPhone are sold only through the App Store.
/// Product ids must exist in App Store Connect; until they do, `products` stays empty and the UI says so.
@Observable
final class Store {
    static let creditPackIDs = ["com.abus777.nxorapp.credits.1000", "com.abus777.nxorapp.credits.3000", "com.abus777.nxorapp.credits.10000"]
    static let planIDs = ["com.abus777.nxorapp.plan.starter", "com.abus777.nxorapp.plan.professional", "com.abus777.nxorapp.plan.power"]

    var products: [String: Product] = [:]
    var loaded = false
    var purchasing = false
    var message: String?

    @MainActor
    func load() async {
        guard !loaded else { return }
        loaded = true
        if let list = try? await Product.products(for: Self.creditPackIDs + Self.planIDs) {
            for p in list { products[p.id] = p }
        }
    }

    func price(_ id: String) -> String? { products[id]?.displayPrice }

    @MainActor
    func buy(_ id: String) async -> Bool {
        guard let product = products[id] else {
            message = "In-app purchases aren't set up in App Store Connect yet. They'll work once the products are approved."
            return false
        }
        purchasing = true
        defer { purchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                if case let .verified(transaction) = verification {
                    await transaction.finish()
                    return true
                }
                message = "The App Store couldn't verify this purchase."
            case .pending:
                message = "Purchase is waiting for approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = error.localizedDescription
        }
        return false
    }

    @MainActor
    func restore() async {
        do {
            try await AppStore.sync()
            message = "Purchases restored."
        } catch {
            message = error.localizedDescription
        }
    }
}
