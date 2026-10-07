# Component index

199 components, grouped by upstream category. "all" platforms includes watchOS (CPU rasterizer); "Metal" means iOS, iPadOS, macOS, tvOS and visionOS only.

## Adjustments

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [BrightnessContrast](components/BrightnessContrast.md) | filter | all | Adjust brightness and contrast of the image |
| [Duotone](components/Duotone.md) | filter | all | Map colors to two tones based on luminance |
| [Exposure](components/Exposure.md) | filter | all | Multiplicative exposure (gain) on the child |
| [FilmStock](components/FilmStock.md) | filter | Metal | Real analog film color from measured film-emulation LUTs  |
| [Grayscale](components/Grayscale.md) | filter | all | Convert colors to black and white |
| [HueShift](components/HueShift.md) | filter | all | Rotate hue around the color wheel |
| [Invert](components/Invert.md) | filter | all | Invert RGB colors while preserving alpha |
| [Posterize](components/Posterize.md) | filter | all | Reduce color depth to create a poster effect |
| [Saturation](components/Saturation.md) | filter | all | Adjust color saturation intensity |
| [Sharpness](components/Sharpness.md) | filter | all | Adjust image sharpness using a convolution kernel |
| [Solarize](components/Solarize.md) | filter | all | Inverts tones above a luminance threshold  |
| [Tint](components/Tint.md) | filter | all | Apply a color tint to the image |
| [Tritone](components/Tritone.md) | filter | all | Map colors to three tones: shadows, midtones, highlights |
| [Vibrance](components/Vibrance.md) | filter | all | Selective saturation adjustment protecting skin tones |

## Blurs

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [AngularBlur](components/AngularBlur.md) | filter | all | Radial motion blur rotating around a center point |
| [Blur](components/Blur.md) | filter | Metal | A simple Gaussian blur effect |
| [BokehBlur](components/BokehBlur.md) | filter | Metal | Photographic lens blur where bright highlights bloom into aperture-shaped discs |
| [ChannelBlur](components/ChannelBlur.md) | filter | Metal | Independent blur for red, green, and blue channels |
| [DiffuseBlur](components/DiffuseBlur.md) | filter | all | Grain-like pixel displacement at random |
| [LinearBlur](components/LinearBlur.md) | filter | all | Directional motion blur in a specific angle |
| [ProgressiveBlur](components/ProgressiveBlur.md) | filter | Metal | Blur that increases progressively in one direction |
| [TiltShift](components/TiltShift.md) | filter | Metal | Selective focus blur mimicking tilt-shift photography |
| [ZoomBlur](components/ZoomBlur.md) | filter | all | Radial zoom blur expanding from a center point |

