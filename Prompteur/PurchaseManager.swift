import StoreKit
import SwiftUI

// MARK: - Gestionnaire des achats In-App
@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    // ID du produit Premium (doit correspondre à App Store Connect)
    static let premiumProductID = "com.bobprompt.premium"
    
    @Published private(set) var isPremium: Bool = false
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchaseError: String? = nil
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var loadingStatus: String = ""
    
    private var transactionListener: Task<Void, Error>?
    private let premiumKey = "isPremiumUser"
    
    // Limite de textes en mode gratuit
    static let freeTextLimit = 2
    
    // Limite de textes en mode Premium (pour éviter les ralentissements)
    static let premiumTextLimit = 50
    
    init() {
        // Charger l'état premium depuis UserDefaults (cache local)
        isPremium = UserDefaults.standard.bool(forKey: premiumKey)
        
        // Démarrer l'écoute des transactions
        transactionListener = listenForTransactions()
        
        // Vérifier les achats existants
        Task {
            await checkPurchasedProducts()
            await loadProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Chargement des produits
    
    func loadProducts() async {
        do {
            isLoading = true
            loadingStatus = "Chargement des produits..."
            print("🛒 Chargement du produit: \(PurchaseManager.premiumProductID)")
            
            // Timeout de 10 secondes
            let loadTask = Task {
                try await Product.products(for: [PurchaseManager.premiumProductID])
            }
            
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: 10_000_000_000) // 10 secondes
                loadTask.cancel()
            }
            
            do {
                products = try await loadTask.value
                timeoutTask.cancel()
                print("✅ Produits chargés: \(products.count)")
                if products.isEmpty {
                    loadingStatus = ""
                    // Ne pas afficher d'erreur si les produits ne sont pas encore disponibles
                    // L'utilisateur peut réessayer ou le produit sera chargé au prochain lancement
                    print("⚠️ Aucun produit disponible - en attente de validation App Store")
                } else {
                    loadingStatus = ""
                    purchaseError = nil
                    for product in products {
                        print("  - \(product.id): \(product.displayPrice)")
                    }
                }
            } catch {
                timeoutTask.cancel()
                if Task.isCancelled {
                    print("⏱️ Timeout chargement produits")
                    loadingStatus = ""
                    // Ne pas afficher d'erreur bloquante
                    print("⚠️ Délai dépassé lors du chargement des produits")
                } else {
                    throw error
                }
            }
            
            isLoading = false
        } catch {
            print("❌ Erreur chargement produits: \(error)")
            loadingStatus = ""
            // Ne pas bloquer l'UI avec une erreur technique
            isLoading = false
        }
    }
    
    // MARK: - Achat
    
    func purchase() async {
        guard let product = products.first else {
            purchaseError = "Produit non disponible"
            return
        }
        
        do {
            isLoading = true
            purchaseError = nil
            
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await updatePurchasedProducts()
                await transaction.finish()
                
            case .userCancelled:
                purchaseError = nil
                
            case .pending:
                purchaseError = "Achat en attente de validation"
                
            @unknown default:
                purchaseError = "Erreur inconnue"
            }
            
            isLoading = false
            
        } catch {
            isLoading = false
            purchaseError = "Erreur: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Restauration des achats
    
    func restorePurchases() async {
        isLoading = true
        purchaseError = nil
        
        do {
            try await AppStore.sync()
            await checkPurchasedProducts()
            
            if !isPremium {
                purchaseError = "Aucun achat à restaurer"
            }
        } catch {
            purchaseError = "Erreur de restauration: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Vérification des achats
    
    private func checkPurchasedProducts() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == PurchaseManager.premiumProductID {
                    await MainActor.run {
                        isPremium = true
                        UserDefaults.standard.set(true, forKey: premiumKey)
                    }
                    return
                }
            }
        }
    }
    
    private func updatePurchasedProducts() async {
        await checkPurchasedProducts()
    }
    
    // MARK: - Écoute des transactions
    
    private func listenForTransactions() -> Task<Void, Error> {
        let productID = PurchaseManager.premiumProductID
        return Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    if transaction.productID == productID {
                        await MainActor.run {
                            self.isPremium = true
                            UserDefaults.standard.set(true, forKey: self.premiumKey)
                        }
                    }
                    await transaction.finish()
                }
            }
        }
    }
    
    // MARK: - Vérification de la transaction
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Helpers
    
    var premiumProduct: Product? {
        products.first
    }
    
    var formattedPrice: String {
        premiumProduct?.displayPrice ?? "—"
    }
    
    func canSaveMoreTexts(currentCount: Int) -> Bool {
        if isPremium {
            return currentCount < PurchaseManager.premiumTextLimit
        }
        return currentCount < PurchaseManager.freeTextLimit
    }
}

// MARK: - Erreurs Store

enum StoreError: Error {
    case failedVerification
}

// MARK: - Extension pour formater le prix
extension Product {
    var localizedPrice: String {
        displayPrice
    }
}
