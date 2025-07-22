import SwiftUI

struct SplashCardView<Content: View>: View {
    let content: Content
    @State private var animateBackground = false

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        ZStack {
            Rectangle().fill(.black.opacity(animateBackground ? 0.7 : 0)).ignoresSafeArea()
            VStack { content }
                .padding(35)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 25, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 25, style: .continuous).stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5))
                .cornerRadius(25)
                .shadow(color: .black.opacity(0.4), radius: 30)
                .frame(maxWidth: 520)
                .padding(40)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)), removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9))))
        }
        .onAppear { withAnimation(.easeOut(duration: 0.4)) { animateBackground = true } }
        .onDisappear { animateBackground = false }
    }
}

@ViewBuilder
func InfoRow(icon: String, color: Color, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 20) {
        Image(systemName: icon)
            .font(.title)
            .foregroundColor(color)
            .frame(width: 35)
            .shadow(color: color.opacity(0.4), radius: 7)
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline).fontWeight(.bold)
            Text(description).foregroundColor(.secondary).font(.subheadline).fixedSize(horizontal: false, vertical: true)
        }
    }
}
