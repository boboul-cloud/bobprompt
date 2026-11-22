import StoreKit
import Observation

/// Achat unique « bobprompt Premium » (non consommable).
@MainActor
@Observable
final class PurchaseManager {
    static let shared = PurchaseManager()
    static let premiumProductID = "com.bobprompt.premium"

    private(set) var isPremium: Bool
    private(set) var product: Product?
    private(set) var isWorking = false
    private(set) var message: String?

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private let cacheKey = "isPremiumUser"

    private init() {
        isPremium = UserDefaults.standard.bool(forKey: cacheKey)
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                guard case .verified(let t) = result else { continue }
                await t.finish()
                await self?.refreshEntitlements()
            }
        }
        Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.loadProduct()
        }
    }

    var priceText: String { product?.displayPrice ?? "—" }

    func loadProduct() async {
        guard product == nil else { return }
        do {
            product = try await Product.products(for: [Self.premiumProductID]).first
        } catch {
            // Produit indisponible (hors ligne, en attente de validation) : on réessaiera.
        }
    }

    func purchase() async {
        message = nil
        if product == nil { await loadProduct() }
        guard let product else {
            message = "La boutique est indisponible pour le moment. Réessayez plus tard."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    await refreshEntitlements()
                } else {
                    message = "L'achat n'a pas pu être vérifié."
                }
            case .pending:
                message = "Achat en attente de validation."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "L'achat n'a pas abouti : \(error.localizedDescription)"
        }
    }

    func restore() async {
        message = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await AppStore.sync()
        } catch {
            message = "Restauration impossible : \(error.localizedDescription)"
            return
        }
        await refreshEntitlements()
        if !isPremium { message = "Aucun achat à restaurer sur ce compte." }
    }

    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.premiumProductID, t.revocationDate == nil {
                owned = true
            }
        }
        #if DEBUG
        if debugOverride { return }
        #endif
        setPremium(owned)
    }

    private func setPremium(_ value: Bool) {
        isPremium = value
        UserDefaults.standard.set(value, forKey: cacheKey)
    }

    #if DEBUG
    @ObservationIgnored private var debugOverride = false
    func debugSetPremium(_ value: Bool) { debugOverride = true; setPremium(value) }
    #endif
}
