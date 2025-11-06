//
//  FruitGrabVideoView.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/18/25.
//

import SwiftUI
import AVKit

struct FruitGrabVideoView: View {
    @State private var goGame = false
    @State private var didHandleReset = false
    @Environment(\.dismiss) private var dismiss
    
    @State private var player: AVPlayer = {
        guard let url = Bundle.main.url(forResource: "instruction-fruit-grab", withExtension: "mp4") else {
            return AVPlayer()
        }
        let p = AVPlayer(url: url)
        p.actionAtItemEnd = .pause
        return p
    }()
    
    var body: some View {
        VStack {
            // 재생바 없는 커스텀 플레이어
            FitVideoPlayerView(player: player)
                .aspectRatio(2402/1080, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                )
            
            HStack(spacing: 30) {
                Button {
                    replay()
                } label: {
                    Text("다시보기")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    player.pause()
                    goGame = true
                } label: {
                    Text("시작하기")
                        .font(.system(size: 32, weight: .bold))
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
                .background(
                    RoundedRectangle(cornerRadius: 100, style: .continuous)
                        .fill(Color.blue)
                )
            }
            .padding(.horizontal, 108)
            .padding(.bottom, 32)
            .padding(.top, 24)
        }
        .task {
            AudioManager.shared.stopBGM()
            await MainActor.run {
                player.seek(to: .zero)
                player.play()
            }
        }
        .onDisappear {
            player.pause()
            player.replaceCurrentItem(with: nil)
        }
        .navigationDestination(isPresented: $goGame) {
            FruitGrabGameView()
        }
    }
    
    private func replay() {
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        player.play()
    }
}

/// 재생바 제거용 UIViewControllerRepresentable
struct FitVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false // 👈 재생바 제거
        vc.videoGravity = .resizeAspect   // 비율 유지
        vc.view.backgroundColor = .clear
        return vc
    }
    
    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {
        if vc.player !== player { vc.player = player }
        vc.showsPlaybackControls = false
    }
}
