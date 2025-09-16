//
//  ReactionDiffusionEngine.swift - Complete with Glow
//  reaction-diffusion-metal
//

import Metal
import Foundation
import simd
import SwiftUI

class ReactionDiffusionEngine: ObservableObject {
    // MARK: - Properties
    
    // Metal components
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var simulationPipeline: MTLComputePipelineState!
    private var displayPipeline: MTLComputePipelineState!
    private var initializePipeline: MTLComputePipelineState!
    
    // Simulation textures
    private var textureA: MTLTexture!
    private var textureB: MTLTexture!
    private var displayTexture: MTLTexture!
    
    // Metal buffers
    private var parametersBuffer: MTLBuffer!
    private var colorSchemeBuffer: MTLBuffer!
    
    // Simulation state
    @Published var settings = RDSettings()
    private var currentTextureIndex = 0
    private var isInitialized = false
    @Published var isRunning = true
    
    // Performance tracking
    private var frameCount = 0
    private var lastFrameTime = CACurrentMediaTime()
    private(set) var currentFPS: Double = 0
    
    // Current color scheme
    private var currentColorScheme = RDColorScheme.organic
    
    // Animation state
    @Published var lightAnimationEnabled = false
    var lightAnimationSpeed: Float = 0.5
    
    // MARK: - Initialization
    
