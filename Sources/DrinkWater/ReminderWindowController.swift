import AppKit
import Carbon

// MARK: - 全局快捷键管理

class HotkeyManager {
    static var hotKeyRef: EventHotKeyRef?
    static let hotKeyID = EventHotKeyID(signature: 0x44524E4B, id: 1)
    static var isHandlerInstalled = false
    fileprivate static var handler: (() -> Void)?
    fileprivate static var eventHandlerRef: EventHandlerRef?

    /// 安装一次 Carbon 事件处理器（永久有效）
    static func installHandler(_ handle: @escaping () -> Void) {
        handler = handle
        guard !isHandlerInstalled else { return }
        isHandlerInstalled = true

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(GetEventDispatcherTarget(), hotkeyCallback, 1, &eventSpec, nil, nil)
    }

    private static let hotkeyCallback: EventHandlerUPP = { _, event, _ -> OSStatus in
        var hkID = EventHotKeyID()
        let err = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hkID
        )
        guard err == noErr, hkID.signature == 0x44524E4B else { return err }
        DispatchQueue.main.async { handler?() }
        return noErr
    }

    static func registerCurrent() {
        unregister()
        let kc = savedKeyCode()
        let mod = savedModifiers()
        let status = RegisterEventHotKey(kc, mod, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("HotKey registration failed: \(status)")
        }
    }

    static func unregister() {
        guard let ref = hotKeyRef else { return }
        UnregisterEventHotKey(ref)
        hotKeyRef = nil
    }

    // MARK: UserDefaults 存取

    static func savedKeyCode() -> UInt32 {
        let c = UserDefaults.standard.integer(forKey: "hk_keyCode")
        return c > 0 ? UInt32(c) : 18           // default: '1'
    }
    static func savedModifiers() -> UInt32 {
        let m = UserDefaults.standard.integer(forKey: "hk_modifiers")
        return m > 0 ? UInt32(m) : UInt32(cmdKey)
    }
    static func save(keyCode: Int, modifiers: Int) {
        UserDefaults.standard.set(keyCode, forKey: "hk_keyCode")
        UserDefaults.standard.set(modifiers, forKey: "hk_modifiers")
    }

    // MARK: 显示文字

    static func modifierString(_ m: UInt32) -> String {
        var parts: [String] = []
        if m & UInt32(cmdKey)    != 0 { parts.append("⌘") }
        if m & UInt32(optionKey) != 0 { parts.append("⌥") }
        if m & UInt32(controlKey) != 0 { parts.append("⌃") }
        if m & UInt32(shiftKey)  != 0 { parts.append("⇧") }
        return parts.joined()
    }

    static func keyName(_ code: UInt32) -> String {
        let map: [UInt32: String] = [
            18: "1", 19: "2", 20: "3", 21: "4", 22: "5",
            23: "6", 24: "7", 25: "8", 26: "9", 27: "0",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H",
            5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            12: "Q", 13: "W", 14: "E", 15: "R", 16: "T",
            17: "Y", 31: "O", 32: "U", 34: "I", 35: "P",
            36: "⏎", 53: "⎋", 49: "Space",
        ]
        return map[code] ?? "key\(code)"
    }

    static var shortcutDisplay: String {
        "\(modifierString(savedModifiers()))\(keyName(savedKeyCode()))"
    }
}

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

        let screen = ReminderWindowController.builtInScreen()
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
        win.orderFrontRegardless()     // 不抢焦点

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.55
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            win.animator().setFrame(initFrame, display: true)
        } completionHandler: {
            // 入场后再做弹跳
            view.playBounce()
        }

        // 注册全局快捷键（默认 ⌘1）
        HotkeyManager.installHandler { [weak self] in
            self?.dismiss()
        }
        HotkeyManager.registerCurrent()

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
        guard let win = window else { return }
        let screen = ReminderWindowController.builtInScreen()
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

    // MARK: - 屏幕选择：优先内置屏幕，没有则用主屏

    static func builtInScreen() -> NSScreen {
        // macOS 内置屏幕的 displayID 可通过 CGDisplayIsBuiltin 判断
        for screen in NSScreen.screens {
            if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
               CGDisplayIsBuiltin(id) != 0 {
                return screen
            }
        }
        // 没有内置屏（台式机 / 所有外接）则回退到主屏
        return NSScreen.main ?? NSScreen.screens[0]
    }

    // MARK: - 关闭

    private func dismiss() {
        growTimer?.invalidate()
        growTimer = nil
        HotkeyManager.unregister()

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
