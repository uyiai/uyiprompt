import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case chinese
    case english

    var id: String { rawValue }

    enum Resolved: String, Sendable {
        case chinese
        case english
    }

    /// Labels that stay in their own language so the switcher is always findable.
    var pickerTitle: String {
        switch self {
        case .system: L10n.t("language.system")
        case .chinese: "中文"
        case .english: "English"
        }
    }

    var resolved: Resolved {
        switch self {
        case .chinese: return .chinese
        case .english: return .english
        case .system:
            let code = Locale.preferredLanguages.first ?? ""
            return code.hasPrefix("zh") ? .chinese : .english
        }
    }

    var locale: Locale {
        switch resolved {
        case .chinese: Locale(identifier: "zh-Hans")
        case .english: Locale(identifier: "en")
        }
    }
}

enum L10n {
    private final class Box: @unchecked Sendable {
        private let lock = NSLock()
        private var value: AppLanguage.Resolved = .chinese

        var current: AppLanguage.Resolved {
            get {
                lock.lock()
                defer { lock.unlock() }
                return value
            }
            set {
                lock.lock()
                value = newValue
                lock.unlock()
            }
        }
    }

    private static let box = Box()

    static var current: AppLanguage.Resolved {
        get { box.current }
        set { box.current = newValue }
    }

    static func sync(_ language: AppLanguage) {
        current = language.resolved
    }

    static func t(_ key: String) -> String {
        tables[current]?[key] ?? tables[.chinese]?[key] ?? key
    }

    static func format(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }

    private static let tables: [AppLanguage.Resolved: [String: String]] = [
        .chinese: zh,
        .english: en,
    ]

