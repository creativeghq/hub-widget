import SwiftUI
import WidgetKit

enum Look {
    static let radius: CGFloat = 12
    static let hairline = Color.primary.opacity(0.10)
}

/// The glass both panels and icons are made of: see-through, lit by a diagonal reflection and a
/// bright rim, never a drop shadow. A widget cannot blur what is behind it, so this is drawn.
struct GlassSurface<S: InsettableShape>: View {
    @Environment(\.colorScheme) private var scheme
    let shape: S
    var tint: Color? = nil
    var strength: Double = 1
    var rim: CGFloat = 0.75

    var body: some View {
        let dark = scheme == .dark
        shape.fill(Color.white.opacity(dark ? 0.07 : 0.20))
            .overlay { if let tint { shape.fill(tint.opacity(dark ? 0.14 : 0.10)) } }
            .overlay(shape.fill(LinearGradient(stops: [
                .init(color: .white.opacity((dark ? 0.30 : 0.70) * strength), location: 0),
                .init(color: .white.opacity((dark ? 0.08 : 0.18) * strength), location: 0.42),
                .init(color: .white.opacity(0), location: 0.60),
                .init(color: .white.opacity((dark ? 0.10 : 0.25) * strength), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)))
            .overlay(shape.strokeBorder(LinearGradient(stops: [
                .init(color: .white.opacity(dark ? 0.55 : 1.0), location: 0),
                .init(color: .white.opacity(dark ? 0.08 : 0.25), location: 0.5),
                .init(color: .white.opacity(dark ? 0.30 : 0.70), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: rim))
    }
}

/// In the desktop's tinted and clear modes the system draws the glass, so only a faint fill stays.
struct GlassBackground: ViewModifier {
    @Environment(\.widgetRenderingMode) private var mode
    var tint: Color? = nil
    var radius: CGFloat = Look.radius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return content.background {
            if mode == .fullColor {
                GlassSurface(shape: shape, tint: tint, strength: 0.45)
            } else {
                shape.fill(Color.white.opacity(0.10))
            }
        }
    }
}

extension View {
    func glass(tint: Color? = nil, radius: CGFloat = Look.radius) -> some View {
        modifier(GlassBackground(tint: tint, radius: radius))
    }

    /// A panel or card; one needing attention gets a warm glass.
    func tile(_ accent: Color, attention: Bool = false) -> some View { glass(tint: attention ? accent : nil) }
}

/// An area as a glass app icon with its glyph in the area's colour, and a red Dock badge when
/// something needs attention.
struct AppIcon: View {
    @Environment(\.widgetRenderingMode) private var mode
    let key: String
    var size: CGFloat = 44
    var badge: String? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
        let tint = SectionStyle.tint(key)
        let color = mode == .fullColor
        ZStack {
            if color {
                GlassSurface(shape: shape, tint: tint, rim: size > 20 ? 0.75 : 0.5)
            } else {
                shape.fill(Color.white.opacity(0.14))
            }
            Image(systemName: SectionStyle.symbol(key))
                .symbolVariant(.fill)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: size * 0.50, weight: .medium))
                .foregroundStyle(color ? AnyShapeStyle(tint.gradient) : AnyShapeStyle(Color.white))
                .widgetAccentable()
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if let badge {
                Text(badge)
                    .font(.system(size: max(8.5, size * 0.21), weight: .semibold)).monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3.5).frame(minWidth: size * 0.34, minHeight: size * 0.34)
                    .background(Capsule().fill(color ? Color(red: 1.0, green: 0.23, blue: 0.19) : Color.white.opacity(0.3)))
                    .offset(x: size * 0.12, y: -size * 0.12)
            }
        }
    }
}
