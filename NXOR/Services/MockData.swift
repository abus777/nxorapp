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
        planName: "Starter",
        planSlug: "starter",
        available: 3000,
        reserved: 0,
        monthlyGrant: 4000
    )

    static let projects: [Project] = [
        Project(id: "p-default", name: "My work", isDefault: true),
        Project(id: "p-palm", name: "Palm Villa Launch", isDefault: false),
        Project(id: "p-oud", name: "Oud & Co perfume", isDefault: false),
        Project(id: "p-personal", name: "Personal", isDefault: false),
    ]

    static let projectMeta: [String: ProjectMeta] = [
        "p-palm": ProjectMeta(kind: .realEstate, about: "Ad videos for a villa listing, EN + AR. Premium tone, golden hour, no people in frame.", defaultFormat: "9:16", brandColors: ["#0B2545", "#8A93A0", "#EEF1F5"]),
        "p-oud": ProjectMeta(kind: .brand, about: "Brand content for Instagram. Warm, smoky, gold accents.", defaultFormat: "4:5", brandColors: ["#3B2A1A", "#C9A227", "#0B0D10"]),
        "p-personal": ProjectMeta(kind: .folder, about: "Everything else"),
    ]

    private static let ferrariPrompt = "A red Ferrari LaFerrari drives along a wide, sunlit boulevard in Dubai, glass skyscrapers line the road, Burj Khalifa in the distance. Low tracking shot, warm golden-hour light, heat shimmer over the asphalt, cinematic 24fps."

    private static let shotList = """
    Prompt for Seedance 2: 10 shots in 15 seconds, Dubai at night.

    ```
    A cinematic luxury car commercial for a red LaFerrari in Dubai at night, 15 seconds, 24fps.
    Shot 1 · 0–1.5 s wide aerial drone shot over the Dubai skyline, the car's lights cutting through the city.
    Shot 2 · 1.5–3 s low-angle tracking shot on a wet boulevard, reflections of neon on the paint.
    Shot 3 · 3–4.5 s close-up of the front fascia, headlights flaring.
    Shot 4 · 4.5–6 s side profile at speed, motion blur on the wheels.
    Shot 5 · 6–7.5 s interior, hands on the wheel, dashboard glow.
    Shot 6 · 7.5–9 s rear three-quarter, exhaust heat haze.
    Shot 7 · 9–10.5 s overhead through Sheikh Zayed Road interchange.
    Shot 8 · 10.5–12 s slow push-in on the badge.
    Shot 9 · 12–13.5 s the car stops under the Burj Khalifa, doors open upward.
    Shot 10 · 13.5–15 s logo card over the skyline.
    ```
    """

    static let chats: [ChatThread] = [
        ChatThread(id: "c1", title: "LaFerrari in Dubai", messages: [
            .init(role: .user, text: "Make a video of a LaFerrari driving in Dubai"),
            .init(role: .assistant, text: "Here is the video prompt — check it and press Generate.",
                  answeredBy: "Fast",
                  proposals: [ChatProposal(id: "demo-prop", kind: "video", prompt: ferrariPrompt, modelLabel: "PixVerse V6", modelSlug: nil, credits: 180)]),
        ]),
        ChatThread(id: "c2", title: "LaFerrari prompt", messages: [
            .init(role: .user, text: "Write a prompt: at least 10 shots in 15 seconds, LaFerrari ad in Dubai"),
            .init(role: .assistant, text: shotList, answeredBy: "Fast"),
        ]),
        ChatThread(id: "c3", title: "LaFerrari video", messages: [
            .init(role: .user, text: "Make a video of a LaFerrari driving in Dubai"),
            .init(role: .assistant, text: "Done. Want a night version or with sound?", answeredBy: "Fast",
                  generation: .init(kind: .video, model: "PixVerse V6", credits: 180, status: .completed, prompt: ferrariPrompt)),
        ]),
        ChatThread(id: "c4", title: "Arabic caption for reel", messages: [
            .init(role: .user, text: "Write an Instagram caption in Arabic for a perfume reel"),
            .init(role: .assistant, text: "عطر يحكي قصتك — دخان العود ودفء الذهب في كل رشة. ✨\n\nWant an English version too?", answeredBy: "Fast"),
        ]),
        ChatThread(id: "c7", title: "Footballer in a LaFerrari", messages: [
            .init(role: .user, text: "Make a video of [famous footballer] driving a LaFerrari in Dubai"),
            .init(role: .assistant, text: "Here is the video prompt — check it and press Generate.", answeredBy: "Fast",
                  generation: .init(kind: .video, model: "PixVerse V6", credits: 180, status: .failed, prompt: "A famous footballer drives a red LaFerrari through Dubai", errorMessage: "This would show a real, identifiable person without their consent. Try a made-up character or your own photo.")),
        ]),
        ChatThread(id: "c5", title: "Ramadan campaign plan", messages: []),
        ChatThread(id: "c6", title: "Invoice question", messages: []),
        ChatThread(id: "p1", title: "Listing description EN/AR", messages: [
            .init(role: .user, text: "Write the listing text in English and Arabic"),
            .init(role: .assistant, text: "**English**\n\nVilla in Dubai Hills, five bedrooms, private pool and a garden that faces the golf course. Ready to move in, 15 minutes from Downtown.\n\n**العربية**\n\nفيلا في دبي هيلز، خمس غرف نوم، مسبح خاص وحديقة تطل على ملعب الغولف. جاهزة للسكن، على بعد 15 دقيقة من وسط المدينة.", answeredBy: "Smart"),
            .init(role: .user, text: "And a hero picture"),
            .init(role: .assistant, text: "Here is the hero shot. Add the Arabic headline from the listing text?", answeredBy: "Smart",
                  proposals: [ChatProposal(id: "demo-prop-2", kind: "image", prompt: "Modern villa in Dubai Hills at golden hour, pool in front, space for an Arabic headline on top, @image1 @image2 + brand kit", modelLabel: "Nano Banana Pro", modelSlug: nil, credits: 25)]),
        ], projectID: "p-palm", tier: "smart"),
        ChatThread(id: "p2", title: "Script for 30-sec video", messages: [], projectID: "p-palm", tier: "genius"),
        ChatThread(id: "p3", title: "Hashtags and captions", messages: [], projectID: "p-palm"),
        ChatThread(id: "o1", title: "Launch post copy", messages: [], projectID: "p-oud"),
    ]
}
