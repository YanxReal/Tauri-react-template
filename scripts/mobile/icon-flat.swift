// icon-flat.swift — write a flat-color PNG (neutral placeholder).
// Usage: swift icon-flat.swift <out.png> <width> <height> <RRGGBB>
// macOS-only helper for the vendored mobile templates (their shipped icons
// are replaced with neutral placeholders; real brands are composed by
// icon-composite.swift from the icon master at regen time).
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count == 5,
      let w = Int(args[2]), let h = Int(args[3]), w > 0, h > 0
else { FileHandle.standardError.write("usage: icon-flat <out> <w> <h> <hex>\n".data(using: .utf8)!); exit(2) }

var hex: UInt64 = 0x9BA1A6
Scanner(string: args[4]).scanHexInt64(&hex)
let r = CGFloat((hex >> 16) & 0xFF) / 255.0
let g = CGFloat((hex >> 8) & 0xFF) / 255.0
let b = CGFloat(hex & 0xFF) / 255.0

guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
else { FileHandle.standardError.write("CGContext failed\n".data(using: .utf8)!); exit(1) }
ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
guard let image = ctx.makeImage() else { exit(1) }

let url = URL(fileURLWithPath: args[1])
guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)