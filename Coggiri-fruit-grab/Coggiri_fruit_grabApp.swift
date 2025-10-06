//
//  Coggiri_fruit_grabApp.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/6/25.
//

import SwiftUI

@main
struct Coggiri_fruit_grabApp: App {
    @StateObject private var assets = AssetStore()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            RootGateView()
                .environmentObject(assets)
        }
        .onChange(of: scenePhase) {
            switch scenePhase {
            case .background, .inactive:
                // 🛑 앱이 백그라운드로 가거나 비활성화되면 모두 정지
                AudioManager.shared.stopBGM()
            case .active:
                break // 복귀 시 자동 재생은 원하면 따로 처리 가능
            @unknown default:
                break
            }
        }
    }
}
