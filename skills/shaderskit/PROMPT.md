# Agent prompt contract

The demo app's "Copy agent prompt" produces this text (placeholders in angle brackets). When you
receive one, follow it literally: reproduce the Swift snippet exactly, then place it where the
prompt says.

```
Add the ShadersKit "<Component>" shader to my <Platform> app.

Install the ShadersKit skill first if it is not already available:
    npx skills add InsaneArts/shaderskit --skill shaderskit -y
Then use the `shaderskit` skill.

Package: ShadersKit (Swift package, product "ShadersKit"). Location: https://github.com/InsaneArts/shaderskit (or a local checkout).
Minimum OS: iOS 17 / iPadOS 17 / macOS 14 / tvOS 17 / watchOS 10.

Render exactly this configuration (change it only if I ask):

```swift
import ShadersKit

ShaderView {
    <Component>(<props with the values chosen in the demo>)
}
```

Placement: <where the effect goes, e.g. "full-bleed background of the home screen behind the content">.

Reference: skills/shaderskit/components/<Component>.md (props, ranges, platform notes).

Done means: the project builds for <Platform>, the shader renders in the running app, and the code
uses the typed ShadersKit API above (no hand-written Metal, no renamed props).
```

Compositions from the Playground use the same template with the whole `ShaderView { … }` tree
and "Reference" pointing at the components involved.
