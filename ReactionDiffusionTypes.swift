//
//  ReactionDiffusionTypes.swift
//  reaction-diffusion-metal
//
//  Created by suf on 13/09/2025.
//

import Foundation
import simd

// Reaction-Diffusion parameters structure for Metal buffer alignment
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
    var diffusionRadius: Float  // Changed from padding to diffusionRadius
}

// Preset structure for storing complete configurations
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

// Color scheme parameters
struct RDColorScheme {
    var colorA: SIMD3<Float>
    var colorB: SIMD3<Float>
    var colorC: SIMD3<Float>
    var mode: Int32
    var intensity: Float
    var contrast: Float
    
    static let organic = RDColorScheme(
        colorA: SIMD3<Float>(0.05, 0.05, 0.15),
        colorB: SIMD3<Float>(0.8, 0.6, 0.3),
        colorC: SIMD3<Float>(0.95, 0.95, 0.9),
        mode: 1, intensity: 1.0, contrast: 1.0
    )
    
    static let fire = RDColorScheme(
        colorA: SIMD3<Float>(0.1, 0.0, 0.0),
        colorB: SIMD3<Float>(1.0, 0.3, 0.0),
        colorC: SIMD3<Float>(1.0, 1.0, 0.8),
        mode: 1, intensity: 1.2, contrast: 1.1
    )
    
    static let ocean = RDColorScheme(
        colorA: SIMD3<Float>(0.0, 0.1, 0.3),
        colorB: SIMD3<Float>(0.0, 0.7, 0.9),
        colorC: SIMD3<Float>(0.8, 1.0, 1.0),
        mode: 1, intensity: 1.1, contrast: 1.0
    )
    
    static let grayscale = RDColorScheme(
        colorA: SIMD3<Float>(0, 0, 0),
        colorB: SIMD3<Float>(1, 1, 1),
        colorC: SIMD3<Float>(0.5, 0.5, 0.5),
        mode: 0, intensity: 1.0, contrast: 1.0
    )
}

// Preset manager to handle all reaction-diffusion presets
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
            // Classic Gray-Scott patterns
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
            
            // Experimental patterns
            RDPreset(name: "Maze", description: "Maze-like network structures", f: 0.029, k: 0.057),
            RDPreset(name: "Negative", description: "Inverted pattern dynamics", f: 0.018, k: 0.051),
            RDPreset(name: "Holes", description: "Pattern with stable holes", f: 0.039, k: 0.058),
        ]
    }
    
    private func setupFeaturedPresets() {
        // Focus on the most visually distinct and proven patterns
        featuredPresets = [
            availablePresets[0], // Coral
            availablePresets[1], // Maze
            availablePresets[2], // Spots and Dots
            availablePresets[3], // Waves
            availablePresets[4], // Worms
            availablePresets[5]  // Flicker
        ]
    }
    
    func getPreset(named name: String) -> RDPreset? {
        return availablePresets.first { $0.name == name }
    }
}

// Settings class for reaction-diffusion parameters
class RDSettings: ObservableObject {
    @Published var feedRate: Float = 0.055
    @Published var killRate: Float = 0.062
    @Published var diffusionA: Float = 1.0
    @Published var diffusionB: Float = 0.5
    @Published var deltaTime: Float = 1.0
    @Published var brushRadius: Float = 10.0
    @Published var diffusionRadius: Float = 3.0  // Add this

    // Brush state
    var brushPosition: SIMD2<Float> = .zero
    var brushStrength: Float = 0.0
    
    // Animation time
    var time: Float = 0.0
    
    // Simulation dimensions
    var width: Int32 = 1024
    var height: Int32 = 1024
    
    init() {
        loadPreset(RDPresetManager.shared.availablePresets[0]) // Load default
    }
    
    func loadPreset(_ preset: RDPreset) {
        feedRate = preset.feedRate
        killRate = preset.killRate
        diffusionA = preset.diffusionA
        diffusionB = preset.diffusionB
        deltaTime = preset.deltaTime
    }
    
    func getMetalParams() -> ReactionDiffusionParameters {
        return ReactionDiffusionParameters(
            feedRate: feedRate,
            killRate: killRate,
            diffusionA: diffusionA,
            diffusionB: diffusionB,
            deltaTime: deltaTime,
            brushRadius: brushRadius,
            brushPosition: brushPosition,
            brushStrength: brushStrength,
            time: time,
            width: width,
            height: height,
            diffusionRadius: diffusionRadius  // Changed from padding: 0.0
         )
    }
    
    // Generate interesting random parameters
    func randomize() {
        feedRate = Float.random(in: 0.01...0.06)
        killRate = Float.random(in: 0.045...0.065)
        diffusionA = 1.0  // Usually kept at 1.0
        diffusionB = Float.random(in: 0.4...0.6)
        deltaTime = Float.random(in: 0.8...1.2)
    }
    
    // Update simulation size
    func updateSize(width: Int32, height: Int32) {
        self.width = max(64, min(4096, width))
        self.height = max(64, min(4096, height))
    }
}
