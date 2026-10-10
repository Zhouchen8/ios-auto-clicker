---
AIGC:
    Label: "1"
    ContentProducer: 001191440300708461136T1XGW3
    ProduceID: b5ed181661e1daf0257708e9c91f0e0d_6d13c19ec4b911f197b3525400248c00
    ReservedCode1: dG0zZukFxHnY+t84oCj2yGZmhQwjPptbNr8piwOwsuEoefmMCYNSUK9z2ATpiCMMeV+KT4+uZ7P21opGCPfHu1AJsMR1+amE60Z2n6Wvkgiev4Sj/gliWJRfiL/4GXpzzPIExsjkPUzQ+cjdI+kgqMfMZKdGUJ5fI4TNxK8uI7kFjvw3KBUQEeRCOLI=
    ContentPropagator: 001191440300708461136T1XGW3
    PropagateID: b5ed181661e1daf0257708e9c91f0e0d_6d13c19ec4b911f197b3525400248c00
    ReservedCode2: dG0zZukFxHnY+t84oCj2yGZmhQwjPptbNr8piwOwsuEoefmMCYNSUK9z2ATpiCMMeV+KT4+uZ7P21opGCPfHu1AJsMR1+amE60Z2n6Wvkgiev4Sj/gliWJRfiL/4GXpzzPIExsjkPUzQ+cjdI+kgqMfMZKdGUJ5fI4TNxK8uI7kFjvw3KBUQEeRCOLI=
---

# GitHub Actions 云构建 IPA 完整操作指南

> 目标：在无 Mac 的环境下，把 `ios-auto-clicker` 工程推到 GitHub，让云端 macOS 自动构建未签名 IPA 并发布到 Release。
> 适用：本地 Windows + Git 已安装（已确认：git 2.56.0，工程已 init 并提交，分支 main）。

---

## 〇、整体流程图

```
本地工程（已 git init + commit）
        │  ① 在 GitHub 建空仓库
        ▼
GitHub 空仓库
        │  ② git remote add + push
        ▼
仓库 main 分支（含 .github/workflows/build-ipa.yml）
        │  ③ push 自动触发 Actions
        ▼
GitHub Actions（macos-14 runner）
  ├── brew install xcodegen
  ├── xcodegen generate
  ├── xcodebuild archive（CODE_SIGNING_ALLOWED=NO）
  └── zip → AutoClicker-unsigned.ipa
        │  ④ 构建完成
        ▼
Release 资产：AutoClicker-unsigned.ipa（未签名）
        │  ⑤ 下载 → 签名 → 分发安装（见文末）
        ▼
可安装的 AutoClicker.ipa
```

---

## 一、前置准备

1. 一个 **GitHub 账号**（免费注册：https://github.com/signup）。
2. 本地 Git 已安装并可用（已确认：`git version 2.56.0.windows.2`）。
3. 工程已初始化并提交（已完成）：
   - 分支名：`main`
   - 最新提交：`d3de2fc iOS auto clicker: XcodeGen project + CI + distribution page`
   - 关键文件已入库：`project.yml`、`AutoClicker/`、`.github/workflows/build-ipa.yml`、`download.html`、`README.md`、`manifest.plist`
   - `.gitignore` 已排除 `*.ipa`、`build/`、`*.xcodeproj/` 等（这些会在 CI 里自动生成，无需入库）

> 注意：`.xcodeproj` 不入库是**正常且正确**的——CI 里会执行 `xcodegen generate` 现场生成。

---

## 二、第 1 步：在 GitHub 创建空仓库

### 方式 A：网页创建（推荐，无需装额外工具）

1. 登录 GitHub，点右上角 **+ → New repository**。
2. 填写：
   - **Repository name**：如 `ios-auto-clicker`（可自定义，建议全小写英文）
   - **Description**（可选）：`iOS auto clicker based on Switch Control`
   - **Public / Private**：见下方"公共还是私有"提醒
   - **初始化选项**：**不要勾选** `Add a README file`、`.gitignore`、`license`（保持完全空仓库，避免与本地已有提交冲突）
3. 点 **Create repository**。
4. 创建后页面会显示仓库地址，形如：
   - HTTPS：`https://github.com/你的用户名/ios-auto-clicker.git`
   - SSH：`git@github.com:你的用户名/ios-auto-clicker.git`

> **公共还是私有（重要）**：
> - **公共仓库**：Actions 构建完全免费，macOS runner 不限额度，最简单。
> - **私有仓库**：Actions 有免费额度（每月 2000 分钟，但 macOS runner 按 10 倍消耗，约等于每月 200 分钟 macOS 构建时间；一次构建约 5-8 分钟，够用但要注意）。
> - 如果代码不想公开，选 Private 即可，仍能正常构建，只是额度有限。

### 方式 B：gh CLI 创建（可选）

本机当前未安装 `gh`，如需用命令行创建，先装：
```powershell
winget install GitHub.cli
gh auth login          # 按提示浏览器登录
gh repo create ios-auto-clicker --public --source . --remote origin --push
```
最后一条命令会直接完成"建仓 + 关联 + 推送"，可跳过第三、四步。

---

## 三、第 2 步：把本地仓库关联到 GitHub

在本地工程目录打开 PowerShell：

```powershell
cd C:\Users\10137\AppData\Roaming\Tencent\Marvis\User\77528A40C833E6F80F9872083CC19191\workspace\conv_0c9407ea8b1c4edd990196fad30a896c\output\ios-auto-clicker
git remote add origin https://github.com/你的用户名/ios-auto-clicker.git
```

