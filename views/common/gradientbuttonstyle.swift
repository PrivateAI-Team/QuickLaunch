import SwiftUI

struct GradientButtonStyle: ButtonStyle {
    var colors: [Color]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.bold)
            .foregroundColor(.white.opacity(0.9))
            .padding()
            .frame(maxWidth: .infinity)
            .background(LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing))
            .cornerRadius(14)
            .shadow(color: colors.first?.opacity(0.5) ?? .black.opacity(0.4), radius: configuration.isPressed ? 6 : 12, y: configuration.isPressed ? 3 : 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
