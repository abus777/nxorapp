# NXOR for iOS

Native SwiftUI client for [nxor.ai](https://nxor.ai) — one chat for every AI model, plus a studio for images and videos.
The interface follows the "v1 · Wireframe" canvas in Claude Design (53 screens, NXOR design system).

## What's inside

- **Navigation (01–02b)**: the app opens on a new chat. ≡ menu (also a swipe from the left edge on the chat screen)
  with search, a Chat | Studio switch, recent chats, Create Image / Video / Audio, projects, profile, Presets and Library.
- **Chat (03–05d)**: `+` menu (Photos, Camera, Files, Add to project, Web search, Memory), Fast / Smart / Genius menu,
  presets button, price-in-the-send-button. Generation cards with editable prompt, settings chips,
  Balanced / Quality / Cheapest, the picked model + 2 alternatives, All models, Generate · N cr.
  Prompt blocks with Copy, Open in Studio, shot list and "Use this prompt → choose model".
  Results in the chat with Save / Variations / +5 s and "Saved to Studio · Open". Move a chat (and its media) into a project.
- **Studio (06–08)**: all your work in a grid with "Month · All ▾" filter, Import and Select, "Aa from chat" badges,
  a long-press menu with preview, drag a picture onto the create line to use it as a reference.
  The create sheet has the IMG / VID / AUD key (tap = next mode, hold = list), ✦ Improve prompt with Undo,
  references, model chip and "↑ price". Run settings form (model, references, aspect, quality, duration slider,
  number of images, brand kit), model picker with search and Image / Video / Audio, presets and categories,
  the result screen with Save, Animate, Edit, Variations, To project, Use as reference, Made in chat, prompt and details.
- **Projects (10–13)**: list with "N chats · N media", two-step creation (what it's for → only the fields it needs),
  the project opens chats-first from Chat and media-first from Studio, project chats that know the project's
  instructions, New image / video / audio inside a project, project info and settings.
- **Account and platform (14–16, R1–R14)**: sign-in screen (Apple / Google buttons are placeholders until the
  NXOR server supports them; email + 6-digit code works), account with appearance, memory, sign out and delete,
  credits and plans through the App Store (StoreKit 2, Restore Purchases), notification prompt after the first video,
  local "ready" notifications, Live Activity + Dynamic Island while rendering, home-screen widget, Siri shortcuts,
  Photos permission screen, not-enough-credits banner, failed generation (credits returned), refused request,
  offline queue, empty Studio, Arabic right-to-left layout, light theme.

Generating images, videos and chat replies spends credits on your NXOR account, exactly as on the website.

## Run

Requirements: Xcode 16 or newer, iOS 17+.

```bash
git clone https://github.com/abus777/nxorapp.git
open nxorapp/NXOR.xcodeproj
```

Pick an iPhone simulator and press **⌘R**.

### On your iPhone

1. Select the **NXOR** target → *Signing & Capabilities* → Team: your Apple ID. Do the same for **NXORWidgets**.
2. If Xcode says the bundle ID is taken, create `Config/Local.xcconfig` (it's ignored by git):

   ```
   NXOR_BUNDLE_ID = com.yourname.nxorapp
   ```

   Both the app and the widget use it.

### Launch arguments for screenshots

Product → Scheme → Edit Scheme → Arguments: `-demo YES`, `-route chat|studio|projects`, `-chat <id>`,
`-push presets|category:product|account|projects|project|project:studio|projectChat:p1|newProjectChat|result:first`,
`-sheet create|fromChat|credits|plans|newProject|move|notify|photos`, `-openSettings YES`, `-sidebar YES`,
`-offline YES`, `-appearance light`.

## Not done yet

- **Sign in with Apple / Google** need endpoints on the NXOR server.
- **In-app purchases** need the products `com.abus777.nxorapp.credits.*` and `…plan.*` in App Store Connect,
  plus server-side receipt handling so credits land on the NXOR account.
- **Share Extension from Photos (16)** needs an App Group to hand the picture to the app (paid developer account).
- **Audio / voice-over** — the NXOR API has no voice models yet; the AUD mode explains this.
- Project type, instructions and brand kit are stored on the device (the API has projects with a name only).

## Structure

```
NXOR/
  App/              entry point, fonts, Siri intents
  DesignSystem/     tokens (light + dark), parallelogram buttons, glass, aura, headers
  Models/           catalog, chat, workspace (navigation, projects, drafts)
  Services/         AppModel (state), MockData, Store (StoreKit), Live Activities
  Services/API/     APIClient (cookie session + refresh), NXORService, ChatStream (SSE)
  Features/         Auth, Root, Sidebar, Chat, Studio, Projects, Presets, Account, Library model
NXORShared/         types shared with the widget extension
NXORWidgets/        home widget and render Live Activity
Config/             Info.plist additions, Base.xcconfig
docs/BRIEF.md       analysis of nxor.ai: screens, API, chat SSE protocol, plan
```

## CI

Every push to `main` builds the app on a macOS runner, launches it in an iPhone simulator, takes a screenshot
of each screen and publishes the build log and screenshots to the `ci-results` branch.
