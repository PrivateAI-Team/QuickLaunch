New vewsion - QuickLaunch v1.0.1
import SwiftUI
import Combine

@main
struct QuickLaunchApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}

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

struct AppInfo: Identifiable, Hashable, Codable {
    var id: String { url.absoluteString }
    let name: String
    let url: URL

    static func == (lhs: AppInfo, rhs: AppInfo) -> Bool {
        return lhs.url == rhs.url
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }
}

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

struct GeminiService {
    struct GeminiRequest: Codable {
        let contents: [Content]
        let generationConfig: GenerationConfig?
    }
    struct Content: Codable {
        let parts: [Part]
    }
    struct Part: Codable {
        let text: String
    }
    struct GenerationConfig: Codable {
        let responseMimeType: String
    }

    struct GeminiResponse: Codable {
        struct Candidate: Codable {
            let content: Content
        }
        let candidates: [Candidate]?
        let error: APIError?
    }
    
    struct AppSearchResponse: Codable {
        let apps: [String]
    }
    
    struct APIError: Codable, Error, LocalizedError {
        let message: String
        
        var errorDescription: String? {
            return message
        }
    }

    private let apiKey = "AIzaSyDSzsoIaHbpxOZYwq8OReW7e4pCwY45dk8"
    private let urlSession = URLSession.shared

