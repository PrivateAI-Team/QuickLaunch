import Foundation

struct AppInfo: Identifiable, Hashable, Codable {
    var id: String { url.absoluteString }
    let name: String
    let url: URL

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool { lhs.url == rhs.url }
    func hash(into hasher: inout Hasher) { hasher.combine(url) }
}
