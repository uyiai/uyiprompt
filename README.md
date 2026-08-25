# uyiprompt

macOS 菜单栏改写 / 翻译。选中文字后点选区下方的「改写」或「翻译」，再点「替换」写回去。

窗口由 AppKit 托管，界面用 SwiftUI。读选区和粘贴走辅助功能 + 合成 ⌘C / ⌘V。模型走你自己的 OpenAI 兼容 `/v1/chat/completions`。

当前版本 **0.2.1**：https://github.com/uyiai/uyiprompt/releases/tag/v0.2.1

## 要求

- macOS 15+
- 自己的 API Key（DeepSeek / OpenAI / Kimi / 自定义兼容接口）

## 使用

1. 打开应用，走完三步引导（动作条、辅助功能、连接模型）。之后只待在菜单栏。
2. 点菜单栏图标打开设置 → **模型服务**，选供应商、贴 Key、测连接。
3. 在别的软件里选中文字，松开后点「改写」或「翻译」。
4. 浮层里「替换」或「复制」。**⌘⇧U** 打开草稿面板。
5. 界面语言在设置 → 通用（跟随系统 / 中文 / English）。最近结果在设置 → 历史，或菜单栏右键 → 最近。

没读到选区时，浮层会提供「打开面板」，把文字贴进去即可。

## 密钥存在哪

**API Key 在钥匙串里**，服务名 `app.uyiprompt.apikey`，不进 git，也不再写入 JSON。

`~/Library/Application Support/uyiprompt/settings.json` 只保存外观、模型名、地址等非密钥偏好（权限 0600）。`history.json` 是最近 20 条改写/翻译，同样只在本机。

密钥只发往你填的 Base URL。仓库里没有真实 Key（测试里的 `sk-live` 是假数据）。

不要把 `settings.json`、钥匙串导出或 `.env` 提交到 git。本仓库 `.gitignore` 已忽略这些文件名。

## 从源码运行

```bash
open uyiprompt.xcodeproj
```

Xcode Scheme `uyiprompt`，Product → Run 用 Debug。打安装包用 Release：

```bash
xcodebuild -project uyiprompt.xcodeproj -scheme uyiprompt \
  -configuration Release -destination 'platform=macOS,arch=arm64' build
```

首次需要在 **系统设置 → 隐私与安全性 → 辅助功能** 打开 uyiprompt。换过签名或重装后，删掉旧条目再把新的 App 拖进去。
