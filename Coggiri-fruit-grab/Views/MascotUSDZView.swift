//
//  MascotUSDZView.swift
//  Coggiri-fruit-grab
//
//  Created by Joni Park on 10/14/25.
//

import SwiftUI
import RealityKit

struct MascotUSDZView: View {
    @EnvironmentObject private var assets: AssetStore
    let mascotText: String
    
    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                let root = Entity()
                content.add(root)
                
                // 캐시에서 복제본 받아서 붙이기
                if let entity = assets.makeMascotInstance() {
                    root.addChild(entity)
                    fit(entity, into: 0.18)
                    
                    let adjust = simd_quatf(angle: .pi/6, axis: [0, -1, 0])
                    entity.orientation = adjust * entity.orientation
                    
                    let camera = PerspectiveCamera()
                    camera.position = [0, 0, 0.36]
                    root.addChild(camera)
                    
                    for anim in entity.availableAnimations {
                        entity.playAnimation(anim.repeat(), transitionDuration: 0.25)
                    }
                } else {
                    // 혹시 프리로드가 아직이면 백업 로드 (1회성)
                    if let fresh = try? await Entity(named: "01", in: .main) {
                        root.addChild(fresh)
                        fit(fresh, into: 0.18)
                        let adjust = simd_quatf(angle: .pi/6, axis: [0, -1, 0])
                        fresh.orientation = adjust * fresh.orientation
                        
                        let camera = PerspectiveCamera()
                        camera.position = [0, 0, 0.36]
                        root.addChild(camera)
                        
                        for anim in fresh.availableAnimations {
                            fresh.playAnimation(anim.repeat(), transitionDuration: 0.25)
                        }
                    }
                }
            }
            .background(.clear)
            .frame(width: 400, height: 320)
            .padding(.leading, 200)
            .padding(.top, 100)
            
            
            SpeechBubble(text: mascotText)
        }
        .frame(width: 400, height: 320)
    }
}

struct MascotUSDZViewRich: View {
    @EnvironmentObject private var assets: AssetStore
    let mascotAttributedText: AttributedString
    
    var body: some View {
        ZStack(alignment: .top) {
            RealityView { content in
                let root = Entity()
                content.add(root)
                
                if let entity = assets.makeMascotInstance() {
                    root.addChild(entity)
                    fit(entity, into: 0.18)
                    
                    let adjust = simd_quatf(angle: .pi/6, axis: [0, -1, 0])
                    entity.orientation = adjust * entity.orientation
                    
                    let camera = PerspectiveCamera()
                    camera.position = [0, 0, 0.36]
                    root.addChild(camera)
                    
                    for anim in entity.availableAnimations {
                        entity.playAnimation(anim.repeat(), transitionDuration: 0.25)
                    }
                } else if let fresh = try? await Entity(named: "01", in: .main) {
                    root.addChild(fresh)
                    fit(fresh, into: 0.18)
                    let adjust = simd_quatf(angle: .pi/6, axis: [0, -1, 0])
                    fresh.orientation = adjust * fresh.orientation
                    
                    let camera = PerspectiveCamera()
                    camera.position = [0, 0, 0.36]
                    root.addChild(camera)
                    
                    for anim in fresh.availableAnimations {
                        fresh.playAnimation(anim.repeat(), transitionDuration: 0.25)
                    }
                }
            }
            .background(.clear)
            .frame(width: 400, height: 320)
            .padding(.leading, 200)
            .padding(.top, 100)
            
            SpeechBubbleRich(attributed: mascotAttributedText)
        }
        .frame(width: 400, height: 320)
    }
}

// 말풍선 (AttributedString + 타자효과)
struct SpeechBubbleRich: View {
    var attributed: AttributedString
    var cornerRadius: CGFloat = 24
    var verticalPadding: CGFloat = 12
    var horizontalPadding: CGFloat = 56
    
    var body: some View {
        RichTypingText(
            full: attributed,
            charDelay: 0.10,
            punctuationDelay: 0.10,
            showCursorWhileTyping: false
        )
        .font(.system(size: 20, weight: .semibold))
        .multilineTextAlignment(.center)
        .foregroundColor(.black) // 기본색 (부분빨강은 attributed 내에 있음)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), Color(white: 0.93)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
        )
        .accessibilityLabel(Text(String(attributed.characters)))
    }
}

