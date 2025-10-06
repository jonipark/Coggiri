//
//  FruitGrabGameView.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/14/25.
//

import SwiftUI
import RealityKit
import AVKit

enum GamePhase { case intro, playing, gameOver }

/// “정해진 과일 셋 + 메타정보”
let FruitCatalog: [FruitMeta] = [
    .init(model: "Apple",      displayName: "사과",      promptColor: .blue,   color: .red),
    .init(model: "Persimmon",  displayName: "감",        promptColor: .green,  color: .orange),
    .init(model: "Grapes",     displayName: "포도",      promptColor: .pink,   color: .purple),
    .init(model: "Peach",      displayName: "복숭아",    promptColor: .cyan,   color: .pink),
    .init(model: "Blueberry",  displayName: "블루베리",  promptColor: .yellow, color: .indigo),
    .init(model: "Banana",     displayName: "바나나",    promptColor: .orange, color: .yellow),
    .init(model: "Acorn",      displayName: "도토리",    promptColor: .purple, color: .brown)
]

struct FruitMeta: Hashable {
    let model: String               // png filename
    let displayName: String         // UI 표시명
    let promptColor: Color
    let color: Color
}

// MARK: - Prompt (문항)
enum PromptKind: Hashable {
    case text(String)         // 예: "사과", "빨간색", "다람쥐가 좋아하는 것"
    case image(String)        // 이미지 asset 이름 (예: "Apple", "Grapes" …)
}

struct Prompt: Hashable {
    let kind: PromptKind
    let targetModel: String   // FruitCatalog.model 중 하나
}

// 항상 1:1 매칭되는 문항들
let Prompts: [Prompt] = [
    // [A] 과일 이름(텍스트 문제)
    .init(kind: .text("사과"),     targetModel: "Apple"),
    .init(kind: .text("포도"),     targetModel: "Grapes"),
    .init(kind: .text("감"),       targetModel: "Persimmon"),
    .init(kind: .text("도토리"),   targetModel: "Acorn"),
    .init(kind: .text("바나나"),   targetModel: "Banana"),
    .init(kind: .text("블루베리"), targetModel: "Blueberry"),

    // [B] 색상(텍스트 문제) — 유일 매핑
    .init(kind: .text("빨간색"), targetModel: "Apple"),
    .init(kind: .text("보라색"), targetModel: "Grapes"),
    .init(kind: .text("파란색"), targetModel: "Blueberry"),
    .init(kind: .text("분홍색"), targetModel: "Peach"),
    .init(kind: .text("주황색"), targetModel: "Persimmon"),
    .init(kind: .text("노란색"), targetModel: "Banana"),
    .init(kind: .text("갈색"),   targetModel: "Acorn"),

    // [C] 콘셉트(텍스트 문제)
    .init(kind: .text("다람쥐가 좋아하는 것"),   targetModel: "Acorn"),
    .init(kind: .text("원숭이가 좋아하는 과일"), targetModel: "Banana"),

    // [D] 이미지 문제 — 에셋 이름(또는 PDF/PNG)과 model 이름을 동일하게 쓰면 관리 편해요.
    .init(kind: .image("Apple"),     targetModel: "Apple"),
    .init(kind: .image("Grapes"),    targetModel: "Grapes"),
    .init(kind: .image("Persimmon"), targetModel: "Persimmon"),
    .init(kind: .image("Acorn"),     targetModel: "Acorn"),
    .init(kind: .image("Banana"),    targetModel: "Banana"),
    .init(kind: .image("Blueberry"), targetModel: "Blueberry"),
    .init(kind: .image("Peach"),     targetModel: "Peach"),
]

// MARK: - Spawned Fruit Instance

struct Fruit: Identifiable, Hashable {
    let id = UUID()
    var modelName: String // USDZ file name (without ".usdz")
    var x: CGFloat        // [0, 1] relative x
    var y: CGFloat        // [0, 1] relative y (0 = top)
    var speed: CGFloat    // fraction of screen per second
}

// MARK: - USDZ Entity Cache (with input/collision/hover prepared)

