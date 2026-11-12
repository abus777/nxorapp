# NXOR for iOS

Native SwiftUI client for [nxor.ai](https://nxor.ai). Work in progress — the app currently runs on bundled mock data (real NXOR model, preset and plan catalogs); the live API comes in a later stage.

## Run

Requirements: Xcode 16 or newer (iOS 17+ simulator).

```bash
git clone https://github.com/abus777/nxorapp.git
open nxorapp/NXOR.xcodeproj
```

Pick an iPhone simulator in the toolbar and press **⌘R**.

To run on your own iPhone: select the **NXOR** target → *Signing & Capabilities* → choose your Team (your Apple ID).

## Structure

```
NXOR/
  App/            entry point
  DesignSystem/   colors, gradients, fonts, CutCorner shape, components
  Models/         Codable models matching the NXOR API
  Services/       AppModel (state), MockData
  Features/       Root, Sidebar, Chat, Presets …
  Resources/Mocks JSON catalogs captured from the NXOR API
docs/BRIEF.md     full analysis: screens, API, chat SSE protocol, plan
```
