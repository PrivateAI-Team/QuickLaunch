import SwiftUI

struct TypingIndicatorView: View {
    @State private var scale: CGFloat = 0.5
    private let animation = Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)
    var body: some View {
        HStack(spacing: 5) {
            Circle().frame(width: 8, height: 8).scaleEffect(scale).animation(animation.delay(0), value: scale)
            Circle().frame(width: 8, height: 8).scaleEffect(scale).animation(animation.delay(0.2), value: scale)
            Circle().frame(width: 8, height: 8).scaleEffect(scale).animation(animation.delay(0.4), value: scale)
        }
        .padding(.horizontal, 8)
        .onAppear { self.scale = 1 }
    }
}
