// icon-composite.swift — compose a branded PNG from a 1024 icon master.
// Modes:
//   bg <RRGGBB>  -> master drawn over a solid background (iOS AppIcon-1024*)
//   silhouette    -> master's alpha as a black shape on transparent
//                    (iOS AppIcon-1024-tinted)
// Usage: swift icon-composite.swift <master.png> <out.png> <bg|silhouette> [RRGGBB]
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 4 else {
  FileHandle.standardError.write("usage: icon-composite <master> <out> <bg|silhouette> [hex]\n".data(using: .utf8)!)
  exit(2)
}

func loadImage(_ path: String) -> CGImage? {
  guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
        let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
  return img
}

guard let master = loadImage(args[1]) else { exit(1) }
let w = master.width, h = master.height
let mode = args[3]

guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                          bytesPerRow: 0,
                          space: CGColorSpaceCreateDeviceRGB(),
                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { exit(1) }

if mode == "bg", args.count >= 5 {
  var hex: UInt64 = 0
  Scanner(string: args[4]).scanHexInt64(&hex)
  let r = CGFloat((hex >> 16) & 0xFF) / 255.0
  let g = CGFloat((hex >> 8) & 0xFF) / 255.0
  let b = CGFloat(hex & 0xFF) / 255.0
  ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1))
  ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
  ctx.draw(master, in: CGRect(x: 0, y: 0, width: w, height: h))
} else {
  // silhouette: black where the master has alpha
  ctx.setBlendMode(.clear)
  ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
  ctx.setBlendMode(.normal)
  ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
  ctx.clip(to: CGRect(x: 0, y: 0, width: w, height: h), mask: master)
  ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
}

guard let image = ctx.makeImage() else { exit(1) }
let url = URL(fileURLWithPath: args[2])
guard let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                 UTType.png.identifier as CFString, 1, nil)
else { exit(1) }
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)