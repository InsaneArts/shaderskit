import Testing
import simd
import ShadersKit

// Reference values come from the upstream TypeScript (shaders-core 1.7.0, colorjs.io 0.5.2),
// run through tsx: `transformColorGpu`, `transformPosition`, `transformAngle`, `packStops`,
// `packConvertedStops`, `resolveDimensionalProps`, `resolveListItems` and `packList`.

private func close(_ a: [Float], _ b: [Double], _ tolerance: Double) -> Bool {
    guard a.count == b.count else { return false }
    return zip(a, b).allSatisfy { abs(Double($0) - $1) <= tolerance }
}

private func values(_ c: RGBA) -> [Float] { [c.r, c.g, c.b, c.a] }

struct ColorCase: Sendable, CustomTestStringConvertible {
    let css: String
    let srgb: [Double]?
    let p3: [Double]
    let linear: [Double]

    init(_ css: String, srgb: [Double]?, p3: [Double], linear: [Double]) {
        self.css = css
        self.srgb = srgb
        self.p3 = p3
        self.linear = linear
    }

    var testDescription: String { css }

    static let all: [ColorCase] = [
        ColorCase("#1aff00", srgb: [0.10196078431372549, 1, 0, 1], p3: [0.1860339194536209, 0.9671486616134644, 0.07257390022277832, 1], linear: [0.01032982300966978, 1, 0, 1]),
        ColorCase("#7c3aed", srgb: [0.48627450980392156, 0.22745098039215686, 0.9294117647058824, 1], p3: [0.17328423261642456, 0.04759741574525833, 0.7776013016700745, 1], linear: [0.2015562504529953, 0.0423114113509655, 0.8468732237815857, 1]),
        ColorCase("#fff", srgb: [1, 1, 1, 1], p3: [1, 1, 1, 1], linear: [1, 1, 1, 1]),
        ColorCase("#f0a", srgb: [1, 0, 0.6666666666666666, 1], p3: [0.8224619626998901, 0.033194199204444885, 0.38309141993522644, 1], linear: [1, 0, 0.4019777774810791, 1]),
        ColorCase("#ff000080", srgb: [1, 0, 0, 0.5019607843137255], p3: [0.8224619626998901, 0.033194199204444885, 0.017082631587982178, 0.501960813999176], linear: [1, 0, 0, 0.501960813999176]),
        ColorCase("#12345678", srgb: [0.07058823529411765, 0.20392156862745098, 0.33725490196078434, 0.47058823529411764], p3: [0.011071557179093361, 0.03340071067214012, 0.08732148259878159, 0.47058823704719543], linear: [0.006048833020031452, 0.03433980792760849, 0.09305896610021591, 0.47058823704719543]),
        ColorCase("rgb(255, 128, 0)", srgb: [1, 0.5019607843137255, 0, 1], p3: [0.8607854247093201, 0.24188938736915588, 0.032710377126932144, 1], linear: [1, 0.2158605009317398, 0, 1]),
        ColorCase("rgb(10% 20% 30% / 0.5)", srgb: [0.1, 0.2, 0.3, 0.5], p3: [0.01412074826657772, 0.03233857825398445, 0.06925344467163086, 0.5], linear: [0.010022825561463833, 0.03310476616024971, 0.07323895394802094, 0.5]),
        ColorCase("rgba(0, 0, 255, 0.25)", srgb: [0, 0, 1, 0.25], p3: [-5.551115123125783e-17, 3.469446951953614e-18, 0.9105199575424194, 0.25], linear: [0, 0, 1, 0.25]),
        ColorCase("hsl(210, 60%, 40%)", srgb: [0.16000000000000003, 0.4, 0.64, 1], p3: [0.041667673736810684, 0.12918750941753387, 0.34438005089759827, 1], linear: [0.021980946883559227, 0.13286831974983215, 0.36724647879600525, 1]),
        ColorCase("hsl(0.25turn 80% 30% / 50%)", srgb: [0.3, 0.54, 0.06, 0.5], p3: [0.10514451563358307, 0.24698470532894135, 0.024022240191698074, 0.5], linear: [0.07323895394802094, 0.2529500722885132, 0.004896310158073902, 0.5]),
        ColorCase("hwb(200 10% 20%)", srgb: [0.09999999999999992, 0.5666666666666663, 0.8, 1], p3: [0.05813456326723099, 0.2720213830471039, 0.5703129172325134, 1], linear: [0.010022825561463833, 0.2810167968273163, 0.6038273572921753, 1]),
        ColorCase("rebeccapurple", srgb: [0.4, 0.2, 0.6, 1], p3: [0.11515649408102036, 0.03641633689403534, 0.29470962285995483, 1], linear: [0.13286831974983215, 0.03310476616024971, 0.31854677200317383, 1]),
        ColorCase("CornflowerBlue", srgb: [0.39215686274509803, 0.5843137254901961, 0.9294117647058824, 1], p3: [0.15817059576511383, 0.2947976887226105, 0.7950305342674255, 1], linear: [0.12743768095970154, 0.30054378509521484, 0.8468732237815857, 1]),
        ColorCase("transparent", srgb: [0, 0, 0, 0], p3: [0, 0, 0, 0], linear: [0, 0, 0, 0]),
        ColorCase("not-a-color", srgb: nil, p3: [0, 0, 0, 0], linear: [0, 0, 0, 0]),
        ColorCase("#abcd", srgb: [0.6666666666666666, 0.7333333333333333, 0.8, 0.8666666666666667], p3: [0.41883593797683716, 0.49378103017807007, 0.5926403403282166, 0.8666666746139526], linear: [0.4019777774810791, 0.4969329833984375, 0.6038273572921753, 0.8666666746139526]),
        ColorCase("hsl(3.14159rad 50% 50%)", srgb: [0.25, 0.75, 0.7499987330042024, 1], p3: [0.1346110999584198, 0.5068656802177429, 0.5144628286361694, 1], linear: [0.05087608844041824, 0.5225215554237366, 0.522519588470459, 1]),
        ColorCase("rgb(300 0 0)", srgb: [1.1764705882352942, 0, 0, 1], p3: [1.192141056060791, 0.04811428114771843, 0.024760907515883446, 1], linear: [1.4494786262512207, 0, 0, 1]),
        ColorCase("hsla(120, 100%, 50%, 0.3)", srgb: [0, 1, 0, 0.3], p3: [0.17753803730010986, 0.9668058156967163, 0.07239744067192078, 0.30000001192092896], linear: [0, 1, 0, 0.30000001192092896]),
    ]
}

