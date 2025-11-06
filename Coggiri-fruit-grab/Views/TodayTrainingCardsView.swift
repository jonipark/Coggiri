//
//  TodayTrainingCardsView.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/18/25.
//

import SwiftUI

// MARK: - Guide Stage

enum GuideStage: Int, CaseIterable {
    case intro0      // 아무 것도 설명 안 됨
    case card1       // 1번째 카드 하이라이트 + 대사2
    case card2       // 2번째 카드 하이라이트 + 대사3
    case card3       // 3번째 카드 하이라이트 + 대사4
    case demoStart   // 1번째 카드 하이라이트 + 시작하기 활성 + 대사5
}

// MARK: - Model

struct TrainingGame:Identifiable, Hashable {
    let id = UUID()
    let title: String
    let imageName: String
    let badges: [String] // 예: ["badge_walk", "badge_sit"]
}


// MARK: - Main View

struct TodayTrainingCardsView: View {
    @State private var selectedIndex: Int = 0
    @State private var showVideoView = false
    @State private var didHandleReset = false
    @State private var stage: GuideStage = .intro0
    @State private var guideTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    
    private let games: [TrainingGame] = [
        .init(title: "과일 잡기",   imageName: "game-preview-fruit",        badges: ["stand"]),
        .init(title: "그림자 놀이", imageName: "game-preview-shadowPlay",   badges: ["stand", "sit"]),
        .init(title: "가든 퍼즐",   imageName: "game-preview-gardenPuzzle", badges: ["stand"])
    ]
    
    // 지금 단계에서 하이라이트할 카드 인덱스
    private var highlightedIndex: Int? {
        switch stage {
        case .intro0:    return nil
        case .card1:     return 0
        case .card2:     return 1
        case .card3:     return 2
        case .demoStart: return 0
        }
    }
    
    // 시작하기 버튼 활성 조건 (데모 스테이지)
    private var isStartEnabled: Bool { stage == .demoStart }
    
    // 코끼리 말풍선(부분 빨강 적용)
    private var mascotAttributed: AttributedString {
        script(for: stage)
    }
    
    // MARK: - Script builder (부분 빨강 강조)

    private func script(for stage: GuideStage) -> AttributedString {
        switch stage {
        case .intro0:
            return colored("""
            사용자의 현재 인지 능력을 바탕으로
            오늘의 게임을 구성했어요.
            """)
            
        case .card1:
            // "순발력 향상"만 빨강
            return colored("""
            먼저 순발력 향상을 위한
            과일 잡기,
            """, reds: ["순발력 향상"])
            
        case .card2:
            // "소근육 발달"만 빨강
            return colored("""
            소근육 발달을 위한
            그림자 놀이,
            """, reds: ["소근육 발달"])
            
        case .card3:
            // "공간지각력"만 빨강
            return colored("""
            공간지각력을 위한 가든 퍼즐까지!
            순서대로 플레이해 볼 거예요.
            """, reds: ["공간지각력"])
            
        case .demoStart:
            // "과일 잡기"만 빨강
            return colored("""
            오늘 Demo Training에서는
            과일 잡기만 진행해 보겠습니다!
            """, reds: ["과일 잡기"])
        }
    }

    // 문자열에서 특정 구절만 빨강(및 약간 Bold)으로 칠한 AttributedString 생성
    private func colored(_ text: String, reds: [String] = []) -> AttributedString {
        var a = AttributedString(text)
        for key in reds {
            if let r = a.range(of: key) {
                a[r].foregroundColor = .red
                a[r].font = .system(size: 20, weight: .bold)
            }
        }
        return a
    }

