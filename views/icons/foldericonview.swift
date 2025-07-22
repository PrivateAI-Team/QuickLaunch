import SwiftUI
import AppKit

struct FolderIconView: View {
    @ObservedObject var folder: FolderInfo
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
                    ForEach(iconPreviews.indices, id: \.self) { i in
                        if let url = iconPreviews[safe: i] {
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
                (NSApp.delegate as? NSObject)?
                    .performSelector(onMainThread: Selector(("deleteFolder:")), with: folder.id, waitUntilDone: false)
            } label: { Label("Apagar Pasta", systemImage: "trash") }
        }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.5)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.02)) { self.hasAppeared = true }
        }
    }
}
