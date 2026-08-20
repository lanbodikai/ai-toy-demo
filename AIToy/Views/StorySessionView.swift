import SwiftUI

struct StorySessionView: View {
    @StateObject private var viewModel: LessonSessionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var hasJoinedCall = false
    @State private var pressingTalk = false
    @State private var showStoryText = false
    @State private var showEnglishSubtitles = false

    init(viewModel: LessonSessionViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [CallPalette.background, CallPalette.cyan.opacity(0.11), CallPalette.purple.opacity(0.07)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            if viewModel.phase == .completed {
                completionView
            } else if hasJoinedCall {
                liveCallView
            } else {
                callLobbyView
            }
        }
        .navigationTitle(hasJoinedCall ? "故事通话" : viewModel.story.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.light, for: .navigationBar)
        .toolbarBackground(CallPalette.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("查看完整故事", systemImage: "doc.text") {
                        showStoryText = true
                    }
                    Toggle("英文字幕", systemImage: "captions.bubble", isOn: $showEnglishSubtitles)
                    if hasJoinedCall {
                        Button("重听这一段", systemImage: "gobackward") {
                            Task { await viewModel.playCurrentScene() }
                        }
                        Button("重听问题", systemImage: "questionmark.bubble") {
                            Task { await viewModel.askQuestion() }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(CallPalette.ink)
                }
                .accessibilityLabel("更多选项")
            }
        }
        .sheet(isPresented: $showStoryText) {
            StoryTextSheet(story: viewModel.story)
        }
        .onDisappear { viewModel.stop() }
    }

