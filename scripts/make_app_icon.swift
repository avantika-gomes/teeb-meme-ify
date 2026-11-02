// Renders the Fetch app icon (handoff/HANDOFF.md §3) at 1024x1024.
// Usage: swift scripts/make_app_icon.swift TessaMemeGenerator/Fonts/Anton-Regular.ttf TessaMemeGenerator/Assets.xcassets/AppIcon.appiconset/AppIcon.png

import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

// Fetch app mark (handoff/HANDOFF.md §3), from the prototype's 42pt padding box scaled to 1024.
let fontPath = CommandLine.arguments[1]
let outPath = CommandLine.arguments[2]
let size: CGFloat = 1024
let u = size / 42  // one prototype pt

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}
let ink = rgb(0x0A0A0A), paper = rgb(0xFBFBF9), lime = rgb(0xD9FF3D), orange = rgb(0xFF5C38)

guard let provider = CGDataProvider(url: URL(fileURLWithPath: fontPath) as CFURL),
      let cgFont = CGFont(provider) else { fatalError("font") }
let font = CTFontCreateWithGraphicsFont(cgFont, 29 * u, nil, nil)

let ctx = CGContext(data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
// Work in top-left-origin coordinates like the CSS.
ctx.translateBy(x: 0, y: size)
ctx.scaleBy(x: 1, y: -1)

// Diagonal split: 66.2% across the top, 33.8% across the bottom.
let leftWedge = CGMutablePath()
leftWedge.addLines(between: [CGPoint(x: 0, y: 0), CGPoint(x: size * 0.662, y: 0),
                             CGPoint(x: size * 0.338, y: size), CGPoint(x: 0, y: size)])
leftWedge.closeSubpath()
let rightWedge = CGMutablePath()
rightWedge.addLines(between: [CGPoint(x: size * 0.662, y: 0), CGPoint(x: size, y: 0),
                              CGPoint(x: size, y: size), CGPoint(x: size * 0.338, y: size)])
rightWedge.closeSubpath()

ctx.setFillColor(paper); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
ctx.setFillColor(ink); ctx.addPath(leftWedge); ctx.fillPath()

// "F" centered as CSS lays out a line-height:1 line box, stretched 1.28x about its center.
let glyphs: [CGGlyph] = {
    var g = CGGlyph(); var c: UniChar = 0x46
    CTFontGetGlyphsForCharacters(font, &c, &g, 1); return [g]
}()
var advance = CGSize.zero
CTFontGetAdvancesForGlyphs(font, .horizontal, glyphs, &advance, 1)
let ascent = CTFontGetAscent(font), descent = CTFontGetDescent(font)
let fontSize = 29 * u
let lineTop = (size - fontSize) / 2
let baseline = lineTop + (fontSize - (ascent + descent)) / 2 + ascent

func drawF(color: CGColor, clip: CGPath) {
    ctx.saveGState()
    ctx.addPath(clip); ctx.clip()
    ctx.translateBy(x: size / 2, y: baseline)
    ctx.scaleBy(x: 1.28, y: -1)  // stretch, and flip back to glyph space
    ctx.setFillColor(color)
    var pos = CGPoint(x: -advance.width / 2, y: 0)
    CTFontDrawGlyphs(font, glyphs, &pos, 1, ctx)
    ctx.restoreGState()
}
drawF(color: lime, clip: leftWedge)
drawF(color: ink, clip: rightWedge)

// Tongue: 15x3 pill, 4pt above the bottom edge.
let bar = CGRect(x: (size - 15 * u) / 2, y: size - 4 * u - 3 * u, width: 15 * u, height: 3 * u)
ctx.setFillColor(orange)
ctx.addPath(CGPath(roundedRect: bar, cornerWidth: bar.height / 2, cornerHeight: bar.height / 2, transform: nil))
ctx.fillPath()

let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
print("wrote \(outPath)")
