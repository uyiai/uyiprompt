import AppKit
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var windows: AppWindows
    @EnvironmentObject private var session: AppSession
    @State private var step = 0
    @State private var accessibilityOn = SelectionService.isTrusted

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Capsule()
                        .fill(index <= step ? Color.accentColor : Color.primary.opacity(0.12))
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)

            Group {
                switch step {
                case 0: welcome
                case 1: access
                default: modelStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                if step == 0 {
                    Button("稍后再说") { windows.completeOnboarding() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                } else {
                    Button("上一步") { step = max(0, step - 1) }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(primaryTitle) {
                    if step == 2 {
                        windows.completeOnboarding()
                    } else {
                        step += 1
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
                .controlSize(.large)
            }
            .padding(24)
        }
        .frame(
            minWidth: WindowMetrics.onboardingMin.width,
            minHeight: WindowMetrics.onboardingMin.height
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { accessibilityOn = SelectionService.isTrusted }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            accessibilityOn = SelectionService.isTrusted
        }
    }

    private var primaryTitle: String {
        switch step {
        case 2: session.llm.isReady ? "开始使用" : "先放到菜单栏"
        default: "继续"
        }
    }

    private var welcome: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 8)
            AppMark(size: 64)
            Text("选中文字，改写或翻译")
                .font(.largeTitle.weight(.semibold))
            HStack(spacing: 16) {
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        KeyCap(text: "⌘")
                        KeyCap(text: "⇧")
                        KeyCap(text: "E")
                    }
                    Text("改写")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        KeyCap(text: "⌘")
                        KeyCap(text: "⇧")
                        KeyCap(text: "T")
                    }
                    Text("翻译")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            Text("待在菜单栏。在微信、浏览器、编辑器里选一段话，改完或译完点「替换」写回去。")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 440)
            HStack(spacing: 10) {
                featureChip(symbol: "pencil.and.outline", title: "改写")
                featureChip(symbol: "globe", title: "翻译")
                featureChip(symbol: "arrow.uturn.forward", title: "写回原文")
            }
            .padding(.top, 4)
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 32)
    }

    private func featureChip(symbol: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .foregroundStyle(Color.accentColor)
            Text(title)
                .font(.callout.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.primary.opacity(0.05), in: Capsule())
    }

    private var access: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            IconBadge(symbol: "accessibility", size: 64)
            Text("需要「辅助功能」")
                .font(.largeTitle.weight(.semibold))
            Text("这样才能读到你选中的字，并把改写结果粘贴回去。只在你按快捷键时工作，可以稍后开启。")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 460)
            Text(accessibilityOn ? "已经开启，可以继续" : "还没开启，点下面会跳到系统设置")
                .foregroundStyle(accessibilityOn ? Color.green : Color.secondary)
            if !accessibilityOn {
                Button {
                    SelectionService.requestAccess()
                } label: {
                    Label("打开系统设置", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 32)
    }

    private var modelStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("连接模型")
                    .font(.title.weight(.semibold))
                Text(session.llm.isReady
                     ? "已经连上了，可以直接开始。也可以换成 DeepSeek。"
                     : "推荐 DeepSeek。密钥只存在这台电脑，不会上传到我们这边。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                ModelSetupCard(provider: session.llm.activeProvider, compact: true, showProviderPicker: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppWindows())
        .environmentObject(AppSession())
        .frame(width: 640, height: 620)
}