## Distortions

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [BarShift](components/BarShift.md) | warp | all | Slices content into parallel bars, each offset independently for a fractured or glitch-lik |
| [Bend](components/Bend.md) | warp | all | Bends the ends of the frame toward you like a curved display  |
| [Bulge](components/Bulge.md) | warp | all | Magnify or pinch content around a center point |
| [ConcentricSpin](components/ConcentricSpin.md) | warp | all | Concentric rings that each rotate the underlying image by different amounts |
| [CornerPin](components/CornerPin.md) | warp | all | Pin each corner of the content to an arbitrary position for a free perspective warp |
| [DisplacementMap](components/DisplacementMap.md) | filter | all | Distorts child content using another layer's pixels as a displacement map |
| [Flip](components/Flip.md) | warp | all | Mirror content horizontally, vertically, or both |
| [FlowField](components/FlowField.md) | warp | all | Fluid-like distortion with constant smooth motion |
| [FlutedGlass](components/FlutedGlass.md) | filter | all | Full-screen fluted glass effect  |
| [Form3D](components/Form3D.md) | shapeEffect | all | Wraps child content onto a 3D raymarched shape with lighting |
| [GlassTiles](components/GlassTiles.md) | filter | all | Refraction-like distortion in a tile grid pattern |
| [Kaleidoscope](components/Kaleidoscope.md) | warp | all | Create a kaleidoscope effect with radial mirrored segments |
| [Mirror](components/Mirror.md) | warp | all | Mirror content across a line defined by center point and angle |
| [Perspective](components/Perspective.md) | warp | all | Rotate the plane in 3D space with pan and tilt |
| [PolarCoordinates](components/PolarCoordinates.md) | warp | all | Convert rectangular coordinates to polar space |
| [RectangularCoordinates](components/RectangularCoordinates.md) | warp | all | Convert polar coordinates back to rectangular space |
| [Repeater](components/Repeater.md) | structural | all | Repeat the child content in grid, radial or linear layouts with per-instance variation |
| [Spherize](components/Spherize.md) | filter | all | Map content onto a 3D sphere surface with depth distortion |
| [Stretch](components/Stretch.md) | warp | all | Stretch content towards a direction from a center point |
| [Surface3D](components/Surface3D.md) | shapeEffect | Metal | Drapes child content over a 3D wave surface with perspective and lighting |
| [Twirl](components/Twirl.md) | warp | all | Rotate and twist content around a center point |
| [WaveDistortion](components/WaveDistortion.md) | warp | all | Wave-based distortion with multiple waveform types |

## Interactive

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [Boids](components/Boids.md) | simulation | Metal | A living murmuration of hundreds of flocking agents drawn as crisp arrows, streaks, dots o |
| [ChromaFlow](components/ChromaFlow.md) | simulation | all | Interactive liquid flow effect that follows your cursor |
| [CursorRipples](components/CursorRipples.md) | filter | Metal | Fluid-like ripple distortion |
| [CursorTrail](components/CursorTrail.md) | simulation | all | Animated trail effect that tracks cursor movement |
| [Fog](components/Fog.md) | simulation | Metal | Fog that fills the screen and interacts with the mouse |
| [GridDistortion](components/GridDistortion.md) | warp | Metal | Interactive grid distortion controlled by mouse position |
| [InkFlow](components/InkFlow.md) | simulation | Metal | Drag to paint swirling ribbons of ink through a real fluid field  |
| [Liquify](components/Liquify.md) | warp | Metal | Liquid-like interactive deformation effect |
| [MagneticFilings](components/MagneticFilings.md) | simulation | Metal | Thousands of tiny iron filings scattered on paper that swing to align with a magnetic fiel |
| [ParticleFlow](components/ParticleFlow.md) | simulation | Metal | Thousands of drifting dust particles carried by a real incompressible fluid field the curs |
| [PixelSort](components/PixelSort.md) | simulation | Metal | Pixels sort by brightness around the cursor and keep their sorted position, optionally dec |
| [PixelThrow](components/PixelThrow.md) | simulation | all | Throws pixels along the cursor's path like a fluid  |
| [ReactionDiffusion](components/ReactionDiffusion.md) | simulation | Metal | A living Gray-Scott reaction-diffusion pattern that fills the layer and blooms wherever yo |
| [Shatter](components/Shatter.md) | simulation | Metal | Broken glass effect with tectonic plate displacement |
| [Smoke](components/Smoke.md) | simulation | Metal | Realistic fluid smoke simulation with vorticity dynamics |
| [SmokeFlow](components/SmokeFlow.md) | simulation | Metal | Cursor-driven smoke that lingers, swirls, and dissipates with fluid dynamics |

