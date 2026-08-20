import SwiftUI

struct StoryListView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var progress: [String: StoryProgress] = [:]
    @State private var showParentSettings = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [LibraryPalette.background, LibraryPalette.cyan.opacity(0.12), LibraryPalette.purple.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        welcomeHeader

                        Text("今天的故事")
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(LibraryPalette.ink)

                        ForEach(environment.catalog.stories) { story in
                            NavigationLink {
                                StorySessionView(viewModel: environment.makeSession(for: story))
                            } label: {
                                StoryCard(story: story, progress: progress[story.id])
                            }
                            .buttonStyle(.plain)
                        }

                        privacyNote
                    }
                    .padding(20)
                }
            }
            .navigationTitle("故事屋")
            .tint(LibraryPalette.blue)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("家长", systemImage: "person.badge.shield.checkmark") {
                        showParentSettings = true
                    }
                }
            }
            .sheet(isPresented: $showParentSettings) {
                ParentSettingsView()
                    .environmentObject(environment)
            }
            .onAppear(perform: refreshProgress)
        }
    }

    private var welcomeHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [LibraryPalette.cyan.opacity(0.15), LibraryPalette.purple.opacity(0.09)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text("🎂")
                    .font(.system(size: 42))
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text("你好，小小故事家！")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(LibraryPalette.ink)
                Text("听故事、找线索、用中文回答。")
                    .foregroundStyle(LibraryPalette.muted)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LibraryPalette.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(LibraryPalette.border, lineWidth: 1)
        }
        .shadow(color: LibraryPalette.blue.opacity(0.045), radius: 18, y: 7)
    }

    private var privacyNote: some View {
        Label("回答不会保存在云端。离开故事后，文字记录会消失。", systemImage: "lock.shield.fill")
            .font(.footnote)
            .foregroundStyle(LibraryPalette.muted)
            .symbolRenderingMode(.hierarchical)
            .tint(LibraryPalette.blue)
            .padding(.horizontal, 8)
    }

    private func refreshProgress() {
        progress = Dictionary(uniqueKeysWithValues: environment.catalog.stories.map {
            ($0.id, environment.progressStore.progress(for: $0.id))
        })
    }
}

private struct StoryCard: View {
    let story: StoryLesson
    let progress: StoryProgress?

    private var completedCount: Int { progress?.completedCheckpointIDs.count ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [LibraryPalette.cyan.opacity(0.14), LibraryPalette.blue.opacity(0.08), LibraryPalette.purple.opacity(0.09)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(story.coverEmoji).font(.system(size: 52))
                }
                .frame(width: 98, height: 98)

                VStack(alignment: .leading, spacing: 7) {
                    Text(story.title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(LibraryPalette.ink)
                    Text(story.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(LibraryPalette.muted)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        Label("\(story.estimatedMinutes) 分钟", systemImage: "clock")
                        Text(story.difficulty.displayName)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LibraryPalette.blue)
                }
            }

            ProgressView(value: Double(completedCount), total: Double(story.beats.count))
                .tint(LibraryPalette.blue)

            HStack {
                Text(completedCount == 0 ? "开始故事" : completedCount == story.beats.count ? "再听一次" : "继续故事")
                    .font(.headline)
                    .foregroundStyle(LibraryPalette.ink)
                Spacer()
                Text("\(completedCount)/\(story.beats.count)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(LibraryPalette.muted)
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(LibraryPalette.blue)
            }
        }
        .padding(20)
        .background(LibraryPalette.surface, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(LibraryPalette.border, lineWidth: 1)
        }
        .shadow(color: LibraryPalette.blue.opacity(0.05), radius: 18, y: 7)
    }
}

private struct ParentSettingsView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("数据") {
                    Label("学习进度仅存储在这台设备", systemImage: "iphone")
                    Label("声音和回答文字不会被保存", systemImage: "waveform.slash")
                }
                Section {
                    Button("撤销同意并返回确认页面", role: .destructive) {
                        environment.consentStore.revoke()
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(LibraryPalette.background)
            .navigationTitle("家长设置")
            .tint(LibraryPalette.blue)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private enum LibraryPalette {
    static let background = Color(red: 0.98, green: 0.995, blue: 0.92)
    static let surface = Color(red: 1.00, green: 1.00, blue: 0.98)
    static let ink = Color(red: 0.14, green: 0.20, blue: 0.09)
    static let muted = Color(red: 0.35, green: 0.41, blue: 0.27)
    static let border = Color(red: 0.84, green: 0.90, blue: 0.64)
    static let purple = Color(red: 0.98, green: 0.82, blue: 0.24)
    static let blue = Color(red: 0.24, green: 0.50, blue: 0.12)
    static let cyan = Color(red: 0.74, green: 0.90, blue: 0.28)
}
