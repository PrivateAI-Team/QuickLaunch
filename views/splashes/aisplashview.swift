import SwiftUI

struct AISplashView: View {
    var onContinue: () -> Void
    @State private var animate = false
    var body: some View {
        SplashCardView {
            VStack(spacing: 25) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                    .padding(.bottom, 15)
                    .scaleEffect(animate ? 1 : 0.8)
                    .opacity(animate ? 1 : 0)
                Text("Pesquisa com IA Ativada!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)
                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "questionmark.circle.fill", color: .blue, title: "Para que serve?", description: "Use linguagem natural para encontrar seus aplicativos. Você pode pedir por 'apps de imagem' ou 'programas para escrever texto'.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)
                    InfoRow(icon: "exclamationmark.triangle.fill", color: .blue, title: "Pontos de Atenção", description: "A IA pode ocasionalmente cometer erros ou ser um pouco lenta. Uma conexão estável com a internet é recomendada.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)
                    InfoRow(icon: "cpu.fill", color: .blue, title: "Tecnologia Utilizada", description: "Esta funcionalidade é potencializada pelo modelo de linguagem Gemini do Google.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.9), value: animate)
                }
                .padding(.horizontal)
                Button("Continuar", action: onContinue)
                    .buttonStyle(GradientButtonStyle(colors: [.cyan, .blue]))
                    .padding(.top)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.9)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(1.1), value: animate)
            }
        }
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) { animate = true } }
    }
}
