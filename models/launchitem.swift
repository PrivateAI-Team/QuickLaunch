import Foundation

enum LaunchItem: Identifiable, Hashable {
    case app(AppInfo)
    case folder(FolderInfo)

    var id: String {
        switch self {
        case .app(let app): return app.id
        case .folder(let folder): return folder.id
        }
    }

    var name: String {
        switch self {
        case .app(let app): return app.name
        case .folder(let folder): return folder.name
        }
    }
}
