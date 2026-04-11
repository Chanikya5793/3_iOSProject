import UIKit

final class PieChartView: UIView {

    struct Segment {
        let value: Double
        let color: UIColor
    }

    var segments: [Segment] = [] {
        didSet { setNeedsDisplay() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        contentMode = .redraw
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let total = segments.reduce(0) { $0 + max($1.value, 0) }
        let drawRect = rect.insetBy(dx: 3, dy: 3)

        if total <= 0 {
            UIColor.systemGray4.setFill()
            context.fillEllipse(in: drawRect)
            return
        }

        let center = CGPoint(x: drawRect.midX, y: drawRect.midY)
        let radius = min(drawRect.width, drawRect.height) / 2
        var startAngle = -CGFloat.pi / 2

        for segment in segments where segment.value > 0 {
            let angle = CGFloat(segment.value / total) * .pi * 2
            let endAngle = startAngle + angle

            let path = UIBezierPath()
            path.move(to: center)
            path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
            path.close()

            segment.color.setFill()
            path.fill()

            UIColor(white: 1, alpha: 0.18).setStroke()
            path.lineWidth = 1
            path.stroke()

            startAngle = endAngle
        }

        UIColor(white: 0.95, alpha: 0.65).setFill()
        let innerRadius = radius * 0.4
        let innerRect = CGRect(
            x: center.x - innerRadius,
            y: center.y - innerRadius,
            width: innerRadius * 2,
            height: innerRadius * 2
        )
        context.fillEllipse(in: innerRect)
    }
}
