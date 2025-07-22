import SwiftUI

struct ChatSplashView: View {
    var onContinue: () -> Void
    @State private var animate = false
    var body: some View {
        SplashCardView {
            VStack(spacing: 25) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                    .padding(.bottom, 15)
                    .scaleEffect(animate ? 1 : 0.8)
                    .opacity(animate ? 1 : 0)
                Text("Recomendador de Apps")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)
                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "bubble.left.and.bubble.right.fill", color: .blue, title: "Como funciona?", description: "Descreva uma tarefa ou necessidade e a nossa IA irá sugerir os melhores aplicativos para si.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)
                    InfoRow(icon: "sparkles", color: .blue, title: "Exemplos de Uso", description: "Pode pedir por 'um bom editor de vídeo gratuito' ou 'apps para me ajudar a focar no trabalho'.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)
                }
                .padding(.horizontal)
                Button("Continuar", action: onContinue)
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
