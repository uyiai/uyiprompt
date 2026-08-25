# uyiprompt

macOS 菜单栏改写 / 翻译工具。选中文字后点右侧「改写」或「翻译」，再点「替换」写回去。

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

1. 打开应用，走完三步引导（选中动作、辅助功能、连接模型）。
2. 设置 → **模型服务**：选 DeepSeek / OpenAI / Kimi / 自定义，粘贴 API Key，点「测试连接」。
3. 在微信、备忘录、编辑器里选中文字，选区右侧点「改写」或「翻译」。
4. 在浮层里点「替换」或「复制」。**⌘⇧U** 打开草稿面板。目标语言在设置 → 通用。

密钥写在 `~/Library/Application Support/uyiprompt/settings.json`（权限 0600），只发往你选的服务商。

## 文档

- [docs/windows-and-modules.md](docs/windows-and-modules.md) — 窗口清单，AppKit / SwiftUI 分工