## Shape Effects

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [BrushedMetal](components/BrushedMetal.md) | shapeEffect | Metal | Photorealistic brushed metal  |
| [CarbonFiber](components/CarbonFiber.md) | shapeEffect | Metal | Photorealistic woven carbon fibre  |
| [Chrome](components/Chrome.md) | shapeEffect | Metal | Studio-lit mirror chrome  |
| [Crystal](components/Crystal.md) | shapeEffect | Metal | Diamond-like crystal lens with faceted refraction |
| [Emboss](components/Emboss.md) | shapeEffect | Metal | Embossed / debossed relief shading on top of child content, driven by a custom shape |
| [Frost](components/Frost.md) | shapeEffect | Metal | Photoreal frozen ice  |
| [Glass](components/Glass.md) | shapeEffect | Metal | Optically realistic glass lens driven in a custom shape |
| [Goo](components/Goo.md) | shapeEffect | Metal | Photoreal wet liquid  |
| [Heatmap](components/Heatmap.md) | shapeEffect | Metal | Thermal-camera heat flowing through any 2D, SVG, or 3D shape |
| [Hologram](components/Hologram.md) | shapeEffect | Metal | Volumetric sci-fi hologram  |
| [Holographic](components/Holographic.md) | shapeEffect | Metal | Iridescent holographic foil sticker with animated rainbow sheen and glitter flakes |
| [Irradiance](components/Irradiance.md) | shapeEffect | Metal | Photorealistic light spilling around the edge of any 2D, SVG, or 3D shape  |
| [LightEdge](components/LightEdge.md) | shapeEffect | Metal | Glowing, pulsing light racing around the edge of any 2D, SVG, or 3D shape |
| [LiquidMetal](components/LiquidMetal.md) | shapeEffect | Metal | Flowing liquid chrome  |
| [Nebula](components/Nebula.md) | shapeEffect | Metal | A volumetric gas nebula sealed inside polished glass; billowing emission clouds with hollo |
| [Neon](components/Neon.md) | shapeEffect | Metal | Photorealistic neon tube / 3D pipe effect driven by a custom shape |
| [Obsidian](components/Obsidian.md) | shapeEffect | Metal | Dark tinted glass whose faces stay near-black while every surface turning away from the vi |
| [Particles](components/Particles.md) | simulation | Metal | A swarm of simulated particles that settles into the shape, filling it evenly  |
| [Plastic](components/Plastic.md) | shapeEffect | Metal | Glossy molded plastic with photorealistic studio reflections, driven in a custom shape |
| [SmokeFill](components/SmokeFill.md) | simulation | Metal | Fill a shape with swirling fluid smoke that interacts with the shape boundary |
| [ThinFilm](components/ThinFilm.md) | shapeEffect | Metal | Iridescent thin-film edge |
| [Voxels](components/Voxels.md) | shapeEffect | Metal | Rebuild any shape out of voxels  |
| [Water](components/Water.md) | shapeEffect | Metal | Translucent water  |

## Shapes

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [Arc](components/Arc.md) | shape | all | Pie sector (arc wedge) with adjustable radius and aperture angle |
| [Circle](components/Circle.md) | shape | all | Generate a circle with adjustable size and softness |
| [Crescent](components/Crescent.md) | shape | all | Crescent moon shape  |
| [Cross](components/Cross.md) | shape | all | Plus / cross shape with adjustable arm length, width, and rounding |
| [Ellipse](components/Ellipse.md) | shape | all | Ellipse with independently adjustable horizontal and vertical radii |
| [Flower](components/Flower.md) | shape | all | Petal shape with N lobes and adjustable inner-to-outer radius ratio |
| [Heart](components/Heart.md) | shape | all | Heart shape with adjustable size |
| [Line](components/Line.md) | generator | all | Draw a straight line between two points with color, thickness, and solid, dashed, or dotte |
| [Parallelogram](components/Parallelogram.md) | shape | all | Parallelogram with adjustable width, height and skew |
| [Polygon](components/Polygon.md) | shape | all | Regular polygon with adjustable sides and corner rounding |
| [Ring](components/Ring.md) | shape | all | Annular ring (donut) with adjustable radius and band thickness |
| [RoundedRect](components/RoundedRect.md) | shape | all | Rounded rectangle with adjustable width, height, and corner rounding |
| [Star](components/Star.md) | shape | all | Classic star polygon with straight sides and sharp pointed tips |
| [Teardrop](components/Teardrop.md) | shape | all | Teardrop  |
| [Trapezoid](components/Trapezoid.md) | shape | all | Trapezoid with adjustable top and bottom widths and height |
| [Vesica](components/Vesica.md) | shape | all | Vesica piscis (lens shape) formed by the intersection of two overlapping circles |

