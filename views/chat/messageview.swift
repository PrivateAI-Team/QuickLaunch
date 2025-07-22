import SwiftUI

struct MessageView: View {
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel

    var body: some View {
        HStack {
            if message.isFromUser { Spacer() }
            if !message.isFromUser && message.text.isEmpty {
                TypingIndicatorView()
                    .padding(12)
                    .background(Color.secondary.opacity(0.3))
                    .cornerRadius(16)
                    .transition(.scale)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.text)
                        .frame(maxWidth: 300, alignment: .leading)
                    if message.id == viewModel.lastFailedUserMessage?.id {
                        Button(action: { viewModel.retryLastMessage() }) {
                            Label("Tentar Novamente", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.accentColor)
                        .padding(.top, 2)
                    }
                }
                .padding(12)
                .background(message.isFromUser ? Color.blue : Color.secondary.opacity(0.3))
                .foregroundColor(message.isFromUser ? .white : .primary)
                .cornerRadius(16)
            }
            if !message.isFromUser { Spacer() }
        }
    }
}
