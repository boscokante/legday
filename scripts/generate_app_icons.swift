import Foundation
import AppKit

// Usage: swift scripts/generate_app_icons.swift /absolute/path/to/source.png /absolute/path/to/AppIcon.appiconset

struct Rendition {
    let filename: String
    let size: CGFloat // pixels edge
}

let renditions: [Rendition] = [
    .init(filename: "icon_1024.png", size: 1024),
    .init(filename: "icon_1024_dark.png", size: 1024),
    .init(filename: "icon_1024_tinted.png", size: 1024),
    .init(filename: "icon_512.png", size: 512),
    .init(filename: "icon_512@2x.png", size: 1024),
    .init(filename: "icon_256.png", size: 256),
    .init(filename: "icon_256@2x.png", size: 512),
    .init(filename: "icon_128.png", size: 128),
    .init(filename: "icon_128@2x.png", size: 256),
    .init(filename: "icon_32.png", size: 32),
    .init(filename: "icon_32@2x.png", size: 64),
    .init(filename: "icon_16.png", size: 16),
    .init(filename: "icon_16@2x.png", size: 32),
]

func die(_ message: String) -> Never {
    fputs("Error: \(message)\n", stderr)
    exit(1)
}

guard CommandLine.arguments.count >= 3 else {
    die("Usage: swift scripts/generate_app_icons.swift /abs/source.png /abs/AppIcon.appiconset")
}

let sourcePath = CommandLine.arguments[1]
let destPath = CommandLine.arguments[2]

guard let sourceImage = NSImage(contentsOfFile: sourcePath) else {
    die("Could not read source image at: \(sourcePath)")
}

func resized(_ image: NSImage, to size: CGFloat) -> NSImage? {
    let target = NSSize(width: size, height: size)
    let result = NSImage(size: target)
    result.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(origin: .zero, size: target), from: .zero, operation: .copy, fraction: 1.0)
    result.unlockFocus()
    return result
}

func savePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "icon.gen", code: -1, userInfo: [NSLocalizedDescriptionKey: "PNG conversion failed"])
    }
    try data.write(to: url)
}

let destURL = URL(fileURLWithPath: destPath)
try? FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)

for r in renditions {
    guard let img = resized(sourceImage, to: r.size) else { continue }
    let out = destURL.appendingPathComponent(r.filename)
    do {
        try savePNG(img, to: out)
        print("✅ \(r.filename)")
    } catch {
        print("❌ \(r.filename): \(error)")
    }
}

print("Done. Place the generated files next to Contents.json in AppIcon.appiconset.")


