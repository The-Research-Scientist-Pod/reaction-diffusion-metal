//
//  ReactionDiffusionTypes.swift
//  reaction-diffusion-metal
//  Complete version with Glow and Resolution Scaling
//

import Foundation
import simd

// Reaction-Diffusion parameters structure
struct ReactionDiffusionParameters {
    var feedRate: Float
    var killRate: Float
    var diffusionA: Float
    var diffusionB: Float
    var deltaTime: Float
    var brushRadius: Float
    var brushPosition: SIMD2<Float>
    var brushStrength: Float
    var time: Float
    var width: Int32
    var height: Int32
    var diffusionRadius: Float
}

// Preset structure
struct RDPreset: Codable {
    let name: String
    let description: String
    let feedRate: Float
    let killRate: Float
    let diffusionA: Float
    let diffusionB: Float
    let deltaTime: Float
    
    init(name: String, description: String, f: Float, k: Float, da: Float = 1.0, db: Float = 0.5, dt: Float = 1.0) {
        self.name = name
        self.description = description
        self.feedRate = f
        self.killRate = k
        self.diffusionA = da
        self.diffusionB = db
        self.deltaTime = dt
    }
}

// Enhanced color scheme with glow parameters
struct RDColorScheme {
    var colorA: SIMD3<Float>
    var colorB: SIMD3<Float>
    var colorC: SIMD3<Float>
    var mode: Int32
    var intensity: Float
    var contrast: Float
    // 3D lighting parameters
    var lightPosition: SIMD3<Float>
    var viewPosition: SIMD3<Float>
    var heightScale: Float
    var shininess: Float
    var ambientStrength: Float
    var diffuseStrength: Float
    var specularStrength: Float
    // Glow parameters
    var glowEnabled: Float  // 0.0 or 1.0 (float for Metal compatibility)
    var glowIntensity: Float
    var glowThreshold: Float
    var glowColor: SIMD3<Float>
    var glowFalloff: Float
    
    // Presets with glow settings
    static let organic = RDColorScheme(
        colorA: SIMD3<Float>(0.05, 0.05, 0.15),
        colorB: SIMD3<Float>(0.8, 0.6, 0.3),
        colorC: SIMD3<Float>(0.95, 0.95, 0.9),
        mode: 1,
        intensity: 1.0,
        contrast: 1.0,
        lightPosition: SIMD3<Float>(0.3, 0.7, 1.5),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.15,
        shininess: 32.0,
        ambientStrength: 0.4,
        diffuseStrength: 0.6,
        specularStrength: 0.5,
        glowEnabled: 0.0,
        glowIntensity: 1.0,
        glowThreshold: 0.7,
        glowColor: SIMD3<Float>(1.0, 0.8, 0.4),
        glowFalloff: 2.0
    )
    
    static let fire = RDColorScheme(
        colorA: SIMD3<Float>(0.1, 0.0, 0.0),
        colorB: SIMD3<Float>(1.0, 0.3, 0.0),
        colorC: SIMD3<Float>(1.0, 1.0, 0.8),
        mode: 1,
        intensity: 1.2,
        contrast: 1.1,
        lightPosition: SIMD3<Float>(0.3, 0.7, 1.5),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.2,
        shininess: 64.0,
        ambientStrength: 0.3,
        diffuseStrength: 0.7,
        specularStrength: 0.8,
        glowEnabled: 0.0,
        glowIntensity: 1.5,
        glowThreshold: 0.6,
        glowColor: SIMD3<Float>(1.0, 0.6, 0.2),
        glowFalloff: 1.5
    )
    
    static let ocean = RDColorScheme(
        colorA: SIMD3<Float>(0.0, 0.1, 0.3),
        colorB: SIMD3<Float>(0.0, 0.7, 0.9),
        colorC: SIMD3<Float>(0.8, 1.0, 1.0),
        mode: 1,
        intensity: 1.1,
        contrast: 1.0,
        lightPosition: SIMD3<Float>(0.3, 0.7, 1.5),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.12,
        shininess: 128.0,
        ambientStrength: 0.45,
        diffuseStrength: 0.55,
        specularStrength: 0.7,
        glowEnabled: 0.0,
        glowIntensity: 0.8,
        glowThreshold: 0.75,
        glowColor: SIMD3<Float>(0.4, 0.8, 1.0),
        glowFalloff: 2.5
    )
    
    static let grayscale = RDColorScheme(
        colorA: SIMD3<Float>(0, 0, 0),
        colorB: SIMD3<Float>(1, 1, 1),
        colorC: SIMD3<Float>(0.5, 0.5, 0.5),
        mode: 0,
        intensity: 1.0,
        contrast: 1.0,
        lightPosition: SIMD3<Float>(0.3, 0.7, 1.5),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.18,
        shininess: 16.0,
        ambientStrength: 0.35,
        diffuseStrength: 0.65,
        specularStrength: 0.4,
        glowEnabled: 0.0,
        glowIntensity: 1.0,
        glowThreshold: 0.8,
        glowColor: SIMD3<Float>(1.0, 1.0, 1.0),
        glowFalloff: 2.0
    )
    
