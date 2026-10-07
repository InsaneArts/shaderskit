import SwiftUI
import ShadersKit

// SwiftUI and ShadersKit both declare a few type names. Inside the demo the bare names mean the
// SwiftUI types, and shader layers are spelled with the module prefix:
// `ShadersKit.Circle`, `ShadersKit.LinearGradient`, `ShadersKit.Text`, `ShadersKit.Group` …
typealias Text = SwiftUI.Text
typealias Circle = SwiftUI.Circle
typealias Group<Content> = SwiftUI.Group<Content>
typealias LinearGradient = SwiftUI.LinearGradient
typealias RadialGradient = SwiftUI.RadialGradient

// The demo never uses SwiftUI's blend mode or mesh gradient types by name.
typealias BlendMode = ShadersKit.BlendMode
typealias MeshGradient = ShadersKit.MeshGradient