    private static let zh: [String: String] = [
        "language.system": "跟随系统",
        "language.section": "界面语言",
        "language.caption": "立刻切换应用内的中文和英文。",

        "job.enhance": "改写",
        "job.translate": "翻译",
        "job.enhanceSelection": "改写选中文字",
        "job.translateSelection": "翻译选中文字",

        "nav.providers": "模型服务",
        "nav.general": "通用",
        "nav.profiles": "写作风格",
        "nav.appDefaults": "按应用",
        "nav.shortcuts": "快捷键",
        "nav.connected": "已连接",
        "nav.disconnected": "未连接",

        "window.settings": "设置",
        "window.welcome": "欢迎",
        "menu.openPanel": "打开面板",
        "menu.providers": "模型服务",
        "menu.settings": "设置…",
        "menu.onboarding": "使用说明",
        "menu.quit": "退出 uyiprompt",
        "menu.fillKey": "填写 API Key…",
        "menu.enableAccess": "开启辅助功能…",
        "menu.currentProfile": "当前风格：%@",
        "menu.noProfiles": "还没有风格",
        "status.tooltip": "uyiprompt · 选中文字后点「改写」或「翻译」",

        "appearance": "外观",
        "appearance.theme": "主题",
        "appearance.system": "跟随系统",
        "appearance.light": "浅色",
        "appearance.dark": "深色",

        "section.language": "语言",
        "enhance.output": "改写输出",
        "enhance.output.caption": "自动会保持原文语言。",
        "translate.target": "翻译目标",
        "translate.target.caption": "自动：中文译成英语，其它语言译成中文。",
        "section.permissions": "权限",
        "access.title": "辅助功能",
        "access.caption": "读取选中的文字，并把改写或译文写回去。",
        "access.on": "已开启",
        "access.off": "未开启",
        "access.enable": "去开启",
        "section.selection": "选区",
        "selection.actionBar": "选中文字后显示动作条",
        "selection.actionBar.caption": "松开鼠标后，在选区右侧出现「改写 / 翻译」。关掉后只能把文字粘贴到面板里处理。",
        "section.desktop": "桌面",
        "desktop.dock": "在程序坞显示图标",
        "desktop.pin": "面板始终置顶",
        "desktop.popover": "改写后弹出结果窗",
        "desktop.autoRun": "点「改写」后立刻开始",
        "desktop.autoRun.caption": "关掉后，会先弹出窗口让你选风格再改写。",

        "providers.title": "服务商",
        "providers.recommended": "推荐",
        "providers.using": "当前使用",
        "providers.setCurrent": "设为当前",
        "provider.custom": "自定义",
        "provider.deepseek.caption": "推荐 · 国内直连",
        "provider.openai.caption": "官方接口",
        "provider.moonshot.caption": "月之暗面",
        "provider.custom.caption": "OpenAI 兼容",
        "provider.deepseek.help": "打开 DeepSeek 开放平台，创建 API Key 后粘贴过来。",
        "provider.openai.help": "打开 OpenAI 的 API keys 页面，创建密钥后粘贴过来。",
        "provider.moonshot.help": "打开 Moonshot 开放平台，创建 API Key 后粘贴过来。",
        "provider.custom.help": "填接口地址、密钥和模型名。需要兼容 OpenAI 的 /v1/chat/completions。",
        "model.apiKey": "API Key",
        "model.getKey": "去申请密钥",
        "model.keyPlaceholder": "粘贴密钥，只存在这台电脑",
        "model.hideKey": "隐藏密钥",
        "model.showKey": "显示密钥",
        "model.model": "模型",
        "model.modelPlaceholder": "模型名，可手填",
        "model.thinking": "打开思考",
        "model.thinking.caption": "改写一般不用开，更快更省。编程、长文、难改时再开。",
        "model.baseURL": "接口地址",
        "model.baseURL.caption": "使用 OpenAI 兼容的 /v1/chat/completions。",
        "model.advancedURL": "高级：接口地址",
        "model.advancedURL.caption": "一般不用改。",
        "model.test": "测试连接",
        "model.testOK": "连接成功，可以用了",
        "model.missingKey": "还差 API Key",
        "model.missingURL": "还差接口地址",
        "model.missingModel": "还差模型名",
        "model.hasKey": "已填密钥",
        "model.thinkingSuffix": " · 思考",
        "model.fast": "快",
        "model.strong": "强",
        "model.oldName": "旧名",
        "model.cheap": "快省",
        "model.balanced": "均衡",
        "model.best": "最强",
        "model.general": "通用",
        "model.flagship": "旗舰",
        "model.coding": "编程",
        "model.thinkingOld": "思考",

        "profile.grammar": "校对",
        "profile.email": "写邮件",
        "profile.social": "发帖",
        "profile.image-prompt": "生图提示",
        "profile.summarize": "总结",
        "profile.reply": "写回复",
        "profile.professional": "更正式",
        "profile.concise": "更短",
        "profile.explain": "讲人话",
        "profile.code": "编程提示",
        "profiles.title": "风格",
        "profiles.add": "添加风格",
        "profiles.name": "名称",
        "profiles.prompt": "给模型的说明",
        "profiles.use": "使用",
        "profiles.current": "当前",
        "profiles.delete": "删除",
        "profiles.newName": "新风格",
        "profiles.newPrompt": "按用户意图改写这段文字，保留原文语言和关键事实。",
        "appDefaults.follow": "跟随当前风格",
        "appDefaults.profile": "风格",

        "shortcuts.title": "快捷键",
        "shortcuts.chips": "改写 / 翻译",
        "shortcuts.chips.caption": "选中文字后点弹出的按钮",
        "shortcuts.panel": "打开草稿面板",
        "shortcuts.panel.caption": "把文字贴进面板再处理",
        "shortcuts.select": "选中",
        "howto.select": "选中文字",
        "howto.action": "改写或翻译",
        "howto.replace": "点「替换」",
        "shortcuts.help": "在微信、备忘录里选中文字，右侧会出现改写 / 翻译。点按钮后，在浮层里替换或复制。",

        "panel.needKey": "还差 API Key，填上就能改写和翻译",
        "panel.fill": "去填写",
        "panel.needAccess": "辅助功能对不上当前程序，读不了选中文字",
        "panel.pin": "始终置顶",
        "panel.hide": "收起",
        "panel.placeholder.enhance": "粘贴要改的文字",
        "panel.placeholder.translate": "粘贴要译的文字",
        "panel.placeholder.hint": "或在别的软件里选中后点弹出的按钮",
        "panel.goKey": "去填写密钥",
        "panel.copy": "复制",
        "panel.copied": "已复制",
        "panel.working.enhance": "正在改写…",
        "panel.working.translate": "正在翻译…",
        "panel.again.enhance": "再改一次",
        "panel.again.translate": "再译一次",
        "panel.style": "风格",
        "panel.into": "译成",

        "popover.close": "关闭",
        "popover.retry": "再试一次",
        "popover.start.enhance": "开始改写",
        "popover.start.translate": "开始翻译",
        "popover.replace.enhance": "替换原文",
        "popover.replace.translate": "替换为译文",
        "popover.replace.help.enhance": "用改写结果覆盖选中的文字",
        "popover.replace.help.translate": "用译文覆盖选中的文字",
        "popover.loading.enhance": "正在用「%@」改写…",
        "popover.loading.translate": "正在译成%@…",
        "popover.reauth": "去系统设置重新授权",
        "result.changes": "改动",
        "result.edit": "结果",

        "onboard.later": "稍后再说",
        "onboard.back": "上一步",
        "onboard.continue": "继续",
        "onboard.start": "开始使用",
        "onboard.menubar": "先放到菜单栏",
        "onboard.welcome.title": "选中文字，改写或翻译",
        "onboard.welcome.caption": "待在菜单栏。选中一段话，点右侧的按钮即可。",
        "onboard.step1.title": "选中一段文字",
        "onboard.step1.caption": "在微信、浏览器、编辑器里都可以。",
        "onboard.step2.title": "点「改写」或「翻译」",
        "onboard.step2.caption": "松开鼠标后会出现在选区右侧。",
        "onboard.step3.title": "替换回原文",
        "onboard.step3.caption": "也可以只复制，不改原来的内容。",
        "onboard.access.title": "需要「辅助功能」",
        "onboard.access.caption": "这样才能读到你选中的字，并把结果粘贴回去。只在你选中文字时工作，可以稍后开启。",
        "onboard.access.ok": "已经开启，可以继续",
        "onboard.access.need": "还没开启，点下面会跳到系统设置",
        "onboard.access.open": "打开系统设置",
        "onboard.model.title": "连接模型",
        "onboard.model.ready": "已经连上了，可以直接开始。也可以换成 DeepSeek。",
        "onboard.model.need": "推荐 DeepSeek。密钥只存在这台电脑，不会上传到我们这边。",
        "hint.menubar": "已经放到菜单栏",
        "hint.action": "选中文字后点「改写」或「翻译」",

        "lang.autoKeep": "自动（保持原文语言）",
        "lang.autoPair": "自动（中英互译）",
        "lang.auto": "自动",
        "lang.chinese": "中文",
        "lang.english": "英语",
        "lang.japanese": "日语",
        "lang.korean": "韩语",
        "lang.french": "法语",
        "lang.german": "德语",
        "lang.spanish": "西班牙语",
        "lang.portuguese": "葡萄牙语",
        "lang.russian": "俄语",
        "lang.vietnamese": "越南语",
        "lang.hindi": "印地语",
        "lang.czech": "捷克语",
        "lang.simplified": "简体中文",
        "lang.esShort": "西语",
        "lang.ptShort": "葡语",
        "route.zhEn": "中→英",
        "route.jaZh": "日→中",
        "route.koZh": "韩→中",
        "route.toZh": "→中",

        "error.missingKey": "还没有填 API Key。打开设置，选 DeepSeek 后贴上密钥即可。",
        "error.missingURL": "还没有填接口地址。DeepSeek 一般是 https://api.deepseek.com/v1",
        "error.missingModel": "还没有填模型名。DeepSeek 常用 deepseek-v4-flash",
        "error.empty": "先选中一段文字，再点弹出的「改写」或「翻译」",
        "error.tooLong": "文字太长了，最多 5 万字",
        "error.network": "网络不通，请检查网络后重试",
        "error.emptyResponse": "模型没有返回内容，请再试一次",
        "error.http401": "密钥无效或没权限，请到设置里核对 API Key",
        "error.http429": "请求太频繁或额度用完了，稍后再试",
        "error.http404": "接口地址或模型名可能不对，请检查 Base URL 和模型",
        "error.http": "服务返回错误（%d）",
        "error.httpBody": "服务返回错误（%d）：%@",
        "error.access": "辅助功能开关对不上当前这份程序。请到系统设置 → 隐私与安全性 → 辅助功能：删掉旧的 uyiprompt，再把「应用程序」里的 uyiprompt 拖进去打开。",
        "error.switchApp": "请切回原来的软件再试一次",
        "error.pasteAccess": "还写不回去：辅助功能对不上当前程序。可以先点「复制」。",
        "error.pasteFail": "没能粘贴回去",
        "error.selectOther": "请先在别的软件里选中文字",
        "error.noSelection": "没读到选中的文字，再选一次试试",
    ]

