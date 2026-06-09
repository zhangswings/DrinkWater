import AppKit

class ReminderWindowController: NSWindowController {
    static let shared = ReminderWindowController()

    private var growTimer: Timer?
    private var alreadyShowing = false

    // 每次膨胀量：宽高各加这个值
    private let growStep: CGFloat = 80
    // 膨胀间隔：30秒
    private let growInterval: TimeInterval = 30

    private override init(window: NSWindow?) { super.init(window: window) }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - 显示

    func show() {
        guard !alreadyShowing else { return }
        alreadyShowing = true

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.visibleFrame   // 不遮挡菜单栏

        // 初始大小
        let initW: CGFloat = 280
        let initH: CGFloat = 300

        // 左上角（AppKit 坐标系 Y 轴朝上，所以 top = maxY - height）
        let margin: CGFloat = 16
        let initFrame = NSRect(
            x: screenFrame.minX + margin,
            y: screenFrame.maxY - initH - margin,
            width: initW,
            height: initH
        )

        let win = NSWindow(
            contentRect: initFrame,
            styleMask: [.fullSizeContentView, .titled],
            backing: .buffered,
            defer: false
        )
        win.level = .floating            // 悬浮在所有窗口之上
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.backgroundColor = .clear
        win.isOpaque = false
        win.hasShadow = true

        let view = ReminderView(onDrank: { [weak self] in
            self?.dismiss()
        })
        win.contentView = view

        self.window = win

        // 先从屏幕外（左侧）飞入 —— 入场动效
        var offFrame = initFrame
        offFrame.origin.x = -initW - 40
        win.setFrame(offFrame, display: false)
        win.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.55
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().setFrame(initFrame, display: true)
        } completionHandler: {
            // 入场后再做弹跳
            view.playBounce()
        }

        startGrowing()
    }

    // MARK: - 每 30 秒膨胀

    private func startGrowing() {
        growTimer = Timer.scheduledTimer(withTimeInterval: growInterval, repeats: true) { [weak self] _ in
            self?.grow()
        }
        RunLoop.main.add(growTimer!, forMode: .common)
    }

    private func grow() {
        guard let win = window,
              let screen = NSScreen.main else { return }

        let screenFrame = screen.frame   // 膨胀时可以盖住菜单栏，更有压迫感
        let current = win.frame

        // 向右下膨胀（锚点在左上角）
        var next = current
        next.size.width  = min(current.width  + growStep, screenFrame.width)
        next.size.height = min(current.height + growStep, screenFrame.height)
        // 左边 x 不动，顶边 y 不动（AppKit y 朝上，所以顶 = origin.y + height）
        // 保持 top 位置不变
        let currentTop = current.origin.y + current.height
        next.origin.y = currentTop - next.height
        next.origin.x = current.origin.x  // 左边锚住

        // 边界保护
        next.origin.x = max(next.origin.x, screenFrame.minX)
        next.origin.y = max(next.origin.y, screenFrame.minY)
        next.size.width  = min(next.size.width,  screenFrame.width  - next.origin.x + screenFrame.minX)
        next.size.height = min(next.size.height, screenFrame.height - next.origin.y + screenFrame.minY)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            win.animator().setFrame(next, display: true)
        }

        // 同步更新 view 缩放
        if let view = win.contentView as? ReminderView {
            let ratio = next.width / 280.0
            view.updateScale(ratio)
        }
    }

    // MARK: - 关闭

    private func dismiss() {
        growTimer?.invalidate()
        growTimer = nil

        guard let win = window else { return }

        // 向左飞出
        var outFrame = win.frame
        outFrame.origin.x = -(outFrame.width + 40)

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.4
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            win.animator().setFrame(outFrame, display: true)
        }, completionHandler: { [weak self] in
            win.orderOut(nil)
            self?.window = nil
            self?.alreadyShowing = false
        })
    }
}
