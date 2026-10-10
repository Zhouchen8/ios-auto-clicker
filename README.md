# iOS 自动点击器（签名 IPA 分发版）

根据 PRD v2.0 实现的 iOS 15+ 自动点击工具。基于原生「切换控制」执行系统级点击，免越狱、不注入，数据全本地存储。

版本：1.0.0（分发入口 `download.html`）

## 工程结构

```
ios-auto-clicker/
├── project.yml                     # XcodeGen 工程定义（iOS 15+ / SwiftUI）
├── download.html                   # 一站式分发页（TestFlight/企业直装/.ipa 下载三模式自适应）
├── manifest.plist                  # 企业签名直装描述文件模板（itms-services 用）
├── AutoClicker/
│   ├── App/AutoClickerApp.swift    # 入口 + 安全确认路由
│   ├── Models/Script.swift         # Point / Script / Params / 校验器 / 状态机
│   ├── Stores/ScriptStore.swift    # 持久化 + 运行节拍 + 前后台中断监控
│   ├── Services/
│   │   ├── NotificationService.swift  # 完成/中断本地通知
│   │   └── AppShortcuts.swift         # AppIntents（iOS 16+ 快捷指令）
│   ├── Views/
│   │   ├── SafetyNoticeView.swift  # FR0.1 安全须知 10s 倒计时
│   │   ├── ScriptListView.swift    # 脚本列表 CRUD
│   │   ├── ScriptEditView.swift    # 参数编辑 + §7.1 校验
│   │   ├── CaptureView.swift       # 打点：覆盖层/手动/截图标定
│   │   ├── ConsoleView.swift       # 运行控制台（FR3/FR4）
│   │   └── WizardView.swift        # 五步配置向导（FR0.2）
│   └── Assets.xcassets
└── .github/workflows/build-ipa.yml # CI 自动构建未签名 IPA
```

## 构建 .ipa

前置：macOS + Xcode 15+（CI 已内置）。

```bash
brew install xcodegen        # 或 brew install xcodegen 后跳过手工生成
xcodegen generate            # 生成 AutoClicker.xcodeproj
open AutoClicker.xcodeproj   # 选择 Team 签名后 Archive 导出 .ipa
```

或直接推送 main 分支，GitHub Actions 自动构建并发布未签名 IPA 到 Release。

## 签名与分发

| 方式 | 有效期 | 说明 |
|------|--------|------|
| 个人免费签名 | 7 天 | 需重签，适合自用测试 |
| 开发者签名（$99/年） | 1 年 | 推荐，可长期使用 |
| 企业证书（In-House） | 按证书 | 可网页直装，受苹果管控 |

`download.html` 为**一站式分发页**，自动按优先级切换三种安装通道（修改页面底部 `CONFIG` 即可）：

1. **TestFlight 直装**（最推荐）：填写 `testflightUrl`（如 `https://testflight.apple.com/join/xxxx`），用户点按钮即跳 TestFlight 安装，官方渠道无信任提示。
2. **企业签名直装**：企业签名的 `AutoClicker.ipa` 与 `manifest.plist` 放到 https 服务器，填写 `manifestUrl` 后按钮触发 itms-services 系统安装；首次需在「设置 → 通用 → VPN 与设备管理」信任证书。
3. **.ipa 下载**（兜底）：签名后的 `AutoClicker.ipa` 放到与 `download.html` 同目录（或填 `ipaUrl`），用户下载后用爱思助手/Xcode 安装。

> 重要：iOS 无"点开 .ipa 直接安装"机制；第三方分发（含自动点击器同行）均需一次签名与信任步骤。要完全无信任提示只能走 App Store/TestFlight。manifest.plist 模板已随工程提供。

## 功能覆盖（对照 PRD v2.0）

- FR0 安全须知倒计时 + 五步向导 + 切换控制状态提示
- FR1 三种打点：覆盖层捕捉（相对坐标）/ 手动坐标 / 截图标定（系统照片选择器，零权限）
- FR2 点位上限 20、参数校验（§7.1 步进对齐）、名称 ≤30 字符、保存/复制/删除
- FR3 启动/暂停/停止、AppIntents 快捷指令（16+）、三击引导、前后台 30s 中断自动停止
- FR4 完成/中断本地通知、控制台节拍计数、防呆校验
- NFR iOS 15+、横竖屏相对坐标点位集、本地 JSON 存储（UserDefaults）、最小权限（无网络/无定位）

## 已知边界（PRD §2.2 / §9）

- 真实点击由系统「切换控制」执行，App 内不模拟系统输入（合规前提）
- 不做跨 App 悬浮球、不做锁屏后台点击、不承诺防封号
- 代理模式（iOS 17+，功能更全）需另行维护签名工程，本次交付为原生辅助功能路径