@MainActor
final class EntityCache {
    static let shared = EntityCache()
    private var cache: [String: Entity] = [:]
    
    func entity(named name: String) async throws -> Entity {
        if let e = cache[name] { return e }
        guard let url = Bundle.main.url(forResource: name, withExtension: "usdz") else {
            throw NSError(domain: "EntityCache", code: 404, userInfo: [NSLocalizedDescriptionKey: "\(name).usdz not found"])
        }
        let raw = try await Entity(contentsOf: url)
        let bounds = raw.visualBounds(relativeTo: nil)
        let center = bounds.center
        let size = bounds.extents
        
        let pivot = Entity()
        raw.position = -center
        pivot.addChild(raw)
        
        let targetBox: SIMD3<Float> = .init(repeating: 0.12)
        let sx = targetBox.x / max(size.x, 1e-6)
        let sy = targetBox.y / max(size.y, 1e-6)
        let sz = targetBox.z / max(size.z, 1e-6)
        var s = min(sx, min(sy, sz))
        s *= 0.9
        pivot.scale = .init(repeating: s)

        // Collision & hover
        let inflated = size * 1.1
        pivot.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: inflated)]))
        pivot.components.set(HoverEffectComponent(.highlight(.default)))
        pivot.components.set(InputTargetComponent())
        pivot.name = name
        
        cache[name] = pivot
        return pivot
    }
}

extension Bool {
    static func random(probability p: Double) -> Bool {
        guard p > 0 else { return false }
        guard p < 1 else { return true }
        return Double.random(in: 0...1) < p
    }
}

struct FruitGrabGameView: View {
    @State private var phase: GamePhase = .intro
    @State private var introCountdown: TimeInterval = 4
    @State private var activeStep: Int = 1
    @State private var fruits: [Fruit] = []
    @State private var grabbedOnce = Set<UUID>()
    @State private var lastUpdate = Date()
    @State private var spawnAccumulator: TimeInterval = 0
    @State private var score = 0
    @State private var timeLeft: TimeInterval = 60
    @State private var isGameOver = false
    @State private var cachedThumb: Entity?
    @State private var totalSteps = 6
    @State private var stepDuration: TimeInterval = 10
    @State private var showResult = false
    @State private var didHandleReset = false

    // FIX: 빠른 중복 탭 방지 락
    @State private var isHandlingTap = false

    private let targetSpawnBias: Double = 0.6

    private var currentStep: Int {
        max(1, min(totalSteps, totalSteps - Int(timeLeft / stepDuration)))
    }
    private var stepElapsed: TimeInterval {
        stepDuration - (timeLeft.truncatingRemainder(dividingBy: stepDuration))
    }
    
    @State private var lastWholeSecond: Int = 60
    @State private var didNotifyGameEnd: Bool = false
    @State private var notifiedSteps: Set<Int> = []
    @State private var effects: [GrabEffect] = []

    @State private var currentPrompt: Prompt = .init(kind: .text("사과"), targetModel: "Apple")
    @State private var promptOpacity: Double = 0.0
    @State private var scoreOpacity: Double  = 0.2
    @State private var scoreDisplay: Int = 0
    @State private var scoreFlash: Bool = false
    @State private var pendingScoreBumps: Int = 0
    @Environment(\.dismiss) private var dismiss
    