    private var callLobbyView: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("中文故事伙伴")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .tracking(1.4)
                            .foregroundStyle(CallPalette.blue)
                        Text(viewModel.isReturningLearner ? "欢迎回来！" : "准备和啾啾说话吗？")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(CallPalette.ink)
                        Text(
                            viewModel.isReturningLearner
                                ? "准备好再听《\(viewModel.story.title)》了吗？"
                                : viewModel.story.subtitle
                        )
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(CallPalette.muted)
                    }
                    .padding(.top, 34)

                    Spacer(minLength: 30)

                    ConversationOrb(phase: .preparing, size: min(proxy.size.width * 0.58, 238))
                        .accessibilityLabel("啾啾的语音光环")

                    Spacer(minLength: 34)

                    VStack(spacing: 14) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.35)) {
                                hasJoinedCall = true
                            }
                            Task { await viewModel.start() }
                        } label: {
                            Label("加入故事通话", systemImage: "phone.fill")
                                .font(.headline)
                                .foregroundStyle(CallPalette.ink)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    LinearGradient(
                                        colors: [CallPalette.cyan, CallPalette.blue, CallPalette.purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    in: Capsule()
                                )
                                .shadow(color: CallPalette.blue.opacity(0.14), radius: 22, y: 8)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("连接语音服务并开始播放故事")

                        Button {
                            showStoryText = true
                        } label: {
                            Label("先看看完整故事", systemImage: "doc.text")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(CallPalette.blue)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 26)
                }
                .frame(minHeight: proxy.size.height)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var liveCallView: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                callProgressHeader
                    .padding(.horizontal, 22)
                    .padding(.top, 12)

                Spacer(minLength: 18)

                ConversationOrb(
                    phase: viewModel.phase,
                    size: viewModel.warmupStep == .finished
                        ? min(proxy.size.width * 0.60, 246)
                        : min(proxy.size.width * 0.50, 204)
                )
                .accessibilityLabel(phaseTitle)

                VStack(spacing: 9) {
                    Text(phaseTitle)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .foregroundStyle(CallPalette.ink)
                        .multilineTextAlignment(.center)

                    Text(viewModel.feedback)
                        .font(.subheadline)
                        .foregroundStyle(CallPalette.muted)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !viewModel.transcriptPreview.isEmpty {
                        Text("我听到：\(viewModel.transcriptPreview)")
                            .font(.caption)
                            .foregroundStyle(CallPalette.blue)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)

                if viewModel.warmupStep == .mood {
                    moodChoiceCard
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                } else if viewModel.warmupStep == .ready {
                    readyToStartCard
                        .padding(.horizontal, 22)
                        .padding(.top, 18)
                }

                if shouldShowQuestion {
                    questionPill
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                } else if showEnglishSubtitles, viewModel.phase == .narrating {
                    englishNarrationCard
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                }

                if viewModel.phase == .audioProblem || viewModel.phase == .serviceUnavailable {
                    VStack(spacing: 8) {
                        if let error = viewModel.serviceError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(CallPalette.orange)
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                        }
                        Button("重新连接", systemImage: "arrow.clockwise") {
                            Task { await viewModel.recoverFromAudioProblem() }
                        }
                        .buttonStyle(.bordered)
                        .tint(CallPalette.blue)
                    }
                    .padding(.top, 12)
                }

                Spacer(minLength: 18)

                callControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, 18))
            }
        }
    }

    private var callProgressHeader: some View {
        VStack(spacing: 10) {
            HStack {
                Label("啾啾", systemImage: "sparkles")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CallPalette.ink.opacity(0.82))
                Spacer()
                Label(
                    viewModel.voiceConnected ? "语音已连接" : "语音未连接",
                    systemImage: viewModel.voiceConnected ? "waveform.circle.fill" : "waveform.circle"
                )
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(viewModel.voiceConnected ? CallPalette.teal : CallPalette.orange)
            }
            ProgressView(value: viewModel.progressFraction)
                .tint(CallPalette.blue)
                .background(CallPalette.border)
        }
    }

    private var questionPill: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "quote.bubble.fill")
                .foregroundStyle(CallPalette.blue)
            VStack(alignment: .leading, spacing: 5) {
                Text(viewModel.currentCheckpoint.question)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CallPalette.ink.opacity(0.88))
                    .multilineTextAlignment(.leading)
                if showEnglishSubtitles {
                    Text(viewModel.currentCheckpoint.englishQuestion)
                        .font(.caption)
                        .foregroundStyle(CallPalette.muted)
                        .multilineTextAlignment(.leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .background(CallPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CallPalette.border, lineWidth: 1)
        }
        .shadow(color: CallPalette.blue.opacity(0.035), radius: 16, y: 7)
    }

    private var englishNarrationCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "captions.bubble.fill")
                .foregroundStyle(CallPalette.blue)
            Text(viewModel.englishSubtitleText)
                .font(.caption)
                .foregroundStyle(CallPalette.muted)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: viewModel.englishSubtitleText)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(CallPalette.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CallPalette.border, lineWidth: 1)
        }
    }

    private var moodChoiceCard: some View {
        VStack(spacing: 14) {
            Text("你今天心情怎么样？")
                .font(.headline)
                .foregroundStyle(CallPalette.ink)

            HStack(spacing: 8) {
                ForEach(LessonSessionViewModel.Mood.allCases) { mood in
                    Button(mood.label) {
                        Task { await viewModel.respondToMood(mood) }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CallPalette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 11)
                    .frame(maxWidth: .infinity)
                    .background(CallPalette.background, in: Capsule())
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(CallPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CallPalette.border, lineWidth: 1)
        }
        .shadow(color: CallPalette.blue.opacity(0.04), radius: 18, y: 7)
    }

    private var readyToStartCard: some View {
        VStack(spacing: 13) {
            Text(viewModel.readyPrompt)
                .font(.headline)
                .foregroundStyle(CallPalette.ink)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.confirmStoryStart() }
            } label: {
                Label(viewModel.readyButtonTitle, systemImage: "play.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(CallPalette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [CallPalette.blue, CallPalette.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(CallPalette.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(CallPalette.border, lineWidth: 1)
        }
        .shadow(color: CallPalette.blue.opacity(0.04), radius: 18, y: 7)
    }

    private var callControls: some View {
        HStack(alignment: .center) {
            callControlButton(
                icon: "doc.text",
                label: "故事",
                tint: CallPalette.blue
            ) {
                showStoryText = true
            }

            Spacer()

            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(viewModel.isListening ? Color.red : CallPalette.blue)
                        .frame(width: 82, height: 82)
                        .shadow(
                            color: (viewModel.isListening ? Color.red : CallPalette.blue).opacity(0.16),
                            radius: pressingTalk ? 24 : 12
                        )
                        .scaleEffect(pressingTalk ? 1.08 : 1)
                    Image(systemName: viewModel.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 29, weight: .bold))
                        .foregroundStyle(viewModel.isListening ? Color.white : CallPalette.ink)
                }
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !pressingTalk, viewModel.canTalk else { return }
                            pressingTalk = true
                            Task { await viewModel.beginListening() }
                        }
                        .onEnded { _ in
                            guard pressingTalk else { return }
                            pressingTalk = false
                            Task { await viewModel.endListening() }
                        }
                )
                .opacity(viewModel.canTalk || viewModel.isListening ? 1 : 0.42)
                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: pressingTalk)
                .accessibilityLabel("按住说话")
                .accessibilityHint("按住回答问题，说完后松开")

                Text(viewModel.isListening ? "松开发送" : "按住说话")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CallPalette.muted)
            }

            Spacer()

            callControlButton(
                icon: "phone.down.fill",
                label: "结束",
                tint: .red
            ) {
                viewModel.stop()
                dismiss()
            }
        }
    }

    private func callControlButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 54, height: 54)
                    .background(CallPalette.control, in: Circle())
                    .overlay {
                        Circle().stroke(CallPalette.border, lineWidth: 1)
                    }
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CallPalette.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private var completionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                ConversationOrb(phase: .completed, size: 180)
                    .overlay {
                        Image(systemName: "checkmark")
                            .font(.system(size: 48, weight: .bold))
                            .foregroundStyle(CallPalette.ink)
                    }
                    .padding(.top, 34)

                Text("故事通话完成！")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(CallPalette.ink)

                if viewModel.practiceVocabulary.isEmpty {
                    Text("今天没有需要特别复习的词语。下次再来发现新的故事细节吧！")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(CallPalette.muted)
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        Label("今天练一练", systemImage: "text.book.closed.fill")
                            .font(.title3.bold())
                            .foregroundStyle(CallPalette.ink)

                        ForEach(viewModel.practiceVocabulary) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.chinese)
                                        .font(.headline)
                                        .foregroundStyle(CallPalette.ink)
                                    Text(item.pinyin)
                                        .font(.caption)
                                        .foregroundStyle(CallPalette.blue)
                                }
                                Spacer()
                                Text(item.english)
                                    .font(.subheadline)
                                    .foregroundStyle(CallPalette.muted)
                                    .multilineTextAlignment(.trailing)
                            }
                            if item.id != viewModel.practiceVocabulary.last?.id {
                                Divider().overlay(CallPalette.border)
                            }
                        }
                    }
                    .padding(20)
                    .background(CallPalette.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(CallPalette.border, lineWidth: 1)
                    }
                }

                Button("再听一次", systemImage: "arrow.counterclockwise") {
                    Task { await viewModel.resetStory() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(CallPalette.blue)

                Button("回到故事屋") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .tint(CallPalette.blue)
            }
            .padding(28)
        }
    }

    private var shouldShowQuestion: Bool {
        switch viewModel.phase {
        case .asking, .waitingForAnswer, .listening, .evaluating, .givingFeedback, .audioProblem, .serviceUnavailable:
            true
        default:
            false
        }
    }

    private var phaseTitle: String {
        switch viewModel.phase {
        case .preparing: "正在连接啾啾"
        case .welcome: "先认识一下吧"
        case .readyToStart: "一起去听故事"
        case .narrating: "啾啾正在讲故事"
        case .asking: "听听这个问题"
        case .waitingForAnswer: "轮到你说啦"
        case .listening: "我在认真听"
        case .evaluating: "正在理解你的回答"
        case .givingFeedback: "啾啾正在回应"
        case .audioProblem: "没有听清楚"
        case .serviceUnavailable: "语音连接中断"
        case .completed: "故事完成"
        }
    }
}

