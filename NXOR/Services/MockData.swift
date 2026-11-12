import Foundation

enum MockData {
    static func load<T: Decodable>(_ name: String, as type: T.Type = T.self) -> T? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static let account = Account(
        name: "Demo User",
        email: "demo@nxor.ai",
        planName: "Power User",
        planSlug: "expert",
        available: 4800,
        reserved: 0,
        monthlyGrant: 34400
    )

    static let projects: [Project] = [
        Project(id: "p-default", name: "My work", isDefault: true),
        Project(id: "p-grain", name: "Grain", isDefault: false),
        Project(id: "p-cars", name: "Cars", isDefault: false),
    ]

    static let chats: [ChatThread] = [
        ChatThread(id: "c1", title: "Coffee ad at sunset in Dubai", messages: [
            .init(role: .user, text: "Make a video ad for a coffee shop in Dubai at sunset from this photo"),
            .init(role: .assistant, text: "Here's the prompt I'd use for the video — review it on the card and run it if you like it. Current settings: PixVerse V6, 5 seconds, 720p, no sound.",
                  answeredBy: "Claude Sonnet 5.5",
                  generation: .init(kind: .video, model: "PixVerse V6", credits: 180, status: .completed,
                                    prompt: "Animate the attached photo into a premium coffee advertisement set at Dubai's golden hour just after sunset. Slow dolly push-in toward the foam, warm bokeh, Burj Khalifa glowing through the window.")),
        ]),
        ChatThread(id: "c2", title: "LaFerrari on a Moscow street", messages: [
            .init(role: .user, text: "Make me a photo of a LaFerrari in Moscow"),
            .init(role: .assistant, text: "Your Ferrari LaFerrari photo on a Moscow street is being created. Model: FLUX 2 Pro, 2K, 3:2.\n\nWant a different angle or another spot in Moscow?",
                  answeredBy: "Claude Haiku 5.5",
                  generation: .init(kind: .image, model: "FLUX 2 Pro", credits: 35, status: .completed,
                                    prompt: "A red Ferrari LaFerrari hypercar parked on a wet cobblestone street in central Moscow, cream-coloured imperial-era facades, low three-quarter front angle.")),
        ]),
        ChatThread(id: "c3", title: "Analyse the PDF and make slides", messages: []),
        ChatThread(id: "c4", title: "Write a script for a video", messages: []),
        ChatThread(id: "c5", title: "I want a video with a cat", messages: []),
        ChatThread(id: "c6", title: "Rabbit running around Etihad Towers", messages: []),
        ChatThread(id: "c7", title: "Bring @image1 to life in Wan 3.0", messages: []),
    ]
}
