#!/usr/bin/env swift

import AppKit
import Foundation

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Assets/HeelpIcon.png")
let size = 1024

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Could not create icon canvas")
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.shouldAntialias = true

NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: size, height: size).fill()

let tileRect = NSRect(x: 72, y: 72, width: 880, height: 880)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 205, yRadius: 205)

let tileShadow = NSShadow()
tileShadow.shadowColor = NSColor(calibratedWhite: 0.05, alpha: 0.35)
tileShadow.shadowBlurRadius = 42
tileShadow.shadowOffset = NSSize(width: 0, height: -18)
tileShadow.set()
NSColor(calibratedRed: 0.16, green: 0.25, blue: 0.72, alpha: 1).setFill()
tile.fill()

NSShadow().set()
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.24, green: 0.78, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.25, green: 0.49, blue: 0.94, alpha: 1),
    NSColor(calibratedRed: 0.31, green: 0.24, blue: 0.76, alpha: 1)
])!
background.draw(in: tile, angle: -52)

let highlight = NSBezierPath(roundedRect: NSRect(x: 108, y: 566, width: 808, height: 330), xRadius: 155, yRadius: 155)
NSColor(calibratedWhite: 1, alpha: 0.09).setFill()
highlight.fill()

let bubbleShadow = NSShadow()
bubbleShadow.shadowColor = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.40, alpha: 0.30)
bubbleShadow.shadowBlurRadius = 30
bubbleShadow.shadowOffset = NSSize(width: 0, height: -14)
bubbleShadow.set()

let bubble = NSBezierPath(roundedRect: NSRect(x: 205, y: 294, width: 614, height: 470), xRadius: 126, yRadius: 126)
NSColor(calibratedWhite: 1, alpha: 0.97).setFill()
bubble.fill()

let tail = NSBezierPath()
tail.move(to: NSPoint(x: 314, y: 336))
tail.curve(
    to: NSPoint(x: 244, y: 184),
    controlPoint1: NSPoint(x: 306, y: 282),
    controlPoint2: NSPoint(x: 274, y: 220)
)
tail.curve(
    to: NSPoint(x: 464, y: 307),
    controlPoint1: NSPoint(x: 327, y: 230),
    controlPoint2: NSPoint(x: 388, y: 277)
)
tail.close()
tail.fill()

NSShadow().set()
let ink = NSColor(calibratedRed: 0.24, green: 0.34, blue: 0.78, alpha: 1)
for line in [
    NSRect(x: 326, y: 590, width: 362, height: 42),
    NSRect(x: 326, y: 500, width: 274, height: 42),
    NSRect(x: 326, y: 410, width: 332, height: 42)
] {
    ink.setFill()
    NSBezierPath(roundedRect: line, xRadius: 21, yRadius: 21).fill()
}

let sparkleShadow = NSShadow()
sparkleShadow.shadowColor = NSColor(calibratedRed: 0.17, green: 0.13, blue: 0.45, alpha: 0.25)
sparkleShadow.shadowBlurRadius = 14
sparkleShadow.shadowOffset = NSSize(width: 0, height: -6)
sparkleShadow.set()

let sparkle = NSBezierPath()
let sparklePoints = [
    NSPoint(x: 782, y: 876),
    NSPoint(x: 807, y: 811),
    NSPoint(x: 872, y: 786),
    NSPoint(x: 807, y: 761),
    NSPoint(x: 782, y: 696),
    NSPoint(x: 757, y: 761),
    NSPoint(x: 692, y: 786),
    NSPoint(x: 757, y: 811)
]
sparkle.move(to: sparklePoints[0])
for point in sparklePoints.dropFirst() {
    sparkle.line(to: point)
}
sparkle.close()
NSColor(calibratedRed: 1.00, green: 0.88, blue: 0.38, alpha: 1).setFill()
sparkle.fill()

NSGraphicsContext.restoreGraphicsState()

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not encode icon PNG")
}
try png.write(to: outputURL)
print("Generated \(outputURL.path)")
