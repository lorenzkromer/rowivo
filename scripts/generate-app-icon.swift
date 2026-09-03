import AppKit

// Vector construction of Rowivo's paired-oar mark. Run from the repository root.
let size = 1024
let colorSpace = CGColorSpaceCreateDeviceRGB()
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.setFillColor(CGColor(red: 0.07, green: 0.20, blue: 0.20, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: size, height: size))
context.setStrokeColor(CGColor(red: 0.84, green: 0.94, blue: 0.65, alpha: 1))
context.setLineCap(.round)
context.setLineWidth(103)
context.move(to: CGPoint(x: 265, y: 435))
context.addLine(to: CGPoint(x: 500, y: 716))
context.strokePath()
context.move(to: CGPoint(x: 506, y: 322))
context.addLine(to: CGPoint(x: 741, y: 603))
context.strokePath()
let bitmap = NSBitmapImageRep(cgImage: context.makeImage()!)
let url = URL(fileURLWithPath: "Rowivo/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
try bitmap.representation(using: .png, properties: [:])!.write(to: url)
