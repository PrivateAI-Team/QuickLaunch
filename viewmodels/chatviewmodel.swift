import Foundation
import Combine
import SwiftUI

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isAwaitingResponse = false
    @Published var lastFailedUserMessage: (id: UUID, text: String)?
    private let geminiService = GeminiService()
    private var typingTimer: AnyCancellable?

    init() {
        messages.append(ChatMessage(text: "Olá! Descreva uma tarefa ou necessidade e eu recomendarei aplicativos para você. Por exemplo: 'Preciso de um bom editor de imagens que seja gratuito'.", isFromUser: false))
    }
    func sendMessage(_ messageText: String) {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAwaitingResponse else { return }
        lastFailedUserMessage = nil
        messages.append(ChatMessage(text: trimmed, isFromUser: true))
        isAwaitingResponse = true
        let aiMessageId = UUID()
        messages.append(ChatMessage(id: aiMessageId, text: "", isFromUser: false))
        geminiService.sendChatMessage(message: trimmed) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let aiResponse):
                self.typeOutResponse(text: aiResponse, messageId: aiMessageId)
            case .failure(let error):
                let errorMessage: String
                if error.localizedDescription.lowercased().contains("overloaded") {
                    errorMessage = "O nosso assistente está muito ocupado no momento. Por favor, tente novamente dentro de alguns instantes."
                } else {
                    errorMessage = "Desculpe, ocorreu um erro. Por favor, verifique a sua ligação à Internet e tente novamente."
                }
                if let index = self.messages.firstIndex(where: { $0.id == aiMessageId }) {
                    self.messages[index].text = errorMessage
                }
                self.lastFailedUserMessage = (id: aiMessageId, text: trimmed)
                self.isAwaitingResponse = false
            }
        }
    }
    func retryLastMessage() {
        guard let info = lastFailedUserMessage else { return }
        messages.removeAll { $0.id == info.id }
        sendMessage(info.text)
    }
    private func typeOutResponse(text: String, messageId: UUID) {
        var charIndex = 0
        let chars = Array(text)
        typingTimer?.cancel()
        typingTimer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect().sink { [weak self] _ in
            guard let self = self else { return }
            if charIndex < chars.count {
                if let idx = self.messages.firstIndex(where: { $0.id == messageId }) {
                    self.messages[idx].text.append(chars[charIndex])
                    charIndex += 1
                } else {
                    self.typingTimer?.cancel()
                    self.isAwaitingResponse = false
                }
            } else {
                self.typingTimer?.cancel()
                self.isAwaitingResponse = false
            }
        }
    }
}