## Stylize

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [Ascii](components/Ascii.md) | filter | all | Convert imagery to ASCII character art |
| [CRTScreen](components/CRTScreen.md) | filter | all | Retro CRT monitor simulation with scanlines |
| [Chalkboard](components/Chalkboard.md) | filter | all | Renders content as a chalk drawing on a blackboard, with edge strokes and cross-hatch shad |
| [ChromaticAberration](components/ChromaticAberration.md) | filter | all | Separate RGB channels for a prismatic distortion effect |
| [CompressionArtifacts](components/CompressionArtifacts.md) | filter | Metal | Simulates lossy JPEG compression  |
| [ContourLines](components/ContourLines.md) | filter | all | Draw topographical contour lines based on luminance or alpha |
| [DataMosh](components/DataMosh.md) | simulation | Metal | Corrupted-codec motion smearing  |
| [Dither](components/Dither.md) | filter | all | Dithering effect with multiple pattern options |
| [DropShadow](components/DropShadow.md) | filter | all | Adds a soft shadow behind the child content based on its alpha silhouette |
| [Engraving](components/Engraving.md) | filter | all | Copper-plate line engraving  |
| [FilmGrain](components/FilmGrain.md) | filter | all | Analog film grain texture overlay, weighted toward darker areas |
| [Glitch](components/Glitch.md) | filter | all | Digital glitch that melts pixels and distorts colors |
| [Glow](components/Glow.md) | filter | Metal | Soft glow effect with adjustable intensity |
| [GradientMap](components/GradientMap.md) | filter | all | Maps source luminance through an animated color gradient (Photoshop-style gradient map) |
| [Halftone](components/Halftone.md) | filter | all | Halftone dot pattern effect for printing aesthetics |
| [KeyFrames](components/KeyFrames.md) | overlay | Metal | Motion-tracking overlay  |
| [LensDistortion](components/LensDistortion.md) | filter | all | Split content into shifting chromatic layers with barrel or pincushion lens warp |
| [LensFlare](components/LensFlare.md) | generator | all | Realistic camera lens flare with artifacts |
| [LightLeak](components/LightLeak.md) | filter | all | Photorealistic film light leak  |
| [ObjectTracker](components/ObjectTracker.md) | overlay | all | Computer-vision style object detection overlay  |
| [Paper](components/Paper.md) | filter | all | Applies realistic paper grain and surface roughness to child content |
| [ParticleField](components/ParticleField.md) | simulation | Metal | Explodes the child content into a breathing 3D field of particles  |
| [Pixelate](components/Pixelate.md) | filter | all | Pixelation effect with adjustable cell size |
| [ReflectivePlane](components/ReflectivePlane.md) | filter | Metal | Reflective floor that mirrors the content above it |
| [Sparkle](components/Sparkle.md) | filter | all | Twinkling star glints over the bright parts of the layer inside |
| [Stone](components/Stone.md) | filter | all | Applies a marbled stone relief and surface distortion to child content |
| [TimeTrail](components/TimeTrail.md) | simulation | Metal | An Echo-style temporal trail  |
| [VHS](components/VHS.md) | filter | all | Analog VHS tape with intermittent tape damage, chroma bleed, and per-scanline noise |
| [Vignette](components/Vignette.md) | filter | all | Darkens or tints the edges of the frame, drawing attention toward the center |
| [Watercolor](components/Watercolor.md) | filter | all | Painterly watercolor look  |
| [Wool](components/Wool.md) | filter | all | Applies an interwoven fibrous fabric texture and distortion to child content |

