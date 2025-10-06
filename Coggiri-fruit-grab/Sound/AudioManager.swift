//
//  AudioManager.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 11/1/25.
//

import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var bgmPlayer: AVAudioPlayer?
    private var sfxPlayers: [AVAudioPlayer] = []   // 여러 효과음을 동시에 재생 가능하게

    // MARK: - 배경음 (루프)
    func playBGM(named fileName: String, withExtension ext: String = "wav") {
        stopBGM() // 기존 BGM 정지
        guard let url = Bundle.main.url(forResource: fileName, withExtension: ext) else {
            print("❌ BGM file not found: \(fileName).\(ext)")
            return
        }

        do {
            bgmPlayer = try AVAudioPlayer(contentsOf: url)
            bgmPlayer?.numberOfLoops = -1  // 무한 반복
            bgmPlayer?.volume = 0.5
            bgmPlayer?.prepareToPlay()
            bgmPlayer?.play()
        } catch {
            print("BGM error: \(error)")
        }
    }

    func stopBGM() {
        bgmPlayer?.stop()
        bgmPlayer = nil
    }

    // MARK: - 효과음 (한 번만 재생)
    func playSFX(named fileName: String, withExtension ext: String = "wav") {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: ext) else {
            print("❌ SFX file not found: \(fileName).\(ext)")
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = 0
            player.volume = 1.0
            player.play()

            // 끝난 후 자동 정리
            sfxPlayers.append(player)
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) {
                self.sfxPlayers.removeAll { $0 === player }
            }
        } catch {
            print("SFX error: \(error)")
        }
    }
    
    func stopAllSFX() {
        // 현재 재생 중인 모든 효과음을 멈추고 배열 비우기
        for player in sfxPlayers {
            player.stop()
        }
        sfxPlayers.removeAll()
    }
}