private struct ConversationOrb: View {
    let phase: LessonSessionViewModel.Phase
    let size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rotating = false
    @State private var breathing = false

    private var colors: [Color] {
        switch phase {
        case .listening:
            [CallPalette.cyan, .mint, CallPalette.blue, CallPalette.cyan]
        case .audioProblem, .serviceUnavailable:
            [.orange, .red, CallPalette.purple, .orange]
        case .completed:
            [.mint, CallPalette.cyan, CallPalette.blue, .mint]
        default:
            [CallPalette.purple, CallPalette.blue, CallPalette.cyan, CallPalette.purple]
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [colors[1].opacity(0.09), CallPalette.background.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.52
                    )
                )

            Circle()
                .stroke(
                    AngularGradient(colors: colors, center: .center),
                    style: StrokeStyle(lineWidth: 9, lineCap: .round)
                )
                .blur(radius: 15)
                .opacity(0.32)

            Circle()
                .stroke(
                    AngularGradient(colors: colors, center: .center),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                )
                .opacity(0.84)
                .rotationEffect(.degrees(rotating ? 360 : 0))

            Circle()
                .trim(from: 0.05, to: 0.32)
                .stroke(.white.opacity(0.88), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .blur(radius: 1.2)
                .rotationEffect(.degrees(rotating ? 430 : 70))

            Circle()
                .fill(colors[0].opacity(0.055))
                .frame(width: size * 0.58, height: size * 0.58)
                .blur(radius: 26)
                .offset(x: breathing ? size * 0.08 : -size * 0.06, y: breathing ? -size * 0.04 : size * 0.07)
        }
        .frame(width: size, height: size)
        .scaleEffect(breathing ? 1.035 : 0.985)
        .shadow(color: colors[1].opacity(0.11), radius: 30)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                rotating = true
            }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}