    init() {
        print("🚀 Initializing ReactionDiffusionEngine with 3D lighting and glow...")
        
        setupMetal()
        print("✅ Metal setup complete")
        
        setupTextures()
        print("✅ Textures created")
        
        setupBuffers()
        print("✅ Buffers created")
        
        setupPipelines()
        print("✅ Pipelines created")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let defaultPreset = RDPresetManager.shared.availablePresets.first {
                self.settings.loadPreset(defaultPreset)
                print("✅ Default preset loaded: \(defaultPreset.name)")
            }
            
            self.updateBuffers()
            self.initializeSimulation()
            self.isInitialized = true
            
            print("🎯 ReactionDiffusionEngine with glow initialized successfully")
        }
    }
    
    // MARK: - Metal Setup
    
    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        self.device = device
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create Metal command queue")
        }
        
        self.commandQueue = commandQueue
        commandQueue.label = "ReactionDiffusion.CommandQueue"
    }
    
    private func setupTextures() {
        let width = Int(settings.width)
        let height = Int(settings.height)
        
        let simDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        simDescriptor.usage = [.shaderRead, .shaderWrite]
        simDescriptor.storageMode = .private
        
        textureA = device.makeTexture(descriptor: simDescriptor)!
        textureB = device.makeTexture(descriptor: simDescriptor)!
        
        textureA.label = "ReactionDiffusion.TextureA"
        textureB.label = "ReactionDiffusion.TextureB"
        
        let displayDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba32Float,
            width: width,
            height: height,
            mipmapped: false
        )
        displayDescriptor.usage = [.shaderRead, .shaderWrite]
        displayDescriptor.storageMode = .private
        
        displayTexture = device.makeTexture(descriptor: displayDescriptor)!
        displayTexture.label = "ReactionDiffusion.DisplayTexture"
    }
    
    private func setupBuffers() {
        let parametersSize = MemoryLayout<ReactionDiffusionParameters>.stride
        parametersBuffer = device.makeBuffer(length: parametersSize, options: .storageModeShared)!
        parametersBuffer.label = "ReactionDiffusion.ParametersBuffer"
        
        let colorSchemeSize = MemoryLayout<RDColorScheme>.stride
        colorSchemeBuffer = device.makeBuffer(length: colorSchemeSize, options: .storageModeShared)!
        colorSchemeBuffer.label = "ReactionDiffusion.ColorSchemeBuffer"
        
        updateColorSchemeBuffer()
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create Metal library")
        }
        
        guard let simulationFunction = library.makeFunction(name: "reactionDiffusionStep") else {
            fatalError("Could not find reactionDiffusionStep function")
        }
        
        do {
            simulationPipeline = try device.makeComputePipelineState(function: simulationFunction)
        } catch {
            fatalError("Could not create simulation pipeline: \(error)")
        }
        
        guard let displayFunction = library.makeFunction(name: "renderReactionDiffusion") else {
            fatalError("Could not find renderReactionDiffusion function")
        }
        
        do {
            displayPipeline = try device.makeComputePipelineState(function: displayFunction)
        } catch {
            fatalError("Could not create display pipeline: \(error)")
        }
        
        guard let initFunction = library.makeFunction(name: "initializeReactionDiffusion") else {
            fatalError("Could not find initializeReactionDiffusion function")
        }
        
        do {
            initializePipeline = try device.makeComputePipelineState(function: initFunction)
        } catch {
            fatalError("Could not create initialize pipeline: \(error)")
        }
        
        print("Metal pipelines with glow support created successfully")
    }
    
    // MARK: - Buffer Updates
    
    private func updateBuffers() {
        updateParametersBuffer()
        updateColorSchemeBuffer()
    }
    
    private func updateParametersBuffer() {
        settings.time = Float(CACurrentMediaTime())
        let params = settings.getMetalParams()
        
        let parametersPointer = parametersBuffer.contents().bindMemory(to: ReactionDiffusionParameters.self, capacity: 1)
        parametersPointer[0] = params
    }
    
    private func updateColorSchemeBuffer() {
        var scheme = currentColorScheme
        
        // Apply current settings overrides
        scheme.heightScale = settings.heightScale
        scheme.shininess = settings.shininess
        scheme.ambientStrength = settings.ambientStrength
        scheme.diffuseStrength = settings.diffuseStrength
        scheme.specularStrength = settings.specularStrength
        
        // Apply glow settings
        scheme.glowEnabled = settings.glowEnabled ? 1.0 : 0.0
        scheme.glowIntensity = settings.glowIntensity
        scheme.glowThreshold = settings.glowThreshold
        scheme.glowColor = settings.glowColor
        scheme.glowFalloff = settings.glowFalloff
        
        // Animate light position if enabled
        if lightAnimationEnabled {
            let angle = settings.lightAngle
            scheme.lightPosition = SIMD3<Float>(
                0.5 + 0.3 * cos(angle),
                0.5 + 0.3 * sin(angle),
                1.5 + 0.5 * sin(angle * 0.5)
            )
            settings.lightAngle += lightAnimationSpeed * 0.02
        }
        
        let colorSchemePointer = colorSchemeBuffer.contents().bindMemory(to: RDColorScheme.self, capacity: 1)
        colorSchemePointer[0] = scheme
    }
    
    // MARK: - Simulation Control
    
    func step() {
        guard isInitialized && isRunning else { return }
        
        updateParametersBuffer()
        updateColorSchemeBuffer()
        
        let stepsPerFrame = 2
        for _ in 0..<stepsPerFrame {
            runSimulationStep()
        }
        
        runDisplayStep()
        updateFPS()
        
        settings.brushStrength = 0.0
    }
    
    private func runSimulationStep() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(simulationPipeline)
        
        let currentSim = currentTextureIndex == 0 ? textureA! : textureB!
        let nextSim = currentTextureIndex == 0 ? textureB! : textureA!
        
        encoder.setTexture(currentSim, index: 0)
        encoder.setTexture(nextSim, index: 1)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(settings.width) + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (Int(settings.height) + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        currentTextureIndex = 1 - currentTextureIndex
    }
    
    private func runDisplayStep() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(displayPipeline)
        
        let currentSim = currentTextureIndex == 0 ? textureA! : textureB!
        encoder.setTexture(currentSim, index: 0)
        encoder.setTexture(displayTexture, index: 1)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        encoder.setBuffer(colorSchemeBuffer, offset: 0, index: 1)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(settings.width) + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (Int(settings.height) + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
    }
    
    private func updateFPS() {
        frameCount += 1
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastFrameTime
        
        if deltaTime >= 1.0 {
            currentFPS = Double(frameCount) / deltaTime
            frameCount = 0
            lastFrameTime = currentTime
        }
    }
    
    // MARK: - Public Interface
    
    func initializeSimulation() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(initializePipeline)
        encoder.setTexture(textureA, index: 0)
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        
        let threadGroupSize = MTLSize(width: 16, height: 16, depth: 1)
        let threadGroups = MTLSize(
            width: (Int(settings.width) + threadGroupSize.width - 1) / threadGroupSize.width,
            height: (Int(settings.height) + threadGroupSize.height - 1) / threadGroupSize.height,
            depth: 1
        )
        
        encoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
        encoder.endEncoding()
        
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        currentTextureIndex = 0
        print("Simulation initialized with glow support")
    }
    
    func reset() {
        initializeSimulation()
        print("Simulation reset")
    }
    
    func changePreset(to presetName: String) {
        if let preset = RDPresetManager.shared.getPreset(named: presetName) {
            settings.loadPreset(preset)
            reset()
            print("Changed preset to: \(presetName)")
        }
    }
    
    func randomizeParameters() {
        settings.randomize()
        reset()
        print("Parameters randomized")
    }
    
    func togglePlayPause() {
        isRunning.toggle()
        print("Simulation \(isRunning ? "resumed" : "paused")")
    }
    
    func injectChemical(at point: CGPoint, radius: Float = 10.0, strength: Float = 1.0) {
        let texX = Float(point.x * CGFloat(settings.width))
        let texY = Float(point.y * CGFloat(settings.height))
        
        settings.brushPosition = SIMD2<Float>(texX, texY)
        // Note: brushRadius will be scaled in getMetalParams()
        settings.brushRadius = radius
        settings.brushStrength = strength
    }
    
    func getDisplayTexture() -> MTLTexture {
        return displayTexture
    }
    
    func updateSize(width: Int32, height: Int32) {
        settings.updateSize(width: width, height: height)
        setupTextures()
        reset()
        print("Simulation size updated to: \(width)×\(height)")
    }
    
    // MARK: - Color Scheme Management
    
    func setColorScheme(_ scheme: RDColorScheme) {
        currentColorScheme = scheme
        // Preserve user's glow settings if they've customized them
        if settings.glowEnabled {
            settings.glowColor = scheme.glowColor
        }
        updateColorSchemeBuffer()
    }
    
    func setPresetColorScheme(named name: String) {
        let scheme: RDColorScheme
        
        switch name {
        case "Organic":
            scheme = RDColorScheme.organic
        case "Fire":
            scheme = RDColorScheme.fire
        case "Ocean":
            scheme = RDColorScheme.ocean
        case "Grayscale":
            scheme = RDColorScheme.grayscale
        case "Electric":
            scheme = RDColorScheme.electric
        case "Sunset":
            scheme = RDColorScheme.sunset
        case "Metallic":
            scheme = RDColorScheme.metallic
        case "Neon":
            scheme = RDColorScheme.neon
            settings.glowEnabled = true  // Auto-enable glow for Neon
        case "Blood":
            scheme = RDColorScheme.blood
        default:
            scheme = RDColorScheme.organic
        }
        
        setColorScheme(scheme)
        print("Color scheme changed to: \(name) with glow support")
    }
    
    // MARK: - Lighting & Glow Controls
    
    func toggleLightAnimation() {
        lightAnimationEnabled.toggle()
        updateColorSchemeBuffer()
        print("Light animation \(lightAnimationEnabled ? "enabled" : "disabled")")
    }
    
    func setLightAnimationSpeed(_ speed: Float) {
        lightAnimationSpeed = max(0.1, min(2.0, speed))
        updateColorSchemeBuffer()
    }
    
    func toggleGlow() {
        settings.glowEnabled.toggle()
        updateColorSchemeBuffer()
        print("Glow \(settings.glowEnabled ? "enabled" : "disabled")")
    }
    
    func updateGlowParameters(intensity: Float? = nil,
                             threshold: Float? = nil,
                             falloff: Float? = nil,
                             color: SIMD3<Float>? = nil) {
        if let i = intensity { settings.glowIntensity = i }
        if let t = threshold { settings.glowThreshold = t }
        if let f = falloff { settings.glowFalloff = f }
        if let c = color { settings.glowColor = c }
        
        updateColorSchemeBuffer()
    }
    
    func updateLightingParameters(heightScale: Float? = nil,
                                 shininess: Float? = nil,
                                 ambient: Float? = nil,
                                 diffuse: Float? = nil,
                                 specular: Float? = nil) {
        if let h = heightScale { settings.heightScale = h }
        if let s = shininess { settings.shininess = s }
        if let a = ambient { settings.ambientStrength = a }
        if let d = diffuse { settings.diffuseStrength = d }
        if let sp = specular { settings.specularStrength = sp }
        
        updateColorSchemeBuffer()
    }
    
    func forceUpdateLighting() {
        updateColorSchemeBuffer()
    }
    
    func getSimulationInfo() -> String {
        let glowStatus = settings.glowEnabled ? "ON" : "OFF"
        return String(format: "FPS: %.1f | %dx%d | %@ | GPU: %@ | 3D: ON | Glow: %@",
                     currentFPS,
                     Int(settings.width),
                     Int(settings.height),
                     isRunning ? "Running" : "Paused",
                     device.name,
                     glowStatus)
    }
}
