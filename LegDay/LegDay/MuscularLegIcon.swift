import SwiftUI

struct MuscularLegIcon: View {
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.11, blue: 0.16), Color(red: 0.10, green: 0.16, blue: 0.28)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(
                RadialGradient(colors: [Color.white.opacity(0.12), .clear], center: .topLeading, startRadius: 20, endRadius: 600)
            )
            .clipShape(RoundedRectangle(cornerRadius: 220, style: .continuous))

            // Leg glyph
            LegGlyph()
                .frame(width: 740, height: 740)
        }
        .frame(width: 1024, height: 1024)
        .overlay(
            RoundedRectangle(cornerRadius: 220, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 220, style: .continuous))
    }
}

private struct LegGlyph: View {
    var body: some View {
        ZStack {
            // Thigh
            Capsule()
                .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.51, blue: 0.30), Color(red: 0.72, green: 0.27, blue: 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 380, height: 640)
                .rotationEffect(.degrees(-28))
                .offset(x: -40, y: -40)
                .shadow(color: .black.opacity(0.25), radius: 32, x: 0, y: 18)

            // Vastus medialis bulge
            Capsule()
                .fill(LinearGradient(colors: [Color.white.opacity(0.30), .clear], startPoint: .top, endPoint: .bottom))
                .frame(width: 140, height: 220)
                .rotationEffect(.degrees(-28))
                .offset(x: -120, y: 120)
                .blendMode(.plusLighter)
                .opacity(0.5)

            // Knee cap
            Circle()
                .fill(LinearGradient(colors: [Color(red: 0.98, green: 0.70, blue: 0.52), Color(red: 0.75, green: 0.45, blue: 0.30)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 130, height: 130)
                .offset(x: -120, y: 150)
                .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 10)

            // Calf
            Capsule()
                .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.51, blue: 0.30), Color(red: 0.72, green: 0.27, blue: 0.16)], startPoint: .top, endPoint: .bottom))
                .frame(width: 260, height: 520)
                .rotationEffect(.degrees(12))
                .offset(x: -50, y: 340)
                .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 16)

            // Gastrocnemius highlight
            Capsule(style: .continuous)
                .fill(LinearGradient(colors: [Color.white.opacity(0.28), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 120, height: 260)
                .rotationEffect(.degrees(18))
                .offset(x: -80, y: 270)
                .opacity(0.55)
                .blendMode(.screen)

            // Achilles
            Capsule()
                .fill(Color(red: 0.58, green: 0.18, blue: 0.12))
                .frame(width: 40, height: 160)
                .rotationEffect(.degrees(16))
                .offset(x: 56, y: 480)

            // Foot
            Capsule()
                .fill(LinearGradient(colors: [Color(red: 0.96, green: 0.51, blue: 0.30), Color(red: 0.72, green: 0.27, blue: 0.16)], startPoint: .leading, endPoint: .trailing))
                .frame(width: 320, height: 120)
                .rotationEffect(.degrees(6))
                .offset(x: 60, y: 590)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)

            // Definition lines
            Group {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 160, height: 12)
                    .rotationEffect(.degrees(-30))
                    .offset(x: -44, y: 10)
                    .blur(radius: 0.5)
                    .blendMode(.screen)

                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 120, height: 10)
                    .rotationEffect(.degrees(8))
                    .offset(x: -74, y: 320)
                    .blur(radius: 0.6)
                    .blendMode(.screen)
            }
        }
        .foregroundStyle(.primary)
        .symbolRenderingMode(.hierarchical)
    }
}

#if DEBUG
struct MuscularLegIcon_Previews: PreviewProvider {
    static var previews: some View {
        MuscularLegIcon()
            .previewLayout(.sizeThatFits)
    }
}
#endif


