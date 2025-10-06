//
//  TrainingHomeView.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/14/25.
//

import SwiftUI

struct TrainingHomeView: View {
    @State private var showTodayTraining = false
    @State private var selectedTraining: String = "오늘의 트레이닝"
    @State private var showDemoToast = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack {
                    HeaderBar()
                    TrainingCard(onStart: { showTodayTraining = true })
                    Spacer()
                }
                .padding(.top, 24)
                .padding(.horizontal, 36)
                
                // Mascot + bubble docked at bottom-right
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MascotUSDZView(mascotText: "Coggiri에 오신 것을\n환영합니다!")
                    }
                }
            }
            .onAppear {
                AudioManager.shared.stopBGM()
                AudioManager.shared.playBGM(named: "serviceBGM")
                AudioManager.shared.playSFX(named: "01-Cogirri에 오신걸")
            }
            .overlay(alignment: .bottom) {
                if showDemoToast {
                    DemoToast(message: "데모 플레이에서는 오늘의 트레이닝만 제공됩니다.")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 16)
                }
            }
            .animation(.smooth, value: showDemoToast)
            .ornament(attachmentAnchor: .scene(.bottom)) {
                HStack(spacing: 12) {
                    trainingButton("오늘의 트레이닝")
                    trainingButton("두뇌 훈련")
                    trainingButton("신체 훈련")
                    trainingButton("친구와 함께하기")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .navigationDestination(isPresented: $showTodayTraining) {
                TodayTrainingCardsView()
            }
        }
    }
    
    @ViewBuilder
    func trainingButton(_ title: String) -> some View {
        Button {
            selectedTraining = title
            
            if title != "오늘의 트레이닝" {
                // ⬇️ 효과음 1회 재생
                AudioManager.shared.playSFX(named: "system_denied")
                
                // ⬇️ 토스트 잠깐 보여주기
                showDemoToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showDemoToast = false
                }
            }
        } label: {
            Text(title)
                .padding(.vertical, 6)
                .padding(.horizontal, 20)
                .cornerRadius(8)
        }
        .buttonStyle(.borderedProminent)
    }
}

// MARK: - Header
struct HeaderBar: View {
    var body: some View {
        HStack {
            Text(formattedDate(Date()))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.secondary)

            Spacer()

            CoinBadge(count: 400)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ko_KR")
        fmt.dateFormat = "yyyy년 M월 d일 E요일"
        return fmt.string(from: date)
    }
}

// MARK: - Main Card
struct TrainingCard: View {
    var onStart: () -> Void = {}
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Image("training-home-bg")
                .resizable()
                .scaledToFit()

            // Content stack
            HStack {
                Spacer()
                VStack {
                    (
                        Text("순발력").bold() +
                        Text("과 ") +
                        Text("집중력").bold() +
                        Text("을 길러보세요.")
                    )
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.3))
                    )
                    
                    VStack(alignment: .center, spacing: 6) {
                        Text("안녕하세요,")
                        Text("오늘의 트레이닝을 해볼까요?")
                    }
                    .font(.system(size: 56, weight: .black))
                    .foregroundStyle(.white)
                    
                    HStack {
                        Image(systemName: "clock")
                        Text("약 3분 소요")
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 28, weight: .bold))
                    .padding(.top, 2)
                    
                    Spacer()
                    
                    StartButton(title: "시작하기", action: onStart)
                }
                Spacer()
            }
            .padding(.vertical, 48)
        }
        .frame(height: 520)
        .padding(20)
    }
}

struct StartButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button() {
            AudioManager.shared.playSFX(named: "start")
            action()
        } label: {
            Text(title)
                .font(.system(size: 36, weight: .bold))
                .frame(width: 280, height: 92)
            
        }
        .foregroundStyle(.white)
    }
}

struct CoinBadge: View {
    var count: Int

    var body: some View {
        HStack(spacing: 8) {
            Image("seed")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
            Text("\(count)")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Capsule().fill(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.5),
                        Color.black.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
        )
    }
}

struct DemoToast: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title3)
            Text(message)
                .font(.headline)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 8)
    }
}
