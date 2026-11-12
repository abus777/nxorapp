import SwiftUI

/// NXOR's signature shape: top-right and bottom-left corners cut at 45°.
struct CutCorner: InsettableShape {
    var cut: CGFloat = 12
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let c = min(cut, min(r.width, r.height) / 2)
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> CutCorner {
        var s = self
        s.insetAmount += amount
        return s
    }
}

/// The NXOR "X" mark: two thick crossing bars with flat ends.
struct NXMark: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let t = w * 0.30
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.minY + h * 0.30))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + h * 0.14))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.72, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - h * 0.14))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX - t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - h * 0.30))
        p.addLine(to: CGPoint(x: rect.minX + t, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - h * 0.14))
        p.addLine(to: CGPoint(x: rect.minX + w * 0.28, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.14))
        p.closeSubpath()
        return p
    }
}
