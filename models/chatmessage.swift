import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    var text: String
    let isFromUser: Bool

    init(id: UUID = UUID(), text: String, isFromUser: Bool) {
        self.id = id
        self.text = text
        self.isFromUser = isFromUser
    }
}
