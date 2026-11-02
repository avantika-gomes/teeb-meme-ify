# Fetch

*Good dog, bad jokes.* AI-powered iOS meme generator. Take or pick a photo, get witty caption suggestions from OpenAI Vision (or write your own), place the text, and save or share your meme.

## Quick Start

1. Open `TessaMemeGenerator.xcodeproj` in Xcode.
2. Copy your API key into `Config/Secrets.xcconfig`:
   ```
   OPENAI_API_KEY = sk-your-real-key-here
   ```
3. Select your iPhone as the run destination (camera requires a physical device).
4. In the target's **Signing & Capabilities** tab, choose your Apple ID team.
5. Press **Run** (Cmd+R).

## How It Works

1. **Home** — Take a photo or choose one from your library. *Your Greatest Hits* shows memes you've made; tap one to re-share it.
2. **Make a bad joke** — Captions generate automatically. Pick a suggestion (optionally steer it and tap ↻), or switch to *Write my own*.
3. **Place** — Drag the text, pick an alignment, and slide to resize. What you see here is exactly what gets saved.
4. **Done** — Save to Photos, share, or start over.

## Requirements

- Xcode 15+
- iOS 17+
- OpenAI API key with access to `gpt-4o`
- Physical iPhone for camera capture

## Project Structure

```
TessaMemeGenerator/
  BrandTheme.swift  Fetch design tokens, fonts, button styles, toast
  Models/           SavedPhoto, SavedMeme, CaptionResult, CaptionContext, MemeTextLayout
  Services/         PhotoStore, MemeStore, OpenAIService, CaptionFallback, MemeRenderer,
                    PhotoMetadata, PlaceLookup
  Views/            HomeView, CaptionView, MemeEditorView, MemePreviewView, MemeStyleText,
                    CameraPicker, ShareSheet
  Views/Components/ FlowHeader, BrandSegmentedControl
  Fonts/            Anton, Space Grotesk (SIL Open Font License — see OFL-*.txt)
Config/
  Secrets.xcconfig          Your API key (gitignored)
  Secrets.xcconfig.example  Template
scripts/
  make_app_icon.swift       Renders the app icon
```
