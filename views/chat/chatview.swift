import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                Text("Recomendador de Apps")
                    .font(.title2).fontWeight(.bold)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message, viewModel: viewModel)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                .onChange(of: viewModel.messages.last?.text) { _ in
                    if let last = viewModel.messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            HStack(spacing: 15) {
                TextField("Ex: 'Um app para controlar minhas tarefas'", text: $messageText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Color.secondary.opacity(0.15))
                    .cornerRadius(12)
                    .focused($isTextFieldFocused)
                    .onSubmit(sendMessage)
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(messageText.isEmpty || viewModel.isAwaitingResponse)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 500, idealHeight: 600)
        .onAppear { isTextFieldFocused = true }
    }
    private func sendMessage() {
        viewModel.sendMessage(messageText)
        messageText = ""
    }
}