    static let electric = RDColorScheme(
        colorA: SIMD3<Float>(0.1, 0.0, 0.5),
        colorB: SIMD3<Float>(0.0, 1.0, 1.0),
        colorC: SIMD3<Float>(1.0, 1.0, 1.0),
        mode: 1,
        intensity: 1.3,
        contrast: 1.4,
        lightPosition: SIMD3<Float>(0.3, 0.7, 1.5),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.25,
        shininess: 128.0,
        ambientStrength: 0.25,
        diffuseStrength: 0.65,
        specularStrength: 0.9,
        glowEnabled: 0.0,
        glowIntensity: 2.0,
        glowThreshold: 0.5,
        glowColor: SIMD3<Float>(0.2, 0.8, 1.0),
        glowFalloff: 1.2
    )
    
    static let sunset = RDColorScheme(
        colorA: SIMD3<Float>(0.2, 0.0, 0.4),
        colorB: SIMD3<Float>(1.0, 0.4, 0.0),
        colorC: SIMD3<Float>(1.0, 1.0, 0.8),
        mode: 1,
        intensity: 1.1,
        contrast: 1.2,
        lightPosition: SIMD3<Float>(0.7, 0.3, 1.2),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.18,
        shininess: 48.0,
        ambientStrength: 0.38,
        diffuseStrength: 0.62,
        specularStrength: 0.6,
        glowEnabled: 0.0,
        glowIntensity: 1.2,
        glowThreshold: 0.65,
        glowColor: SIMD3<Float>(1.0, 0.7, 0.3),
        glowFalloff: 1.8
    )
    
    static let metallic = RDColorScheme(
        colorA: SIMD3<Float>(0.1, 0.1, 0.15),
        colorB: SIMD3<Float>(0.6, 0.65, 0.7),
        colorC: SIMD3<Float>(0.95, 0.95, 1.0),
        mode: 1,
        intensity: 1.0,
        contrast: 1.3,
        lightPosition: SIMD3<Float>(0.3, 0.7, 1.5),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.22,
        shininess: 256.0,
        ambientStrength: 0.3,
        diffuseStrength: 0.5,
        specularStrength: 1.0,
        glowEnabled: 0.0,
        glowIntensity: 0.6,
        glowThreshold: 0.85,
        glowColor: SIMD3<Float>(0.8, 0.9, 1.0),
        glowFalloff: 3.0
    )
    
    static let neon = RDColorScheme(
        colorA: SIMD3<Float>(0.0, 0.0, 0.0),
        colorB: SIMD3<Float>(1.0, 0.0, 1.0),
        colorC: SIMD3<Float>(0.0, 1.0, 1.0),
        mode: 1,
        intensity: 1.4,
        contrast: 1.5,
        lightPosition: SIMD3<Float>(0.5, 0.5, 1.8),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.3,
        shininess: 64.0,
        ambientStrength: 0.2,
        diffuseStrength: 0.8,
        specularStrength: 1.2,
        glowEnabled: 1.0,  // Neon has glow enabled by default!
        glowIntensity: 2.5,
        glowThreshold: 0.3,
        glowColor: SIMD3<Float>(1.0, 0.2, 1.0),
        glowFalloff: 1.0
    )
    
    static let blood = RDColorScheme(
        colorA: SIMD3<Float>(0.4, 0.0, 0.0),
        colorB: SIMD3<Float>(0.8, 0.3, 0.3),
        colorC: SIMD3<Float>(1.0, 0.9, 0.9),
        mode: 1,
        intensity: 1.0,
        contrast: 1.5,
        lightPosition: SIMD3<Float>(0.3, 0.7, 1.5),
        viewPosition: SIMD3<Float>(0.5, 0.5, 2.0),
        heightScale: 0.18,
        shininess: 30.0,
        ambientStrength: 0.5,
        diffuseStrength: 0.6,
        specularStrength: 0.4,
        glowEnabled: 0.0,
        glowIntensity: 1.0,
        glowThreshold: 0.8,
        glowColor: SIMD3<Float>(1.0, 0.4, 0.4),
        glowFalloff: 2.2
    )
}

// Enhanced settings with glow controls and resolution scaling
class RDSettings: ObservableObject {
    @Published var feedRate: Float = 0.055
    @Published var killRate: Float = 0.062
    @Published var diffusionA: Float = 1.0
    @Published var diffusionB: Float = 0.5
    @Published var deltaTime: Float = 1.0
    @Published var brushRadius: Float = 10.0
    @Published var diffusionRadius: Float = 3.0
    
    // 3D lighting controls
    @Published var heightScale: Float = 0.15
    @Published var shininess: Float = 32.0
    @Published var ambientStrength: Float = 0.4
    @Published var diffuseStrength: Float = 0.6
    @Published var specularStrength: Float = 0.5
    @Published var lightAngle: Float = 0.0
    
