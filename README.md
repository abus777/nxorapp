# NXOR for iOS

Native SwiftUI client for [nxor.ai](https://nxor.ai) — one chat for every AI model, plus a studio for images and videos.

## Features

- **Sign in** with your email and a 6-digit code (no password), or explore a **demo mode** without an account.
- **Chat** with the NXOR agent: streaming replies, Fast / Smart / Genius modes, live stages
  ("Thinking", "Writing the prompt", "Creating video"…), generation cards that update until the result is ready,
  agent proposals, photo attachments and a stop button.
- **Studio**: text-to-image and text-to-video with every NXOR model. Model, quality, resolution, duration and
  aspect-ratio pickers are built from the live model catalog; the price in credits is quoted before you run;
  "AI prompt" rewrites your prompt.
- **Presets**: all 123 NXOR looks and camera moves with sample outputs; upload a photo and run a preset.
- **Library**: images and videos grouped by month, full-screen viewer with prompt and metadata,
  share, save to Photos, delete.
- **Plan & settings**: balance, reserved and monthly credits, plans (view only — billing happens on nxor.ai), help, sign out.

Generating images, videos and chat replies spends credits on your NXOR account, exactly as on the website.

## Run

Requirements: Xcode 16 or newer, iOS 17+.

```bash
git clone https://github.com/abus777/nxorapp.git
open nxorapp/NXOR.xcodeproj
```

Pick an iPhone simulator and press **⌘R**. To run on your own iPhone, select the **NXOR** target →
*Signing & Capabilities* → choose your Team (your Apple ID).

Launch arguments (Product → Scheme → Edit Scheme → Arguments) open a screen directly:
`-demo YES`, `-route studio|library|presets|billing|settings|help`, `-chat <id>`, `-sidebar YES`,
`-sheet capabilities`, `-preset <slug>`.

## Structure

```
NXOR/
  App/              entry point
  DesignSystem/     colors, gradients, fonts, CutCorner shape, components
  Models/           catalog and chat models
  Services/         AppModel (state), MockData
  Services/API/     APIClient (cookie session + refresh), NXORService, ChatStream (SSE)
  Features/         Auth, Chat, Sidebar, Studio, Library, Presets, Account
  Resources/Mocks/  NXOR catalogs used by demo mode
docs/BRIEF.md       analysis of nxor.ai: screens, API, chat SSE protocol, plan
```

## CI

Every push to `main` builds the app on a macOS runner, launches it in an iPhone simulator, takes a screenshot
of each screen and publishes the build log and screenshots to the `ci-results` branch.