@Suite("CSSColor")
struct CSSColorTests {
    @Test("parse and linear match colorjs.io", arguments: ColorCase.all)
    func matchesUpstream(_ c: ColorCase) {
        if let srgb = c.srgb {
            let parsed = CSSColor.parse(c.css)
            #expect(parsed.map { close(values($0), srgb, 1e-5) } == true, "parse \(c.css): \(String(describing: parsed))")
        } else {
            #expect(CSSColor.parse(c.css) == nil)
        }
        let p3 = CSSColor.linear(c.css)
        #expect(close(values(p3), c.p3, 1e-4), "p3-linear \(c.css): \(p3)")
        let linear = CSSColor.linear(c.css, mode: .sRGBLinear)
        #expect(close(values(linear), c.linear, 1e-4), "srgb-linear \(c.css): \(linear)")
    }

    @Test("CSS syntax colorjs.io rejects or misreads", arguments: [
        ("rgba(255, 0, 0)", [1.0, 0, 0, 1]),
        ("rgb(255, 0, 0, 0.5)", [1.0, 0, 0, 0.5]),
        ("hsl(120 100 50)", [0.0, 1, 0, 1]),
        ("  RED ", [1.0, 0, 0, 1]),
        ("rgb(255 0 0 / 1.5)", [1.0, 0, 0, 1]),
        ("hwb(0 60% 60%)", [0.5, 0.5, 0.5, 1]),
    ])
    func cssSyntax(_ css: String, expected: [Double]) {
        let parsed = CSSColor.parse(css)
        #expect(parsed.map { close(values($0), expected, 1e-6) } == true, "\(css): \(String(describing: parsed))")
    }

    @Test("invalid strings", arguments: [
        "", "0", "#12345", "#1234567", "rgb(1e2 0 0)", "rgb(255 0)", "hsl(10% 50% 50%)", "rgb(255 0 0 / 1 / 2)",
        "foo(1 2 3)", "rgb(255 0 0", "#ggg",
    ])
    func invalid(_ css: String) {
        #expect(CSSColor.parse(css) == nil)
        #expect(CSSColor.linear(css) == RGBA(r: 0, g: 0, b: 0, a: 0))
    }

