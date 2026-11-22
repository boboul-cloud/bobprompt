import SwiftUI

@main
struct BobpromptApp: App {
    @State private var purchases = PurchaseManager.shared
    @State private var store: ScriptStore
    @State private var settings = SettingsStore()
    @State private var router = AppRouter()
    @State private var rewards: RewardStore
    @Environment(\.scenePhase) private var scenePhase

    init() {
        AudioSession.configure()
        #if DEBUG
        let s = DemoConfig.current.seed ? ScriptStore(persistence: MemoryScriptPersistence(DemoConfig.seedScripts))
                                         : ScriptStore()
        #else
        let s = ScriptStore()
        #endif
        s.isPremium = { PurchaseManager.shared.isPremium }
        _store = State(initialValue: s)
        #if DEBUG
        let r = DemoConfig.current.seed ? RewardStore(defaults: UserDefaults(suiteName: "demo-rewards")!) : RewardStore()
        if DemoConfig.current.seed { DemoConfig.seedRewards(r) }
        #else
        let r = RewardStore()
        #endif
        _rewards = State(initialValue: r)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(purchases)
                .environment(store)
                .environment(settings)
                .environment(router)
                .environment(rewards)
                .tint(Palette.onAir)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.retryLoadIfNeeded() } else { store.flush() }
        }
    }
}

struct RootView: View {
    @Environment(AppRouter.self) private var router
    @Environment(ScriptStore.self) private var store
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        @Bindable var router = router
        NavigationStack(path: $router.path) {
            HomeView()
                .navigationDestination(for: AppRouter.Route.self) { route in
                    switch route {
                    case .kids: KidsHomeView()
                    case .studio: LibraryView()
                    case .rewards: RewardsView()
                    case .editor(let id, let profile):
                        EditorView(scriptID: id).environment(\.readerProfile, profile)
                    }
                }
        }
        .fullScreenCover(item: $router.reading) { r in
            ReaderView(script: r.script, profile: r.profile)
        }
        .sheet(item: $router.sheet) { sheet in
            switch sheet {
            case .premium: PremiumView()
            case .help: HelpView()
            case .create(let profile): AICreateView().environment(\.readerProfile, profile)
            }
        }
        #if DEBUG
        .task { DemoConfig.current.apply(router: router, store: store, settings: settings) }
        #endif
    }
}

#if DEBUG
/// Arguments de lancement pour photographier chaque écran dans le simulateur.
/// ex. `-demoScreen reader -demoStyle drum -demoWord 30`
struct DemoConfig {
    var screen: String?
    var style: StageStyle?
    var theme: ClassicTheme?
    var sample = 0
    var word: Int?
    var play = false
    var seed = false
    var premium: Bool?
    var voice = false
    var profile: ReaderProfile = .studio
    var speed: Double?

    static let current: DemoConfig = {
        let d = UserDefaults.standard
        var c = DemoConfig()
        c.screen = d.string(forKey: "demoScreen")
        c.style = d.string(forKey: "demoStyle").flatMap(StageStyle.init(rawValue:))
        c.theme = d.string(forKey: "demoTheme").flatMap(ClassicTheme.init(rawValue:))
        c.sample = d.integer(forKey: "demoSample")
        c.word = d.object(forKey: "demoWord") == nil ? nil : d.integer(forKey: "demoWord")
        c.play = d.bool(forKey: "demoPlay")
        c.seed = d.bool(forKey: "demoSeed")
        c.premium = d.object(forKey: "demoPremium") == nil ? nil : d.bool(forKey: "demoPremium")
        c.voice = d.bool(forKey: "demoVoice")
        c.speed = d.object(forKey: "demoSpeed") == nil ? nil : d.double(forKey: "demoSpeed")
        c.profile = d.string(forKey: "demoProfile").flatMap(ReaderProfile.init(rawValue:)) ?? .studio
        return c
    }()

    static let seedScripts: [Script] = [
        Script(title: "Exposé sur les volcans", content: """
        Bonjour à tous ! Aujourd'hui, je vais vous parler des volcans.

        Un volcan est une montagne qui laisse sortir de la lave, des cendres et des gaz. Sous nos pieds, la Terre est très chaude.

        Il existe des volcans rouges, qui coulent doucement, et des volcans gris, qui explosent.
        """, updatedAt: Date().addingTimeInterval(-3600 * 3), lastWord: 22, colorIndex: 0),
        Script(title: "Vidéo : ma routine du matin", content: """
        Salut tout le monde ! Dans cette vidéo, je vous montre ma routine du matin, en cinq minutes chrono.
        """, updatedAt: Date().addingTimeInterval(-86400 * 2), colorIndex: 2)
    ]

    @MainActor
    static func seedRewards(_ r: RewardStore) {
        r.reset()
        let yesterday = Date().addingTimeInterval(-86_400)
        for _ in 0..<38 { r.sentenceRead(today: yesterday) }
        r.textFinished(SampleScripts.dragon.id, wordsPerMinute: 20)
        r.textProgress(SampleScripts.corbeau.id, fraction: 0.5)
        r.sentenceRead()
    }

    @MainActor
    func apply(router: AppRouter, store: ScriptStore, settings: SettingsStore) {
        if let premium { PurchaseManager.shared.debugSetPremium(premium) }
        if let style { settings[profile].style = style }
        if let theme { settings[profile].classicTheme = theme }
        if voice { settings[profile].voiceOn = true }
        if let speed { settings[profile].wordsPerMinute = speed }
        guard let screen else { return }
        var script = SampleScripts.all[min(max(0, sample), SampleScripts.all.count - 1)]
        if seed, sample < 0, let first = store.scripts.first { script = first }
        switch screen {
        case "reader", "styles", "settings": router.reading = .init(script: script, profile: profile)
        case "editor": if let s = store.scripts.first { router.edit(s.id) }
        case "create": router.sheet = .create(profile)
        case "premium": router.sheet = .premium
        case "help": router.sheet = .help
        case "kids": router.path = [.kids]
        case "studio": router.path = [.studio]
        case "rewards": router.path = [.kids, .rewards]
        default: break
        }
    }
}
#endif