// AttributedString 타자 효과
struct RichTypingText: View {
    let full: AttributedString
    var charDelay: Double = 0.04
    var punctuationDelay: Double = 0.25
    var showCursorWhileTyping: Bool = false
    var cursorSymbol: String = "|"

    @State private var visible = AttributedString("")
    @State private var isTyping = false
    @State private var cursorOn = true
    @State private var runToken = 0   // ← 취소 토큰

    var body: some View {
        Text(visible + (isTyping && showCursorWhileTyping && cursorOn ? AttributedString(cursorSymbol) : AttributedString("")))
            .onAppear { startTyping() }
            // ✅ full이 바뀌면 새로 시작
            .onChange(of: full) { startTyping() }
            // 커서 깜박임은 기존대로
            .task(id: isTyping && showCursorWhileTyping) {
                guard showCursorWhileTyping else { return }
                while isTyping {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    cursorOn.toggle()
                }
                cursorOn = false
            }
    }

    private func startTyping() {
        runToken += 1
        let token = runToken

        isTyping = true
        visible = AttributedString("")
        cursorOn = true

        Task {
            for run in full.runs {
                // 다른 실행이 시작되었으면 중단
                guard token == runToken else { return }

                let range = run.range
                let segment = AttributedString(full[range])

                var i = segment.startIndex
                while i < segment.endIndex {
                    guard token == runToken else { return }

                    let j = segment.index(i, offsetByCharacters: 1)
                    let piece = segment[i..<j]
                    visible += piece

                    let ch: Character = piece.characters.first ?? " "
                    let punct: Set<Character> = [".", ",", "!", "?", "…", "\n"]
                    let delay = punct.contains(ch) ? punctuationDelay : charDelay
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

                    i = j
                }
            }
            guard token == runToken else { return }
            isTyping = false
        }
    }
}


// MARK: - Helper
private func fit(_ entity: Entity, into target: Float) {
    let b = entity.visualBounds(relativeTo: nil)
    let maxDim = max(b.extents.x, max(b.extents.y, b.extents.z))
    guard maxDim > 0 else { return }
    let s = target / maxDim
    entity.scale = [s, s, s]
    let c = b.center * s
    entity.position -= c
}

struct SpeechBubble: View {
    var text: String
    
    var cornerRadius: CGFloat = 24
    var verticalPadding: CGFloat = 12
    var horizontalPadding: CGFloat = 56
    
    var body: some View {
        TypingText(
            fullText: text,
            charDelay: 0.1,         // 기본 글자 간 딜레이(초)
            punctuationDelay: 0.1,  // 문장부호/줄바꿈 딜레이(초)
            showCursorWhileTyping: false
        )
        .font(.system(size: 20, weight: .semibold))
        .multilineTextAlignment(.center)
        .foregroundColor(.black)
        .padding(.vertical, verticalPadding)
        .padding(.horizontal, horizontalPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.98), Color(white: 0.93)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.6), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.18), radius: 12, x: 0, y: 6)
        )
        // 접근성: 완성되면 한 번 읽어주도록 힌트
        .accessibilityLabel(Text(text))
    }
}

// MARK: - TypingText (글자별 타이핑 애니메이션 뷰)

struct TypingText: View {
    let fullText: String
    var charDelay: Double = 0.04              // 기본 글자 간 딜레이
    var punctuationDelay: Double = 0.25       // 문장부호/줄바꿈 추가 딜레이
    var showCursorWhileTyping: Bool = false   // 타이핑 중 커서 표시 여부
    var cursorSymbol: String = "|"            // 커서 모양
    
    @State private var visibleText: String = ""
    @State private var isTyping: Bool = false
    @State private var cursorOn: Bool = true  // 깜박임용
    
    var body: some View {
        Text(visibleText + (isTyping && showCursorWhileTyping && cursorOn ? cursorSymbol : ""))
            .onAppear { startTyping() }
            .task(id: isTyping && showCursorWhileTyping) {
                // 커서 깜박임
                guard showCursorWhileTyping else { return }
                while isTyping {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    cursorOn.toggle()
                }
                cursorOn = false
            }
    }
    
    private func startTyping() {
        isTyping = true
        visibleText = ""
        cursorOn = true
        
        Task {
            for ch in fullText {
                // 현재까지 보여줄 문자 추가
                visibleText.append(ch)
                
                // 문장부호/줄바꿈은 조금 더 쉬어가기
                let needsPause = ".,!?…\n".contains(ch)
                let delay = needsPause ? punctuationDelay : charDelay
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            // 종료
            isTyping = false
        }
    }
}
