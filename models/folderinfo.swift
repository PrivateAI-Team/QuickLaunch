import Foundation
import Combine

class FolderInfo: Identifiable, Hashable, ObservableObject {
    let id: String
    @Published var name: String
    @Published var items: [LaunchItem]

    init(id: String = UUID().uuidString, name: String, items: [LaunchItem] = []) {
        self.id = id
        self.name = name
        self.items = items
    }

    static func == (lhs: FolderInfo, rhs: FolderInfo) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
