import SwiftUI
import Speech
import AVFoundation

struct AddTaskSheet: View {
    // Колбэк при успешном добавлении с приоритетом
    var onAdd: (String, Priority) -> Void
    @State private var title = ""
    @State private var selectedPriority: Priority = .none
    @FocusState private var isFocused: Bool
    @State private var showingPriorityPopover = false
    // Состояния для записи голоса
    @State private var isRecording = false
    @State private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ru-RU"))
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                TextField("Что бы вы хотели сделать?", text: $title)
                    .focused($isFocused)
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                    .padding(.horizontal)

                HStack(spacing: 24) {
                    Image(systemName: "calendar")
                    Image(systemName: "clock")
                    // Иконка флажка для выбора приоритета
                    Button {
                        showingPriorityPopover = true
                    } label: {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(flagColor(for: selectedPriority))
                    }
                    .popover(isPresented: $showingPriorityPopover, attachmentAnchor: .point(.bottom), arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Priority.allCases, id: \.self) { level in
                                Button(action: {
                                    selectedPriority = level
                                    showingPriorityPopover = false
                                }) {
                                    HStack {
                                        Image(systemName: "flag.fill")
                                            .foregroundStyle(flagColor(for: level))
                                        Text(label(for: level))
                                            .foregroundStyle(.black)
                                            .font(.headline)
                                        Spacer()
                                        if level == selectedPriority {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.black)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                if level != Priority.allCases.last {
                                    Divider()
                                }
                            }
                        }
                        .frame(width: 250)
                        .padding(.vertical, 8)
                        .background(Color(.systemBackground))
                        .presentationCompactAdaptation(.popover)
                    }
                    Image(systemName: "tag")
                    // Кнопка для записи голоса
                    Button {
                        if isRecording {
                            stopRecording()
                        } else {
                            startRecording()
                        }
                    } label: {
                        Image(systemName: isRecording ? "mic.fill" : "mic")
                            .foregroundStyle(isRecording ? .red : .primary)
                    }
                    Spacer()
                    Button("Добавить") {
                        onAdd(title, selectedPriority)
                    }
                    .disabled(title.isEmpty)
                }
                .padding(.horizontal)
                .font(.system(size: 20))

                Spacer()
            }
            .padding(.top, 12)
        }
        .onAppear {
            // При появлении сразу открываем клавиатуру
            isFocused = true
            // Запрашиваем разрешения
            requestSpeechAuthorization()
            requestMicrophoneAuthorization()
        }
    }

    // MARK: - Speech Recognition Methods

    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus != .authorized {
                    print("Speech recognition not authorized")
                }
            }
        }
    }

    private func requestMicrophoneAuthorization() {
        Task {
            let granted = await AVAudioApplication.requestRecordPermission()
            if !granted { print("Доступ к микрофону не получен") }
        }
    }

    private func startRecording() {
        // Проверяем доступность распознавания речи
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            print("Speech recognition not available")
            return
        }

        // Создаём запрос на распознавание
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true

        // Настраиваем аудиосессию
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }

        // Настраиваем входной узел
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Начинаем запись
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
            return
        }

        // Начинаем распознавание
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.title = result.bestTranscription.formattedString
                }
            }

            if let error = error {
                print("Recognition error: \(error)")
                self.stopRecording()
            }
        }

        isRecording = true
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
    }

    // MARK: - Helper Methods

    private func flagColor(for priority: Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .yellow
        case .low: return .blue
        case .none: return .gray
        }
    }

    private func label(for priority: Priority) -> String {
        switch priority {
        case .high: return "Высокий"
        case .medium: return "Средний"
        case .low: return "Низкий"
        case .none: return "Без приоритета"
        }
    }
}
