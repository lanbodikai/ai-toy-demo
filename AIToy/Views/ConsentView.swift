import SwiftUI

struct ConsentView: View {
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [ConsentPalette.background, ConsentPalette.cyan.opacity(0.15), ConsentPalette.purple.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [ConsentPalette.cyan.opacity(0.16), ConsentPalette.purple.opacity(0.10)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(Circle().stroke(.white.opacity(0.9), lineWidth: 3))
                                .shadow(color: ConsentPalette.blue.opacity(0.16), radius: 24, y: 10)

                            Text("🎂")
                                .font(.system(size: 54))
                                .accessibilityHidden(true)
                        }
                        .frame(width: 96, height: 96)

                        Text("AI Toy")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .foregroundStyle(ConsentPalette.ink)
                        Text("中文故事伙伴")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(ConsentPalette.muted)
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Label("家长或监护人确认", systemImage: "person.2.badge.shield.checkmark")
                            .font(.title2.bold())
                            .foregroundStyle(ConsentPalette.ink)
                            .symbolRenderingMode(.hierarchical)
                            .tint(ConsentPalette.blue)

                        Text("This supervised pilot uses AI speech transcription and may occasionally misunderstand a child. A parent or guardian must remain nearby during use.")
                            .font(.body)
                            .foregroundStyle(ConsentPalette.muted)

                        DisclosureGroup("隐私与安全说明") {
                            VStack(alignment: .leading, spacing: 10) {
                                bullet("只在按住话筒时采集声音")
                                bullet("不保存原始声音或回答文字")
                                bullet("学习进度只保存在这台 iPhone")
                                bullet("不收集姓名、邮箱或儿童账户")
                                bullet("遇到敏感内容时会暂停并请家长协助")
                            }
                            .padding(.top, 8)
                        }
                        .tint(ConsentPalette.blue)
                        .foregroundStyle(ConsentPalette.ink)

                        Button {
                            environment.consentStore.accept()
                        } label: {
                            Label("同意并开始", systemImage: "arrow.right")
                                .font(.headline)
                                .foregroundStyle(ConsentPalette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(
                                    LinearGradient(
                                        colors: [ConsentPalette.cyan, ConsentPalette.blue, ConsentPalette.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                                .shadow(color: ConsentPalette.blue.opacity(0.12), radius: 16, y: 7)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("同意隐私说明并进入故事列表")
                    }
                    .padding(24)
                    .background(ConsentPalette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(ConsentPalette.border, lineWidth: 1)
                    }
                    .shadow(color: ConsentPalette.blue.opacity(0.055), radius: 24, y: 10)
                }
                .padding(24)
            }
        }
    }

    private func bullet(_ text: String) -> some View {
        Label(text, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(ConsentPalette.muted)
            .symbolRenderingMode(.hierarchical)
            .tint(ConsentPalette.cyan)
    }
}

private enum ConsentPalette {
    static let background = Color(red: 0.98, green: 0.995, blue: 0.92)
    static let surface = Color(red: 1.00, green: 1.00, blue: 0.98)
    static let ink = Color(red: 0.14, green: 0.20, blue: 0.09)
    static let muted = Color(red: 0.35, green: 0.41, blue: 0.27)
    static let border = Color(red: 0.84, green: 0.90, blue: 0.64)
    static let purple = Color(red: 0.98, green: 0.82, blue: 0.24)
    static let blue = Color(red: 0.24, green: 0.50, blue: 0.12)
    static let cyan = Color(red: 0.74, green: 0.90, blue: 0.28)
}
