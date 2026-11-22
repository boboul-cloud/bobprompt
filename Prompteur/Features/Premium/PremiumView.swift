import SwiftUI
import SafariServices

struct PremiumView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss
    @State private var link: WebLink?

    private let privacyURL = URL(string: "https://boboul-cloud.github.io/bobprompt/privacy.html")!
    private let termsURL = URL(string: "https://boboul-cloud.github.io/bobprompt/terms.html")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 26) {
                    hero
                    benefits
                    if purchases.isPremium { owned } else { buy }
                    legal
                }
                .padding(22)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Palette.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Fermer") { dismiss() } }
            }
            .sheet(item: $link) { l in SafariView(url: l.url).ignoresSafeArea() }
            .task { await purchases.loadProduct() }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(Palette.sun.opacity(0.18)).frame(width: 120, height: 120)
                Circle().fill(Palette.sun).frame(width: 84, height: 84)
                    .shadow(color: Palette.sun.opacity(0.5), radius: 18, y: 8)
                Image(systemName: "crown.fill").font(.system(size: 38, weight: .bold)).foregroundStyle(.white)
            }
            Text("bobprompt Premium")
                .font(Typo.title(30))
                .foregroundStyle(Palette.ink)
            Text("Un seul achat, pour toujours. Pas d'abonnement.")
                .font(Typo.body(16))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 10)
    }

    private var benefits: some View {
        VStack(spacing: 0) {
            row("books.vertical.fill", Palette.indigo, "\(ScriptStore.premiumLimit) textes au lieu de \(ScriptStore.freeLimit)",
                "Toute ta bibliothèque de lectures, d'exposés et de scripts.")
            Divider().padding(.leading, 62)
            row("lock.shield.fill", Palette.teal, "Gardés même après réinstallation",
                "Tes textes restent sur ton appareil, sans compte.")
            Divider().padding(.leading, 62)
            row("heart.fill", Palette.pink, "Tu soutiens une petite app indépendante",
                "Et toutes les nouveautés à venir sont incluses.")
        }
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.surface))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Palette.hairline))
    }

    private func row(_ symbol: String, _ color: Color, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 34, height: 34)
                .background(RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(Typo.headline(16)).foregroundStyle(Palette.ink)
                Text(detail).font(Typo.body(14)).foregroundStyle(Palette.inkSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var buy: some View {
        VStack(spacing: 12) {
            Button {
                Task { await purchases.purchase() }
            } label: {
                HStack {
                    if purchases.isWorking { ProgressView().tint(.white) }
                    Text(purchases.product == nil ? "Débloquer Premium" : "Débloquer pour \(purchases.priceText)")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(purchases.isWorking)

            Button("Restaurer mes achats") { Task { await purchases.restore() } }
                .font(Typo.headline(15))
                .foregroundStyle(Palette.inkSoft)
                .disabled(purchases.isWorking)

            if let m = purchases.message {
                Text(m).font(Typo.body(13)).foregroundStyle(Palette.onAirDeep).multilineTextAlignment(.center)
            }
        }
    }

    private var owned: some View {
        Label("Premium est actif. Merci !", systemImage: "checkmark.seal.fill")
            .font(Typo.headline(17))
            .foregroundStyle(Palette.leaf)
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.leaf.opacity(0.12)))
    }

    private var legal: some View {
        VStack(spacing: 8) {
            Text("Achat unique non consommable, lié à ton identifiant Apple. Le paiement est débité sur ton compte à la confirmation.")
                .font(Typo.body(12))
                .foregroundStyle(Palette.inkSoft)
                .multilineTextAlignment(.center)
            HStack(spacing: 18) {
                Button("Confidentialité") { link = WebLink(url: privacyURL) }
                Button("Conditions d'utilisation") { link = WebLink(url: termsURL) }
            }
            .font(Typo.caption(13))
        }
    }
}

struct WebLink: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController { SFSafariViewController(url: url) }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
