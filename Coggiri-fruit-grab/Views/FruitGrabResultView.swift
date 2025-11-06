//
//  FruitGrabResultView.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/27/25.
//

import SwiftUI
import Foundation
import AVKit

extension Notification.Name {
    static let ResetToHome = Notification.Name("ResetToHome")
}

struct FruitGrabResultView: View {
    let score: Int
    @State private var enableExitButton = false
    @State private var goHome = false
    @Environment(\.dismiss) private var dismiss
    
    // 업로드 관련 상태
    @State private var isUploading: Bool = false
    @State private var showUploadAlert: Bool = false
    @State private var uploadAlertMessage: String = ""
    @State private var generatedName: String = ""
    
    // 당신의 웹훅/백엔드 엔드포인트로 교체
    private let uploadEndpoint = URL(string: "https://hook.us2.make.com/jgu1f1e5qxjlobjhyn0xr38bez4u8zqu")!
    
    struct ScorePayload: Codable {
        let name: String
        let score: Int
        let createdAt: String
    }
    
    @State private var player: AVPlayer = {
        guard let url = Bundle.main.url(forResource: "game_recap", withExtension: "mp4") else {
            return AVPlayer()
        }
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .pause
        return p
    }()
    
    private var mascotAttributed: AttributedString {
        script(for: enableExitButton)
    }
    
    private func script(for enableExitButton: Bool) -> AttributedString {
        if enableExitButton {
            return colored("""
            오늘은 여기까지 진행하겠습니다.
            고생 많으셨어요. 좋은 하루 되세요!
            """, reds: ["오늘은 여기까지 진행하겠습니다."])
        } else {
            return colored("""
            와! 정말 대단해요!
            """)
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
        VStack {
            ZStack {
                Group {
                    if enableExitButton {
                        // 12초 이후 비디오 대신 이미지로 전환
                        Image("game-recap-end-bg")
                            .resizable()
                            .scaledToFit()
                            .transition(.opacity.combined(with: .scale))
                        
                        VStack(spacing: 8) {
                            Text("트레이닝 세션이 종료되었습니다.")
                            Text("디바이스를 벗어주세요.")
                        }
                        .font(.system(size: 52, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    } else {
                        FitVideoPlayerView(player: player)
                            .transition(.opacity)
                    }
                }
                .aspectRatio(2402/1080, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
                .animation(.easeInOut(duration: 0.32), value: enableExitButton)
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        MascotUSDZViewRich(mascotAttributedText: mascotAttributed)
                    }
                }
            }
            
            HStack(spacing: 30) {
                Button {
                    Task { await uploadRandomRank() }
                } label: {
                    Text("내 순위 업로드하기")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
                
                Button {
                    goHome = true
                } label: {
                    Text("나가기")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(enableExitButton ? Color.blue : Color.blue.opacity(0.5))
                )
            }
            .padding(.horizontal, 108)
            .padding(.bottom, 32)
            .padding(.top, 24)
            .disabled(!enableExitButton)
        }
        .task {
            await MainActor.run {
                player.seek(to: .zero)
                player.play()
            }
            AudioManager.shared.playSFX(named: "09-와정말 대단")
            
            // recap video is 12 seconds
            try? await Task.sleep(nanoseconds: 12 * 1_000_000_000)
            AudioManager.shared.playSFX(named: "10-12")
            await MainActor.run {
                // 전환 직전에 플레이어 정리
                player.pause()
                player.replaceCurrentItem(with: nil)
                enableExitButton = true
            }
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        .navigationDestination(isPresented: $goHome) {
            TrainingHomeView()
                .navigationBarBackButtonHidden(true)
        }
        .navigationBarItems(trailing: CoinBadge(count: enableExitButton ? 440: 400))
        .alert(uploadAlertMessage, isPresented: $showUploadAlert) {
            Button("확인", role: .cancel) { }
        }
    }
    
    // 한국어 랜덤 닉네임 생성
    private func randomKoreanNickname() -> String {
        let adjectives = ["빠른","용감한","반짝이는","싱그러운","씩씩한","슬기로운","귀여운","든든한","맑은","대담한","총명한","상냥한","날쌘","영리한","행복한","당당한"]
        let animals    = ["코끼리","호랑이","수달","판다","여우","너구리","치타","하마","고래","앵무새","다람쥐","물개","기린","독수리","참새","올빼미"]
        return "\(adjectives.randomElement()!) \(animals.randomElement()!)"
    }
    
    @MainActor
    private func uploadRandomRank() async {
        // 1) 랜덤 생성
        let name = randomKoreanNickname()
        
        // 2) 업로드 바디 구성
        isUploading = true
        defer { isUploading = false }
        
        do {
            let iso = ISO8601DateFormatter()
            let payload = ScorePayload(
                name: name,
                score: score,
                createdAt: iso.string(from: Date())
            )
            let body = try JSONEncoder().encode(payload)
            print("Payload JSON:", String(data: body, encoding: .utf8) ?? "nil")
            
            var req = URLRequest(url: uploadEndpoint)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 12
            req.httpBody = body
            
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            // 3) 팝업에 랜덤 이름 & 점수 표시
            generatedName = name
            uploadAlertMessage = "업로드 완료! \(generatedName)님의 점수 \(score)점이 기록되었습니다."
            showUploadAlert = true
        } catch {
            // 실패해도 어떤 값으로 시도했는지 보여주면 UX가 좋아짐
            generatedName = name
            uploadAlertMessage = "업로드 실패: \(error.localizedDescription)\n(시도한 닉네임: \(generatedName), 점수: \(score))"
            showUploadAlert = true
        }
    }
}