## Textures

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [Aurora](components/Aurora.md) | generator | all | Mesmerizing aurora borealis with layered curtains, vertical rays, and flowing light |
| [Beam](components/Beam.md) | generator | all | A beam of light from one point to another |
| [Blob](components/Blob.md) | generator | all | Organic animated blob with 3D lighting and gradients |
| [BlockNoise](components/BlockNoise.md) | generator | all | Blocky value noise with soft cells that morph over time |
| [BlueNoise](components/BlueNoise.md) | generator | all | High-frequency blue noise  |
| [BrickPattern](components/BrickPattern.md) | generator | all | Classic brick wall pattern with alternating rows and mortar gaps |
| [Checkerboard](components/Checkerboard.md) | generator | all | Classic checkerboard pattern with two alternating colors |
| [Chevron](components/Chevron.md) | generator | all | Animated chevron / zigzag stripe pattern |
| [ColorWheel](components/ColorWheel.md) | generator | all | A directional gradient that smoothly cycles through rainbow colors or a custom set of thre |
| [ConicGradient](components/ConicGradient.md) | generator | all | Colors sweep in a full circle around a center point, like a color wheel |
| [CurlNoise](components/CurlNoise.md) | generator | all | Swirling divergence-free flow field that drifts over time |
| [DiamondGradient](components/DiamondGradient.md) | generator | all | Diamond-shaped gradient radiating from a center point using Manhattan distance |
| [DotGrid](components/DotGrid.md) | generator | all | Grid of dots with optional twinkling animation |
| [ErosionNoise](components/ErosionNoise.md) | generator | all | Branching, hydraulic-erosion ridges carved into noise |
| [FallingLines](components/FallingLines.md) | generator | all | Directional falling lines with a leading-to-trailing color fade |
| [FloatingParticles](components/FloatingParticles.md) | simulation | Metal | Drifting, twinkling motes  |
| [FlowingGradient](components/FlowingGradient.md) | generator | all | Liquid silk gradient with organic flowing color bands |
| [FractalNoise](components/FractalNoise.md) | generator | all | Multi-octave fractal Brownian motion noise texture with true noise evolution |
| [GaborNoise](components/GaborNoise.md) | generator | all | Oriented sine-grain noise with a fingerprint-like flow |
| [Godrays](components/Godrays.md) | generator | all | Volumetric light rays emanating from a point |
| [Grid](components/Grid.md) | generator | all | Simple grid lines pattern with adjustable thickness and rotation |
| [HTMLInCanvas](components/HTMLInCanvas.md) | media | all | Render live HTML/DOM content as a WebGPU texture layer via the html-in-canvas API |
| [HexGrid](components/HexGrid.md) | generator | all | Honeycomb hexagonal grid pattern |
| [ImageTexture](components/ImageTexture.md) | media | all | Display an image with customizable object-fit modes |
| [IsometricCubes](components/IsometricCubes.md) | generator | all | Isometric tumbling-blocks tiling  |
| [LinearGradient](components/LinearGradient.md) | generator | all | Create smooth linear color gradients |
| [Marble](components/Marble.md) | generator | all | Classic marble swirl and vein texture using noise-warped sine waves |
| [MeshGradient](components/MeshGradient.md) | generator | all | Flowing mesh gradient of soft drifting color swaths whose seams wrap through the palette |
| [MultiPointGradient](components/MultiPointGradient.md) | generator | all | Five individually placed color points blended together by proximity  |
| [PerlinNoise](components/PerlinNoise.md) | generator | all | Smooth gradient noise that morphs over time |
| [Plasma](components/Plasma.md) | generator | all | Animated effect of glowing plasma |
| [Prism](components/Prism.md) | generator | all | A beam of light that fans out and splits into a slowly-rotating rainbow past a controllabl |
| [RadialGradient](components/RadialGradient.md) | generator | all | Radial gradient radiating from a center point |
| [Ripples](components/Ripples.md) | generator | all | Concentric animated ripples emanating from a point |
| [Scratches](components/Scratches.md) | generator | all | Fine hairline scratches, like a worn film or scratched surface |
| [SimplexNoise](components/SimplexNoise.md) | generator | all | Organic noise with animated movement |
| [SineWave](components/SineWave.md) | generator | all | Animated wave with thickness and softness |
| [SolidColor](components/SolidColor.md) | generator | all | Fill the canvas with a single solid color |
| [Spiral](components/Spiral.md) | generator | all | Rotating spiral pattern with animated movement |
| [Strands](components/Strands.md) | generator | all | Flowing ribbons of light with a multi-color gradient |
| [Stripes](components/Stripes.md) | generator | all | Alternating colored stripes with animation |
| [StudioBackground](components/StudioBackground.md) | generator | all | Multi-light studio background with ambient motion |
| [SunBurst](components/SunBurst.md) | generator | all | Radial sunburst rays emanating from a center point |
| [Swirl](components/Swirl.md) | generator | all | Flowing swirl pattern with multi-layered noise |
| [Text](components/Text.md) | media | all | Text with any Google font  |
| [TriangularGrid](components/TriangularGrid.md) | generator | all | Tiling grid of equilateral triangles with optional animated row offsets |
| [Truchet](components/Truchet.md) | generator | all | Quarter-circle arc tiles that connect to form organic, maze-like flowing curves |
| [VideoTexture](components/VideoTexture.md) | media | Metal | Display a video with customizable playback and object-fit modes |
| [Voronoi](components/Voronoi.md) | generator | all | Cellular pattern where each pixel is colored by its distance to the nearest of many scatte |
| [Waveform](components/Waveform.md) | generator | all | Audio-visualizer waveform  |
| [WaveletNoise](components/WaveletNoise.md) | generator | all | Rotating banded wavelets that ripple as they animate |
| [Weave](components/Weave.md) | generator | all | Interlaced textile weave pattern with two thread colors going over and under each other |
| [WebcamTexture](components/WebcamTexture.md) | media | Metal | Display a live webcam feed with customizable object-fit modes |
| [WorleyNoise](components/WorleyNoise.md) | generator | all | Cellular noise field  |