    @Test func transferFunctionRoundTrip() {
        for v: Float in [-0.5, 0, 0.002, 0.04, 0.2, 0.5, 1, 1.3] {
            #expect(abs(ColorMath.linearToSrgb(ColorMath.srgbToLinear(v)) - v) < 1e-6)
        }
        let p3 = SIMD3<Float>(0.3, 0.6, 0.9)
        #expect(simd_distance(ColorMath.linearSRGBToLinearP3(ColorMath.linearP3ToLinearSRGB(p3)), p3) < 1e-6)
    }
}

@Suite("ColorMath")
struct ColorMathTests {
    let samples: [SIMD3<Float>] = [
        SIMD3(0.8, 0.2, 0.1), SIMD3(0.1, 0.7, 0.3), SIMD3(0.2, 0.3, 0.9), SIMD3(0.5, 0.5, 0.2),
    ]

    @Test func gpuConversionsRoundTrip() {
        for rgb in samples {
            #expect(simd_distance(ColorMath.oklabToRgb(ColorMath.rgbToOklab(rgb)), rgb) < 1e-4)
            #expect(simd_distance(ColorMath.oklabToRgb(ColorMath.oklchToOklab(ColorMath.oklabToOklch(ColorMath.rgbToOklab(rgb)))), rgb) < 1e-4)
            #expect(simd_distance(ColorMath.hslToRgb(ColorMath.rgbToHsl(rgb)), rgb) < 1e-4)
            #expect(simd_distance(ColorMath.hsvToRgb(ColorMath.rgbToHsv(rgb)), rgb) < 1e-4)
            #expect(simd_distance(ColorMath.labToRgb(ColorMath.lchToLab(ColorMath.labToLch(ColorMath.rgbToLab(rgb)))), rgb) < 1e-4)
            #expect(simd_distance(ColorMath.sRGBToP3(ColorMath.p3ToSRGB(rgb)), rgb) < 1e-5)
            // Upstream's 7-digit P3 matrix agrees with the colorjs.io matrices.
            #expect(simd_distance(ColorMath.p3ToSRGB(rgb), ColorMath.linearP3ToLinearSRGB(rgb)) < 1e-5)
        }
    }

    @Test func gpuPortsAgreeWithCPUPath() {
        for p3 in samples {
            let srgb = ColorMath.p3ToSRGB(p3)
            let cpuOklab = ColorMath.convertP3ToMixSpaceCPU(r: p3.x, g: p3.y, b: p3.z, mode: 2)
            #expect(simd_distance(ColorMath.rgbToOklab(srgb), cpuOklab) < 1e-5)
            let cpuHsv = ColorMath.convertP3ToMixSpaceCPU(r: p3.x, g: p3.y, b: p3.z, mode: 4)
            #expect(simd_distance(ColorMath.rgbToHsv(srgb), cpuHsv) < 1e-5)
            let cpuLch = ColorMath.convertP3ToMixSpaceCPU(r: p3.x, g: p3.y, b: p3.z, mode: 5)
            #expect(simd_distance(ColorMath.labToLch(ColorMath.rgbToLab(srgb)), cpuLch) < 1e-3)
        }
    }
}

@Suite("PropTransforms")
struct PropTransformsTests {
    @Test func boolean() {
        #expect(PropTransforms.transformBoolean(true) == 1)
        #expect(PropTransforms.transformBoolean(false) == -1)
    }

    @Test("position keywords", arguments: [
        ("top left", SIMD2<Float>(0, 1)),
        ("center", SIMD2<Float>(0.5, 0.5)),
        ("bottom right", SIMD2<Float>(1, 0)),
        ("top", SIMD2<Float>(0.5, 1)),
        ("right", SIMD2<Float>(1, 0.5)),
        ("  Bottom  Left ", SIMD2<Float>(0, 0)),
        ("bogus", SIMD2<Float>(0.5, 0.5)),
    ])
    func positionKeyword(_ s: String, expected: SIMD2<Float>) {
        #expect(PropTransforms.transformPosition(.keyword(s)) == expected)
    }