    func findAppsWithAI(query: String, appNames: [String], retries: Int = 100, completion: @escaping (Result<[String], Error>) -> Void) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "URL do endpoint inválida."])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Você é uma API de busca inteligente. Sua tarefa é encontrar aplicativos em uma lista fornecida que correspondam à pesquisa do usuário.
        Pesquisa do usuário: "\(query)"
        Lista de aplicativos disponíveis: \(appNames.joined(separator: ", "))
        Responda APENAS com um objeto JSON no formato {"apps": ["AppName1", "AppName2", ...]} contendo os nomes dos aplicativos correspondentes da lista. Se nenhum aplicativo corresponder, retorne um array vazio.
        """
        
        let requestBody = GeminiRequest(
            contents: [Content(parts: [Part(text: prompt)])],
            generationConfig: GenerationConfig(responseMimeType: "application/json")
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        urlSession.dataTask(with: request) { data, response, error in
            let hasNetworkError = error != nil
            let hasServerError = (response as? HTTPURLResponse)?.statusCode ?? 200 >= 500
            
            if (hasNetworkError || hasServerError) && retries > 0 {
                print("Falha na busca de apps, tentando novamente... Tentativas restantes: \(retries - 1)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    self.findAppsWithAI(query: query, appNames: appNames, retries: retries - 1, completion: completion)
                }
                return
            }

            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(NSError(domain: "NoData", code: 0, userInfo: [NSLocalizedDescriptionKey: "Nenhum dado recebido do servidor."])))
                    return
                }

                do {
                    let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    
                    if decodedResponse.error != nil && retries > 0 {
                        print("API retornou um erro na busca de apps, tentando novamente... Tentativas restantes: \(retries - 1)")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                            self.findAppsWithAI(query: query, appNames: appNames, retries: retries - 1, completion: completion)
                        }
                        return
                    }
                    
                    if let apiError = decodedResponse.error {
                        completion(.failure(apiError))
                    } else if let text = decodedResponse.candidates?.first?.content.parts.first?.text,
                              let jsonData = text.data(using: .utf8) {
                        let appSearchResponse = try JSONDecoder().decode(AppSearchResponse.self, from: jsonData)
                        completion(.success(appSearchResponse.apps))
                    } else {
                        if retries > 0 {
                            print("Resposta inesperada na busca de apps, tentando novamente... Tentativas restantes: \(retries - 1)")
                            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                                self.findAppsWithAI(query: query, appNames: appNames, retries: retries - 1, completion: completion)
                            }
                            return
                        }
                        let rawString = String(data: data, encoding: .utf8) ?? "Resposta inválida."
                        completion(.failure(NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Formato de resposta inesperado: \(rawString)"])))
                    }
                } catch {
                    if retries > 0 {
                        print("Erro de decodificação na busca de apps, tentando novamente... Tentativas restantes: \(retries - 1)")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                            self.findAppsWithAI(query: query, appNames: appNames, retries: retries - 1, completion: completion)
                        }
                        return
                    }
                    let rawString = String(data: data, encoding: .utf8) ?? "Erro ao decodificar."
                    completion(.failure(NSError(domain: "DecodingError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Falha ao decodificar a resposta: \(error.localizedDescription). Resposta bruta: \(rawString)"])))
                }
            }
        }.resume()
    }
    
    func sendChatMessage(message: String, retries: Int = 100, completion: @escaping (Result<String, Error>) -> Void) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: [NSLocalizedDescriptionKey: "URL do endpoint inválida."])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let prompt = """
        Você é um assistente prestativo especializado em recomendar aplicativos para macOS.
        Sua conversa com o usuário é privada e não será salva.
        O usuário irá descrever uma necessidade. Sua tarefa é sugerir um ou mais aplicativos que atendam a essa necessidade.
        Para cada sugestão, forneça o nome do aplicativo em negrito (ex: **Nome do App**) e uma breve descrição do que ele faz.
        Se você não souber um aplicativo, diga que não conseguiu encontrar uma recomendação.

        Necessidade do usuário: "\(message)"

        Sugestões:
        """

        let requestBody = GeminiRequest(
            contents: [Content(parts: [Part(text: prompt)])],
            generationConfig: nil
        )

        do {
            request.httpBody = try JSONEncoder().encode(requestBody)
        } catch {
            completion(.failure(error))
            return
        }

        urlSession.dataTask(with: request) { data, response, error in
            let hasNetworkError = error != nil
            let hasServerError = (response as? HTTPURLResponse)?.statusCode ?? 200 >= 500

            if (hasNetworkError || hasServerError) && retries > 0 {
                print("Falha no chat, tentando novamente... Tentativas restantes: \(retries - 1)")
                DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                    self.sendChatMessage(message: message, retries: retries - 1, completion: completion)
                }
                return
            }

            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data else {
                    completion(.failure(NSError(domain: "NoData", code: 0, userInfo: [NSLocalizedDescriptionKey: "Nenhum dado recebido do servidor."])))
                    return
                }

                do {
                    let decodedResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
                    
                    if decodedResponse.error != nil && retries > 0 {
                        print("API retornou um erro no chat, tentando novamente... Tentativas restantes: \(retries - 1)")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                            self.sendChatMessage(message: message, retries: retries - 1, completion: completion)
                        }
                        return
                    }
                    
                    if let apiError = decodedResponse.error {
                        completion(.failure(apiError))
                    } else if let text = decodedResponse.candidates?.first?.content.parts.first?.text {
                        completion(.success(text))
                    } else {
                        if retries > 0 {
                            print("Resposta inesperada no chat, tentando novamente... Tentativas restantes: \(retries - 1)")
                            DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                                self.sendChatMessage(message: message, retries: retries - 1, completion: completion)
                            }
                            return
                        }
                        completion(.failure(NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "Formato de resposta inesperado."])))
                    }
                } catch {
                    if retries > 0 {
                        print("Erro de decodificação no chat, tentando novamente... Tentativas restantes: \(retries - 1)")
                        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
                            self.sendChatMessage(message: message, retries: retries - 1, completion: completion)
                        }
                        return
                    }
                    completion(.failure(error))
                }
            }
        }.resume()
    }
}

class AppViewModel: ObservableObject {
    @Published var rootItems: [LaunchItem] = []
    @Published var navigationStack: [FolderInfo] = []
    @Published var isLoading: Bool = true
    
    @Published var isGeminiLoading: Bool = false
    @Published var geminiSearchError: String?
    @Published var aiFilteredApps: [LaunchItem]? = nil
    
    @Published var lastFailedSearchQuery: String? = nil

    private let geminiService = GeminiService()
    
    @AppStorage("customSearchPathsData") private var customSearchPathsData: Data = Data()
    @Published var customSearchPaths: [URL] = []
    
    var currentFolder: FolderInfo? { navigationStack.last }
    
    var allApps: [LaunchItem] {
        var apps: [LaunchItem] = []
        func collectApps(from items: [LaunchItem]) {
            for item in items {
                switch item {
                case .app:
                    apps.append(item)
                case .folder(let folderInfo):
                    collectApps(from: folderInfo.items)
                }
            }
        }
        collectApps(from: rootItems)
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
    
    deinit {
        customSearchPaths.forEach { $0.stopAccessingSecurityScopedResource() }
    }

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
        let itemsToSearch = items ?? rootItems
        for item in itemsToSearch {
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
            if case .app(let app) = item, app.id == id {
                return app
            }
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
        if let folder = folder {
            folder.items.append(item)
        } else {
            rootItems.append(item)
        }
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
        
        for potentialParent in findAllFolders() {
            if let itemIndex = potentialParent.items.firstIndex(where: { $0.id == folderId }), case .folder(let folder) = potentialParent.items[itemIndex] {
                return (folder, potentialParent)
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

            if let localAppsURL = fileManager.urls(for: .applicationDirectory, in: .localDomainMask).first {
                searchDirectories.append(localAppsURL)
            }
            if let userAppsURL = fileManager.urls(for: .applicationDirectory, in: .userDomainMask).first {
                searchDirectories.append(userAppsURL)
            }
            if let systemAppsURL = fileManager.urls(for: .applicationDirectory, in: .systemDomainMask).first {
                searchDirectories.append(systemAppsURL)
            }

            var foundAppsSet = Set<AppInfo>()

            for directory in searchDirectories {
                let enumeratorOptions: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
                if let enumerator = fileManager.enumerator(at: directory,
                                                           includingPropertiesForKeys: [.nameKey],
                                                           options: enumeratorOptions) {
                    
                    for case let fileURL as URL in enumerator where fileURL.pathExtension == "app" {
                        let appName = fileURL.deletingPathExtension().lastPathComponent
                        let appInfo = AppInfo(name: appName, url: fileURL)
                        foundAppsSet.insert(appInfo)
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
                guard let url = try? URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) else {
                    return nil
                }
                _ = url.startAccessingSecurityScopedResource()
                return url
            }
        } catch {
            print("Falha ao carregar pastas personalizadas: \(error)")
            customSearchPaths = []
        }
    }

    private func saveCustomPaths() {
        do {
            let bookmarks = try customSearchPaths.map {
                try $0.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            }
            customSearchPathsData = try NSKeyedArchiver.archivedData(withRootObject: bookmarks, requiringSecureCoding: false)
        } catch {
            print("Falha ao salvar pastas personalizadas: \(error)")
        }
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
            case .success(let foundNames):
                self.aiFilteredApps = self.allApps.filter { foundNames.contains($0.name) }
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

class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isAwaitingResponse = false
    
    @Published var lastFailedUserMessage: (id: UUID, text: String)? = nil
    
    private let geminiService = GeminiService()
    private var typingTimer: AnyCancellable?

    init() {
        messages.append(ChatMessage(text: "Olá! Descreva uma tarefa ou necessidade e eu recomendarei aplicativos para você. Por exemplo: 'Preciso de um bom editor de imagens que seja gratuito'.", isFromUser: false))
    }
    
    func sendMessage(_ messageText: String) {
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty, !isAwaitingResponse else { return }
        
        lastFailedUserMessage = nil
        
        messages.append(ChatMessage(text: trimmedText, isFromUser: true))
        isAwaitingResponse = true
        
        let aiMessageId = UUID()
        messages.append(ChatMessage(id: aiMessageId, text: "", isFromUser: false))
        
        geminiService.sendChatMessage(message: trimmedText) { [weak self] result in
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
                self.lastFailedUserMessage = (id: aiMessageId, text: trimmedText)
                self.isAwaitingResponse = false
            }
        }
    }
    
    func retryLastMessage() {
        guard let failedMessageInfo = lastFailedUserMessage else { return }
        
        messages.removeAll { $0.id == failedMessageInfo.id }
        
        sendMessage(failedMessageInfo.text)
    }
    
    private func typeOutResponse(text: String, messageId: UUID) {
        var charIndex = 0
        let responseChars = Array(text)
        
        typingTimer?.cancel()
        
        typingTimer = Timer.publish(every: 0.03, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                if charIndex < responseChars.count {
                    if let index = self.messages.firstIndex(where: { $0.id == messageId }) {
                        self.messages[index].text.append(responseChars[charIndex])
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

struct TypingIndicatorView: View {
    @State private var scale: CGFloat = 0.5
    private let animation = Animation.easeInOut(duration: 0.4).repeatForever(autoreverses: true)

    var body: some View {
        HStack(spacing: 5) {
            Circle().frame(width: 8, height: 8).scaleEffect(scale)
                .animation(animation.delay(0), value: scale)
            Circle().frame(width: 8, height: 8).scaleEffect(scale)
                .animation(animation.delay(0.2), value: scale)
            Circle().frame(width: 8, height: 8).scaleEffect(scale)
                .animation(animation.delay(0.4), value: scale)
        }
        .padding(.horizontal, 8)
        .onAppear {
            self.scale = 1
        }
    }
}

struct GradientButtonStyle: ButtonStyle {
    var colors: [Color]
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .fontWeight(.bold)
            .foregroundColor(.white.opacity(0.9))
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .cornerRadius(14)
            .shadow(color: colors.first?.opacity(0.5) ?? .black.opacity(0.4), radius: configuration.isPressed ? 6 : 12, y: configuration.isPressed ? 3 : 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SplashCardView<Content: View>: View {
    let content: Content
    @State private var animateBackground = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(animateBackground ? 0.7 : 0))
                .ignoresSafeArea()

            VStack {
                content
            }
            .padding(35)
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: 25, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0.1)], startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
            )
            .cornerRadius(25)
            .shadow(color: .black.opacity(0.4), radius: 30)
            .frame(maxWidth: 520)
            .padding(40)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.9)),
                removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
            )
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                animateBackground = true
            }
        }
        .onDisappear {
            animateBackground = false
        }
    }
}

struct AISplashView: View {
    var onContinue: () -> Void
    @State private var animate = false

    var body: some View {
        SplashCardView {
            VStack(spacing: 25) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                    .padding(.bottom, 15)
                    .scaleEffect(animate ? 1 : 0.8)
                    .opacity(animate ? 1 : 0)

                Text("Pesquisa com IA Ativada!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)

                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "questionmark.circle.fill", color: .blue, title: "Para que serve?", description: "Use linguagem natural para encontrar seus aplicativos. Você pode pedir por 'apps de imagem' ou 'programas para escrever texto'.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)

                    InfoRow(icon: "exclamationmark.triangle.fill", color: .blue, title: "Pontos de Atenção", description: "A IA pode ocasionalmente cometer erros ou ser um pouco lenta. Uma conexão estável com a internet é recomendada.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)

                    InfoRow(icon: "cpu.fill", color: .blue, title: "Tecnologia Utilizada", description: "Esta funcionalidade é potencializada pelo modelo de linguagem Gemini do Google.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.9), value: animate)
                }
                .padding(.horizontal)

                Button("Continuar", action: onContinue)
                    .buttonStyle(GradientButtonStyle(colors: [.cyan, .blue]))
                    .padding(.top)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.9)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(1.1), value: animate)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

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
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

struct ChatSplashView: View {
    var onContinue: () -> Void
    @State private var animate = false

    var body: some View {
        SplashCardView {
            VStack(spacing: 25) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                    .padding(.bottom, 15)
                    .scaleEffect(animate ? 1 : 0.8)
                    .opacity(animate ? 1 : 0)

                Text("Recomendador de Apps")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)

                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "bubble.left.and.bubble.right.fill", color: .blue, title: "Como funciona?", description: "Descreva uma tarefa ou necessidade e a nossa IA irá sugerir os melhores aplicativos para si.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)

                    InfoRow(icon: "sparkles", color: .blue, title: "Exemplos de Uso", description: "Pode pedir por 'um bom editor de vídeo gratuito' ou 'apps para me ajudar a focar no trabalho'.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)
                }
                .padding(.horizontal)

                Button("Continuar", action: onContinue)
                    .buttonStyle(GradientButtonStyle(colors: [.cyan, .blue]))
                    .padding(.top)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.9)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.9), value: animate)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

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
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

struct AdvancedModeSplashView: View {
    var onContinue: () -> Void
    @State private var animate = false

    var body: some View {
        SplashCardView {
            VStack(spacing: 25) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 60, weight: .bold))
                    .foregroundStyle(.linearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .shadow(color: .blue.opacity(0.5), radius: 20, y: 8)
                    .padding(.bottom, 15)
                    .scaleEffect(animate ? 1 : 0.8)
                    .opacity(animate ? 1 : 0)

                Text("Modo Avançado Ativado!")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .opacity(animate ? 1 : 0)
                    .offset(y: animate ? 0 : 15)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.3), value: animate)

                VStack(alignment: .leading, spacing: 30) {
                    InfoRow(icon: "magnifyingglass.circle.fill", color: .blue, title: "Busca Personalizada", description: "Adicione pastas personalizadas onde o QuickLaunch deve procurar por aplicativos, além dos locais padrão.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.5), value: animate)

                    InfoRow(icon: "sidebar.left", color: .blue, title: "Gerenciamento Fácil", description: "As pastas que você adicionar aparecerão em uma lista, permitindo que você as remova a qualquer momento.")
                        .opacity(animate ? 1 : 0)
                        .offset(x: animate ? 0 : -20)
                        .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.7), value: animate)
                }
                .padding(.horizontal)

                Button("Entendi", action: onContinue)
                    .buttonStyle(GradientButtonStyle(colors: [.cyan, .blue]))
                    .padding(.top)
                    .opacity(animate ? 1 : 0)
                    .scaleEffect(animate ? 1 : 0.9)
                    .animation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.9), value: animate)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 1.0, dampingFraction: 0.7)) {
                animate = true
            }
        }
    }
}

@ViewBuilder
private func InfoRow(icon: String, color: Color, title: String, description: String) -> some View {
    HStack(alignment: .top, spacing: 20) {
        Image(systemName: icon)
            .font(.title)
            .foregroundColor(color)
            .frame(width: 35)
            .shadow(color: color.opacity(0.4), radius: 7)
        
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            Text(description)
                .foregroundColor(.secondary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

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
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.messages.last?.text) { _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
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
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                }
                .disabled(messageText.isEmpty || viewModel.isAwaitingResponse)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .frame(minWidth: 400, idealWidth: 500, minHeight: 500, idealHeight: 600)
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func sendMessage() {
        viewModel.sendMessage(messageText)
        messageText = ""
    }
}

struct MessageView: View {
    let message: ChatMessage
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack {
            if message.isFromUser {
                Spacer()
            }
            
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
                        Button(action: {
                            viewModel.retryLastMessage()
                        }) {
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

            if !message.isFromUser {
                Spacer()
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()
    @AppStorage("hasShownAIPrivacyInfo") private var hasShownAIPrivacyInfo: Bool = false
    @AppStorage("hasShownChatSplashInfo") private var hasShownChatSplashInfo: Bool = false
    @AppStorage("isAdvancedModeEnabled") private var isAdvancedModeEnabled: Bool = false
    @AppStorage("hasShownAdvancedModeInfo") private var hasShownAdvancedModeInfo: Bool = false
    
    @State private var searchText = ""
    @State private var editingFolderName: String = ""
    @State private var isEditingTitle: Bool = false
    @State private var isAISearchActive: Bool = false
    @State private var isHoveringOnEnterKey: Bool = false
    
    @State private var showAISplashScreen: Bool = false
    @State private var showPrivacySplashScreen: Bool = false
    @State private var showChatSplashScreen: Bool = false
    @State private var showChatPrivacySplashScreen: Bool = false
    @State private var showAdvancedModeSplashScreen: Bool = false
    
    @State private var isChatPresented: Bool = false
    
    @State private var isDraggingOverTop: Bool = false
    @State private var isDraggingOverBottom: Bool = false
    let timer = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()
    
    @State private var animateFloatingButton: Bool = false
    @State private var isHoveringOnChatButton: Bool = false

    var filteredItems: [LaunchItem] {
        if let aiApps = viewModel.aiFilteredApps { return aiApps }
        
        let items = viewModel.currentItems
        if searchText.isEmpty { return items }
        return items.filter { $0.name.lowercased().contains(searchText.lowercased()) }
    }
    
    private var shouldShowErrorAlert: Binding<Bool> {
        Binding<Bool>(
            get: { viewModel.geminiSearchError != nil },
            set: { _ in viewModel.geminiSearchError = nil }
        )
    }

    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("A carregar aplicações...")
            } else {
                GeometryReader { geo in
                    ScrollViewReader { scrollProxy in
                        ZStack {
                            mainContent(scrollProxy: scrollProxy, containerWidth: geo.size.width)
                                .id(viewModel.currentFolder?.id ?? "root")
                                .transition(.scale(scale: 0.95).combined(with: .opacity))

                            autoscrollZones()
                            
                            if viewModel.isGeminiLoading {
                                ProgressView("A IA está a pensar...")
                                    .padding(20)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(15)
                                    .shadow(radius: 10)
                            }
                        }
                        .onReceive(timer) { _ in handleAutoscroll(with: scrollProxy) }
                    }
                }
            }
            
            if showAISplashScreen {
                AISplashView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showAISplashScreen = false
                        showPrivacySplashScreen = true
                    }
                }
            } else if showPrivacySplashScreen {
                PrivacySplashView {
                    hasShownAIPrivacyInfo = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showPrivacySplashScreen = false
                    }
                }
            } else if showChatSplashScreen {
                ChatSplashView {
                    withAnimation {
                        showChatSplashScreen = false
                        showChatPrivacySplashScreen = true
                    }
                }
            } else if showChatPrivacySplashScreen {
                ChatPrivacySplashView {
                    hasShownChatSplashInfo = true
                    withAnimation {
                        showChatPrivacySplashScreen = false
                        isChatPresented = true
                    }
                }
            } else if showAdvancedModeSplashScreen {
                AdvancedModeSplashView {
                    hasShownAdvancedModeInfo = true
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showAdvancedModeSplashScreen = false
                    }
                }
            }
            
            floatingChatButton
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(HostingWindowFinder())
        .animation(.easeInOut(duration: 0.35), value: viewModel.currentFolder)
        .alert("Erro na Pesquisa", isPresented: shouldShowErrorAlert, actions: {
            Button("Tentar Novamente") {
                if let query = viewModel.lastFailedSearchQuery {
                    viewModel.findAppsWithAI(query: query)
                }
            }
            Button("OK", role: .cancel) { }
        }, message: {
            Text(viewModel.geminiSearchError ?? "Ocorreu um erro desconhecido.")
        })
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty { viewModel.aiFilteredApps = nil }
        }
        .onChange(of: isAISearchActive) { isActive in
            if isActive {
                if !hasShownAIPrivacyInfo {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showAISplashScreen = true
                    }
                }
            } else {
                viewModel.aiFilteredApps = nil
            }
        }
        .onChange(of: isAdvancedModeEnabled) { isEnabled in
            if isEnabled && !hasShownAdvancedModeInfo {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showAdvancedModeSplashScreen = true
                }
            }
        }
        .sheet(isPresented: $isChatPresented) {
            ChatView()
        }
    }
    
    private var floatingChatButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    if hasShownChatSplashInfo {
                        isChatPresented = true
                    } else {
                        withAnimation {
                            showChatSplashScreen = true
                        }
                    }
                }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(20)
                        .background(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.6), radius: isHoveringOnChatButton ? 20 : 12, y: isHoveringOnChatButton ? 10 : 5)
                }
                .buttonStyle(.plain)
                .padding(30)
                .scaleEffect(animateFloatingButton ? (isHoveringOnChatButton ? 1.15 : 1.0) : 0)
                .opacity(animateFloatingButton ? 1 : 0)
                .onHover { isHovering in
                    withAnimation(.spring()) {
                        isHoveringOnChatButton = isHovering
                    }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.2)) {
                animateFloatingButton = true
            }
        }
    }
    
    @ViewBuilder
    private func mainContent(scrollProxy: ScrollViewProxy, containerWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            if let folder = viewModel.currentFolder {
                HStack {
                    Button(action: { viewModel.goBack() }) {
                        Image(systemName: "chevron.left"); Text("Voltar")
                    }
                    .buttonStyle(.plain)
                    .onDrop(of: ["public.text"], isTargeted: nil) { providers in
                        handleDropToRoot(providers: providers)
                        return true
                    }
                    
                    if isEditingTitle {
                        TextField("Nome da Pasta", text: $editingFolderName, onCommit: {
                            folder.name = editingFolderName
                            isEditingTitle = false
                        })
                        .textFieldStyle(.roundedBorder)
                        .frame(minWidth: 150)
                    } else {
                        Text(folder.name)
                            .font(.title).fontWeight(.bold)
                            .onTapGesture {
                                editingFolderName = folder.name
                                isEditingTitle = true
                            }
                    }
                    
                    Spacer()
                    searchBar().frame(maxWidth: 250)
                }
                .padding(.horizontal, 40).padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    HStack(alignment: .center, spacing: 15) {
                        Text("QuickLaunch")
                            .font(.system(size: 48, weight: .bold))
                        
                        if isAdvancedModeEnabled {
                            Button(action: {
                                viewModel.addSearchPath()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 30, weight: .medium))
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                            .help("Adicionar uma pasta para procurar apps")
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                    
                    searchBar().frame(maxWidth: 500)
                    
                    if isAdvancedModeEnabled {
                        advancedSettingsView
                            .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .move(edge: .top).combined(with: .opacity)))
                    }
                }
                .padding(.horizontal, 40).padding(.vertical, 20)
            }

            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 1).id("top_anchor")
                    
                    let minItemWidth: CGFloat = 120
                    let spacing: CGFloat = 30
                    let horizontalPadding: CGFloat = 40 * 2
                    let availableWidth = containerWidth - horizontalPadding
                    let columnCount = max(1, Int(availableWidth / (minItemWidth + spacing)))
                    let itemChunks = filteredItems.enumerated().map { $0 }.chunked(into: columnCount)

                    VStack(alignment: .leading, spacing: spacing) {
                        ForEach(itemChunks.indices, id: \.self) { rowIndex in
                            HStack(spacing: spacing) {
                                ForEach(itemChunks[rowIndex], id: \.element.id) { (index, item) in
                                    switch item {
                                    case .app(let app):
                                        AppIconView(app: app, index: index)
                                            .onDrag { NSItemProvider(object: app.id as NSString) }
                                            .onDrop(of: ["public.text"], isTargeted: nil) { providers, _ in
                                                handleDrop(providers: providers, targetID: app.id)
                                                return true
                                            }
                                    case .folder(let folder):
                                        FolderIconView(folder: folder, viewModel: viewModel, index: index)
                                            .onTapGesture { viewModel.enterFolder(folder) }
                                            .onDrop(of: ["public.text"], isTargeted: nil) { providers, _ in
                                                handleDrop(providers: providers, targetID: folder.id)
                                                return true
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 40).padding(.bottom, 40)
                    
                    Color.clear.frame(height: 1).id("bottom_anchor")
                }
            }
        }
        .animation(.default, value: isAdvancedModeEnabled)
    }
    
    @ViewBuilder
    private var advancedSettingsView: some View {
        if !viewModel.customSearchPaths.isEmpty {
            GroupBox(label: Label("Pastas de Busca Personalizadas", systemImage: "folder.badge.plus")) {
                List {
                    ForEach(viewModel.customSearchPaths, id: \.self) { url in
                        Text(url.path.removingPercentEncoding ?? url.path)
                            .font(.footnote)
                    }
                    .onDelete(perform: viewModel.removeSearchPath)
                }
                .listStyle(.plain)
                .frame(maxHeight: 150)
            }
            .padding(.top, 10)
            .frame(maxWidth: 500)
        }
    }
    
    @ViewBuilder
    private func searchBar() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack(alignment: .leading) {
                    if searchText.isEmpty {
                        Text(isAISearchActive ? "Pesquise com a IA..." : "Procurar aplicações...")
                            .foregroundColor(isAISearchActive ? .black.opacity(0.6) : .gray)
                    }
                    
                    TextField("", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(isAISearchActive ? .black.opacity(0.8) : .primary)
                        .onSubmit {
                            if isAISearchActive {
                                viewModel.findAppsWithAI(query: searchText)
                            }
                        }
                }
                Button(action: {
                    if isAISearchActive {
                        viewModel.findAppsWithAI(query: searchText)
                    }
                }) {
                    Image(systemName: "return")
                        .foregroundColor(isAISearchActive ? .black.opacity(isHoveringOnEnterKey ? 0.9 : 0.6) : (isHoveringOnEnterKey ? .primary.opacity(0.9) : .gray))
                        .scaleEffect(isHoveringOnEnterKey && !searchText.isEmpty ? 1.2 : 1.0)
                        .padding(8)
                        .background(
                            (isHoveringOnEnterKey && !searchText.isEmpty ? Color.white.opacity(0.2) : Color.clear)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        )
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHoveringOnEnterKey)
                }
                .buttonStyle(.plain)
                .disabled(searchText.isEmpty)
                .onHover { isHoveringOnEnterKey = $0 }
            }
            .padding(.leading, 12).padding(.trailing, 4).padding(.vertical, 4)
            .background(isAISearchActive ? Color.blue.opacity(0.6) : Color.black.opacity(0.1))
            .cornerRadius(10)
            .animation(.easeInOut, value: isAISearchActive)

            HStack {
                Toggle(isOn: $isAISearchActive.animation(.spring())) {
                    Text("Pesquisa com IA")
                }
                .toggleStyle(.switch)
                .disabled(viewModel.isGeminiLoading)
                
                if hasShownAIPrivacyInfo {
                    Button(action: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showPrivacySplashScreen = true
                        }
                    }) {
                        Image(systemName: "questionmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
                
                Spacer()
                
                Toggle(isOn: $isAdvancedModeEnabled.animation(.spring())) {
                    Text("Modo Avançado")
                }
                .toggleStyle(.switch)
            }
        }
    }

    @ViewBuilder
    private func autoscrollZones() -> some View {
        VStack {
            Color.clear
                .frame(height: 50)
                .onDrop(of: ["public.text"], isTargeted: $isDraggingOverTop) { _ in true }
            
            Spacer()
            
            Color.clear
                .frame(height: 50)
                .onDrop(of: ["public.text"], isTargeted: $isDraggingOverBottom) { _ in true }
        }
    }
    
    private func handleAutoscroll(with scrollProxy: ScrollViewProxy) {
        if isDraggingOverTop {
            withAnimation(.linear(duration: 1.5)) {
                scrollProxy.scrollTo("top_anchor", anchor: .top)
            }
        }
        if isDraggingOverBottom {
            withAnimation(.linear(duration: 1.5)) {
                scrollProxy.scrollTo("bottom_anchor", anchor: .bottom)
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider], targetID: String) {
        providers.first?.loadObject(ofClass: NSString.self) { item, error in
            if let draggedAppID = item as? String,
               let draggedApp = viewModel.findApp(by: draggedAppID) {
                DispatchQueue.main.async {
                    viewModel.move(draggedApp, onto: targetID)
                }
            }
        }
    }
    
    private func handleDropToRoot(providers: [NSItemProvider]) {
        providers.first?.loadObject(ofClass: NSString.self) { item, error in
            if let draggedAppID = item as? String,
               let draggedApp = viewModel.findApp(by: draggedAppID) {
                DispatchQueue.main.async {
                    viewModel.moveAppToRoot(draggedApp)
                }
            }
        }
    }
}

struct AppIconView: View {
    let app: AppInfo
    let index: Int
    
    @State private var isHovering = false
    @State private var hasAppeared = false

    var body: some View {
        VStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable().aspectRatio(contentMode: .fit).frame(width: 80, height: 80)
                .shadow(radius: isHovering ? 10 : 3)
            Text(app.name).font(.caption).lineLimit(1).truncationMode(.tail)
        }
        .padding().frame(width: 120, height: 120)
        .background(RoundedRectangle(cornerRadius: 15).fill(isHovering ? Color.white.opacity(0.2) : Color.clear))
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .animation(.spring(), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .onTapGesture { NSWorkspace.shared.open(app.url) }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.5)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.02)) {
                self.hasAppeared = true
            }
        }
    }
}

struct FolderIconView: View {
    @ObservedObject var folder: FolderInfo
    @ObservedObject var viewModel: AppViewModel
    
    let index: Int
    
    @State private var isHovering = false
    @State private var isRenaming = false
    @State private var tempName = ""
    @FocusState private var isNameFieldFocused: Bool
    @State private var hasAppeared = false

    private var iconPreviews: [URL] {
        folder.items.compactMap {
            if case .app(let app) = $0 { return app.url }
            return nil
        }.prefix(4).map { $0 }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.black.opacity(0.15))
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(iconPreviews.indices, id: \.self) { index in
                        if let url = iconPreviews[safe: index] {
                             Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 30, height: 30)
                        } else {
                            Rectangle().fill(Color.clear).frame(width: 30, height: 30)
                        }
                    }
                }
                .padding(10)
            }
            .frame(width: 90, height: 90)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if isRenaming {
                TextField("Nome da Pasta", text: $tempName, onCommit: {
                    if !tempName.isEmpty { folder.name = tempName }
                    isRenaming = false
                })
                .focused($isNameFieldFocused)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .padding(.vertical, 2).padding(.horizontal, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(5)
                .onAppear { isNameFieldFocused = true }
            } else {
                Text(folder.name)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundColor(.primary.opacity(0.8))
            }
        }
        .padding()
        .frame(width: 120, height: 120)
        .scaleEffect(isHovering ? 1.08 : 1.0)
        .animation(.spring(response: 0.4, dampingFraction: 0.6), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .contextMenu {
            Button {
                tempName = folder.name
                isRenaming = true
            } label: { Label("Renomear", systemImage: "pencil") }
            
            Button(role: .destructive) {
                viewModel.deleteFolder(withId: folder.id)
            } label: { Label("Apagar Pasta", systemImage: "trash") }
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.5)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.02)) {
                self.hasAppeared = true
            }
        }
    }
}

struct HostingWindowFinder: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.isOpaque = false
            view.window?.backgroundColor = .clear
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

extension Collection {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}