## Transitions

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [BarnDoors](components/BarnDoors.md) | filter | all | Split the content along a center line and wipe outward in both directions |
| [BlockDissolve](components/BlockDissolve.md) | filter | all | Dissolve the content away as a grid of blocks vanishing in random order |
| [CheckerWipe](components/CheckerWipe.md) | filter | all | Wipe the content away as a checkerboard of fading squares |
| [DiamondWipe](components/DiamondWipe.md) | filter | all | Wipe the content away through a lattice of growing diamonds |
| [IrisWipe](components/IrisWipe.md) | filter | all | Reveal through an expanding circle growing from a center point |
| [LinearWipe](components/LinearWipe.md) | filter | all | Wipe the content away along a straight edge with a soft feathered transition |
| [NoiseDissolve](components/NoiseDissolve.md) | filter | all | Dissolve the content away through an organic noise pattern |
| [PagePeel](components/PagePeel.md) | filter | all | Curl the content up from a corner like a peeling page |
| [RadialWipe](components/RadialWipe.md) | filter | all | Sweep the content away in a clock-hand arc around a center point |
| [RandomBars](components/RandomBars.md) | filter | all | Wipe the content away as parallel bars vanishing in random order |
| [RippleWipe](components/RippleWipe.md) | filter | all | Wipe the content away in concentric rings pulsing out from a center point |
| [SliceWipe](components/SliceWipe.md) | warp | all | Slice the content into strips that slide away in alternating directions |
| [VenetianBlinds](components/VenetianBlinds.md) | filter | all | Wipe the content away behind a set of parallel closing strips |

## Utilities

| Component | Role | Platforms | Summary |
|---|---|---|---|
| [Group](components/Group.md) | structural | all | Container for organizing and composing child effects  |
