import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var scheduleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        startScheduler()

        // 测试模式：DRINKWATER_TEST=1 立即弹窗
        if ProcessInfo.processInfo.environment["DRINKWATER_TEST"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                ReminderWindowController.shared.show()
            }
        }
    }

    // MARK: - 状态栏

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.title = "💧"
        button.toolTip = "喝水提醒 | 工作日 10:00-17:00 每整点提醒"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "立刻提醒我喝水 💧", action: #selector(forceRemind), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(createShortcutMenu())
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    // MARK: - 快捷键菜单

    private func createShortcutMenu() -> NSMenuItem {
        let item = NSMenuItem(title: "关闭快捷键：\(HotkeyManager.shortcutDisplay)", action: nil, keyEquivalent: "")
        let sub = NSMenu()

        // 预设
        var presets: [(title: String, keyCode: Int, mods: Int)] = []
        presets.append(("⌘1", 18, Int(cmdKey)))
        presets.append(("⌘2", 19, Int(cmdKey)))
        presets.append(("⌘3", 20, Int(cmdKey)))
        presets.append(("⌘`", 50, Int(cmdKey)))
        presets.append(("⌘⇧1", 18, Int(cmdKey) | Int(shiftKey)))
        for preset in presets {
            let mi = NSMenuItem(title: preset.title, action: #selector(setPresetShortcut(_:)), keyEquivalent: "")
            mi.representedObject = (preset.keyCode, preset.mods)
            if preset.keyCode == HotkeyManager.savedKeyCode() && preset.mods == HotkeyManager.savedModifiers() {
                mi.state = .on
            }
            sub.addItem(mi)
        }

        sub.addItem(.separator())
        let custom = NSMenuItem(title: "自定义快捷键…", action: #selector(captureCustomShortcut), keyEquivalent: "")
        sub.addItem(custom)

        item.submenu = sub
        return item
    }

    @objc private func setPresetShortcut(_ sender: NSMenuItem) {
        guard let (kc, mods) = sender.representedObject as? (Int, Int) else { return }
        HotkeyManager.save(keyCode: kc, modifiers: mods)
        rebuildMenu()
    }

    @objc private func captureCustomShortcut() {
        // 弹出一个浮动面板，捕获下一组按键
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 140),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "设置快捷键"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor.windowBackgroundColor
        panel.level = .floating
        panel.center()

        let label = NSTextField(labelWithString: "请在键盘上按下新的快捷键组合")
        label.font = .systemFont(ofSize: 14)
        label.alignment = .center
        label.textColor = .secondaryLabelColor

        let display = NSTextField(labelWithString: "等待按键…")
        display.font = .boldSystemFont(ofSize: 28)
        display.alignment = .center
        display.textColor = .labelColor

        // 使用一个隐藏的 NSView 来捕获 keyDown
        let catcher = KeyCatcherView()
        catcher.onKeyCombo = { [weak self] keyCode, modifiers in
            // 过滤掉只有修饰键的组合
            let keyMap: [UInt16: Bool] = [
                54: true, 55: true, 56: true, 57: true, 58: true,
                59: true, 60: true, 61: true, 62: true, 63: true
            ]
            guard keyMap[keyCode] == nil else { return }  // 忽略纯修饰键
            guard modifiers > 0 else { return }            // 必须带修饰键

            panel.orderOut(nil)
            panel.close()

            HotkeyManager.save(keyCode: Int(keyCode), modifiers: Int(modifiers))
            self?.rebuildMenu()
        }

        let stack = NSStackView(views: [label, display, catcher])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .centerX
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        panel.contentView = stack

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func rebuildMenu() {
        guard let button = statusItem?.button else { return }
        // 重建菜单，保持 toolTip 等不变
        let buttonTitle = button.title
        let toolTip = button.toolTip
        setupStatusBar()
        if let newButton = statusItem?.button {
            newButton.title = buttonTitle
            newButton.toolTip = toolTip
        }
    }

    @objc private func forceRemind() {
        ReminderWindowController.shared.show()
    }

    // MARK: - 调度：每分钟检查一次

    private func startScheduler() {
        scheduleTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkTime()
        }
        scheduleTimer?.tolerance = 5
        RunLoop.main.add(scheduleTimer!, forMode: .common)
    }

    private func checkTime() {
        let cal = Calendar.current
        let now = Date()

        // 仅工作日（周一=2 … 周五=6）
        let weekday = cal.component(.weekday, from: now)
        guard weekday >= 2 && weekday <= 6 else { return }

        let hour   = cal.component(.hour,   from: now)
        let minute = cal.component(.minute, from: now)

        // 10:00 ~ 17:00 整点触发（18:00之前最后一次是17:00）
        guard hour >= 10 && hour <= 17 && minute == 0 else { return }

        ReminderWindowController.shared.show()
    }
}

// MARK: - 按键捕获视图

fileprivate class KeyCatcherView: NSView {
    var onKeyCombo: ((_ keyCode: UInt16, _ modifiers: UInt32) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbonMods = carbonModifiers(from: mods)
        onKeyCombo?(event.keyCode, carbonMods)
    }

    private func carbonModifiers(from nsMods: NSEvent.ModifierFlags) -> UInt32 {
        var cm: UInt32 = 0
        if nsMods.contains(.command)  { cm |= UInt32(cmdKey) }
        if nsMods.contains(.option)   { cm |= UInt32(optionKey) }
        if nsMods.contains(.control)  { cm |= UInt32(controlKey) }
        if nsMods.contains(.shift)    { cm |= UInt32(shiftKey) }
        return cm
    }
}