    var body: some View {
        ZStack {
            VStack(spacing: 12) {
                // Cards row
                HStack(alignment: .center, spacing: 28) {
                    ForEach(games.indices, id: \.self) { idx in
                        let style: CardHighlightStyle = {
                            if let hi = highlightedIndex {
                                return (hi == idx) ? .highlight : .dim
                            } else {
                                return .normal
                            }
                        }()
                        
                        GameCardView(
                            game: games[idx],
                            style: style
                        )
                        .onTapGesture {
                            selectedIndex = idx
                        }
                        
                        if idx < games.count - 1 {
                            Image("card-step-arrow")
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 2)
                
                Spacer()
                
                Button {
                    showVideoView = true
                } label: {
                    Text("시작하기")
                        .font(.system(size: 40, weight: .bold))
                        .underline(false)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(isStartEnabled ? Color.blue : Color.gray.opacity(0.35))
                )
                .foregroundColor(.white)
                .opacity(isStartEnabled ? 1 : 0.6)
                .disabled(!isStartEnabled)
                .padding(.horizontal, 48)
                .padding(.bottom, 40)
            }
            
            // Mascot + bubble docked at bottom-right
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    MascotUSDZViewRich(mascotAttributedText: mascotAttributed)
                }
            }
        }
        .onAppear {
            // 왼→오 순차 설명 진행
            guideTask?.cancel() // 혹시 남아있으면 정리
            guideTask = Task { @MainActor in
                AudioManager.shared.playSFX(named: "03-사용자의 현재 인지 능력")
                
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                withAnimation(.easeInOut) { stage = .card1 }
                
                AudioManager.shared.playSFX(named: "04-먼저 순발력 향상")
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.easeInOut) { stage = .card2 }
                
                AudioManager.shared.playSFX(named: "05-소근육 발달을 위한")
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                withAnimation(.easeInOut) { stage = .card3 }
                
                AudioManager.shared.playSFX(named: "06-07")
                try? await Task.sleep(nanoseconds: 3_800_000_000)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { stage = .demoStart }
                
                AudioManager.shared.playSFX(named: "08-오늘 Demo Training")
            }
        }
        .onDisappear {
            guideTask?.cancel()
            guideTask = nil
            AudioManager.shared.stopAllSFX()
        }
        .onReceive(NotificationCenter.default.publisher(for: .ResetToHome)) { _ in
            guard !didHandleReset else { return }
            didHandleReset = true
            
            if showVideoView {
                showVideoView = false
                guideTask?.cancel()
                guideTask = nil
                AudioManager.shared.stopAllSFX()
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .ResetToHome, object: nil)
                }
            } else {
                guideTask?.cancel()
                guideTask = nil
                AudioManager.shared.stopAllSFX()
                dismiss()
            }
        }
        .navigationBarTitle("오늘의 트레이닝")
        .navigationBarItems(trailing: CoinBadge(count: 400))
        .navigationDestination(isPresented: $showVideoView) {
            FruitGrabVideoView()
        }
    }
}

enum CardHighlightStyle { case normal, highlight, dim }

// MARK: - Card

struct GameCardView: View {
    let game: TrainingGame
    let style: CardHighlightStyle

    private let cardSize = CGSize(width: 320, height: 460)
    private let corner   = 28.0

    var body: some View {
        let isHighlight = (style == .highlight)
        let isDim       = (style == .dim)

        VStack(spacing: 24) {
            // Badges
            HStack(spacing: 8) {
                ForEach(game.badges, id: \.self) { symbol in
                    SmallBadgeView(iconName: symbol)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.top, 4)

            // Preview
            Image(game.imageName)
                .resizable()
                .scaledToFit()
                .shadow(radius: 4, y: 2)
                .frame(width: 270, height: 270)
                .saturation(isDim ? 0.6 : 1.0)
                .opacity(isDim ? 0.7 : 1.0)

            // Title pill
            Text(game.title)
                .font(.system(size: 40, weight: .bold))
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    Capsule(style: .continuous)
                        .fill(.thinMaterial)
                )
        }
        .padding(16)
        .frame(width: cardSize.width, height: cardSize.height)

        // 배경: 하이라이트일 때만 BG 이미지 + 기존 fill 유지
        .background(
            ZStack {
                if isHighlight {
                    Image("card-highlight-bg")
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(isHighlight ? 1.04 : (isDim ? 0.98 : 1.0))
                }
                
                Group {
                    if isHighlight {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    } else {
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .fill(.ultraThinMaterial)
                    }
                }
            }
        )
        .overlay(
            Group {
                if isHighlight {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.7), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .shadow(color: .white.opacity(0.45), radius: 12)
                } else {
                    RoundedRectangle(cornerRadius: corner, style: .continuous)
                        .stroke(.white.opacity(0.2), lineWidth: 0.6)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .scaleEffect(isHighlight ? 1.04 : (isDim ? 0.98 : 1.0))
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: isHighlight)
        .animation(.easeInOut(duration: 0.25), value: isDim)
    }
}

struct SmallBadgeView: View {
    let iconName: String
    
    var body: some View {
        Image(iconName)
            .resizable()
            .scaledToFit()
            .frame(width: 36, height: 36)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(radius: 1, y: 1)
    }
}