    private static let en: [String: String] = [
        "language.system": "System",
        "language.section": "App language",
        "language.caption": "Switch the interface between Chinese and English.",

        "job.enhance": "Rewrite",
        "job.translate": "Translate",
        "job.enhanceSelection": "Rewrite selection",
        "job.translateSelection": "Translate selection",

        "nav.providers": "Models",
        "nav.general": "General",
        "nav.profiles": "Styles",
        "nav.appDefaults": "Per app",
        "nav.shortcuts": "Shortcuts",
        "nav.connected": "Connected",
        "nav.disconnected": "Not connected",

        "window.settings": "Settings",
        "window.welcome": "Welcome",
        "menu.openPanel": "Open Panel",
        "menu.providers": "Models",
        "menu.settings": "Settings…",
        "menu.onboarding": "How to Use",
        "menu.quit": "Quit uyiprompt",
        "menu.fillKey": "Add API Key…",
        "menu.enableAccess": "Enable Accessibility…",
        "menu.currentProfile": "Style: %@",
        "menu.noProfiles": "No styles yet",
        "status.tooltip": "uyiprompt · Select text, then Rewrite or Translate",

        "appearance": "Appearance",
        "appearance.theme": "Theme",
        "appearance.system": "System",
        "appearance.light": "Light",
        "appearance.dark": "Dark",

        "section.language": "Languages",
        "enhance.output": "Rewrite output",
        "enhance.output.caption": "Auto keeps the original language.",
        "translate.target": "Translate into",
        "translate.target.caption": "Auto: Chinese → English, everything else → Chinese.",
        "section.permissions": "Permissions",
        "access.title": "Accessibility",
        "access.caption": "Read selected text and paste the result back.",
        "access.on": "On",
        "access.off": "Off",
        "access.enable": "Enable",
        "section.selection": "Selection",
        "selection.actionBar": "Show action bar after selecting text",
        "selection.actionBar.caption": "After you release the mouse, Rewrite / Translate appear beside the selection. Turn this off to use the panel only.",
        "section.desktop": "Desktop",
        "desktop.dock": "Show in Dock",
        "desktop.pin": "Keep panel on top",
        "desktop.popover": "Show result overlay after rewrite",
        "desktop.autoRun": "Start rewriting immediately",
        "desktop.autoRun.caption": "When off, the overlay opens first so you can pick a style.",

        "providers.title": "Providers",
        "providers.recommended": "Recommended",
        "providers.using": "In use",
        "providers.setCurrent": "Use this",
        "provider.custom": "Custom",
        "provider.deepseek.caption": "Recommended · works in China",
        "provider.openai.caption": "Official API",
        "provider.moonshot.caption": "Moonshot",
        "provider.custom.caption": "OpenAI-compatible",
        "provider.deepseek.help": "Open the DeepSeek console, create an API key, then paste it here.",
        "provider.openai.help": "Open OpenAI API keys, create a key, then paste it here.",
        "provider.moonshot.help": "Open the Moonshot console, create an API key, then paste it here.",
        "provider.custom.help": "Enter the base URL, key, and model. Needs OpenAI-compatible /v1/chat/completions.",
        "model.apiKey": "API Key",
        "model.getKey": "Get a key",
        "model.keyPlaceholder": "Paste your key. It stays on this Mac.",
        "model.hideKey": "Hide key",
        "model.showKey": "Show key",
        "model.model": "Model",
        "model.modelPlaceholder": "Model name",
        "model.thinking": "Thinking",
        "model.thinking.caption": "Leave this off for rewrites — faster and cheaper. Turn on for code or hard edits.",
        "model.baseURL": "Base URL",
        "model.baseURL.caption": "OpenAI-compatible /v1/chat/completions.",
        "model.advancedURL": "Advanced: base URL",
        "model.advancedURL.caption": "Usually leave the default.",
        "model.test": "Test connection",
        "model.testOK": "Connected. You’re ready.",
        "model.missingKey": "API key missing",
        "model.missingURL": "Base URL missing",
        "model.missingModel": "Model missing",
        "model.hasKey": "Key saved",
        "model.thinkingSuffix": " · thinking",
        "model.fast": "Fast",
        "model.strong": "Strong",
        "model.oldName": "legacy",
        "model.cheap": "Fast",
        "model.balanced": "Balanced",
        "model.best": "Best",
        "model.general": "General",
        "model.flagship": "Flagship",
        "model.coding": "Code",
        "model.thinkingOld": "Thinking",

        "profile.grammar": "Proofread",
        "profile.email": "Email",
        "profile.social": "Post",
        "profile.image-prompt": "Image prompt",
        "profile.summarize": "Summarize",
        "profile.reply": "Reply",
        "profile.professional": "More formal",
        "profile.concise": "Shorter",
        "profile.explain": "Plain language",
        "profile.code": "Coding prompt",
        "profiles.title": "Styles",
        "profiles.add": "Add style",
        "profiles.name": "Name",
        "profiles.prompt": "Instructions for the model",
        "profiles.use": "Use",
        "profiles.current": "Current",
        "profiles.delete": "Delete",
        "profiles.newName": "New style",
        "profiles.newPrompt": "Rewrite this text for the user’s intent. Keep the original language and key facts.",
        "appDefaults.follow": "Follow current style",
        "appDefaults.profile": "Style",

        "shortcuts.title": "Shortcuts",
        "shortcuts.chips": "Rewrite / Translate",
        "shortcuts.chips.caption": "Tap the chips after selecting text",
        "shortcuts.panel": "Open draft panel",
        "shortcuts.panel.caption": "Paste text into the panel",
        "shortcuts.select": "Select",
        "howto.select": "Select text",
        "howto.action": "Rewrite or Translate",
        "howto.replace": "Replace",
        "shortcuts.help": "Select text in WeChat, Notes, or a browser. Rewrite / Translate appear on the right. Then replace or copy.",

        "panel.needKey": "Add an API key to rewrite and translate",
        "panel.fill": "Add key",
        "panel.needAccess": "Accessibility doesn’t match this app, so selection can’t be read",
        "panel.pin": "Always on top",
        "panel.hide": "Hide",
        "panel.placeholder.enhance": "Paste text to rewrite",
        "panel.placeholder.translate": "Paste text to translate",
        "panel.placeholder.hint": "Or select text in another app and use the chips",
        "panel.goKey": "Add API key",
        "panel.copy": "Copy",
        "panel.copied": "Copied",
        "panel.working.enhance": "Rewriting…",
        "panel.working.translate": "Translating…",
        "panel.again.enhance": "Rewrite again",
        "panel.again.translate": "Translate again",
        "panel.style": "Style",
        "panel.into": "Into",

        "popover.close": "Close",
        "popover.retry": "Try again",
        "popover.start.enhance": "Rewrite",
        "popover.start.translate": "Translate",
        "popover.replace.enhance": "Replace",
        "popover.replace.translate": "Replace",
        "popover.replace.help.enhance": "Replace the selection with the rewrite",
        "popover.replace.help.translate": "Replace the selection with the translation",
        "popover.loading.enhance": "Rewriting with “%@”…",
        "popover.loading.translate": "Translating into %@…",
        "popover.reauth": "Re-authorize in System Settings",
        "result.changes": "Changes",
        "result.edit": "Result",

        "onboard.later": "Skip for now",
        "onboard.back": "Back",
        "onboard.continue": "Continue",
        "onboard.start": "Get started",
        "onboard.menubar": "Move to the menu bar",
        "onboard.welcome.title": "Select text, then rewrite or translate",
        "onboard.welcome.caption": "Lives in the menu bar. Select a sentence, then tap the chips.",
        "onboard.step1.title": "Select some text",
        "onboard.step1.caption": "Works in WeChat, browsers, and editors.",
        "onboard.step2.title": "Tap Rewrite or Translate",
        "onboard.step2.caption": "The chips appear beside the selection when you release the mouse.",
        "onboard.step3.title": "Replace the original",
        "onboard.step3.caption": "Or just copy, and leave the original alone.",
        "onboard.access.title": "Accessibility is required",
        "onboard.access.caption": "So uyiprompt can read the selection and paste back. It only runs when you select text.",
        "onboard.access.ok": "Already on — continue",
        "onboard.access.need": "Not enabled yet. This opens System Settings.",
        "onboard.access.open": "Open System Settings",
        "onboard.model.title": "Connect a model",
        "onboard.model.ready": "You’re connected. You can start, or switch to DeepSeek.",
        "onboard.model.need": "DeepSeek is recommended. The key stays on this Mac.",
        "hint.menubar": "Now in the menu bar",
        "hint.action": "Select text, then Rewrite or Translate",

        "lang.autoKeep": "Auto (keep original)",
        "lang.autoPair": "Auto (Chinese ↔ English)",
        "lang.auto": "Auto",
        "lang.chinese": "Chinese",
        "lang.english": "English",
        "lang.japanese": "Japanese",
        "lang.korean": "Korean",
        "lang.french": "French",
        "lang.german": "German",
        "lang.spanish": "Spanish",
        "lang.portuguese": "Portuguese",
        "lang.russian": "Russian",
        "lang.vietnamese": "Vietnamese",
        "lang.hindi": "Hindi",
        "lang.czech": "Czech",
        "lang.simplified": "Simplified Chinese",
        "lang.esShort": "Spanish",
        "lang.ptShort": "Portuguese",
        "route.zhEn": "ZH→EN",
        "route.jaZh": "JA→ZH",
        "route.koZh": "KO→ZH",
        "route.toZh": "→ZH",

        "error.missingKey": "No API key yet. Open Settings, pick DeepSeek, and paste your key.",
        "error.missingURL": "No base URL yet. For DeepSeek that’s usually https://api.deepseek.com/v1",
        "error.missingModel": "No model name yet. DeepSeek often uses deepseek-v4-flash",
        "error.empty": "Select some text, then tap Rewrite or Translate",
        "error.tooLong": "That’s too long — 50,000 characters max",
        "error.network": "No network. Check the connection and try again",
        "error.emptyResponse": "The model returned nothing. Try again.",
        "error.http401": "Invalid key or no permission. Check the API key in Settings",
        "error.http429": "Too many requests or quota used up. Try again later",
        "error.http404": "Base URL or model name may be wrong",
        "error.http": "Server error (%d)",
        "error.httpBody": "Server error (%d): %@",
        "error.access": "Accessibility doesn’t match this build. In System Settings → Privacy & Security → Accessibility, remove the old uyiprompt, then add this one from Applications.",
        "error.switchApp": "Switch back to the original app and try again",
        "error.pasteAccess": "Couldn’t paste back: Accessibility doesn’t match. Copy instead.",
        "error.pasteFail": "Couldn’t paste back",
        "error.selectOther": "Select text in another app first",
        "error.noSelection": "Couldn’t read the selection. Select it again.",
    ]
}

extension WritingProfile {
    var localizedName: String {
        guard builtin else { return name }
        let fresh = WritingProfile.builtins.first(where: { $0.id == id })?.name
        let stale = WritingProfile.previousNames[id] ?? []
        if name == fresh || stale.contains(name) {
            return L10n.t("profile.\(id)")
        }
        return name
    }
}
