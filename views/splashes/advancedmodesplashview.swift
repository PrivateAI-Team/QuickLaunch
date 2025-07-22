import SwiftUI

struct AdvancedModeSplashView: View {
    var onContinue: () -> Void
    @State private var animate = false
    var body: some View {
        SplashCardView {
            VStack(spacing: 25) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                    .padding(.bottom, 15)
                    .scaleEffect(animate ? 1 : 0.8)
                    .opacity(animate ? 1 : 0)
                Text("Modo Avançado Ativado!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)
                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "magnifyingglass.circle.fill", color: .blue, title: "Busca Personalizada", description: "Adicione pastas personalizadas onde o QuickLaunch deve procurar por aplicativos, além dos locais padrão.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)
                    InfoRow(icon: "sidebar.left", color: .blue, title: "Gerenciamento Fácil", description: "As pastas que você adicionar aparecerão em uma lista, permitindo que você as remova a qualquer momento.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)
                }
                .padding(.horizontal)
                Button("Entendi", action: onContinue)
                    .buttonStyle(GradientButtonStyle(colors: [.cyan, .blue]))
                    .padding(.top)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.9)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.9), value: animate)
            }
        }
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) { animate = true } }
    }
}
