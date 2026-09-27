// 앱 아이콘 원본을 그린다: swift scripts/make-icon.swift <출력.png>
import AppKit

let size: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

// macOS 아이콘 격자: 1024 캔버스에 824 몸통
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)

NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = color(0x000000, 0.28)
shadow.shadowOffset = NSSize(width: 0, height: -12)
shadow.shadowBlurRadius = 28
shadow.set()
color(0xEFEBE3).setFill()
bodyPath.fill()
NSGraphicsContext.restoreGraphicsState()

NSGradient(starting: color(0xF7F4EE), ending: color(0xE6E0D5))!.draw(in: bodyPath, angle: -90)

// 쌓인 카드 세 장. 아래일수록 좁고 흐리다
func card(_ rect: NSRect, fill: NSColor, stroke: NSColor) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 44, yRadius: 44)
    NSGraphicsContext.saveGraphicsState()
    let s = NSShadow()
    s.shadowColor = color(0x3A3226, 0.16)
    s.shadowOffset = NSSize(width: 0, height: -6)
    s.shadowBlurRadius = 14
    s.set()
    fill.setFill()
    path.fill()
    NSGraphicsContext.restoreGraphicsState()
    stroke.setStroke()
    path.lineWidth = 4
    path.stroke()
}

card(NSRect(x: 296, y: 640, width: 432, height: 90), fill: color(0xD9D2C5), stroke: color(0xC7BEAE))
card(NSRect(x: 256, y: 598, width: 512, height: 90), fill: color(0xE7E1D6), stroke: color(0xCFC6B6))
let top = NSRect(x: 212, y: 250, width: 600, height: 400)
card(top, fill: color(0xFFFFFF), stroke: color(0xD6CDBC))

// 맨 위 카드: 왼쪽 인용 줄 + 물음표
color(0xD9912B).setFill()
NSBezierPath(roundedRect: NSRect(x: top.minX + 64, y: top.minY + 88, width: 16, height: 224), xRadius: 8, yRadius: 8).fill()

let mark = "?" as NSString
let font = NSFont.systemFont(ofSize: 300, weight: .semibold)
let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color(0x2E2A25)]
let markSize = mark.size(withAttributes: attrs)
mark.draw(at: NSPoint(x: top.midX - markSize.width / 2 + 28, y: top.midY - markSize.height / 2 + 4), withAttributes: attrs)

NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
