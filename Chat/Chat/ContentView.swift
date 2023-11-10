import AsyncHTTPClient
import NIO
import OpenAIKit
import SwiftUI

struct ContentView: View {
    @State private var haiku = ""
    @State private var isLoading = false
    @State private var greeting: String = ""
    @State private var currentIndex: Int = 0
    @State private var message: String = ""
    @State private var messages: [MessageBubble] = []
    @State private var showGreeting: Bool = true
    @State private var is_gpt_message = false

    private let greetingText = "不知道叫什么的GPT🤪"

    @Environment(\.colorScheme) var colorScheme

    var apiKey: String {
        ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }

    var organization: String {
        ProcessInfo.processInfo.environment["OPENAI_ORGANIZATION"] ?? ""
    }

    var body: some View {
        VStack {
            if showGreeting {
                VStack {
                    Text(greeting)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(colorScheme == .dark ? Color.black : Color.white)
                        .onAppear {
                            animateGreeting()
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(messages.indices, id: \.self) { index in
                        let message = messages[index]
                        MessageBubble(text: message.text, isMyMessage: message.isMyMessage)
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colorScheme == .dark ? Color.black : Color.white)
                        .frame(height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue, lineWidth: 2)
                        )
                    TextField("Message", text: $message, onCommit: sendMessage)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 20)
                        .onTapGesture {
                            deleteGreetingText()
                        }
                }
                .frame(height: 60)
                .padding(.horizontal, 20)

                Button(action: sendMessage) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 50, height: 50)

                        Image(systemName: "arrow.up")
                            .foregroundColor(.white)
                            .font(.system(size: 20, weight: .bold))
                    }
                }
                .padding(.horizontal, 10)
            }
        }
    }

    private func animateGreeting() {
        guard currentIndex < greetingText.count else {
            //            resetAnimation()
            return
        }

        let nextCharacterIndex = greetingText.index(greetingText.startIndex, offsetBy: currentIndex)
        let nextCharacter = String(greetingText[nextCharacterIndex])

        greeting += nextCharacter
        currentIndex += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            animateGreeting()
        }
    }
    
    private func deleteGreetingText() {
        guard !greetingText.isEmpty else {
            return
        }

        var index = greetingText.index(before: greetingText.endIndex)
        
        let deleteTimer = Timer.scheduledTimer(withTimeInterval: 0.1                                                                                               , repeats: true) { timer in
            greeting.remove(at: index)
            if index != greetingText.startIndex {
                index = greetingText.index(before: index)
            } else {
                timer.invalidate()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            deleteTimer.fire()
        }
    }


    struct MessageBubble: View {
        let text: String
        let isMyMessage: Bool
        
        var body: some View {
            HStack {
                Spacer()
                
                Text(text)
                    .foregroundColor(.white)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(isMyMessage ? Color.blue : Color.gray)
                    .cornerRadius(20)
                    .frame(maxWidth: .infinity, alignment: isMyMessage ? .trailing : .leading)
                    .offset(y: 5) // 调整垂直偏移量
            }
            .padding(.horizontal, isMyMessage ? 20 : 0)
        }
    }


    func generateHaiku(prompt: String) {
        isLoading = true

        let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let httpClient = HTTPClient(eventLoopGroupProvider: .shared(eventLoopGroup))

        let configuration = Configuration(apiKey: apiKey, organization: organization)
        let openAIClient = OpenAIKit.Client(httpClient: httpClient, configuration: configuration)

        Task {
            do {
                let completion = try await openAIClient.completions.create(
                    model: Model.GPT3.davinciInstructBeta,
                    prompts: [prompt]
                )

                if let choice = completion.choices.first {
                    DispatchQueue.main.async {
                        self.haiku = choice.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.isLoading = false
                        let newMessage = MessageBubble(text: self.haiku, isMyMessage: false)
                        self.messages.append(newMessage)
                    }
                }
            } catch {
                print("Error generating haiku: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }

            try? httpClient.syncShutdown()
            try? eventLoopGroup.syncShutdownGracefully()
        }
    }

    private func sendMessage() {
        showGreeting = false
        is_gpt_message = !is_gpt_message
        messages.append(MessageBubble(text: message, isMyMessage: true))
        generateHaiku(prompt: message)
        message = ""
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

