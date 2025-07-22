import SwiftUI
import AppKit

struct AppIconView: View {
    let app: AppInfo
    let index: Int
    @State private var isHovering = false
    @State private var hasAppeared = false

    var body: some View {
        VStack {
            Image(nsImage: NSWorkspace.shared.icon(forFile: app.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .shadow(radius: isHovering ? 10 : 3)
            Text(app.name).font(.caption).lineLimit(1).truncationMode(.tail)
        }
        .padding()
        .frame(width: 120, height: 120)
        .background(RoundedRectangle(cornerRadius: 15).fill(isHovering ? Color.white.opacity(0.2) : Color.clear))
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .animation(.spring(), value: isHovering)
        .onHover { hovering in isHovering = hovering }
        .onTapGesture { NSWorkspace.shared.open(app.url) }
        .opacity(hasAppeared ? 1 : 0)
        .scaleEffect(hasAppeared ? 1 : 0.5)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(Double(index) * 0.02)) { self.hasAppeared = true }
        }
    }
}
