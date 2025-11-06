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
                AudioManager.shared.stopBGM()
            case .active:
                break
            @unknown default:
                break
            }
        }
    }
}