    private let ticker = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack {
            if phase == .intro {
                IntroVideoView(
                    url: Bundle.main.url(forResource: "game-start", withExtension: "mp4")!,
                    countdown: $introCountdown
                ) { startGame() }
            } else {
                ZStack {
                    mainPlayArea
                }
                .ornament(attachmentAnchor: .scene(.top)) {
                    TopTimerPanel(
                        currentStep: currentStep,
                        totalSteps: totalSteps,
                        stepElapsed: stepElapsed,
                        stepDuration: stepDuration
                    )
                    .padding(.bottom, 100)
                }
                .ornament(attachmentAnchor: .scene(.leading)) {
                    VStack(alignment: .leading, spacing: 32) {
                        ScorePane(score: scoreDisplay, flashing: scoreFlash)
                            .frame(width: 300, height: 200)
                        InstructionPane(
                            kind: currentPrompt.kind,
                            promptColor: colorForPrompt(currentPrompt.targetModel)
                        )
                        .frame(width: 300, height: 260)
                    }
                    .padding(8)
                }
            }
        }
        .onChange(of: phase) {
            switch phase {
            case .playing:
                AudioManager.shared.playBGM(named: "bgm_fruit_grab")
            default:
                AudioManager.shared.stopBGM()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .ResetToHome)) { _ in
            guard !didHandleReset else { return }
            didHandleReset = true

            if showResult {
                showResult = false
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .ResetToHome, object: nil)
                }
            } else {
                dismiss()
            }
        }
        .navigationDestination(isPresented: $showResult) {
            FruitGrabResultView(score: score)
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            resetGame()
            AudioManager.shared.playSFX(named: "game_start_countdown")
            print("usdz in bundle:", Bundle.main.paths(forResourcesOfType: "usdz", inDirectory: nil))
        }
        .onReceive(ticker) { now in
            tick(now: now)
        }
    }
    
    // ===== 메인 플레이 영역 =====
    @ViewBuilder
    private var mainPlayArea: some View {
        ZStack {
            GeometryReader { geo in
                let size = geo.size
                ForEach(fruits) { fruit in
                    FruitTile(
                        fruitID: fruit.id,
                        modelName: fruit.modelName,
                        // FIX: 탭 처리 중에는 히트테스트 잠깐 막기
                        allowsHitTesting: (phase == .playing) && !isHandlingTap
                    ) { id in
                        grab(id)
                    }
                    .frame(width: 100, height: 100)
                    .position(x: fruit.x * size.width, y: fruit.y * size.height)
                    // .id(fruit.id) // 필요시 강제 재구성
                }
                ZStack {
                    ForEach(effects) { ef in
                        GrabBurst(baseColor: ef.color) {
                            if let i = effects.firstIndex(of: ef) {
                                DispatchQueue.main.async { effects.remove(at: i) }
                            }
                        }
                        .position(x: ef.x * size.width, y: ef.y * size.height)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: fruits)
            
            if isGameOver || timeLeft <= 0 {
                GameOverOverlay(score: score) { resetGame() }
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - UI Helpers
    private func colorForModel(_ model: String) -> Color? {
        FruitCatalog.first(where: { $0.model == model })?.color
    }
    private func colorForPrompt(_ model: String) -> Color? {
        FruitCatalog.first(where: { $0.model == model })?.promptColor
    }
    
    // MARK: - Game Loop
    private func tick(now: Date) {
        guard phase == .playing, !isGameOver else { return }

        let dt = now.timeIntervalSince(lastUpdate)
        lastUpdate = now

        timeLeft = max(0, timeLeft - dt)
        if timeLeft <= 0 {
            endGame()
            return
        }

        let stepNow = currentStep
        if stepNow != activeStep {
            activeStep = stepNow
            nextPrompt()
        }

        spawnAccumulator += dt
        let spawnEvery = 0.6
        while spawnAccumulator >= spawnEvery {
            spawnAccumulator -= spawnEvery
            spawnFruit()
        }

        let dy = CGFloat(dt)
        fruits = fruits
            .map { f in
                var nf = f
                nf.y += nf.speed * dy
                return nf
            }
            .filter { $0.y <= 1 }
        
        // ----- Countdown SFX -----
        let whole = max(0, Int(ceil(timeLeft)))
        if whole != lastWholeSecond {
            lastWholeSecond = whole
            if whole > 0, whole <= 5, !didNotifyGameEnd {
                AudioManager.shared.playSFX(named: "countdown_tick_game_end")
                didNotifyGameEnd = true
            } else if whole > 5 {
                let stepRemaining = stepDuration - stepElapsed
                if stepRemaining <= 2.0, !notifiedSteps.contains(currentStep) {
                    AudioManager.shared.playSFX(named: "countdown_tick_round_end")
                    notifiedSteps.insert(currentStep)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func spawnFruit() {
        let preferTarget = Bool.random(probability: targetSpawnBias)

        if preferTarget,
           let target = FruitCatalog.first(where: { $0.model == currentPrompt.targetModel }) {
            let countSame = fruits.filter { $0.modelName == target.model }.count
            if countSame < 2 {
                let new = Fruit(
                    modelName: target.model,
                    x: CGFloat.random(in: 0.12...0.88),
                    y: 0.0,
                    speed: CGFloat.random(in: 0.15...0.35)
                )
                fruits.append(new)
                return
            }
        }

        var candidates = FruitCatalog.shuffled()
        while !candidates.isEmpty {
            let meta = candidates.removeFirst()
            let countSame = fruits.filter { $0.modelName == meta.model }.count
            if countSame >= 2 { continue }
            let new = Fruit(
                modelName: meta.model,
                x: CGFloat.random(in: 0.12...0.88),
                y: 0.0,
                speed: CGFloat.random(in: 0.15...0.35)
            )
            fruits.append(new)
            return
        }
    }
    
    private func grab(_ id: UUID) {
        // FIX: 재진입/폭주 탭 방지
        guard (phase == .playing), !isHandlingTap else { return }
        isHandlingTap = true
        defer { isHandlingTap = false }

        guard grabbedOnce.insert(id).inserted else { return }
        guard let idx = fruits.firstIndex(where: { $0.id == id }) else { return }

        let fx = fruits[idx].x
        let fy = fruits[idx].y
        let model = fruits[idx].modelName
        let burstColor = colorForModel(model) ?? .yellow

        if model == currentPrompt.targetModel {
            AudioManager.shared.playSFX(named: "grab")
            effects.append(.init(x: fx, y: fy, color: burstColor))

            // FIX: 제스처 파이프라인 탈출 후, 애니메이션 없이 제거
            DispatchQueue.main.async {
                withTransaction(Transaction(animation: nil)) {
                    if let i = fruits.firstIndex(where: { $0.id == id }) {
                        fruits.remove(at: i)
                    }
                }
            }
            enqueueScoreBump()
        } else {
            AudioManager.shared.playSFX(named: "wrong_grab")
            // FIX: 오답도 동일 정책으로 제거
            DispatchQueue.main.async {
                withTransaction(Transaction(animation: nil)) {
                    if let i = fruits.firstIndex(where: { $0.id == id }) {
                        fruits.remove(at: i)
                    }
                }
            }
        }
    }
    
    private func enqueueScoreBump() {
        pendingScoreBumps += 1
        if !scoreFlash { processNextScoreBump() }
    }

    private func processNextScoreBump() {
        guard pendingScoreBumps > 0 else { return }
        scoreFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            score += 1
            scoreDisplay = score
            pendingScoreBumps -= 1
            if pendingScoreBumps > 0 {
                processNextScoreBump()
            } else {
                withAnimation(.easeOut(duration: 0.15)) {
                    scoreFlash = false
                }
            }
        }
    }
    
    private func nextPrompt() {
        let candidates = Prompts.filter { $0 != currentPrompt }
        currentPrompt = (candidates.randomElement() ?? Prompts.randomElement())!
    }
    
    private func prepareForGame() {
        // FIX: 상태 초기화 보강
        fruits.removeAll()
        grabbedOnce.removeAll() // ✅
        score = 0
        scoreDisplay = 0
        timeLeft = TimeInterval(totalSteps) * stepDuration
        isGameOver = false
        lastUpdate = Date()
        spawnAccumulator = 0
        activeStep = 1
        nextPrompt()
    }

    private func startGame() {
        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .playing
        }
        withAnimation(.easeOut(duration: 0.45)) {
            promptOpacity = 1.0
            scoreOpacity  = 1.0
        }
        lastUpdate = Date()
    }
    
    private func endGame() {
        // FIX: 제거는 애니메이션 없이, 다음 런루프로 미루기
        isGameOver = true
        withAnimation(.easeOut(duration: 0.2)) {
            phase = .gameOver
        }
        DispatchQueue.main.async {
            withTransaction(Transaction(animation: nil)) {
                fruits.removeAll()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showResult = true
        }
    }

    private func resetGame() {
        phase = .intro
        introCountdown = 3
        promptOpacity = 0.0
        scoreOpacity  = 0.2
        prepareForGame()
        lastWholeSecond = Int(ceil(timeLeft))
        didNotifyGameEnd = false
        notifiedSteps.removeAll()
    }
}

// MARK: - Tile
struct FruitTile: View {
    let fruitID: UUID
    let modelName: String
    var allowsHitTesting: Bool = true
    var onTap: (UUID) -> Void = { _ in }
    @State private var cached: Entity?

    var body: some View {
        ZStack {
            RealityView { content in
                if let base = cached {
                    let instance = base.clone(recursive: true)
                    instance.name = fruitID.uuidString
                    content.add(instance)
                }
            } update: { content in
                if content.entities.isEmpty, let base = cached {
                    let instance = base.clone(recursive: true)
                    instance.name = fruitID.uuidString
                    content.add(instance)
                }
            }
            .padding(8)
            .gesture(
                SpatialTapGesture()
                    .targetedToAnyEntity()
                    .onEnded { value in
                        guard allowsHitTesting else { return }
                        if let id = owningFruitID(from: value.entity) {
                            onTap(id)
                        }
                    }
            )
            .task {
                do {
                    let base = try await EntityCache.shared.entity(named: modelName)
                    cached = base
                } catch {
                    print("❌ cache load failed:", error)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scaleEffect(1.0)
        .allowsHitTesting(allowsHitTesting)
    }
    
    private func owningFruitID(from entity: Entity) -> UUID? {
        var e: Entity? = entity
        while let cur = e {
            if let id = UUID(uuidString: cur.name) {
                return id
            }
            e = cur.parent
        }
        return nil
    }
}

// ===== 이하 UI 조각(변경 없음/약간만 수정) =====

struct TopTimerPanel: View {
    let currentStep: Int
    let totalSteps: Int
    let stepElapsed: TimeInterval
    let stepDuration: TimeInterval
    
    private var stepProgress: CGFloat {
        let p = 1 - (stepElapsed / stepDuration)
        return CGFloat(min(max(p, 0), 1))
    }
    
    private var stepRemaining: TimeInterval { stepDuration - stepElapsed }
    private var isUrgent: Bool { stepRemaining <= 2.5 }
    
    var body: some View {
        VStack(spacing: 12) {
            Text("\(currentStep) / \(totalSteps)단계")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 12)
                GeometryReader { geo in
                    Capsule()
                        .fill(isUrgent ? Color.red : Color.white)
                        .frame(width: geo.size.width * stepProgress, height: 12)
                }
            }
            .frame(width: 560, height: 12)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background {
            if isUrgent {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.red.opacity(0.2))
            } else {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 8)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct GameOverOverlay: View {
    let score: Int
    var onRestart: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("게임 종료")
                .font(.system(size: 48, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            HStack {
                Text("총")
                    .padding(.trailing, 4)
                Text("\(score)")
                    .fontWeight(.heavy)
                    .foregroundStyle(.yellow)
                Text("개의 과일을 잡았어요!")
            }
            .font(.title.weight(.semibold))
            .foregroundStyle(.white.opacity(0.95))
        }
        .padding(.horizontal, 160)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.19, green: 0.48, blue: 1.0),
                                 Color(red: 0.33, green: 0.36, blue: 0.98)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

private struct CoinChip: View {
    let amount: Int
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "circle.fill")
                .font(.title3)
                .overlay(
                    Image(systemName: "leaf.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                )
                .foregroundStyle(.yellow)
            Text("\(amount)")
                .font(.headline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

struct IntroVideoView: View {
    let url: URL
    @Binding var countdown: TimeInterval
    let onFinish: () -> Void

    @State private var player: AVPlayer?
    private let ticker = Timer.publish(every: 1/30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            if let player {
                FillVideoPlayerView(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        player.seek(to: .zero)
                        player.isMuted = true
                        player.play()
                    }
            } else {
                Color.clear.onAppear {
                    player = AVPlayer(url: url)
                }
            }
        }
        .onReceive(ticker) { _ in
            guard countdown > 0 else { return }
            countdown -= 1/30
            if countdown <= 0 {
                player?.pause()
                onFinish()
            }
        }
    }
}

struct FillVideoPlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerView {
        let v = PlayerView()
        v.playerLayer.player = player
        v.playerLayer.videoGravity = .resizeAspectFill
        v.clipsToBounds = true
        return v
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
    }

    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}

// MARK: - Disappear Effect Model
private struct GrabEffect: Identifiable, Hashable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let color: Color
}

// MARK: - Fruit Burst Effect
private struct GrabBurst: View {
    let baseColor: Color
    let duration: TimeInterval = 0.6
    let onDone: () -> Void

    @State private var seed: UInt64 = .random(in: 0..<UInt64.max)
    @State private var started = Date()

    var body: some View {
        TimelineView(.animation) { ctx in
            let t = min(max(ctx.date.timeIntervalSince(started) / duration, 0), 1)
            ZStack {
                Canvas { context, size in
                    var rng = LCG(seed: seed)
                    let center = CGPoint(x: size.width/2, y: size.height/2)
                    let juice = baseColor
                    let juiceLight = baseColor.opacity(0.85)
                    let juiceDark = baseColor.opacity(0.55)

                    let maxR: CGFloat = 62
                    let r = easeOutCubic(t) * maxR
                    let ringRect = CGRect(x: center.x - r, y: center.y - r, width: r*2, height: r*2)
                    var ringPath = Path()
                    ringPath.addEllipse(in: ringRect)
                    context.stroke(ringPath, with: .color(juiceLight), lineWidth: max(1, 10*(1 - t)))
                    context.blendMode = .plusLighter

                    let wedgeCount = 10
                    for i in 0..<wedgeCount {
                        let baseAng = CGFloat(i) / CGFloat(wedgeCount) * .pi * 2
                        let jitter = CGFloat(rng.nextUnit()) * .pi * 0.15
                        let ang = baseAng + jitter
                        let len = CGFloat(28 + 36 * rng.nextUnit()) * (0.6 + 0.4 * (1 - CGFloat(t)))
                        let spread: CGFloat = .pi * 0.08
                        let tip = CGPoint(x: center.x + cos(ang) * len,
                                          y: center.y + sin(ang) * len)
                        var p = Path()
                        p.move(to: center)
                        p.addLine(to: CGPoint(x: center.x + cos(ang - spread)*len*0.72,
                                              y: center.y + sin(ang - spread)*len*0.72))
                        p.addLine(to: tip)
                        p.addLine(to: CGPoint(x: center.x + cos(ang + spread)*len*0.72,
                                              y: center.y + sin(ang + spread)*len*0.72))
                        p.closeSubpath()
                        context.fill(p, with: .color(juiceDark.opacity(1 - t)))
                    }

                    let dropCount = 14
                    for _ in 0..<dropCount {
                        let ang = CGFloat(rng.nextUnit()) * .pi * 2
                        let v0 = CGFloat(90 + 130 * rng.nextUnit())
                        let vx = cos(ang) * v0
                        let vy = sin(ang) * v0
                        let g: CGFloat = 360
                        let time = CGFloat(t) * 0.55
                        let px = center.x + vx * time * 0.010
                        let py = center.y + (vy * time - 0.5 * g * time * time) * 0.010
                        let s = max(2.5, 6.5 * (1 - CGFloat(t)))
                        let rect = CGRect(x: px - s/2, y: py - s/2, width: s, height: s)
                        let alpha = Double(0.9 - 0.9 * t)
                        context.fill(Path(ellipseIn: rect), with: .color(juice.opacity(alpha)))
                    }

                    let seedCount = 10
                    for _ in 0..<seedCount {
                        let ang = CGFloat(rng.nextUnit()) * .pi * 2
                        let dist = CGFloat(8 + 26 * rng.nextUnit()) * (1 + 0.8 * CGFloat(t))
                        let px = center.x + cos(ang) * dist
                        let py = center.y + sin(ang) * dist
                        let s: CGFloat = 2
                        let rect = CGRect(x: px - s/2, y: py - s/2, width: s, height: s)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.6*(1 - t))))
                    }
                }
                .frame(width: 140, height: 140)
                .opacity(1 - t)

                Circle()
                    .fill(.white.opacity(0.55))
                    .frame(width: 24, height: 24)
                    .opacity(t < 0.08 ? 1 : 0)
                    .scaleEffect(t < 0.08 ? 1 : 1.3)
                    .blendMode(.plusLighter)
            }
            .task {
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                onDone()
            }
        }
    }

    private struct LCG {
        var state: UInt64
        init(seed: UInt64) { self.state = seed &* 6364136223846793005 &+ 1 }
        mutating func next() -> UInt64 {
            state = state &* 2862933555777941757 &+ 3037000493
            return state
        }
        mutating func nextUnit() -> Double { Double(next() % 10_000) / 10_000.0 }
    }

    private func easeOutCubic(_ t: Double) -> CGFloat {
        let x = 1 - pow(1 - t, 3)
        return CGFloat(x)
    }
}

struct ScorePane: View {
    let score: Int
    let flashing: Bool

    var body: some View {
        VStack(spacing: 8) {
            Text("성공한 갯수")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.white)
                .readableOnBusyBG()

            Text("\(score)")
                .font(.system(size: 80, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .readableOnBusyBG()
                .scaleEffect(flashing ? 1.06 : 1.0)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: flashing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(
            flashing
            ? AnyView(
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(Color.yellow.opacity(0.9))
                    RoundedRectangle(cornerRadius: 24).fill(.black.opacity(0.08))
                }
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.12), lineWidth: 1))
            )
            : AnyView(PanelBackground(strength: .strong))
        )
    }
}

struct InstructionPane: View {
    let kind: PromptKind
    let promptColor: Color?
    
    var body: some View {
        VStack(spacing: 12) {
            Text(headerText(for: kind))
                .font(.system(size: 24, weight: .heavy))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .readableOnBusyBG()
                .padding(.top, 8)
            ZStack {
                SubPanelBackground()
                contentView(for: kind)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(12)
        .background(PanelBackground(strength: .strong))
    }
    
    private func headerText(for kind: PromptKind) -> String {
        switch kind {
        case .image:
            return "아래 과일을 잡으세요!"
        case .text(let t):
            if isColorWord(t) {
                return "제시된 색에 맞는\n과일을 잡으세요!"
            } else if shortNameCount(t) <= 4 {
                return "제시된 이름에 맞는\n과일을 잡으세요!"
            } else {
                return "제시된 설명에 맞는\n과일을 잡으세요!"
            }
        }
    }
    
    @ViewBuilder
    private func contentView(for kind: PromptKind) -> some View {
        switch kind {
        case .image(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .shadow(radius: 6)
                .padding(6)
        case .text(let text):
            let isColor = isColorWord(text)
            Text(text)
                .font(.system(size: 36, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(isColor ? (promptColor ?? .white) : .white)
                .minimumScaleFactor(0.6)
                .lineLimit(2)
                .readableOnBusyBG()
                .padding(.vertical, 8)
        }
    }
    
    private func isColorWord(_ s: String) -> Bool { s.contains("색") }
    private func shortNameCount(_ s: String) -> Int {
        s.replacingOccurrences(of: " ", with: "").count
    }
}

private struct SubPanelBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.white.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.black.opacity(0.10))
            )
    }
}

struct PanelBackground: View {
    enum Strength { case normal, strong }
    var strength: Strength = .normal
    var corner: CGFloat = 24
    
    var body: some View {
        let scrimOpacity: Double = (strength == .strong) ? 0.28 : 0.18
        
        return RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.black.opacity(scrimOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 18, y: 8)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

extension View {
    func readableOnBusyBG() -> some View {
        self
            .shadow(color: .black.opacity(0.40), radius: 8, y: 1)
            .shadow(color: .black.opacity(0.20), radius: 2, y: 1)
    }
}
