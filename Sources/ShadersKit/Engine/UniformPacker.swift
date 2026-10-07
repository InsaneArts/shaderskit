import Foundation
import simd

/// Resolves prop values to their GPU encodings and packs a node's uniform block following the
/// WGSL layout the composer emitted (`uniformLayout` in the descriptor).
struct UniformPacker {
    let descriptor: ShaderDescriptor
    private let fieldsByPath: [String: UniformLayoutField]
    private let colorStopsProp: PropDescriptor?
    private let listProps: [PropDescriptor]
    private let extraSizeProps: [String: SizeConversion]?
    private let bbox: BoundingBoxDeclaration?

    init(descriptor: ShaderDescriptor) {
        self.descriptor = descriptor
        fieldsByPath = Dictionary(descriptor.uniformLayout.fields.map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        colorStopsProp = descriptor.props.first { $0.transform == .colorStops }
        listProps = descriptor.props.filter { $0.transform == .list }
        var markers: [String: String] = [:]
        for p in descriptor.props { if let d = p.ui.dimensional { markers[p.name] = d } }
        extraSizeProps = DimensionalProps.buildExtraSizeProps(markers)
        bbox = descriptor.boundingBox?.declaration
    }

    var size: Int { descriptor.uniformLayout.size }

    // MARK: - Prop value resolution

    /// Integer encoding of the color-space select prop (drives color stop pre-conversion).
    func colorSpaceMode(_ props: [String: PropValue]) -> Int {
        guard let p = descriptor.props.first(where: { $0.transform == .colorSpace }) else { return 0 }
        let v = props[p.name] ?? p.defaultValue
        return Int(PropTransforms.transformColorSpace(v.stringValue ?? "linear"))
    }

    private func originString(_ props: [String: PropValue]) -> String {
        props["origin"]?.stringValue ?? descriptor.prop("origin")?.defaultValue.stringValue ?? "center"
    }

    private func dimensionalValue(_ v: PropValue) -> DimensionalPropValue? {
        switch v {
        case .number(let n): return .number(n)
        case .dimensional(let d): return .dimensional(d)
        case .position(let p): return .position(p)
        case .string(let s): return .string(s)
        default: return nil
        }
    }

    private func halfExtents(_ props: [String: PropValue], frame: FrameInput) -> HalfExtents? {
        guard let bbox else { return nil }
        var dimProps: [String: DimensionalPropValue] = [:]
        for p in descriptor.props {
            if let dv = dimensionalValue(props[p.name] ?? p.defaultValue) { dimProps[p.name] = dv }
        }
        return DimensionalProps.boxHalfExtentsUV(bbox, props: dimProps, width: frame.pixelSize.x, height: frame.pixelSize.y)
    }

    /// Resolves px units and origin anchoring for a dimensional prop value.
    private func resolveDimensional(_ prop: PropDescriptor, _ value: PropValue, props: [String: PropValue], frame: FrameInput, he: HalfExtents?) -> PropValue {
        guard let raw = dimensionalValue(value) else { return value }
        let resolved = DimensionalProps.resolveDimensionalProp(bbox, propName: prop.name, rawValue: raw, origin: originString(props), width: frame.pixelSize.x, height: frame.pixelSize.y, extraSizeProps: extraSizeProps, he: he)
        switch resolved {
        case .number(let n): return .number(n)
        case .dimensional(let d): return .number(d.unit == .px ? d.value / max(frame.pixelSize.y, 1) : d.value)
        case .position(let p): return .position(p)
        case .string(let s): return .string(s)
        }
    }

    /// Scalar (f32) encoding of a prop.
    func scalar(_ prop: PropDescriptor, _ value: PropValue) -> Float {
        switch prop.transform {
        case .none:
            return value.numberValue ?? 0
        case .affine(let scale, let offset):
            return (value.numberValue ?? 0) * scale + offset
        case .angle:
            if let s = value.stringValue, Float(s) == nil { return PropTransforms.transformAngle(s) }
            return PropTransforms.transformAngle(value.numberValue ?? 0)
        case .edges: return PropTransforms.transformEdges(value.stringValue ?? "stretch")
        case .colorSpace: return PropTransforms.transformColorSpace(value.stringValue ?? "linear")
        case .strokePosition: return PropTransforms.transformStrokePosition(value.stringValue ?? "center")
        case .boolean: return PropTransforms.transformBoolean(value.boolValue ?? false)
        case .booleanTable(let t, let f): return (value.boolValue ?? false) ? t : f
        case .select(let table):
            if let s = value.stringValue, let v = table[s] { return v }
            if let n = value.numberValue { return n }
            return table[prop.defaultValue.stringValue ?? ""] ?? 0
        case .color, .position, .colorStops, .list:
            return value.numberValue ?? 0
        }
    }

    func vec2(_ prop: PropDescriptor, _ value: PropValue) -> SIMD2<Float> {
        switch value {
        case .position(let p): return PropTransforms.transformPosition(p)
        case .string(let s): return PropTransforms.transformPosition(.keyword(s))
        default:
            if case .position(let p) = prop.defaultValue { return PropTransforms.transformPosition(p) }
            return SIMD2(0.5, 0.5)
        }
    }

    func vec4(_ prop: PropDescriptor, _ value: PropValue, mode: ColorSpaceMode) -> SIMD4<Float> {
        let css = value.stringValue ?? prop.defaultValue.stringValue ?? "#000000"
        let c = CSSColor.linear(css, mode: mode)
        return SIMD4(c.r, c.g, c.b, c.a)
    }

    // MARK: - Packing

    /// Writes the full `combined` uniform block for one node.
    func pack(props: [String: PropValue], state: NodeState, frame: FrameInput, options: RenderOptions, into base: UnsafeMutableRawPointer) {
        memset(base, 0, size)
        let mode = options.colorSpace
        let he = halfExtents(props, frame: frame)

        func write(_ path: String, _ values: [Float]) {
            guard let f = fieldsByPath[path] else { return }
            writeField(f, values, base)
        }

        // System block
        write("_sys.time", [frame.time])
        write("_sys.viewportSize", [frame.pixelSize.x, frame.pixelSize.y])
        write("_sys.logicalViewportSize", [frame.logicalSize.x, frame.logicalSize.y])
        write("_sys.aspect", [frame.aspect])
        write("_sys.pointer", [frame.pointer.x, frame.pointer.y])
        write("_sys.pointerActive", [frame.pointerActive ? 1 : 0])
        write("n_root._opacity", [1])
        write("n_child._opacity", [1])

        // Color stops (one prop expands into four fields)
        if let sp = colorStopsProp {
            var stops: [ColorStop]? = nil
            if case .colorStops(let s)? = props[sp.name] { stops = s }
            let packed = ColorStops.pack(stops, mode: mode)
            let converted = ColorStops.packConverted(colors: packed.colors, stopCount: packed.stopCount, colorSpaceMode: colorSpaceMode(props))
            write("n_x.colorsArray", packed.colors)
            write("n_x.positionsArray", packed.positions)
            write("n_x.convertedColorsArray", converted)
            write("n_x.stopCount", [Float(packed.stopCount)])
        }

        // List props
        for lp in listProps {
            guard let item = lp.ui.item, let maxItems = lp.ui.maxItems else { continue }
            let spec = ListPropSpec(fields: item.map { f in
                ListItemFieldConfig(name: f.name, kind: ListItemFieldKind(rawValue: f.kind) ?? .number, defaultValue: Self.listDefault(f), label: f.label, description: nil, min: f.min, max: f.max, step: f.step)
            }, maxItems: maxItems, minItems: lp.ui.minItems, itemLabel: lp.ui.itemLabel)
            var items: [[String: ListItemValue]] = []
            if case .list(let l)? = props[lp.name] { items = l } else if case .list(let l) = lp.defaultValue { items = l }
            let resolved = ListProps.resolveListItems(items, spec: spec, mode: mode)
            let packed = ListProps.packList(resolved, spec: spec)
            for (field, lanes) in packed.fields { write("n_x.\(ListProps.listFieldName(lp.name, field))", lanes) }
            write("n_x.\(ListProps.listCountName(lp.name))", [Float(packed.count)])
        }

        // Regular props and synthetic fields
        for field in descriptor.fields where !field.cpu {
            let path = "n_x.\(field.name)"
            guard let lf = fieldsByPath[path] else { continue }
            if field.name == "_opacity" { writeField(lf, [1], base); continue }
            if field.name.hasPrefix("_animTime") { writeField(lf, [state.animTime[field.name] ?? 0], base); continue }
            if field.name.hasPrefix("_childBounds_") { writeField(lf, [0.5], base); continue }
            if let ef = descriptor.extraFields.first(where: { $0.name == field.name }) {
                writeField(lf, state.extraFields[field.name] ?? ef.initial, base)
                continue
            }
            guard let prop = descriptor.prop(field.name) else { continue }
            var value = props[prop.name] ?? prop.defaultValue
            if value.isNull { value = prop.defaultValue }
            if prop.transform == .colorStops || prop.transform == .list { continue }
            value = resolveDimensional(prop, value, props: props, frame: frame, he: he)
            switch lf.type {
            case "vec4f":
                let v = vec4(prop, value, mode: mode)
                writeField(lf, [v.x, v.y, v.z, v.w], base)
            case "vec2f":
                let v = vec2(prop, value)
                writeField(lf, [v.x, v.y], base)
            case "vec3f":
                let v = vec4(prop, value, mode: mode)
                writeField(lf, [v.x, v.y, v.z], base)
            default:
                writeField(lf, [scalar(prop, value)], base)
            }
        }
    }

    private static func listDefault(_ f: ListItemFieldConfigJSON) -> ListItemValue {
        switch f.defaultValue {
        case .number(let n): return .number(n)
        case .bool(let b): return .bool(b)
        case .string(let s): return .string(s)
        case .position(let p): return .position(p)
        default: return .number(0)
        }
    }

    /// Writes scalar/vector/array floats honoring WGSL uniform strides (arrays stride 16).
    private func writeField(_ f: UniformLayoutField, _ values: [Float], _ base: UnsafeMutableRawPointer) {
        let p = base.advanced(by: f.offset)
        if f.type.hasPrefix("array<") {
            // array<vecNf, N> — stride 16 bytes per element in the uniform address space
            let inner = f.type.dropFirst("array<".count)
            let comps = inner.hasPrefix("vec4") ? 4 : inner.hasPrefix("vec3") ? 3 : inner.hasPrefix("vec2") ? 2 : 1
            let count = f.size / 16
            var vi = 0
            for i in 0..<count {
                for c in 0..<comps {
                    let v = vi < values.count ? values[vi] : 0
                    p.storeBytes(of: v, toByteOffset: i * 16 + c * 4, as: Float.self)
                    vi += 1
                }
            }
            return
        }
        let comps: Int
        switch f.type {
        case "vec2f", "vec2i", "vec2u": comps = 2
        case "vec3f", "vec3i", "vec3u": comps = 3
        case "vec4f", "vec4i", "vec4u": comps = 4
        default: comps = 1
        }
        for c in 0..<min(comps, max(values.count, 1)) {
            let v = c < values.count ? values[c] : 0
            if f.type == "i32" { p.storeBytes(of: Int32(v), toByteOffset: c * 4, as: Int32.self) }
            else if f.type == "u32" { p.storeBytes(of: UInt32(max(v, 0)), toByteOffset: c * 4, as: UInt32.self) }
            else { p.storeBytes(of: v, toByteOffset: c * 4, as: Float.self) }
        }
    }

    // MARK: - Variant selection

    /// Picks the compiled variant matching the node's compile-time prop values.
    func selectVariant(_ props: [String: PropValue]) -> ShaderVariant? {
        guard !descriptor.variants.isEmpty else { return nil }
        if descriptor.variantAxes.isEmpty { return descriptor.variants[0] }
        for v in descriptor.variants {
            var match = true
            for axis in descriptor.variantAxes {
                let expected = v.key[axis] ?? .null
                let actual = props[axis] ?? descriptor.prop(axis)?.defaultValue ?? .null
                if !Self.variantKeyMatches(expected: expected, actual: actual) { match = false; break }
            }
            if match { return v }
        }
        return descriptor.defaultVariant
    }

    private static func variantKeyMatches(expected: PropValue, actual: PropValue) -> Bool {
        switch (expected, actual) {
        case (.null, .null): return true
        case (.null, .colorStops(let s)): return s.count <= 1
        case (.colorStops, .colorStops(let s)): return s.count > 1
        case (.colorStops, .null): return false
        case (.string(let a), .string(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.number(let a), .number(let b)): return a == b
        case (.string(let a), .bool(let b)): return (a == "true") == b
        case (.bool(let a), .string(let b)): return a == (b == "true")
        default: return expected == actual
        }
    }

    // MARK: - Animated time

    /// Advances the node's per-shader clocks (`speed = 0` pauses, like upstream).
    func advanceClocks(props: [String: PropValue], state: NodeState, deltaTime: Float) {
        if let speedProp = descriptor.animatedTimeSpeedProp {
            let speed = speedValue(speedProp, props)
            state.animTime["_animTime", default: 0] += deltaTime * speed
        }
        for (key, speedProp) in descriptor.extraAnimatedTimes {
            let speed = speedValue(speedProp, props)
            state.animTime["_animTime_\(key)", default: 0] += deltaTime * speed
        }
    }

    private func speedValue(_ name: String, _ props: [String: PropValue]) -> Float {
        guard let p = descriptor.prop(name) else { return 1 }
        return scalar(p, props[name] ?? p.defaultValue)
    }
}
