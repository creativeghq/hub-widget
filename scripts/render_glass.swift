import SwiftUI
import AppKit

private let keys: [String] = ["today", "tasks", "appointments", "projects", "finance", "quotes",
                              "crm", "analytics", "deals", "realestate", "warehouse", "hr"]

private struct Cell: View {
    let key: String
    let badged: Bool

    var body: some View {
        VStack(spacing: 4) {
            AppIcon(key: key, size: 44, badge: badged ? "3" : nil)
            Text(SectionStyle.label(key) ?? key).font(.system(size: 11)).lineLimit(1)
        }
        .frame(width: 62)
    }
}

private struct Row: View {
    let start: Int

    var body: some View {
        HStack(spacing: 18) {
            ForEach(start..<(start + 6), id: \.self) { index in
                Cell(key: keys[index], badged: index % 6 == 1)
            }
        }
    }
}

private struct StatLine: View {
    var body: some View {
        HStack(spacing: 8) {
            AppIcon(key: "finance", size: 16)
            Text("Owed to you").font(.footnote)
            Spacer()
            Text("48,250 EUR").font(.footnote.weight(.semibold))
        }
        .padding(10)
        .glass()
    }
}

private struct Board: View {
    let scheme: ColorScheme

    private var wallpaper: [Color] {
        if scheme == .dark {
            return [Color(red: 0.05, green: 0.08, blue: 0.24), Color(red: 0.32, green: 0.10, blue: 0.36)]
        }
        return [Color(red: 0.55, green: 0.78, blue: 0.98), Color(red: 0.98, green: 0.72, blue: 0.62)]
    }

    var body: some View {
        VStack(spacing: 14) {
            Row(start: 0)
            Row(start: 6)
            StatLine()
        }
        .padding(16)
        .frame(width: 490)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.fill.tertiary))
        .padding(28)
        .frame(width: 546)
        .background(LinearGradient(colors: wallpaper, startPoint: .topLeading, endPoint: .bottomTrailing))
        .environment(\.colorScheme, scheme)
    }
}

/// Draws the icons on a widget-like panel over a wallpaper, in both appearances, to a PNG.
/// CI is the only Mac this repo has, so this is how the glass gets looked at before a release.
@main
struct RenderGlass {
    @MainActor
    static func main() throws {
        let renderer = ImageRenderer(content: VStack(spacing: 0) {
            Board(scheme: .light)
            Board(scheme: .dark)
        })
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try png.write(to: URL(fileURLWithPath: "glass-preview.png"))
    }
}
