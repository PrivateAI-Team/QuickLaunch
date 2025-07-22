import SwiftUI

struct PrivacySplashView: View {
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
                Text("Sua Privacidade")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)
                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "paperplane.fill", color: .blue, title: "O que é enviado?", description: "O texto da sua busca e a lista de nomes dos seus aplicativos são enviados aos servidores do Google para processamento.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)
                    InfoRow(icon: "brain.head.profile", color: .blue, title: "Sem Treinamento", description: "O Google não utiliza seus dados de busca da API para treinar os modelos de inteligência artificial.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)
                    InfoRow(icon: "hand.raised.fill", color: .blue, title: "Controle", description: "Nenhuma informação pessoal além dos nomes dos apps é enviada. A funcionalidade pode ser desativada a qualquer momento.")
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
                Button("Entendi, vamos lá!", action: onDismiss)
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
