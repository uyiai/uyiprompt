# uyiprompt

macOS 菜单栏改写工具。选中文字后按 ⌘⇧E，改完点「替换原文」写回去。

窗口由 AppKit 托管，界面用 SwiftUI 绘制。读选区和粘贴走辅助功能 + 合成 ⌘C / ⌘V。模型走 OpenAI 兼容的 `/v1/chat/completions`，密钥只存在本机。

## 要求

- macOS 15+
- Xcode（Scheme：`uyiprompt`）

## 打开

```bash
open uyiprompt.xcodeproj
```

请用 **Release** 运行（Product → Run，或下面的命令）。Xcode 27 的 Debug 包是空壳，点开会立刻退出。

```bash
xcodebuild -project uyiprompt.xcodeproj -scheme uyiprompt \
  -configuration Release -destination 'platform=macOS,arch=arm64' build
```

## 使用

1. 打开应用，走完三步引导（快捷键、辅助功能、连接模型）。
2. 设置 → **模型服务**：选 DeepSeek / OpenAI / Kimi / 自定义，粘贴 API Key，点「测试连接」。
3. 在微信、浏览器、编辑器里选中文字，按 **⌘⇧E**。
4. 在浮层里点「替换原文」或「复制」。**⌘⇧U** 开关草稿面板。

密钥写在 `~/Library/Application Support/uyiprompt/settings.json`（权限 0600），只发往你选的服务商。

## 文档

- [docs/windows-and-modules.md](docs/windows-and-modules.md) — 窗口清单，AppKit / SwiftUI 分工