    // Glow controls - optimized for local concentration
    @Published var glowEnabled: Bool = false
    @Published var glowIntensity: Float = 0.8  // Reduced from 1.0
    @Published var glowThreshold: Float = 0.5  // Lower threshold for better response
    @Published var glowColor: SIMD3<Float> = SIMD3<Float>(1.0, 0.8, 0.4)
    @Published var glowFalloff: Float = 1.5    // Faster falloff for more localized glow
    
    // Brush state
    var brushPosition: SIMD2<Float> = .zero
    var brushStrength: Float = 0.0
    
    // Animation time
    var time: Float = 0.0
    
    // Simulation dimensions
    var width: Int32 = 1024
    var height: Int32 = 1024
    
    // Reference dimensions for consistent pattern scale
    let referenceWidth: Int32 = 1024
    let referenceHeight: Int32 = 1024
    
    // Calculate scaling factor based on current resolution
    var resolutionScale: Float {
        let avgScale = (Float(width) / Float(referenceWidth) + Float(height) / Float(referenceHeight)) / 2.0
        return avgScale
    }
    
    init() {
        loadPreset(RDPresetManager.shared.availablePresets[0])
    }
    
    func loadPreset(_ preset: RDPreset) {
        feedRate = preset.feedRate
        killRate = preset.killRate
        diffusionA = preset.diffusionA
        diffusionB = preset.diffusionB
        deltaTime = preset.deltaTime
    }
    
    func getMetalParams() -> ReactionDiffusionParameters {
        // Apply resolution scaling to spatial parameters
        let scaledBrushRadius = brushRadius * self.resolutionScale
        let scaledDiffusionRadius = diffusionRadius * self.resolutionScale
        
        return ReactionDiffusionParameters(
            feedRate: feedRate,
            killRate: killRate,
            diffusionA: diffusionA,
            diffusionB: diffusionB,
            deltaTime: deltaTime,
            brushRadius: scaledBrushRadius,
            brushPosition: brushPosition,
            brushStrength: brushStrength,
            time: time,
            width: width,
            height: height,
            diffusionRadius: scaledDiffusionRadius
        )
    }
    
    func randomize() {
        feedRate = Float.random(in: 0.01...0.06)
        killRate = Float.random(in: 0.045...0.065)
        diffusionA = 1.0
        diffusionB = Float.random(in: 0.4...0.6)
        deltaTime = Float.random(in: 0.8...1.2)
    }
    
    func updateSize(width: Int32, height: Int32) {
        self.width = max(64, min(4096, width))
        self.height = max(64, min(4096, height))
    }
}

// Preset manager
class RDPresetManager: ObservableObject {
    static let shared = RDPresetManager()
    
    @Published var availablePresets: [RDPreset] = []
    @Published var featuredPresets: [RDPreset] = []
    
    private init() {
        loadBuiltInPresets()
        setupFeaturedPresets()
    }
    
    private func loadBuiltInPresets() {
        availablePresets = [
            RDPreset(name: "Default", description: "Classic Gray-Scott pattern with stable spots", f: 0.055, k: 0.062),
            RDPreset(name: "Spots and Dots", description: "Circular spots that split and merge", f: 0.030, k: 0.062),
            RDPreset(name: "Stripes and Waves", description: "Interconnected stripe patterns", f: 0.025, k: 0.060),
            RDPreset(name: "Solitons", description: "Self-replicating wave pulses", f: 0.014, k: 0.054),
            RDPreset(name: "Worms", description: "Growing worm-like structures", f: 0.034, k: 0.056),
            RDPreset(name: "Coral", description: "Coral-like growth patterns", f: 0.0545, k: 0.062),
            RDPreset(name: "Zebrafish", description: "Zebrafish-inspired stripes", f: 0.026, k: 0.052),
            RDPreset(name: "Fingerprints", description: "Fingerprint-like whorls", f: 0.040, k: 0.060),
            RDPreset(name: "Spirals", description: "Rotating spiral waves", f: 0.018, k: 0.050),
            RDPreset(name: "Turing", description: "Classic Turing patterns", f: 0.042, k: 0.065),
            RDPreset(name: "Mitosis", description: "Cell division-like behavior", f: 0.028, k: 0.062),
            RDPreset(name: "Bubbles", description: "Bubble-like formations", f: 0.025, k: 0.055, dt: 0.9),
            RDPreset(name: "Maze", description: "Maze-like network structures", f: 0.029, k: 0.057),
            RDPreset(name: "Negative", description: "Inverted pattern dynamics", f: 0.018, k: 0.051),
            RDPreset(name: "Holes", description: "Pattern with stable holes", f: 0.039, k: 0.058),
        ]
    }
    
    private func setupFeaturedPresets() {
        featuredPresets = [
            availablePresets[0],
            availablePresets[1],
            availablePresets[2],
            availablePresets[3],
            availablePresets[4],
            availablePresets[5]
        ]
    }
    
    func getPreset(named name: String) -> RDPreset? {
        return availablePresets.first { $0.name == name }
    }
}