    @Test func positionXY() {
        #expect(PropTransforms.transformPosition(.xy(x: .number(0.25), y: .keyword("top"))) == SIMD2(0.25, 1))
        let p = PropTransforms.transformPosition(.xy(x: .keyword("right"), y: .dimensional(DimensionalValue(value: 0.3, unit: .uv))))
        #expect(abs(p.x - 1) < 1e-6 && abs(p.y - 0.7) < 1e-6)
    }

    @Test("numeric angles", arguments: [
        (Float(0), Float(0)), (45, 45), (-90, 270), (360, 0), (725.5, 5.5), (-720, 0),
    ])
    func angleNumber(_ v: Float, expected: Float) {
        #expect(abs(PropTransforms.transformAngle(v) - expected) < 1e-4)
    }

    @Test("string angles", arguments: [
        ("to right", Float(0)), ("to bottom", 90), ("to top left", 225), ("to right top", 315),
        ("from top", 90), ("from bottom left", 315), ("45deg", 45), ("-30deg", 330),
        ("1rad", 57.29577951308232), ("0.5turn", 180), (".25turn", 90), ("90", 90),
        ("garbage", 0), ("1grad", 0), ("TO LEFT", 180),
    ])
    func angleString(_ s: String, expected: Float) {
        #expect(abs(PropTransforms.transformAngle(s) - expected) < 1e-4)
    }

