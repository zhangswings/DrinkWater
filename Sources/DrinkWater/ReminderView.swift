import AppKit
import QuartzCore

// MARK: - 主视图

class ReminderView: NSView {
    private let onDrank: () -> Void
    private var scale: CGFloat = 1.0

    private let cupView    = CupAnimView()
    private let titleLabel = NSTextField(labelWithString: "嘿，喝水啦！")
    private let tipLabel   = NSTextField(labelWithString: "你已经盯屏幕好久了 👀")
    private let drankBtn   = PillButton()

    init(onDrank: @escaping () -> Void) {
        self.onDrank = onDrank
        super.init(frame: .zero)
        wantsLayer = true
        setupBackground()
        setupSubviews()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: 背景

    private func setupBackground() {
        layer?.cornerRadius = 24
        layer?.masksToBounds = true

        let grad = CAGradientLayer()
        grad.name = "bg"
        grad.colors = [
            NSColor(calibratedRed: 0.20, green: 0.60, blue: 1.00, alpha: 1).cgColor,
            NSColor(calibratedRed: 0.10, green: 0.82, blue: 0.96, alpha: 1).cgColor,
        ]
        grad.startPoint = CGPoint(x: 0, y: 1)
        grad.endPoint   = CGPoint(x: 1, y: 0)
        layer?.addSublayer(grad)
        // 存引用供 layout 用
        layer?.setValue(grad, forKey: "gradLayer")
    }

    override func layout() {
        super.layout()
        if let grad = layer?.value(forKey: "gradLayer") as? CAGradientLayer {
            grad.frame = bounds
        }
        layoutContent()
    }

    // MARK: 子视图

    private func setupSubviews() {
        // 水杯动画
        addSubview(cupView)

        // 标题
        titleLabel.font = .boldSystemFont(ofSize: 26)
        titleLabel.textColor = .white
        titleLabel.alignment = .center
        titleLabel.isEditable = false; titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
        titleLabel.cell?.wraps = true
        addSubview(titleLabel)

        // 小提示
        tipLabel.font = .systemFont(ofSize: 13, weight: .medium)
        tipLabel.textColor = NSColor.white.withAlphaComponent(0.85)
        tipLabel.alignment = .center
        tipLabel.isEditable = false; tipLabel.isBordered = false
        tipLabel.backgroundColor = .clear
        addSubview(tipLabel)

        // 按钮
        drankBtn.btnTitle = "我喝了！🙂"
        drankBtn.target = self
        drankBtn.action = #selector(drankTapped)
        addSubview(drankBtn)
    }

    private func layoutContent() {
        let w = bounds.width
        let h = bounds.height

        let cupSide  = min(w * 0.42, h * 0.38)
        let titleSz  = max(18, min(26 * scale, 54))
        let tipSz    = max(11, min(13 * scale, 26))
        let btnH     = max(40, min(48 * scale, 90))
        let btnW     = min(w - 48, max(150, 180 * scale))
        let pad: CGFloat = 16

        titleLabel.font = .boldSystemFont(ofSize: titleSz)
        tipLabel.font   = .systemFont(ofSize: tipSz, weight: .medium)
        drankBtn.fontSize = max(14, min(17 * scale, 34))

        // 垂直居中整体
        let totalH = cupSide + 10 + titleSz + 8 + tipSz + 18 + btnH
        var y = (h + totalH) / 2

        cupView.frame = NSRect(x: (w - cupSide) / 2, y: y - cupSide, width: cupSide, height: cupSide)
        y -= cupSide + 10

        titleLabel.frame = NSRect(x: pad, y: y - titleSz - 4, width: w - pad*2, height: titleSz + 8)
        y -= titleSz + 14

        tipLabel.frame = NSRect(x: pad, y: y - tipSz - 4, width: w - pad*2, height: tipSz + 8)
        y -= tipSz + 18

        drankBtn.frame = NSRect(x: (w - btnW)/2, y: y - btnH, width: btnW, height: btnH)
        drankBtn.layer?.cornerRadius = btnH / 2
    }

    @objc private func drankTapped() { onDrank() }

    func updateScale(_ s: CGFloat) {
        scale = s
        layer?.cornerRadius = min(24 * s, 40)
        needsLayout = true
    }

    // 入场后的弹跳动效（由 controller 调用）
    func playBounce() {
        cupView.startWiggle()

        let anim = CAKeyframeAnimation(keyPath: "transform.scale")
        anim.values   = [1.0, 1.08, 0.95, 1.03, 1.0]
        anim.keyTimes = [0,   0.25,  0.5,  0.75, 1.0]
        anim.duration = 0.6
        anim.isRemovedOnCompletion = true
        layer?.add(anim, forKey: "bounce")
    }
}

// MARK: - 水杯动画 View

class CupAnimView: NSView {
    private let cupLayer   = CATextLayer()
    private var wiggling   = false

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setupCup()
    }
    required init?(coder: NSCoder) { fatalError() }

    private func setupCup() {
        cupLayer.string = "🥤"
        cupLayer.alignmentMode = .center
        cupLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer?.addSublayer(cupLayer)
    }

    override func layout() {
        super.layout()
        cupLayer.frame = bounds
        cupLayer.fontSize = bounds.height * 0.82
    }

    func startWiggle() {
        guard !wiggling else { return }
        wiggling = true

        let rot = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        rot.values   = [0, -0.18, 0.18, -0.12, 0.12, -0.06, 0.06, 0]
        rot.keyTimes = [0,  0.1,   0.3,   0.5,  0.65,  0.78,  0.9, 1]
        rot.duration = 0.9
        rot.repeatCount = .infinity
        rot.autoreverses = false
        cupLayer.add(rot, forKey: "wiggle")

        // 同时上下浮动
        let bob = CABasicAnimation(keyPath: "transform.translation.y")
        bob.fromValue  = 0
        bob.toValue    = -6
        bob.duration   = 0.8
        bob.autoreverses = true
        bob.repeatCount  = .infinity
        bob.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cupLayer.add(bob, forKey: "bob")
    }
}

// MARK: - 胶囊按钮

class PillButton: NSButton {
    var fontSize: CGFloat = 17 {
        didSet { font = .boldSystemFont(ofSize: fontSize) }
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        isBordered = false
        wantsLayer = true
        font = .boldSystemFont(ofSize: 17)
        layer?.backgroundColor = NSColor.white.cgColor

        // 文字颜色用 attributedTitle
        updateTitle()

        // hover 效果
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
    }
    required init?(coder: NSCoder) { fatalError() }

    var btnTitle: String = "我喝了！🙂" {
        didSet { updateTitle() }
    }

    private func updateTitle() {
        let color = NSColor(calibratedRed: 0.10, green: 0.50, blue: 0.95, alpha: 1)
        let attr = NSAttributedString(string: btnTitle, attributes: [
            .font: NSFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: color
        ])
        attributedTitle = attr
    }

    override func mouseEntered(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 0.88
        }
    }
    override func mouseExited(with event: NSEvent) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            animator().alphaValue = 1.0
        }
    }
    override func mouseDown(with event: NSEvent) {
        layer?.backgroundColor = NSColor(white: 0.92, alpha: 1).cgColor
        super.mouseDown(with: event)
        layer?.backgroundColor = NSColor.white.cgColor
    }
}
