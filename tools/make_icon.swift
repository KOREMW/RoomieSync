// RoomieSync 앱 아이콘 생성기 (1024x1024 PNG)
// 실행: swift tools/make_icon.swift <출력경로>
// 디자인: 인디고 그라데이션 + 흰 집 + ₩ 코인 배지 (룸메이트 공동생활/정산)

import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let out = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "icon-1024.png"

let S = 1024
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
// 앱 아이콘은 알파 채널이 없어야 한다(App Store 요구) → noneSkipLast(불투명).
guard let ctx = CGContext(data: nil, width: S, height: S, bitsPerComponent: 8,
                          bytesPerRow: 0, space: cs,
                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("context")
}

func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(colorSpace: cs, components: [CGFloat(r), CGFloat(g), CGFloat(b), CGFloat(a)])!
}

let indigo      = color(0.31, 0.275, 0.898)   // #4F46E5
let indigoLight = color(0.40, 0.46, 0.96)     // 그라데이션 상단
let indigoDark  = color(0.24, 0.20, 0.74)     // 그라데이션 하단
let white       = color(1, 1, 1)

// 1) 배경 그라데이션 (대각선)
let grad = CGGradient(colorsSpace: cs,
                      colors: [indigoLight, indigoDark] as CFArray,
                      locations: [0, 1])!
ctx.drawLinearGradient(grad,
                       start: CGPoint(x: 0, y: S),
                       end: CGPoint(x: S, y: 0),
                       options: [])

// 살짝 빛나는 하이라이트 (좌상단 부드러운 원)
ctx.saveGState()
let glow = CGGradient(colorsSpace: cs,
                      colors: [color(1,1,1,0.18), color(1,1,1,0)] as CFArray,
                      locations: [0, 1])!
ctx.drawRadialGradient(glow,
                       startCenter: CGPoint(x: 300, y: 760), startRadius: 0,
                       endCenter: CGPoint(x: 300, y: 760), endRadius: 620,
                       options: [])
ctx.restoreGState()

// 2) 집 (흰색) — 지붕(삼각형) + 본체(둥근 사각형) + 문
func roundedRectPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// 본체
let bodyRect = CGRect(x: 320, y: 250, width: 384, height: 290)
ctx.addPath(roundedRectPath(bodyRect, 30))
ctx.setFillColor(white)
ctx.fillPath()

// 지붕 (본체보다 넓은 삼각형)
ctx.beginPath()
ctx.move(to: CGPoint(x: 250, y: 530))
ctx.addLine(to: CGPoint(x: 512, y: 800))
ctx.addLine(to: CGPoint(x: 774, y: 530))
ctx.closePath()
ctx.setFillColor(white)
ctx.fillPath()

// 문 (인디고로 파냄)
let doorRect = CGRect(x: 468, y: 250, width: 88, height: 168)
ctx.addPath(CGPath(roundedRect: doorRect, cornerWidth: 40, cornerHeight: 40, transform: nil))
ctx.setFillColor(indigo)
ctx.fillPath()

// 3) ₩ 코인 배지 (우하단) — 흰 원 + 인디고 ₩
let coinCenter = CGPoint(x: 712, y: 320)
let coinR: CGFloat = 132
// 배경과 분리되도록 인디고 외곽 링
ctx.setFillColor(indigoDark)
ctx.fillEllipse(in: CGRect(x: coinCenter.x - coinR - 14, y: coinCenter.y - coinR - 14,
                           width: (coinR + 14) * 2, height: (coinR + 14) * 2))
ctx.setFillColor(white)
ctx.fillEllipse(in: CGRect(x: coinCenter.x - coinR, y: coinCenter.y - coinR,
                           width: coinR * 2, height: coinR * 2))

// ₩ 글자
let font = CTFontCreateWithName("HelveticaNeue-Bold" as CFString, 170, nil)
let attrs: [NSAttributedString.Key: Any] = [
    NSAttributedString.Key(kCTFontAttributeName as String): font,
    NSAttributedString.Key(kCTForegroundColorAttributeName as String): indigo
]
let line = CTLineCreateWithAttributedString(
    NSAttributedString(string: "₩", attributes: attrs))
var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
let textW = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
ctx.textPosition = CGPoint(x: coinCenter.x - CGFloat(textW) / 2,
                           y: coinCenter.y - (ascent - descent) / 2)
CTLineDraw(line, ctx)

// 4) PNG 저장
guard let image = ctx.makeImage() else { fatalError("image") }
let url = URL(fileURLWithPath: out)
guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
    fatalError("dest")
}
CGImageDestinationAddImage(dest, image, nil)
if CGImageDestinationFinalize(dest) {
    print("✅ 아이콘 생성: \(out)")
} else {
    fatalError("write failed")
}