    @Test func enumTables() {
        let edges: [(String, Float)] = [("stretch", 0), ("transparent", 1), ("MIRROR", 2), ("wrap", 3), ("nope", 0)]
        for (s, v) in edges { #expect(PropTransforms.transformEdges(s) == v) }
        let spaces: [(String, Float)] = [("linear", 0), ("oklch", 1), ("OKLAB", 2), ("hsl", 3), ("hsv", 4), ("lch", 5), ("nope", 0)]
        for (s, v) in spaces { #expect(PropTransforms.transformColorSpace(s) == v) }
        let strokes: [(String, Float)] = [("outside", 0), ("center", 1), ("INSIDE", 2), ("nope", 1)]
        for (s, v) in strokes { #expect(PropTransforms.transformStrokePosition(s) == v) }
    }
}

@Suite("ColorStops")
struct ColorStopsTests {
    let stops = [
        ColorStop(color: "#7c3aed", position: 1),
        ColorStop(color: "#1aff00", position: 0),
        ColorStop(color: "rgb(255, 128, 0)", position: 0.5),
    ]

    @Test func sortIsStable() {
        let sorted = ColorStops.sort([
            ColorStop(color: "a", position: 0.5), ColorStop(color: "b", position: 0),
            ColorStop(color: "c", position: 0.5), ColorStop(color: "d", position: 0),
        ])
        #expect(sorted.map(\.color) == ["b", "d", "a", "c"])
    }

    @Test func packSortsAndConverts() {
        let packed = ColorStops.pack(stops, mode: .displayP3Linear)
        #expect(packed.stopCount == 3)
        #expect(packed.positions == [0, 0.5, 1, 0, 0, 0, 0, 0])
        let expected: [Double] = [
            0.1860339194536209, 0.9671486616134644, 0.07257390022277832, 1,
            0.8607854247093201, 0.24188938736915588, 0.032710377126932144, 1,
            0.17328423261642456, 0.04759741574525833, 0.7776013016700745, 1,
        ] + [Double](repeating: 0, count: 20)
        #expect(close(packed.colors, expected, 1e-4))
    }

    @Test("packConverted matches packConvertedStops", arguments: [
        (0, [0.1860339194536209, 0.9671486616134644, 0.07257390022277832, 0.8607854247093201, 0.24188938736915588, 0.032710377126932144, 0.17328423261642456, 0.04759741574525833, 0.7776013016700745]),
        (1, [0.8676355806142566, 0.2931631482304184, 2.481693867203412, 0.7318948579704438, 0.185803207596769, 0.9247574898979357, 0.5413370790498698, 0.24658590109624448, -1.1692141236384956]),
        (2, [0.8676355806142566, -0.23161480094258147, 0.1797198249072668, 0.7318948579704438, 0.11185877959535012, 0.14835917693451567, 0.5413370790498698, 0.09638430351618232, -0.2269684397777526]),
        (3, [2.0835779011115654, 1.0000002392854908, 0.5000000262414478, 0.2260487505122193, 1.000000115073731, 0.49999991556727413, 4.396059277607252, 0.9048309454469456, 0.44459228448765353]),
        (4, [2.0835779011115654, 1.0000000671598355, 1.000000119642739, 0.2260487505122193, 1.0000000575368622, 0.999999888671404, 4.396059277607252, 0.9500380572981902, 0.8468731415990345]),
        (5, [87.84083615991362, 119.16998686197537, 2.3674881318870753, 67.0548195834609, 85.51422098342118, 1.046267199472894, 43.3964244141113, 102.24356534587358, -0.8844069881794329]),
    ])
    func packConverted(_ mode: Int, expected: [Double]) {
        let packed = ColorStops.pack(stops, mode: .displayP3Linear)
        let converted = ColorStops.packConverted(colors: packed.colors, stopCount: packed.stopCount, colorSpaceMode: mode)
        #expect(converted.count == 24)
        #expect(close(converted, expected + [Double](repeating: 0, count: 15), mode == 5 ? 1e-3 : 1e-4), "\(converted)")
    }

    @Test func emptyStops() {
        let packed = ColorStops.pack(nil, mode: .displayP3Linear)
        #expect(packed == PackedStops(colors: [Float](repeating: 0, count: 32), positions: [Float](repeating: 0, count: 8), stopCount: 0))
        #expect(ColorStops.packConverted(colors: [], stopCount: 3, colorSpaceMode: 1) == [Float](repeating: 0, count: 24))
    }
}

@Suite("DimensionalProps")
struct DimensionalPropsTests {
    let circle = BoundingBoxDeclaration(propBindings: PropBindings(
        x: PropBinding(prop: "center", as: "position-x"),
        y: PropBinding(prop: "center", as: "position-y"),
        width: PropBinding(prop: "radius", as: "canvas-height"),
        height: PropBinding(prop: "radius", as: "canvas-height")
    ))

    private func px(_ v: Float) -> DimensionalValue { DimensionalValue(value: v, unit: .px) }

    private func xy(_ value: DimensionalPropValue?) -> SIMD2<Float>? {
        guard case .position(.xy(.number(let x), .number(let y)))? = value else { return nil }
        return SIMD2(x, y)
    }

    @Test func pxToUVWithCenterOrigin() {
        let out = DimensionalProps.resolveDimensionalProps(circle, rawProps: [
            "center": .position(.xy(x: .dimensional(px(100)), y: .dimensional(px(50)))),
            "radius": .dimensional(px(200)),
        ], width: 800, height: 400)
        #expect(xy(out["center"]) == SIMD2(0.625, 0.625))
        #expect(out["radius"] == .number(0.5))
    }

    @Test func pxToUVWithTopLeftOrigin() {
        let out = DimensionalProps.resolveDimensionalProps(circle, rawProps: [
            "origin": .string("top-left"),
            "center": .position(.xy(x: .dimensional(px(100)), y: .dimensional(px(50)))),
            "radius": .dimensional(px(200)),
        ], width: 800, height: 400)
        #expect(xy(out["center"]) == SIMD2(0.25, 0.375))
        #expect(out["radius"] == .number(0.5))
        #expect(out["origin"] == .string("top-left"))
    }

    @Test func uvWithBottomRightOrigin() {
        let out = DimensionalProps.resolveDimensionalProps(circle, rawProps: [
            "origin": .string("bottom-right"),
            "center": .position(.xy(x: .number(0.9), y: .dimensional(DimensionalValue(value: 0.8, unit: .uv)))),
            "radius": .number(0.25),
        ], width: 800, height: 400)
        let c = xy(out["center"])
        #expect(c.map { simd_distance($0, SIMD2(0.8375, 0.675)) < 1e-6 } == true)
        #expect(out["radius"] == .number(0.25))
    }

    @Test func halfCanvasHeightWithCenterRightOrigin() {
        let rect = BoundingBoxDeclaration(propBindings: PropBindings(
            x: PropBinding(prop: "center", as: "position-x"),
            y: PropBinding(prop: "center", as: "position-y"),
            width: PropBinding(prop: "width", as: "half-canvas-height"),
            height: PropBinding(prop: "height", as: "half-canvas-height")
        ))
        let out = DimensionalProps.resolveDimensionalProps(rect, rawProps: [
            "origin": .string("center-right"),
            "center": .position(.xy(x: .dimensional(px(20)), y: .number(0.5))),
            "width": .dimensional(px(120)),
            "height": .number(0.1),
        ], width: 1000, height: 500)
        let c = xy(out["center"])
        #expect(c.map { simd_distance($0, SIMD2(0.92, 0.5)) < 1e-6 } == true)
        #expect(out["width"] == .number(0.12))
        #expect(out["height"] == .number(0.1))
    }

    @Test func extraSizeProps() {
        let extra = DimensionalProps.buildExtraSizeProps([
            "softness": "canvas-height", "count": "count-canvas-height", "w": "canvas-width", "x": "bogus",
        ])
        #expect(extra == ["softness": .canvasHeight, "count": .countCanvasHeight, "w": .canvasWidth])
        let out = DimensionalProps.resolveDimensionalProps(nil, rawProps: [
            "softness": .dimensional(px(10)), "count": .dimensional(px(25)), "w": .dimensional(px(50)),
        ], width: 800, height: 400, extraSizeProps: extra)
        #expect(out == ["softness": .number(0.025), "count": .number(16), "w": .number(0.0625)])
    }

    @Test func singlePropAndHalfExtents() {
        let he = DimensionalProps.boxHalfExtentsUV(circle, props: ["radius": .dimensional(px(200))], width: 800, height: 400)
        #expect(he == HalfExtents(hwx: 0.125, hhy: 0.25))
        let single = DimensionalProps.resolveDimensionalProp(
            circle, propName: "center",
            rawValue: .position(.xy(x: .dimensional(px(100)), y: .dimensional(px(50)))),
            origin: "bottom-right", width: 800, height: 400, he: HalfExtents(hwx: 0.1, hhy: 0.2)
        )
        #expect(xy(single).map { simd_distance($0, SIMD2(0.775, 0.675)) < 1e-6 } == true)
        #expect(DimensionalProps.dimensionalPropNames(circle) == ["center", "radius"])
        #expect(DimensionalProps.isDimensionalProp(circle, propName: "radius"))
        #expect(!DimensionalProps.isDimensionalProp(circle, propName: "color"))
    }
}

@Suite("ListProps")
struct ListPropsTests {
    let spec = ListPropSpec(fields: [
        ListItemFieldConfig(name: "position", kind: .position, defaultValue: .position(.xy(x: .number(0.5), y: .number(0.5)))),
        ListItemFieldConfig(name: "color", kind: .color, defaultValue: .string("#ffffff")),
        ListItemFieldConfig(name: "intensity", kind: .number, defaultValue: .number(1)),
        ListItemFieldConfig(name: "enabled", kind: .boolean, defaultValue: .bool(true)),
    ], maxItems: 3)

    @Test func names() {
        #expect(ListProps.listFieldName("lights", "color") == "lights_color")
        #expect(ListProps.listCountName("lights") == "lightsCount")
    }

    @Test func resolveAndPack() {
        let items: [[String: ListItemValue]] = [
            ["position": .position(.xy(x: .number(0.2), y: .number(0.3))), "color": .string("#7c3aed"), "intensity": .number(2), "enabled": .bool(false)],
            ["position": .string("top right"), "color": .string("red")],
            ["intensity": .string("x"), "enabled": .bool(true)],
            ["position": .position(.xy(x: .number(0), y: .number(0)))],
        ]
        let resolved = ListProps.resolveListItems(items, spec: spec)
        #expect(resolved.count == 3)
        let packed = ListProps.packList(resolved, spec: spec)
        #expect(packed.count == 3)
        #expect(close(packed.fields["position"] ?? [], [0.2, 0.7, 0, 0, 1, 1, 0, 0, 0.5, 0.5, 0, 0], 1e-6))
        #expect(close(packed.fields["color"] ?? [], [
            0.17328423261642456, 0.04759741574525833, 0.7776013016700745, 1,
            0.8224619626998901, 0.033194199204444885, 0.017082631587982178, 1,
            1, 1, 1, 1,
        ], 1e-4))
        #expect(packed.fields["intensity"] == [2, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0])
        #expect(packed.fields["enabled"] == [-1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0])
    }
}
