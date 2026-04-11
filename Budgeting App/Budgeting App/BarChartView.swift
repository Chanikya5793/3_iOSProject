import UIKit

final class BarChartView: UIView {

    var values: [Double] = [] {
        didSet { setNeedsDisplay() }
    }

    var positiveColor: UIColor = UIColor(red: 0.84, green: 0.64, blue: 0.17, alpha: 1) {
        didSet { setNeedsDisplay() }
    }

    var negativeColor: UIColor = UIColor.systemRed {
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
        guard !values.isEmpty else { return }
        guard let context = UIGraphicsGetCurrentContext() else { return }

        let maxAbsValue = max(values.map { abs($0) }.max() ?? 0, 1)
        let hasPositive = values.contains { $0 > 0 }
        let hasNegative = values.contains { $0 < 0 }

        let topPadding: CGFloat = 8
        let bottomPadding: CGFloat = 10
        let availableHeight = rect.height - topPadding - bottomPadding

        let baselineY: CGFloat
        if hasPositive && hasNegative {
            baselineY = topPadding + (availableHeight / 2)
        } else if hasNegative {
            baselineY = topPadding
        } else {
            baselineY = rect.height - bottomPadding
        }

        let linePath = UIBezierPath()
        linePath.move(to: CGPoint(x: 0, y: baselineY))
        linePath.addLine(to: CGPoint(x: rect.width, y: baselineY))
        UIColor(white: 1, alpha: 0.18).setStroke()
        linePath.lineWidth = 1
        linePath.stroke()

        let count = CGFloat(values.count)
        let slotWidth = rect.width / count
        let barWidth = max(slotWidth * 0.58, 8)
        let cornerRadius = min(barWidth / 2, 6)

        for (index, value) in values.enumerated() {
            let normalized = CGFloat(abs(value) / maxAbsValue)

            let maxBarHeight: CGFloat
            if hasPositive && hasNegative {
                maxBarHeight = (availableHeight / 2) - 4
            } else {
                maxBarHeight = availableHeight - 4
            }

            let barHeight = max(normalized * maxBarHeight, 2)
            let centerX = (CGFloat(index) * slotWidth) + (slotWidth / 2)
            let x = centerX - (barWidth / 2)

            let y: CGFloat
            if value >= 0 {
                y = baselineY - barHeight
            } else {
                y = baselineY
            }

            let barRect = CGRect(x: x, y: y, width: barWidth, height: barHeight)
            let path = UIBezierPath(roundedRect: barRect, cornerRadius: cornerRadius)

            (value >= 0 ? positiveColor : negativeColor).setFill()
            path.fill()
        }

        context.saveGState()
        context.restoreGState()
    }
}
