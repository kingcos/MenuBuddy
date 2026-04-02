#!/usr/bin/env swift
/// Generates Resources/AppIcon.iconset/ with required PNG sizes.
/// Run: swift Scripts/generate-icon.swift
/// Then: iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns

import AppKit
import Foundation

let sizes: [(Int, String)] = [
    (16,    "icon_16x16.png"),
    (32,    "icon_16x16@2x.png"),
    (32,    "icon_32x32.png"),
    (64,    "icon_32x32@2x.png"),
    (128,   "icon_128x128.png"),
    (256,   "icon_128x128@2x.png"),
    (256,   "icon_256x256.png"),
    (512,   "icon_256x256@2x.png"),
    (512,   "icon_512x512.png"),
    (1024,  "icon_512x512@2x.png"),
]

let iconsetDir = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetDir)
try! FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

for (px, filename) in sizes {
    let size = CGSize(width: px, height: px)
    let image = NSImage(size: size)
    image.lockFocus()

    // macOS icon guidelines: content at ~80% of canvas, with transparent padding
    let padding = CGFloat(px) * 0.10
    let contentRect = NSRect(
        x: padding, y: padding,
        width: CGFloat(px) - padding * 2,
        height: CGFloat(px) - padding * 2
    )

    // Background: dark rounded rect (inset to match macOS icon grid)
    let bg = NSBezierPath(
        roundedRect: contentRect,
        xRadius: contentRect.width * 0.20,
        yRadius: contentRect.height * 0.20
    )
    NSColor(red: 0.10, green: 0.10, blue: 0.16, alpha: 1.0).setFill()
    bg.fill()

    // Companion face: "(·>" in warm yellow, monospaced
    let face = "(·>" as NSString
    let fontSize = contentRect.width * 0.30
    let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor(red: 0.98, green: 0.82, blue: 0.28, alpha: 1.0),
    ]
    let faceSize = face.size(withAttributes: attrs)
    let faceRect = NSRect(
        x: contentRect.midX - faceSize.width / 2,
        y: contentRect.midY - faceSize.height / 2,
        width: faceSize.width,
        height: faceSize.height
    )
    face.draw(in: faceRect, withAttributes: attrs)

    // Small star below (rarity indicator)
    let star = "★" as NSString
    let starFont = NSFont.systemFont(ofSize: contentRect.width * 0.12)
    let starAttrs: [NSAttributedString.Key: Any] = [
        .font: starFont,
        .foregroundColor: NSColor(red: 0.98, green: 0.70, blue: 0.20, alpha: 0.7),
    ]
    let starSize = star.size(withAttributes: starAttrs)
    let starRect = NSRect(
        x: contentRect.midX - starSize.width / 2,
        y: faceRect.minY - starSize.height - contentRect.width * 0.04,
        width: starSize.width,
        height: starSize.height
    )
    star.draw(in: starRect, withAttributes: starAttrs)

    image.unlockFocus()

    if let tiff = image.tiffRepresentation,
       let bmp = NSBitmapImageRep(data: tiff),
       let png = bmp.representation(using: .png, properties: [:]) {
        let dest = iconsetDir.appendingPathComponent(filename)
        try! png.write(to: dest)
    }
}

print("Generated \(sizes.count) icon sizes in Resources/AppIcon.iconset/")
print("Run: iconutil -c icns Resources/AppIcon.iconset -o Resources/AppIcon.icns")
