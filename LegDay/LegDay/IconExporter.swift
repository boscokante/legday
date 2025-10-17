import SwiftUI

@MainActor
enum IconExporter {
    static func exportAll() async {
        await export(icon: MuscularLegIcon(), name: "LegDay_MuscularLeg_1024.png")
        await export(icon: MuscularLegIcon().frame(width: 512, height: 512), name: "LegDay_MuscularLeg_512.png")
        await export(icon: MuscularLegIcon().frame(width: 256, height: 256), name: "LegDay_MuscularLeg_256.png")
        await export(icon: MuscularLegIcon().frame(width: 128, height: 128), name: "LegDay_MuscularLeg_128.png")
    }

    private static func export<V: View>(icon: V, name: String) async {
        let renderer = ImageRenderer(content: icon)
        renderer.proposedSize = .init(width: 1024, height: 1024)
        renderer.scale = 1

        guard let uiImage = renderer.uiImage else { return }
        guard let data = uiImage.pngData() else { return }

        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        do {
            try data.write(to: url)
            print("✅ Exported icon to: \(url.path)")
        } catch {
            print("❌ Failed to export icon: \(error.localizedDescription)")
        }
    }
}