> 把 URL 换成你实际创建的仓库地址（HTTPS 或 SSH 均可）。
> 若提示 `remote origin already exists`，先执行 `git remote remove origin` 再 add。

---

## 四、第 3 步：推送代码（触发构建）

```powershell
git push -u origin main
```

- 首次 HTTPS 推送会弹出 GitHub 登录窗口（浏览器），登录一次即可；
- 或在弹出时选择 **Personal Access Token** 方式，令牌需在 GitHub → Settings → Developer settings → Personal access tokens 生成（勾选 `repo` 权限）；
- 推送成功后，GitHub Actions **自动开始构建**（工作流 `Build IPA` 的触发条件就是 `push` 到 `main` 分支）。

> 若推送被拒（`! [rejected]` 提示 non-fast-forward），说明建仓库时勾选了 README 等初始化文件，执行：
> ```powershell
> git pull --rebase origin main
> git push -u origin main
> ```

---

## 五、第 4 步：查看构建进度

1. 打开仓库页面 → 顶部 **Actions** 标签。
2. 能看到 `Build IPA` 工作流的最新运行记录，点击进入。
3. 展开 **build** job，可实时查看日志：
   - `Install XcodeGen` → `Generate Xcode project` → `Build unsigned IPA (archive)` → `Upload unsigned IPA artifact` → `Create GitHub Release`
4. 整个流程约 **5-10 分钟**，出现绿色 ✅ 即构建成功；红色 ❌ 点开对应步骤看失败日志。

**手动触发（可选）**：无需改代码也想重新构建时，进入 Actions → Build IPA → **Run workflow**（因为工作流配置了 `workflow_dispatch`，支持手动触发）。

---

## 六、第 5 步：下载未签名 IPA

1. 仓库页面右侧 **Releases**（或 Actions 成功后自动生成的 Release）。
2. 找到最新 Release，名称形如 `AutoClicker unsigned build`（tag：`build-1`、`build-2`…）。
3. 在 **Assets** 下下载 **`AutoClicker-unsigned.ipa`**。
4. 该文件即未签名 IPA，**不能直接装真机**，需要完成签名（见下一步）。

---

## 七、第 6 步：签名与分发（关键一步）

未签名 ipa 必须签名后才能安装，按你的证书情况选：

| 签名方式 | 有效期 | 成本 | 说明 |
|---|---|---|---|
| 个人免费签名 | 7 天 | 免费 | 适合自测：Windows 上可用**爱思助手 / Sideloadly** 一键签名安装到自己的 iPhone，每 7 天需重签 |
| 开发者签名 | 1 年 | $99/年 | 长期使用：需在 Mac/CI 里用证书签名（`xcodebuild -allowProvisioningUpdates` 或 Xcode Archive） |
| 企业证书签名 | 按证书 | $299/年 | 可网页直装：签名后用 `manifest.plist` + itms-services 分发，即 download.html 的模式② |

**Windows 上的最快路径（个人免费签名）**：
1. 下载 `AutoClicker-unsigned.ipa`；
2. 用**爱思助手**（Windows）连接 iPhone → 应用游戏 → 导入安装包 → 选择该 ipa；
3. 按提示登录你的 Apple ID（免费），爱思助手会自动完成签名安装；
4. 首次打开需在 iPhone「设置 → 通用 → VPN 与设备管理」信任开发者。

**签名完成后的分发**：
- 把签名后的 ipa 命名为 `AutoClicker.ipa`，放到 download.html 同目录（或填 `ipaUrl`）→ 走模式③下载分发；
- 或企业签名后填 `manifestUrl` → 走模式②直装；
- 或开发者账号上 TestFlight → 填 `testflightUrl` → 走模式①直装（推荐，无信任提示）。

---

## 八、常见问题排查

| 现象 | 原因与处理 |
|---|---|
| Actions 显示 ❌ 且日志在 xcodebuild 报错 | 点开日志看具体错误；多为工程配置问题，把错误信息发回 Marvis 协助 |
| push 被拒 | 仓库非空（建仓时勾了 README），按第四节 `pull --rebase` 处理 |
| 登录弹窗反复失败 | 用 PAT 令牌方式；确保勾选 `repo` scope |
| Actions 不触发 | 确认推送到了 `main` 分支；或到 Actions 页手动 Run workflow |
| 构建成功但 Release 里没有 ipa | 等待 1-2 分钟刷新；tag 为 `build-*` 的 Release 即构建产物 |
| ipa 装上后打不开 / 提示未受信任 | 未签名或免费签名过期；重新签名，并在「设置 → VPN 与设备管理」信任 |
| 免费签名 7 天过期 | 重新用爱思助手/Sideloadly 签名安装，这是免费方案固有限制 |

---

## 九、验证清单（做完后自查）

- [ ] GitHub 仓库已创建（Public 或 Private）
- [ ] `git remote -v` 显示 origin 指向你的仓库
- [ ] `git push -u origin main` 成功
- [ ] Actions 页出现 `Build IPA` 运行记录且全绿 ✅
- [ ] Releases 页出现 `build-1`，Assets 含 `AutoClicker-unsigned.ipa`
- [ ] 签名后安装到 iPhone 成功，首次信任开发者后可正常打开
*（内容由AI生成，仅供参考）*
