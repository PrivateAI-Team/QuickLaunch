import SwiftUI
import AppKit
import Combine

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
        Binding(get: { viewModel.geminiSearchError != nil }, set: { _ in viewModel.geminiSearchError = nil })
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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showPrivacySplashScreen = false }
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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { showAdvancedModeSplashScreen = false }
                }
            }
            floatingChatButton
        }
        .frame(minWidth: 800, minHeight: 600)
        .background(HostingWindowFinder())
        .animation(.easeInOut(duration: 0.35), value: viewModel.currentFolder)
        .alert("Erro na Pesquisa", isPresented: shouldShowErrorAlert, actions: {
            Button("Tentar Novamente") { if let q = viewModel.lastFailedSearchQuery { viewModel.findAppsWithAI(query: q) } }
            Button("OK", role: .cancel) { }
        }, message: { Text(viewModel.geminiSearchError ?? "Ocorreu um erro desconhecido.") })
        .onChange(of: searchText) { newValue in if newValue.isEmpty { viewModel.aiFilteredApps = nil } }
        .onChange(of: isAISearchActive) { isActive in
            if isActive {
                if !hasShownAIPrivacyInfo { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showAISplashScreen = true } }
            } else { viewModel.aiFilteredApps = nil }
        }
        .onChange(of: isAdvancedModeEnabled) { isEnabled in
            if isEnabled && !hasShownAdvancedModeInfo {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showAdvancedModeSplashScreen = true }
            }
        }
        .sheet(isPresented: $isChatPresented) { ChatView() }
    }

    private var floatingChatButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button(action: {
                    if hasShownChatSplashInfo { isChatPresented = true } else { withAnimation { showChatSplashScreen = true } }
                }) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(20)
                        .background(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .clipShape(Circle())
                        .shadow(color: .blue.opacity(0.6), radius: isHoveringOnChatButton ? 20 : 12, y: isHoveringOnChatButton ? 10 : 5)
                }
                .buttonStyle(.plain)
                .padding(30)
                .scaleEffect(animateFloatingButton ? (isHoveringOnChatButton ? 1.15 : 1.0) : 0)
                .opacity(animateFloatingButton ? 1 : 0)
                .onHover { isHovering in
                    withAnimation(.spring()) { isHoveringOnChatButton = isHovering }
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.6).delay(1.2)) { animateFloatingButton = true }
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
                        handleDropToRoot(providers: providers); return true
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
                        Text("QuickLaunch").font(.system(size: 48, weight: .bold))
                        if isAdvancedModeEnabled {
                            Button(action: { viewModel.addSearchPath() }) {
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
                                                handleDrop(providers: providers, targetID: app.id); return true
                                            }
                                    case .folder(let folder):
                                        FolderIconView(folder: folder, index: index)
                                            .onTapGesture { viewModel.enterFolder(folder) }
                                            .onDrop(of: ["public.text"], isTargeted: nil) { providers, _ in
                                                handleDrop(providers: providers, targetID: folder.id); return true
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
                        Text(url.path.removingPercentEncoding ?? url.path).font(.footnote)
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
                        .onSubmit { if isAISearchActive { viewModel.findAppsWithAI(query: searchText) } }
                }
                Button(action: { if isAISearchActive { viewModel.findAppsWithAI(query: searchText) } }) {
                    Image(systemName: "return")
                        .foregroundColor(isAISearchActive ? .black.opacity(isHoveringOnEnterKey ? 0.9 : 0.6) : (isHoveringOnEnterKey ? .primary.opacity(0.9) : .gray))
                        .scaleEffect(isHoveringOnEnterKey && !searchText.isEmpty ? 1.2 : 1.0)
                        .padding(8)
                        .background((isHoveringOnEnterKey && !searchText.isEmpty ? Color.white.opacity(0.2) : Color.clear).clipShape(RoundedRectangle(cornerRadius: 8)))
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
                Toggle(isOn: $isAISearchActive.animation(.spring())) { Text("Pesquisa com IA") }
                    .toggleStyle(.switch)
                    .disabled(viewModel.isGeminiLoading)
                if hasShownAIPrivacyInfo {
                    Button(action: { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showPrivacySplashScreen = true } }) {
                        Image(systemName: "questionmark.circle.fill").foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 4)
                }
                Spacer()
                Toggle(isOn: $isAdvancedModeEnabled.animation(.spring())) { Text("Modo Avançado") }
                    .toggleStyle(.switch)
            }
        }
    }

    @ViewBuilder
    private func autoscrollZones() -> some View {
        VStack {
            Color.clear.frame(height: 50).onDrop(of: ["public.text"], isTargeted: $isDraggingOverTop) { _ in true }
            Spacer()
            Color.clear.frame(height: 50).onDrop(of: ["public.text"], isTargeted: $isDraggingOverBottom) { _ in true }
        }
    }

    private func handleAutoscroll(with scrollProxy: ScrollViewProxy) {
        if isDraggingOverTop { withAnimation(.linear(duration: 1.5)) { scrollProxy.scrollTo("top_anchor", anchor: .top) } }
        if isDraggingOverBottom { withAnimation(.linear(duration: 1.5)) { scrollProxy.scrollTo("bottom_anchor", anchor: .bottom) } }
    }
    private func handleDrop(providers: [NSItemProvider], targetID: String) {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            if let draggedId = item as? String, let draggedApp = viewModel.findApp(by: draggedId) {
                DispatchQueue.main.async { viewModel.move(draggedApp, onto: targetID) }
            }
        }
    }
    private func handleDropToRoot(providers: [NSItemProvider]) {
        providers.first?.loadObject(ofClass: NSString.self) { item, _ in
            if let draggedId = item as? String, let draggedApp = viewModel.findApp(by: draggedId) {
                DispatchQueue.main.async { viewModel.moveAppToRoot(draggedApp) }
            }
        }
    }
}
