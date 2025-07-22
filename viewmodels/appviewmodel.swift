import Foundation
import Combine
import SwiftUI

class AppViewModel: ObservableObject {
    @Published var rootItems: [LaunchItem] = []
    @Published var navigationStack: [FolderInfo] = []
    @Published var isLoading: Bool = true
    @Published var isGeminiLoading: Bool = false
    @Published var geminiSearchError: String?
    @Published var aiFilteredApps: [LaunchItem]?
    @Published var lastFailedSearchQuery: String?
    private let geminiService = GeminiService()
    @AppStorage("customSearchPathsData") private var customSearchPathsData: Data = Data()
    @Published var customSearchPaths: [URL] = []
    var currentFolder: FolderInfo? { navigationStack.last }
    var allApps: [LaunchItem] {
        var apps: [LaunchItem] = []
        func collect(from items: [LaunchItem]) {
            for item in items {
                switch item {
                case .app: apps.append(item)
                case .folder(let folder): collect(from: folder.items)
                }
            }
        }
        collect(from: rootItems)
        return apps
    }
    var currentItems: [LaunchItem] {
        (currentFolder?.items ?? rootItems).sorted {
            switch ($0, $1) {
            case (.folder, .app): return true
            case (.app, .folder): return false
            default: return $0.name.lowercased() < $1.name.lowercased()
            }
        }
    }
    var currentTitle: String { currentFolder?.name ?? "QuickLaunch" }

    init() {
        loadCustomPaths()
        fetchApplications()
    }
    deinit { customSearchPaths.forEach { $0.stopAccessingSecurityScopedResource() } }

    func enterFolder(_ folder: FolderInfo) { navigationStack.append(folder) }
    func goBack() { _ = navigationStack.popLast() }

