# DrinkWater 💧

> macOS 菜单栏喝水提醒工具 · A gentle hydration reminder that lives in your macOS menu bar

---

## 简介 / Introduction

**中文**

DrinkWater 是一款极简的 macOS 菜单栏应用。每到工作日（周一至周五）10:00–17:00 的整点，屏幕左上角会飞入一张提醒卡片，提示你喝水。如果你无视它，卡片会每 30 秒自动膨胀一次，直到你点击「我喝了！」为止。

**English**

DrinkWater is a lightweight macOS menu bar app. On weekdays (Mon–Fri) from 10:00 to 17:00, a reminder card slides in from the top-left corner of your screen at the top of every hour. Ignore it and it grows larger every 30 seconds — until you click "I drank it! 🙂".

---

## 功能特性 / Features

| | 中文 | English |
|---|---|---|
| 🕐 | 工作日整点提醒（10:00–17:00） | Hourly reminders on weekdays (10:00–17:00) |
| 📐 | 忽视越久、窗口越大（压迫感拉满） | Window grows every 30 s if ignored |
| 🎬 | 飞入 / 飞出入场动效 + 弹跳水杯 | Slide-in/out animation with bouncing cup |
| 🖱️ | 手动触发「立刻提醒」 | Manual trigger from menu bar |
| 🖥️ | 优先显示在内置屏幕 | Prefers the built-in display |
| ♻️ | 无沙盒、无通知权限依赖 | No sandbox, no notification permissions needed |

---

## 系统要求 / Requirements

- macOS 13 Ventura 或更高版本
- Swift 5.9+（随 Xcode 15+ 附带）

---

## 快速开始 / Quick Start

```bash
git clone https://github.com/zhangswings/DrinkWater.git
cd DrinkWater
./run.sh
```

`run.sh` 会自动编译并启动应用，菜单栏出现 💧 图标即表示运行中。

---

## 手动构建 / Build Manually

```bash
swift build -c release
.build/release/DrinkWater
```

---

## 项目结构 / Project Structure

```
DrinkWater/
├── Sources/DrinkWater/
│   ├── main.swift                  # 入口 / Entry point
│   ├── AppDelegate.swift           # 状态栏 + 调度逻辑 / Menu bar & scheduler
│   ├── ReminderWindowController.swift  # 窗口管理 + 膨胀逻辑 / Window & grow logic
│   └── ReminderView.swift          # UI：卡片、水杯动画、按钮 / Card UI & animations
├── Package.swift
├── run.sh                          # 一键构建并运行 / Build & run script
└── LICENSE
```

---

## 工作原理 / How It Works

1. App 启动后以 `.accessory` 模式运行（不出现在 Dock）。
2. 每分钟检查一次当前时间：工作日 + 整点 + 10:00–17:00 范围内则触发弹窗。
3. 弹窗从左侧飞入，展示动态水杯动画。
4. 若用户未响应，每 30 秒将窗口尺寸增大 80pt（宽高各），最大不超过屏幕尺寸。
5. 点击「我喝了！」后窗口飞出关闭，等待下一个整点。

---

## 开发 / Development

### 环境变量测试模式

启动时设置 `DRINKWATER_TEST=1` 可在 0.5 秒后立即弹出提醒窗口，方便调试 UI：

```bash
DRINKWATER_TEST=1 .build/debug/DrinkWater
```

---

## 贡献 / Contributing

欢迎提 Issue 或 PR！请保持代码风格与现有文件一致（纯 AppKit，无第三方依赖）。

Issues and PRs are welcome. Please keep the code style consistent with existing files — pure AppKit, zero third-party dependencies.

---

## 许可证 / License

[MIT](LICENSE) © 2026 zhangswings
