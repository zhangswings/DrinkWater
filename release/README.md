# macOS 首次发布流程

目标仓库：zhangswings/DrinkWater。目标正式标签：v0.1.0。先以 Draft Release 完成附件下载验证，再对外发布。维护者须确认 Bundle ID、Apple Developer 团队和发布权限。

## 文件与版本

`packaging/version.env` 是版本与 Bundle ID 的唯一配置来源。默认 0.1.0 / build 1 / io.github.zhangswings.DrinkWater；首次签名前确认 Bundle ID 并固定。修改版本后必须重建应用。

- `scripts/build-release.sh`：现有 Swift Package 的 arm64、x86_64 Release 构建，合并 Universal 2，封装 app。只做本地 ad-hoc 签名。
- `scripts/package-release.sh`：Developer ID 签名、公证 app、装订票据、生成 ZIP/DMG、公证 DMG、生成校验和。需要联网与维护者凭据。
- `build/release/`：临时 app、提交 JSON、源 SHA 和工具链记录，不入 Git。
- `dist/0.1.0/`：最终 DrinkWater-0.1.0-macos-universal.zip / .dmg / SHA256SUMS.txt，不入 Git。
- ZIP 根目录含 DrinkWater.app、LICENSE.txt；DMG 另含 Applications 符号链接。

## 维护者凭据准备

需要 Apple Developer Program 团队、带私钥的 Developer ID Application 证书。将公证凭据交互保存到钥匙串：

```bash
xcrun notarytool store-credentials DrinkWater-notary
```

按提示填写 Apple ID、Team ID、专用密码，也可使用 Apple 支持的 App Store Connect API Key。证书、私钥、密码、API Key 不得入库。CI 后续使用临时钥匙串和 Secrets；本次无需先引入 CI。

## 构建与打包

在干净发布检出中执行（Xcode 15+，记录实际工具链）：

```bash
./scripts/build-release.sh
export SIGN_IDENTITY='Developer ID Application: YOUR NAME (TEAMID)'
export NOTARY_PROFILE='DrinkWater-notary'
./scripts/package-release.sh
```

脚本启用 Hardened Runtime 和时间戳，无需添加沙盒或宽松 entitlement。公证必须 Accepted；失败查看 build/release/notary 下的 JSON，并使用提交 ID 获取 `xcrun notarytool log`。若等待超时，先以 `notarytool info` 查询原提交，不要盲目重复提交。ZIP 本身不能装订票据，因此先装订 app 再生成最终 ZIP。DMG 另外签名、公证和装订。已有 dist 目录会阻止覆盖：检查失败结果并移走旧目录后再重试。

参考：[Apple Developer ID](https://developer.apple.com/developer-id/)、[Apple 公证流程](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)。

## 放行清单

- [ ] 检查 app 的版本、Bundle ID、最低系统版本、可执行权限；`lipo -archs` 为 arm64 x86_64，`otool -L` 无开发机绝对依赖；检查两架构 deployment target。
- [ ] `codesign --verify --deep --strict`、app/DMG `stapler validate`、app `spctl --assess --type execute` 均通过。
- [ ] Apple Silicon 和 Intel 各实测，覆盖 macOS 13 与当前 macOS；无法测试的架构不得宣称已支持。
- [ ] 菜单栏启动/退出、手动提醒、不抢焦点、增长/关闭/再次提醒、多屏回退通过。
- [ ] 默认快捷键、自定义 ⌘A、退出重启后的持久化、快捷键冲突回退到鼠标关闭通过；弹窗关闭后不占用快捷键。
- [ ] 用现有 DRINKWATER_TEST=1 测试模式检查 UI；正式启动不携带该变量。实际工作日整点验证一次调度。
- [ ] 新 Bundle ID 可能改变此前裸可执行文件的 UserDefaults 域；从源码版升级者可能需要重新设置快捷键，不承诺自动迁移。
- [ ] 从 Draft Release 经浏览器下载 ZIP/DMG，在保留 quarantine 的独立测试账户/机器验证解压、拖入 Applications、启动及离线启动；不靠移除隔离属性通过测试。
- [ ] 核对最终 SHA256SUMS.txt，任何重新打包或装订后重新生成校验和。

## 发布

1. 提交并审阅发布改动，确认完整 source SHA。首次公开标签 v0.1.0，预发布可用 v0.1.0-rc.1（同时更新版本配置并重建）。
2. 维护者确认仓库、标签、源 SHA、签名身份和发布授权后，创建指向该 SHA 的标签与 Draft Release；上传三个最终文件，填写 v0.1.0.md 中实测结果。GitHub 自动源码包不替代应用附件。
3. 保存工具链、源 SHA、公证提交 ID和验证记录。下载验证完成后发布正式 Release；失败保持草稿，修复后重新验证。
4. README 将尚未发布提示替换为 [下载最新版本](https://github.com/zhangswings/DrinkWater/releases/latest)。重新读取 Release，核验标签、附件、链接、校验和。
5. 公布后不静默覆盖同版本二进制，修复发 0.1.1。保留旧发布记录；严重问题标注并提供修复版本。

当前未完成项：实际维护者证书/公证授权、双机运行验证、下载隔离验证、公开 Release。打包脚本通过本地构建不代表这些步骤已通过。
