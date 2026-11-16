import SwiftUI

struct PremiumView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false
    @State private var animateGradient = false
    
    // URLs pour les conditions et confidentialité - GitHub Pages
    private let privacyPolicyURL = URL(string: "https://boboul-cloud.github.io/bobprompt/privacy.html")!
    private let termsOfUseURL = URL(string: "https://boboul-cloud.github.io/bobprompt/terms.html")!
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 28) {
                    // Header animé
                    headerSection
                    
                    // Avantages Premium
                    benefitsSection
                    
                    // Prix et bouton d'achat
                    purchaseSection
                    
                    // Restauration des achats
                    restoreSection
                    
                    // Liens légaux
                    legalSection
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.purple.opacity(0.1),
                        Color.blue.opacity(0.05),
                        Color.pink.opacity(0.1)
                    ],
                    startPoint: animateGradient ? .topLeading : .bottomTrailing,
                    endPoint: animateGradient ? .bottomTrailing : .topLeading
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: animateGradient)
            )
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                animateGradient = true
            }
            .sheet(isPresented: $showPrivacyPolicy) {
                SafariView(url: privacyPolicyURL)
            }
            .sheet(isPresented: $showTermsOfUse) {
                SafariView(url: termsOfUseURL)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Icône Premium animée
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                    .shadow(color: .orange.opacity(0.5), radius: 20, y: 10)
                
                Image(systemName: "crown.fill")
                    .font(.system(size: 45))
                    .foregroundColor(.white)
            }
            .scaleEffect(animateGradient ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animateGradient)
            
            Text("bobprompt Premium")
                .font(Theme.roundedFont(size: 28, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Débloquez tout le potentiel de votre prompteur")
                .font(Theme.roundedFont(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Avantages
    
    private var benefitsSection: some View {
        VStack(spacing: 16) {
            Text("Avantages Premium")
                .font(Theme.roundedFont(size: 20, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                BenefitRow(
                    icon: "books.vertical.fill",
                    iconColor: .purple,
                    title: "Jusqu'à 50 textes",
                    description: "Sauvegardez tous vos scripts et discours"
                )
                
                BenefitRow(
                    icon: "arrow.clockwise.icloud.fill",
                    iconColor: .blue,
                    title: "Sauvegarde persistante",
                    description: "Vos textes sont conservés même après réinstallation"
                )
                
                BenefitRow(
                    icon: "sparkles",
                    iconColor: .orange,
                    title: "Génération IA illimitée",
                    description: "Créez du contenu sans restrictions"
                )
                
                BenefitRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    title: "Soutenez le développement",
                    description: "Aidez-nous à améliorer l'application"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
    }
    
    // MARK: - Section Achat
    
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            // Affichage du statut Premium
            if purchaseManager.isPremium {
                premiumActiveView
            } else {
                // Prix
                VStack(spacing: 8) {
                    if let product = purchaseManager.premiumProduct {
                        Text(product.displayPrice)
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        
                        Text("Achat unique • Accès à vie")
                            .font(Theme.roundedFont(size: 14))
                            .foregroundColor(.secondary)
                    } else if purchaseManager.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(purchaseManager.loadingStatus)
                                .font(Theme.roundedFont(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else {
                        // Produit en cours de chargement ou non encore disponible
                        VStack(spacing: 8) {
                            Text("2,99 €")
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.purple, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("Achat unique • Accès à vie")
                                .font(Theme.roundedFont(size: 14))
                                .foregroundColor(.secondary)
                            
                            // Bouton pour réessayer le chargement
                            Button(action: {
                                Task {
                                    await purchaseManager.loadProducts()
                                }
                            }) {
                                Label("Charger le produit", systemImage: "arrow.clockwise")
                                    .font(Theme.roundedFont(size: 14))
                            }
                            .buttonStyle(.bordered)
                            .tint(.purple)
                            .padding(.top, 8)
                        }
                    }
                }
                
                // Bouton d'achat
                Button(action: {
                    Task {
                        await purchaseManager.purchase()
                    }
                }) {
                    HStack(spacing: 10) {
                        if purchaseManager.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "crown.fill")
                            Text("Passer Premium")
                        }
                    }
                    .font(Theme.roundedFont(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [.purple, .blue, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .purple.opacity(0.4), radius: 15, y: 8)
                }
                .disabled(purchaseManager.isLoading || purchaseManager.premiumProduct == nil)
                
                // Message d'erreur
                if let error = purchaseManager.purchaseError {
                    Text(error)
                        .font(Theme.roundedFont(size: 14))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        )
    }
    
    private var premiumActiveView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 50))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Vous êtes Premium ! 🎉")
                .font(Theme.roundedFont(size: 22, weight: .bold))
            
            Text("Merci pour votre soutien !")
                .font(Theme.roundedFont(size: 16))
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 20)
    }
    
    // MARK: - Restauration
    
    private var restoreSection: some View {
        Button(action: {
            Task {
                await purchaseManager.restorePurchases()
            }
        }) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.clockwise")
                Text("Restaurer mes achats")
            }
            .font(Theme.roundedFont(size: 16, weight: .medium))
            .foregroundColor(.blue)
        }
        .disabled(purchaseManager.isLoading)
    }
    
    // MARK: - Liens légaux
    
    private var legalSection: some View {
        VStack(spacing: 16) {
            Divider()
            
            HStack(spacing: 20) {
                Button("Confidentialité") {
                    showPrivacyPolicy = true
                }
                .font(Theme.roundedFont(size: 13))
                .foregroundColor(.secondary)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Button("Conditions d'utilisation") {
                    showTermsOfUse = true
                }
                .font(Theme.roundedFont(size: 13))
                .foregroundColor(.secondary)
            }
            
            Text("L'achat est géré par Apple. Paiement débité sur votre compte iTunes. Achat unique sans abonnement.")
                .font(Theme.roundedFont(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - Composants

private struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(iconColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.roundedFont(size: 16, weight: .semibold))
                
                Text(description)
                    .font(Theme.roundedFont(size: 14))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        }
    }
}

// MARK: - Safari View pour les liens

import SafariServices

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Badge Premium pour afficher le statut

struct PremiumBadge: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var showPremiumSheet = false
    
    var body: some View {
        if purchaseManager.isPremium {
            Button(action: { showPremiumSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 10))
                    Text("PREMIUM")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
                    .environmentObject(purchaseManager)
            }
        }
    }
}

// MARK: - Bouton compact pour passer Premium

struct UpgradePremiumButton: View {
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @State private var showPremiumSheet = false
    
    var body: some View {
        if !purchaseManager.isPremium {
            Button(action: { showPremiumSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                    Text("Premium")
                        .font(Theme.roundedFont(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(Capsule())
            }
            .sheet(isPresented: $showPremiumSheet) {
                PremiumView()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct PremiumView_Previews: PreviewProvider {
    static var previews: some View {
        PremiumView()
            .environmentObject(PurchaseManager.shared)
    }
}
#endif
