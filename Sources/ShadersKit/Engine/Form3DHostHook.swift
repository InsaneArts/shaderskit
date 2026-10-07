import Foundation

/// Form3D (shaders/Form3D `drive`): parses the `shape3d` JSON each frame, accumulates the spin,
/// precomputes rotation cos/sin and scaled sizes, and writes the packed `_f3p0`…`_f3p2` params
/// the param-threaded raymarch reads. The shape is the compiled variant's `shape3dType`.
final class Form3DHostHook: HostFieldsHook {
    static let shaderNames = ["Form3D"]
    private static let deg = Double.pi / 180
    private static let tauRate = (Double.pi * 2) / 10
    private static let spinDefaults: [String: [String: Double]] = [
        "torus": ["rotX": -90, "spinY": 0.05],
        "box": ["rotX": 15, "spinY": 0.1],
        "sphere": ["spinY": 0.1],
        "capsule": ["spinY": 0.1],
        "mobius": ["rotX": -30, "spinY": 0.05],
    ]

    private var spinX = 0.0, spinY = 0.0, spinZ = 0.0
    private var lastJson = ""
    private var cfg: [String: Double] = [:]

    init() {}

    private static func parse(_ json: String) -> [String: Double]? {
        guard let data = json.data(using: .utf8),
              let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return nil }
        var out: [String: Double] = [:]
        for (k, v) in obj {
            // `typeof cfg[k] === 'number'` only: JSON booleans are not numbers.
            if let n = v as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID() { out[k] = n.doubleValue }
        }
        return out
    }

    func fields(_ ctx: HostFieldsContext) -> [String: [Float]] {
        if let raw = ctx.string("shape3d"), raw != lastJson {
            lastJson = raw
            if let parsed = Self.parse(raw) { cfg = parsed }
        }
        let shapeType = UniformPacker(descriptor: ctx.descriptor).selectVariant(ctx.props)?.key["shape3dType"]?.stringValue
            ?? ctx.string("shape3dType") ?? "ribbon"
        return drive(shapeType, deltaTime: Double(ctx.frame.deltaTime), speed: Double(ctx.scalar("speed")))
    }

    private func num(_ k: String, _ f: Double) -> Double { cfg[k] ?? f }

    private func drive(_ shapeType: String, deltaTime: Double, speed: Double) -> [String: [Float]] {
        func out(_ p0: [Double], _ p1: [Double], _ p2: [Double]) -> [String: [Float]] {
            ["_f3p0": p0.map(Float.init), "_f3p1": p1.map(Float.init), "_f3p2": p2.map(Float.init)]
        }
        if shapeType == "ribbon" {
            let angle = num("angle", 0) * Self.deg
            let twist = num("twist", 50) * 0.03
            let width = num("width", 40) * 0.012
            let halfW = width * 0.5
            let thickness = num("thickness", 20) * 0.001 + 0.01
            let seed = num("seed", 0)
            let lipschitz = max(halfW * twist, 1)
            return out([angle, twist, halfW, width], [thickness, seed, lipschitz, 0], [0, 0, 0, 0])
        }
        let dfl = Self.spinDefaults[shapeType] ?? [:]
        spinX += deltaTime * speed * num("spinX", dfl["spinX"] ?? 0) * Self.tauRate
        spinY += deltaTime * speed * num("spinY", dfl["spinY"] ?? 0) * Self.tauRate
        spinZ += deltaTime * speed * num("spinZ", dfl["spinZ"] ?? 0) * Self.tauRate
        let aX = num("rotX", dfl["rotX"] ?? 0) * Self.deg + spinX
        let aY = num("rotY", dfl["rotY"] ?? 0) * Self.deg + spinY
        let aZ = num("rotZ", dfl["rotZ"] ?? 0) * Self.deg + spinZ
        let rot0 = [cos(aX), sin(aX), cos(aY), sin(aY)]
        let cz = cos(aZ), sz = sin(aZ)
        switch shapeType {
        case "sphere":
            return out(rot0, [cz, sz, num("radius", 60) * 0.008 + 0.1, 0], [0, 0, 0, 0])
        case "torus":
            return out(rot0, [cz, sz, num("outerRadius", 60) * 0.008 + 0.1, num("tubeRadius", 25) * 0.006 + 0.05], [0, 0, 0, 0])
        case "box":
            return out(rot0, [cz, sz, num("sizeX", 50) * 0.006, num("sizeY", 50) * 0.006], [num("sizeZ", 50) * 0.006, num("rounding", 20) * 0.001, 0, 0])
        case "capsule":
            return out(rot0, [cz, sz, num("radius", 25) * 0.006 + 0.05, num("height", 80) * 0.005], [0, 0, 0, 0])
        default: // mobius
            return out(rot0, [cz, sz, num("ringRadius", 60) * 0.008 + 0.1, num("halfWidth", 30) * 0.005], [num("thickness", 8) * 0.001 + 0.005, 0, 0, 0])
        }
    }
}
