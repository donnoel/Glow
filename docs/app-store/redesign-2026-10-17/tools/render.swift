import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

let _ = NSApplication.shared

// Apple-native composition only. Captured UI is cropped/scaled as a single image;
// controls, text, charts and colors inside it are never redrawn or retouched.
let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/app-store/redesign-2026-10-17")
let fm = FileManager.default
func color(_ hex: String) -> NSColor {
    let v = UInt32(hex, radix: 16)!
    return NSColor(srgbRed: CGFloat((v >> 16) & 255)/255, green: CGFloat((v >> 8) & 255)/255, blue: CGFloat(v & 255)/255, alpha: 1)
}
let ink = color("153F39"), teal = color("007E72")
struct Canvas {
    let rep: NSBitmapImageRep
    let w: CGFloat
    let h: CGFloat
    init(_ width: Int, _ height: Int, _ background: NSColor) {
        w = CGFloat(width); h = CGFloat(height)
        rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        background.setFill(); NSRect(x: 0, y: 0, width: w, height: h).fill()
    }
    func rect(_ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat) -> NSRect {
        NSRect(x: x, y: h-top-height, width: width, height: height)
    }
    func text(_ s: String, _ x: CGFloat, _ top: CGFloat, _ width: CGFloat, _ height: CGFloat, _ size: CGFloat, _ c: NSColor = ink, align: NSTextAlignment = .left, weight: NSFont.Weight = .semibold) {
        let para = NSMutableParagraphStyle(); para.alignment = align; para.lineSpacing = size*0.035; para.lineBreakMode = .byWordWrapping
        let base = NSFont.systemFont(ofSize: size, weight: weight)
        let font = NSFont(descriptor: base.fontDescriptor.withDesign(.rounded) ?? base.fontDescriptor, size: size)!
        let a = NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c, .paragraphStyle: para])
        a.draw(with: rect(x,top,width,height), options: [.usesLineFragmentOrigin, .usesFontLeading])
    }
    func picture(_ path: String, _ x: CGFloat, _ top: CGFloat, _ width: CGFloat, crop: CGRect? = nil) {
        let image = NSImage(contentsOf: root.appendingPathComponent(path))!
        var proposed = CGRect(origin: .zero, size: image.size)
        let cg = image.cgImage(forProposedRect: &proposed, context: nil, hints: nil)!
        let selected = crop.map { cg.cropping(to: $0)! } ?? cg
        let height = width * CGFloat(selected.height) / CGFloat(selected.width)
        let target = rect(x,top,width,height)
        NSImage(cgImage: selected, size: NSSize(width: selected.width, height: selected.height)).draw(in: target, from: .zero, operation: .copy, fraction: 1)
    }
    func save(_ path: String) throws {
        let url = root.appendingPathComponent(path)
        try fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let rgb = CGContext(data: nil, width: Int(w), height: Int(h), bitsPerComponent: 8, bytesPerRow: Int(w)*4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        rgb.draw(rep.cgImage!, in: CGRect(x:0,y:0,width:w,height:h))
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, rgb.makeImage()!, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
    }
}
let names = ["01-today", "02-insights", "03-water", "04-habit-detail", "05-schedule"]
let backgrounds = ["F1F8F5", "F0FAF8", "EFF8FB", "F4F2FA", "F1F8F5"]
for (folder, width, height) in [("iphone",1206,2622),("iphone-large",1320,2868)] {
    let s = CGFloat(width)/1206
    for n in 0..<5 {
        let canvas = Canvas(width,height,color(backgrounds[n]))
        func label(_ top: CGFloat = 48) { canvas.text("Glow  /  Daily Practice", 78*s,top*s,1050*s,58*s,38*s,teal) }
        switch n {
        case 0:
            label()
            canvas.text("Daily habits.\nOne clear view.",78*s,112*s,1060*s,220*s,94*s)
            canvas.picture("captures/iphone/01-today.png",84*s,350*s,1038*s)
        case 1:
            label(68)
            canvas.text("See your\nweekly rhythm.",78*s,175*s,1050*s,265*s,106*s)
            canvas.text("Schedules and check-ins, side by side.",80*s,487*s,1045*s,110*s,43*s,teal,weight:.medium)
            // Focus on the genuine rhythm table, preserving the original tab bar.
            canvas.picture("captures/iphone/02-insights.png",50*s,650*s,1106*s,crop:CGRect(x:0,y:820,width:1206,height:1802))
            canvas.text("A week of small steps, at a glance.",80*s,2400*s,1045*s,105*s,43*s,ink,align:.center,weight:.medium)
        case 2:
            label(56)
            canvas.text("Log every drink.\nSee your daily total.",78*s,145*s,1060*s,235*s,86*s)
            // Omit only the empty lower portion of this actual entry sheet.
            canvas.picture("captures/iphone/03-water.png",60*s,455*s,1086*s,crop:CGRect(x:0,y:0,width:1206,height:2190))
        case 3:
            canvas.picture("captures/iphone/04-habit-detail.png",96*s,50*s,1014*s)
            canvas.text("See your progress\nover time.",78*s,2335*s,1050*s,232*s,83*s)
        default:
            label(60)
            canvas.text("Choose the days\nthat work for you.",78*s,150*s,1050*s,235*s,88*s)
            // End after the selected weekdays; do not feature the unrelated icon grid.
            canvas.picture("captures/iphone/05-schedule.png",63*s,470*s,1080*s,crop:CGRect(x:0,y:0,width:1206,height:2130))
            canvas.text("Daily or custom schedules.",78*s,2460*s,1050*s,80*s,43*s,teal,align:.center,weight:.medium)
        }
        try canvas.save("exports/\(folder)/\(names[n]).png")
    }
}
for n in 0..<5 {
    let canvas = Canvas(2752,2064,color(backgrounds[n]))
    switch n {
    case 0:
        canvas.text("Glow  /  Daily Practice",130,30,2420,60,40,teal)
        canvas.text("Your daily habits, clearly in view.",130,91,2450,115,88)
        canvas.picture("captures/ipad/01-today.png",160,225,2432)
    case 1:
        canvas.picture("captures/ipad/02-insights.png",151,30,2450)
        canvas.text("See your weekly rhythm.",160,1910,2432,120,82)
    case 2:
        canvas.text("Glow  /  Daily Practice",140,82,2440,80,46,teal)
        canvas.text("Water, alongside\nyour daily habits.",140,220,2440,295,132)
        // A single crop of the entire native wide water report, with its real controls.
        canvas.picture("captures/ipad/03-water.png",120,650,2512,crop:CGRect(x:530,y:620,width:2170,height:950))
        canvas.text("7- and 30-day reports. Saved goals. Clearly unlogged days.",140,1835,2440,140,54,ink,weight:.medium)
    case 3:
        canvas.text("Every habit has a history.",150,78,2450,130,94)
        canvas.picture("captures/ipad/04-habit-detail.png",150,220,2452)
    default:
        canvas.text("Glow  /  Daily Practice",140,110,1150,80,46,teal)
        canvas.text("Your week.\nYour schedule.",140,535,1120,400,128)
        canvas.text("Choose custom weekdays\nand set a reminder.",145,1100,1050,240,64,ink,weight:.medium)
        // Keep the complete real form, including its original background and chrome.
        canvas.picture("captures/ipad/05-schedule.png",1350,310,1272,crop:CGRect(x:745,y:350,width:1260,height:1370))
    }
    try canvas.save("exports/ipad/\(names[n]).png")
}
for name in ["01-daily-progress","02-quick-water"] {
    let c = Canvas(422,514,.black)
    c.picture("captures/watch/\(name).png",0,0,422)
    try c.save("exports/watch/\(name).png")
}
// Contact sheets preserve order; full-resolution images remain separate.
for (folder, thumbW, thumbH, cols) in [("iphone",300,652,5),("iphone-large",300,652,5),("ipad",560,420,3),("watch",300,365,2)] {
    let files = try fm.contentsOfDirectory(at: root.appendingPathComponent("exports/\(folder)"),includingPropertiesForKeys:nil).filter{$0.pathExtension=="png"}.sorted{$0.lastPathComponent<$1.lastPathComponent}
    let rows = (files.count+cols-1)/cols
    let c = Canvas(cols*(thumbW+24)+24, rows*(thumbH+70)+100,color("F7FAF9"))
    c.text("Glow / \(folder) / proposed sequence",24,20,c.w-48,65,32)
    for (i,f) in files.enumerated() {
        let x=CGFloat(24+(i%cols)*(thumbW+24)), y=CGFloat(100+(i/cols)*(thumbH+70))
        c.picture("exports/\(folder)/\(f.lastPathComponent)",x,y,CGFloat(thumbW))
        c.text(String(format:"%02d",i+1),x,y+CGFloat(thumbH)+12,CGFloat(thumbW),38,24,teal)
    }
    try c.save("contact-sheets/\(folder).png")
}
print("Rendered 17 opaque PNG exports and 4 ordered contact sheets.")