private struct StoryTextSheet: View {
    let story: StoryLesson
    @Environment(\.dismiss) private var dismiss
    @State private var language: StoryTextLanguage = .chinese

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [CallPalette.background, CallPalette.cyan.opacity(0.12), CallPalette.purple.opacity(0.07)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 7) {
                            HStack(spacing: 14) {
                                Text(story.coverEmoji)
                                    .font(.system(size: 48))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(story.title)
                                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                                        .foregroundStyle(CallPalette.ink)
                                    Text(story.subtitle)
                                        .foregroundStyle(CallPalette.muted)
                                }
                            }

                            Picker("故事语言", selection: $language) {
                                ForEach(StoryTextLanguage.allCases) { option in
                                    Text(option.label).tag(option)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.top, 14)
                        }

                        ForEach(Array(story.beats.enumerated()), id: \.element.id) { index, beat in
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 12) {
                                    ZStack {
                                        Circle()
                                            .fill(CallPalette.cyan.opacity(0.09))
                                        Text(beat.illustrationEmoji)
                                            .font(.largeTitle)
                                    }
                                    .frame(width: 58, height: 58)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("第 \(index + 1) 段")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(CallPalette.blue)
                                        Text(beat.title)
                                            .font(.title3.bold())
                                            .foregroundStyle(CallPalette.ink)
                                    }
                                }

                                if language != .english {
                                    Text(beat.narration)
                                        .font(.body)
                                        .foregroundStyle(CallPalette.ink)
                                        .lineSpacing(6)
                                }

                                if language != .chinese {
                                    if language == .bilingual {
                                        Divider().overlay(CallPalette.border)
                                    }
                                    Text(beat.englishNarration)
                                        .font(.body)
                                        .foregroundStyle(language == .english ? CallPalette.ink : CallPalette.muted)
                                        .lineSpacing(5)
                                }
                            }
                            .padding(18)
                            .background(CallPalette.surface, in: RoundedRectangle(cornerRadius: 22))
                            .overlay {
                                RoundedRectangle(cornerRadius: 22)
                                    .stroke(CallPalette.border, lineWidth: 1)
                            }
                            .shadow(color: CallPalette.blue.opacity(0.04), radius: 16, y: 7)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("完整故事")
            .navigationBarTitleDisplayMode(.inline)
            .tint(CallPalette.blue)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

private enum StoryTextLanguage: String, CaseIterable, Identifiable {
    case chinese
    case english
    case bilingual

    var id: String { rawValue }
    var label: String {
        switch self {
        case .chinese: "中文"
        case .english: "English"
        case .bilingual: "双语"
        }
    }
}

private enum CallPalette {
    static let background = Color(red: 0.98, green: 0.995, blue: 0.92)
    static let surface = Color(red: 1.00, green: 1.00, blue: 0.98)
    static let control = Color(red: 0.96, green: 0.985, blue: 0.88)
    static let ink = Color(red: 0.14, green: 0.20, blue: 0.09)
    static let muted = Color(red: 0.35, green: 0.41, blue: 0.27)
    static let border = Color(red: 0.84, green: 0.90, blue: 0.64)
    static let purple = Color(red: 0.98, green: 0.82, blue: 0.24)
    static let blue = Color(red: 0.24, green: 0.50, blue: 0.12)
    static let cyan = Color(red: 0.74, green: 0.90, blue: 0.28)
    static let teal = Color(red: 0.20, green: 0.58, blue: 0.31)
    static let orange = Color(red: 0.82, green: 0.43, blue: 0.08)
}