    private func removeItem(withId id: String) {
        rootItems.removeAll { $0.id == id }
        for folder in findAllFolders() {
            folder.objectWillChange.send()
            folder.items.removeAll { $0.id == id }
        }
    }
    private func findAllFolders(in items: [LaunchItem]? = nil) -> [FolderInfo] {
        var folders: [FolderInfo] = []
        let list = items ?? rootItems
        for item in list {
            if case .folder(let folder) = item {
                folders.append(folder)
                folders.append(contentsOf: findAllFolders(in: folder.items))
            }
        }
        return folders
    }
    func findApp(by id: String) -> AppInfo? {
        let allItems = rootItems + findAllFolders().flatMap { $0.items }
        for item in allItems {
            if case .app(let app) = item, app.id == id { return app }
        }
        return nil
    }
    func move(_ draggedApp: AppInfo, onto targetItemID: String) {
        guard draggedApp.id != targetItemID else { return }
        guard let targetItem = (rootItems + findAllFolders().flatMap { $0.items }).first(where: { $0.id == targetItemID }) else { return }
        removeItem(withId: draggedApp.id)
        let draggedLaunchItem = LaunchItem.app(draggedApp)
        switch targetItem {
        case .app(let targetApp):
            removeItem(withId: targetApp.id)
            let newFolder = FolderInfo(name: "Nova Pasta", items: [.app(draggedApp), .app(targetApp)])
            add(item: .folder(newFolder), to: currentFolder)
        case .folder(let targetFolder):
            targetFolder.objectWillChange.send()
            targetFolder.items.append(draggedLaunchItem)
        }
        cleanupEmptyFolders()
        objectWillChange.send()
    }
    func moveAppToRoot(_ app: AppInfo) {
        removeItem(withId: app.id)
        rootItems.append(.app(app))
        cleanupEmptyFolders()
        objectWillChange.send()
    }
    private func add(item: LaunchItem, to folder: FolderInfo?) {
        if let folder = folder { folder.items.append(item) } else { rootItems.append(item) }
    }
    func deleteFolder(withId folderId: String) {
        guard let context = findFolderContext(for: folderId) else { return }
        let itemsToUnpack = context.folderToDelete.items
        if let parent = context.parentFolder {
            parent.items.removeAll { $0.id == folderId }
            parent.items.append(contentsOf: itemsToUnpack)
        } else {
            rootItems.removeAll { $0.id == folderId }
            rootItems.append(contentsOf: itemsToUnpack)
        }
        objectWillChange.send()
    }
    private func findFolderContext(for folderId: String) -> (folderToDelete: FolderInfo, parentFolder: FolderInfo?)? {
        if let rootIndex = rootItems.firstIndex(where: { $0.id == folderId }), case .folder(let folder) = rootItems[rootIndex] {
            return (folder, nil)
        }
        for parent in findAllFolders() {
            if let idx = parent.items.firstIndex(where: { $0.id == folderId }), case .folder(let folder) = parent.items[idx] {
                return (folder, parent)
            }
        }
        return nil
    }
    private func cleanupEmptyFolders() {
        rootItems.removeAll {
            if case .folder(let folder) = $0, folder.items.isEmpty { return true }
            return false
        }
        for folder in findAllFolders() {
            folder.items.removeAll {
                if case .folder(let subFolder) = $0, subFolder.items.isEmpty { return true }
                return false
            }
        }
    }
    func fetchApplications() {
        DispatchQueue.global(qos: .userInitiated).async {
            let fileManager = FileManager.default
            var searchDirectories: [URL] = self.customSearchPaths
            if let local = fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first { searchDirectories.append(local) }
            if let user = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first { searchDirectories.append(user) }
            if let system = fileManager.urls(for: .applicationDirectory, in: .systemDomainMask).first { searchDirectories.append(system) }
            var foundAppsSet = Set<AppInfo>()
            for directory in searchDirectories {
                let opts: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
                if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.nameKey], options: opts) {
                    for case let fileURL as URL in enumerator where fileURL.pathExtension == "app" {
                        let name = fileURL.deletingPathExtension().lastPathComponent
                        let info = AppInfo(name: name, url: fileURL)
                        foundAppsSet.insert(info)
                    }
                }
            }
            let foundApps: [LaunchItem] = Array(foundAppsSet).map { .app($0) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.rootItems = foundApps
                self.isLoading = false
            }
        }
    }
    private func loadCustomPaths() {
        guard !customSearchPathsData.isEmpty else { return }
        do {
            let bookmarks = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSArray.self, from: customSearchPathsData) as? [Data] ?? []
            self.customSearchPaths = bookmarks.compactMap { data in
                var isStale = false
                guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else { return nil }
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        } catch {
            customSearchPaths = []
        }
    }
    private func saveCustomPaths() {
        do {
            let bookmarks = try customSearchPaths.map {
                try $0.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            customSearchPathsData = try NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: false)
        } catch {}
    }
    func addSearchPath() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Escolher Pasta"
        if openPanel.runModal() == .OK, let url = openPanel.url {
            guard !customSearchPaths.contains(url) else { return }
            _ = url.startAccessingSecurityScopedResource()
            self.customSearchPaths.append(url)
            saveCustomPaths()
            fetchApplications()
        }
    }
    func removeSearchPath(at offsets: IndexSet) {
        offsets.forEach { index in
            let url = customSearchPaths[index]
            url.stopAccessingSecurityScopedResource()
        }
        customSearchPaths.remove(atOffsets: offsets)
        saveCustomPaths()
        fetchApplications()
    }
    func findAppsWithAI(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isGeminiLoading = true
        aiFilteredApps = nil
        geminiSearchError = nil
        lastFailedSearchQuery = nil
        let allAppNames = allApps.map { $0.name }
        geminiService.findAppsWithAI(query: query, appNames: allAppNames) { result in
            self.isGeminiLoading = false
            switch result {
            case .success(let names):
                self.aiFilteredApps = self.allApps.filter { names.contains($0.name) }
            case .failure(let error):
                self.lastFailedSearchQuery = query
                if error.localizedDescription.lowercased().contains("overloaded") {
                    self.geminiSearchError = "A pesquisa com IA está sobrecarregada. Por favor, tente novamente mais tarde."
                } else {
                    self.geminiSearchError = "Erro na pesquisa: \(error.localizedDescription)"
                }
            }
        }
    }
}
