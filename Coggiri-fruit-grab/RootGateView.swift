//
//  RootGateView.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/19/25.
//

import SwiftUI

struct RootGateView: View {
    @EnvironmentObject private var assets: AssetStore

    var body: some View {
        Group {
            if assets.isReady {
                TrainingHomeView()   // ← 당신의 메인 뷰
            } else {
                SplashLoadingView()  // ← 프리로드 동안 보여줄 화면
            }
        }
        .task {
            await assets.preload()   // 앱 시작 직후 1회만 실행
        }
    }
}

struct SplashLoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.15), .indigo.opacity(0.12)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 16) {
                Text("리소스를 준비하고 있어요…")
                    .font(.title3.weight(.semibold))
                ProgressView()
            }
        }
        .ignoresSafeArea()
        // 접근성: 로딩 안내
        .accessibilityLabel(Text("리소스를 준비 중입니다"))
    }
}
