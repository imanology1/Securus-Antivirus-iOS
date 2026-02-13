# Securus Example App

A SwiftUI demo app that integrates the Securus SDK. Run it in the iOS Simulator to explore the SDK's features.

## Running in the Simulator

### Option A: Xcode (Recommended)

1. **Generate the Xcode project** (requires [xcodegen](https://github.com/yonaskolb/XcodeGen)):

   ```bash
   cd ExampleApp
   brew install xcodegen   # if not installed
   xcodegen generate
   open SecurusExampleApp.xcodeproj
   ```

2. Select an **iPhone 15** (or any iOS 17+) simulator target
3. Press **Cmd+R** to build and run

### Option B: Open as Swift Package

1. In Xcode, open the `ExampleApp/` folder (File > Open)
2. Xcode will resolve the local `../SecurusSDK` package dependency
3. Select a simulator target and run

## What You'll See

The demo app displays:

- **Agent Status** — Green/yellow/red indicator showing SDK lifecycle state
- **Security Status Dashboard** — Network monitoring, runtime protection, and AI engine status
- **Action Buttons** — Trigger demo security scans and integrity checks
- **Threat Log** — Real-time list of detected (or simulated) threat events with severity badges

Since the iOS Simulator doesn't trigger real jailbreak/debugger events, the app generates sample threat events to demonstrate the UI and SDK integration flow.

## Architecture

```
SecurusExampleApp.swift   — App entry point, configures + starts SDK
ContentView.swift         — Main screen with status, actions, threat feed
SecurityStatusView.swift  — Dashboard-style module status display
ThreatLogView.swift       — Full-screen scrollable threat event log
```

The app uses iOS 17's `@Observable` macro and SwiftUI environment to bridge the delegate-based SDK API to reactive views.
