import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var scheduleTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusBar()
        startScheduler()
    }

    // MARK: - 状态栏

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem?.button else { return }
        button.title = "💧"
        button.toolTip = "喝水提醒 | 工作日 10:00-18:00 每整点提醒"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "立刻提醒我喝水 💧", action: #selector(forceRemind), keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
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
