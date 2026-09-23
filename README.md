# ForgeFit — AI Gym Coach for iPhone

ForgeFit is a native SwiftUI iPhone app that builds your workout plan, tracks every set, and has an AI coach (powered by Anthropic's Claude) you can talk to about your struggles — it rewrites your plan to fit.

## Features

**Plans**
- **AI plan generator**: pick your goal, experience, days per week, session length, the **machines & equipment you have**, and optional focus muscles or notes (e.g. "bad left knee"). Claude designs a full weekly program with sets, rep ranges, rest times and cues.
- **Instant generator**: the same inputs, built on-device with no internet or API key needed.
- **Build your own**: create days, add exercises from a 100+ exercise library (filter by muscle and your equipment), and set sets, reps and rest for each one.
- Edit, duplicate and switch between saved plans. The app rotates to the next day after each workout.

**Workout tracking**
- A live workout screen with weight, reps and time inputs, and your previous numbers for every set.
- A rest timer that starts automatically, with +/-15 s and skip, and a notification if the app is in the background.
- Add or remove exercises and sets mid-workout, minimise the workout and resume it later.
- A finish summary with duration, volume, sets and an effort rating (1-10) plus notes.

**Progress**
- Weekly volume and workouts-per-week charts.
- Body weight logging and a trend chart.
- An estimated 1-rep-max strength chart for each exercise, a personal-records leaderboard, and full workout history.

**AI coach chat**
- Tell the coach what's going on ("my knees hurt when I squat", "I only have 30 minutes", "I've stalled"). It sees your profile, current plan, recent workouts and effort ratings.
- When a change would help, it proposes a complete revised plan as a card you can **preview and apply** with one tap.
- Replies stream in live, and you can stop a reply partway.

**Design**
- A dark, modern look with neon-lime and violet gradients, rounded type, glass cards and haptics.

## Get the IPA

Every push runs the **Build iOS IPA** GitHub Action on a macOS runner:

1. Go to **Actions → Build iOS IPA → latest run**.
2. Download the **ForgeFit-ipa** artifact and unzip it to get `ForgeFit.ipa`.
3. Pushing a tag like `v1.0.0` also attaches the IPA to a GitHub Release.

The IPA is **unsigned**. Install it with a sideloading tool that signs it with your Apple ID:
- [AltStore](https://altstore.io) or [Sideloadly](https://sideloadly.io) (free Apple ID, re-sign every 7 days), or
- your own Apple Developer account (for example with `codesign`, Xcode, or an online signing service).

## Enable the AI coach

1. Create an API key at [console.anthropic.com](https://console.anthropic.com).
2. In the app, open **Profile → AI Coach** (or tap **Add API key** in the Coach tab) and paste the key.
3. Pick a model. **Claude Opus 5** is the default. **Sonnet 5** and **Haiku 4.5** are faster and cheaper.

The key is stored in the iOS Keychain on your device. Requests go straight from your phone to `api.anthropic.com`, and usage is billed to your Anthropic account. Without a key, everything except AI generation and chat still works offline.

## Build it yourself (Mac)

```bash
brew install xcodegen
xcodegen generate          # creates ForgeFit.xcodeproj from project.yml
open ForgeFit.xcodeproj    # set your Team under Signing & Capabilities, then Run
```

Requirements: Xcode 16 or later and iOS 17 or later.

## Project layout

```
project.yml                     XcodeGen project definition
ForgeFit/
  App/ForgeFitApp.swift         App entry, tab bar, resume-workout bar
  Models/                       Profile, equipment, exercises, plans, sessions, chat
  Data/ExerciseLibrary.swift    Built-in exercise catalog (IDs the AI references)
  Services/
    AppStore.swift              @Observable state + JSON persistence + stats
    PlanGenerator.swift         Offline rule-based plan generator
    ClaudeClient.swift          Streaming Claude Messages API client (SSE)
    AIPlanning.swift            AI plan design (structured JSON output) + validation
    CoachViewModel.swift        Coach chat with the update_workout_plan tool
    KeychainStore.swift         API key storage
    RestNotifier.swift          Rest-timer notifications
  Theme/                        Colors, gradients, button styles, haptics
  Views/                        Onboarding, Home, Plans, Workout, Progress, Coach, Profile
.github/workflows/build-ipa.yml CI that builds the unsigned IPA
```

### How the AI works
- **Plan generation** uses Claude's structured outputs (`output_config.format` with a JSON schema). Exercise IDs are an `enum` restricted to the exercises your equipment allows, so every plan the app gets back can be used.
- **Coach chat** streams responses and gives Claude one tool, `update_workout_plan`, which takes the complete revised plan. The app validates it and shows it as an "Apply" card instead of changing your plan silently.
- On Claude Opus 5, requests opt into server-side refusal fallbacks (`fallbacks: "default"`). Prompt caching is used for the static coach instructions and the exercise catalog.
