import SwiftUI

struct ChatPrivacySplashView: View {
    var onDismiss: () -> Void
    @State private var animate = false
    var body: some View {
        SplashCardView {
            VStack(spacing: 25) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                    .padding(.bottom, 15)
                    .scaleEffect(animate ? 1 : 0.8)
                    .opacity(animate ? 1 : 0)
                Text("Sua Privacidade no Chat")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)
                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "paperplane.fill", color: .blue, title: "O que é enviado?", description: "O texto que você digita na conversa é enviado aos servidores do Google para gerar as recomendações de aplicativos.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)
                    InfoRow(icon: "brain.head.profile", color: .blue, title: "Sem Treinamento", description: "O Google não utiliza suas conversas da API para treinar os modelos de inteligência artificial.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)
                    InfoRow(icon: "nosign", color: .blue, title: "Não é Salvo", description: "A conversa não é guardada. Cada vez que você abre o chat, uma nova sessão se inicia.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.9), value: animate)
                }
                .padding(.horizontal)
                VStack(spacing: 10) {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                        .symbolRenderingMode(.hierarchical)
                        .padding(12)
                        .background(.black.opacity(0.1))
                        .clipShape(Circle())
                    if let url = URL(string: "https://cloud.google.com/gemini/docs/discover/data-governance") {
                        Link("Saiba mais sobre a privacidade de dados", destination: url)
                            .font(.footnote)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.top, 15)
                .opacity(animate ? 1 : 0)
                .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(1.1), value: animate)
                Button("Entendi, vamos conversar!", action: onDismiss)
                    .buttonStyle(GradientButtonStyle(colors: [.cyan, .blue]))
                    .padding(.top)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.9)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(1.3), value: animate)
            }
        }
        .onAppear { withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) { animate = true } }
    }
}
