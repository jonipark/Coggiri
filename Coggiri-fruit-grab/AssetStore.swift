//
//  AssetStore.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/19/25.
//

import SwiftUI
import RealityKit

@MainActor
final class AssetStore: ObservableObject {
    @Published private(set) var mascotBase: Entity?
    @Published private(set) var isReady: Bool = false
    private var didPreload = false

    func preload() async {
        guard !didPreload else { return }
        didPreload = true
        do {
            let e = try await Entity(named: "01", in: .main)
            self.mascotBase = e
            // 필요하면 여기서 스케일/머터리얼/애니메이션 준비
        } catch {
            print("Failed to preload mascot:", error)
        }
        self.isReady = true
    }

    func makeMascotInstance() -> Entity? {
        mascotBase?.clone(recursive: true)
    }
}
