import SwiftUI
import AppKit

/// Draws the icons on a widget-like panel over a wallpaper, in both appearances, to a PNG.
/// CI is the only Mac this repo has, so this is how the glass gets looked at before a release.
@main
struct RenderGlass {
    static let keys = ["today", "tasks", "appointments", "projects", "finance", "quotes",
                       "crm", "analytics", "deals", "realestate", "warehouse", "hr"]

    @MainActor
    static func board(_ scheme: ColorScheme) -> some View {
        let wallpaper = scheme == .dark
            ? [Color(red: 0.05, green: 0.08, blue: 0.24), Color(red: 0.32, green: 0.10, blue: 0.36)]
            : [Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.98, green: 0.72, blue: 0.62)]
        return ZStack {
            LinearGradient(colors: wallpaper, startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 14) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 18) {
                        ForEach(0..<6, id: \.self) { col in
                            let key = keys[row * 6 + col]
                            VStack(spacing: 4) {
                                AppIcon(key: key, size: 44, badge: col == 1 ? "3" : nil)
                                Text(SectionStyle.label(key)).font(.system(size: 11)).lineLimit(1)
                            }
                            .frame(width: 62)
                        }
                    }
                }
                HStack(spacing: 8) {
                    AppIcon(key: "finance", size: 16)
                    Text("Owed to you").font(.footnote)
                    Spacer()
                    Text("€48,250").font(.footnote.weight(.semibold))
                }
                .padding(10)
                .glass()
            }
            .padding(16)
            .frame(width: 490)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.fill.tertiary))
            .padding(28)
        }
        .frame(width: 546)
        .environment(\.colorScheme, scheme)
    }

    @MainActor
    static func main() throws {
        let renderer = ImageRenderer(content: VStack(spacing: 0) { board(.light); board(.dark) })
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: URL(fileURLWithPath: "glass-preview.png"))
    }
}
