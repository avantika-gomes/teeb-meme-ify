# Tessa Meme Generator

AI-powered iOS meme generator. Take or upload a photo, get witty caption suggestions from OpenAI Vision, pick one, and save or share your meme.

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

1. **Home** — Take a photo, choose from library, or tap a recent photo to reuse.
2. **Captions** — Optionally add steering text, then generate 4 AI captions. Pick one.
3. **Preview** — See the meme with classic white Impact-style text. Save to Photos, share, try another caption, or start over.

Photos are saved locally in the app so you can retry different captions without re-uploading.

## Requirements

- Xcode 15+
- iOS 17+
- OpenAI API key with access to `gpt-4o`
- Physical iPhone for camera capture

## Project Structure

```
TessaMemeGenerator/
  Models/       SavedPhoto, CaptionResult
  Services/     PhotoStore, OpenAIService, MemeRenderer
  Views/        HomeView, CaptionView, MemePreviewView, CameraPicker
Config/
  Secrets.xcconfig          Your API key (gitignored)
  Secrets.xcconfig.example  Template
```
