# ShadersKit Demo

A SwiftUI app that shows all 199 ShadersKit components on iOS, iPadOS, macOS, tvOS and watchOS.

## Generate the project

The Xcode project is generated from `project.yml`. Do not edit `ShadersDemo.xcodeproj` by hand.

```sh
cd Demo
xcodegen generate
```

Run `xcodegen generate` again after you add or remove a source file.

## Build and run

| Target | Scheme | Command |
| --- | --- | --- |
| iPhone / iPad | `ShadersDemo` | `xcodebuild -project ShadersDemo.xcodeproj -scheme ShadersDemo -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5' build CODE_SIGNING_ALLOWED=NO` |
| Mac | `ShadersDemo-macOS` | `xcodebuild -project ShadersDemo.xcodeproj -scheme ShadersDemo-macOS -destination 'platform=macOS' build` |
| Apple TV | `ShadersDemo-tvOS` | `xcodebuild -project ShadersDemo.xcodeproj -scheme ShadersDemo-tvOS -destination 'platform=tvOS Simulator,name=Apple TV' build CODE_SIGNING_ALLOWED=NO` |
| Apple Watch | `ShadersDemo-watchOS` | `xcodebuild -project ShadersDemo.xcodeproj -scheme ShadersDemo-watchOS -destination 'platform=watchOS Simulator,name=Apple Watch Series 11 (46mm)' build CODE_SIGNING_ALLOWED=NO` |

Add `OS=26.5` to the iOS destination if a newer iOS runtime is installed. Without it, `OS:latest` can pick a runtime that has no iPhone 17 Pro.

To run a simulator build:

```sh
xcrun simctl install booted <path to .app>
xcrun simctl launch booted dev.shaderskit.demo -openShader Halftone
```

Bundle IDs: `dev.shaderskit.demo`, `dev.shaderskit.demo.mac`, `dev.shaderskit.demo.tv`, `dev.shaderskit.demo.watch`.

## Features

- **Gallery.** All components, grouped by category, with search and a filter that hides compute-backed components. Sidebar on iPad and Mac, category chips on iPhone, focus-driven shelves with a live hero preview on tvOS. On-screen cards run a live `ShaderView` up to a limit (8 on iPhone, 16 on iPad, 24 on Mac). Other cards show a snapshot from `ShaderRenderer.renderImage`.
- **Detail.** Full-bleed live preview with an inspector generated from the descriptor props. It has sliders, color pickers, selects, toggles, position pads and draggable handles, a 9-way origin grid, and a gradient-stops editor. It respects `ui.hidden` and `ui.condition`. Also: blend mode, opacity, backdrop and subject pickers, a stats HUD, PNG export and Swift code export.
- **Code & API.** The detail screen has an Inspector / Code switch. Code shows the Swift for the current configuration (from `ShaderNode.swiftSource(for:)`, including the subject and backdrop), updated live, with Copy Swift. "Prop API" lists every prop with Swift type, default, range or options and description, plus the platform line. "Copy Agent Prompt" fills the template in `skills/shaderskit/PROMPT.md` with the component, a platform picker, a placement text and the package location. The prompt tells the agent to install the skill with `npx skills add tornikegomareli/shaderskit --skill shaderskit -y`. The package location defaults to `https://github.com/tornikegomareli/shaderskit`. An override set in the prompt form replaces it; a local path is added as an alternative instead. It is stored in UserDefaults under `packageLocationOverride`. The Playground and Showcase code sheets have the same prompt action for a whole composition. Gallery cards have a context menu with "Copy Swift" and "Copy Agent Prompt". On tvOS the prompt form has the platform picker only and shows the text, because tvOS has no pasteboard. watchOS has no Code panel.
- **Playground.** Layer stack with add, wrap in filter, unwrap, reorder, duplicate and delete. Per-layer inspector. Save and load as JSON. Export Swift code with a copy button.
- **Showcase.** 14 compositions that use only components that render today. Full-screen presentation with swipe, arrow keys, the Siri Remote and autoplay.
- **Watch.** List of components, full-screen preview through the package's CPU renderer. The Digital Crown drives the first numeric prop.

Components with `hasCompute == true` show a "Compute port pending" badge.

## Launch arguments

| Argument | Effect |
| --- | --- |
| `-openShader <Name>` | Opens the detail screen for a component (also on watchOS). |
| `-section gallery\|showcase\|playground` | Selects a section. |
| `-category <Name>` | Selects a gallery category, for example `Distortions`. |
| `-presentPreset <index>` | Opens the showcase presentation at that preset. |
| `-playgroundDemo YES` | Loads the first preset into the playground. |
| `-appearance light\|dark` | Forces the color scheme. |
| `-audit YES` | Renders every component once and prints the ones that draw nothing. |
| `-dumpCode YES` | With `-audit YES`, writes exported Swift for all presets and components to the app's `tmp/ExportedCode.swift`. |
| `-detailPane code` | Opens the detail screen on the Code pane. |
| `-setProps "rayCount=24,color=#ff3d7f"` | Sets props of the `-openShader` component at launch. |
| `-codeSheet api\|prompt` | With `-detailPane code`, opens the Prop API or Agent prompt sheet. |
| `-printPrompt <Name> [platform]` | Prints the default agent prompt for a component to stdout, for example `-printPrompt SunBurst macOS`. |
| `-perfLog YES` | Prints the frame rate of every live gallery view every 3 seconds. |

## Layout

```
Demo/
  project.yml          XcodeGen spec
  Shared/App           app entry, navigation model, launch arguments, render audit
  Shared/Gallery       gallery grid, cards, badges
  Shared/Inspector     detail view, inspector, prop controls, HUD
  Shared/Playground    layer model, layer list, code exporter, JSON store
  Shared/Showcase      presets, showcase grid, presentation
  Shared/Support       catalog, previews, thumbnails, live-view budget, platform shims
  macOS/  tvOS/  watchOS/   platform-specific views
  Screenshots/         captured screens
```

SwiftUI and ShadersKit share some type names (`Text`, `Circle`, `Group`, `LinearGradient`, …). In the demo the bare names are the SwiftUI types, and shader layers use the module prefix, for example `ShadersKit.Circle`. See `Shared/Support/NameDisambiguation.swift`.
