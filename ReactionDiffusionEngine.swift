//
//  ReactionDiffusionEngine.swift
//  reaction-diffusion-metal
//
//  Created by suf on 13/09/2025.
//

import Metal
import Foundation
import simd
import SwiftUI

class ReactionDiffusionEngine: ObservableObject {
    // Metal components
    private var device: MTLDevice!
    private var commandQueue: MTLCommandQueue!
    private var simulationPipeline: MTLComputePipelineState!
    private var displayPipeline: MTLComputePipelineState!
    private var initializePipeline: MTLComputePipelineState!
    
    // Simulation textures (double-buffered)
    private var textureA: MTLTexture!
    private var textureB: MTLTexture!
    private var displayTexture: MTLTexture!
    
    // Metal buffers
    private var parametersBuffer: MTLBuffer!
    private var colorSchemeBuffer: MTLBuffer!
    
    // Simulation state
    @Published var settings = RDSettings()
    private var currentTextureIndex = 0  // 0 for A, 1 for B
    private var isInitialized = false
    @Published var isRunning = true
    
    // Performance tracking
    private var frameCount = 0
    private var lastFrameTime = CACurrentMediaTime()
    private(set) var currentFPS: Double = 0
    
    // Current color scheme
    private var currentColorScheme = RDColorScheme.organic
    
    init() {
        print("🚀 Initializing ReactionDiffusionEngine...")
        
        setupMetal()
        print("✅ Metal setup complete")
        
        setupTextures()
        print("✅ Textures created")
        
        setupBuffers()
        print("✅ Buffers created")
        
        setupPipelines()
        print("✅ Pipelines created")
        
        // Initialize with default preset - safely
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            if let defaultPreset = RDPresetManager.shared.availablePresets.first {
                self.settings.loadPreset(defaultPreset)
                print("✅ Default preset loaded: \(defaultPreset.name)")
            }
            
            self.updateBuffers()
            self.initializeSimulation()
            self.isInitialized = true
            
            print("🎯 ReactionDiffusionEngine initialized successfully")
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
        
        // Simulation textures - RG32Float for U and V chemicals
        let simDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rg32Float,
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
        
        // Display texture - RGBA8Unorm for display
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
        // Parameters buffer
        let parametersSize = MemoryLayout<ReactionDiffusionParameters>.stride
        parametersBuffer = device.makeBuffer(length: parametersSize, options: .storageModeShared)!
        parametersBuffer.label = "ReactionDiffusion.ParametersBuffer"
        
        // Color scheme buffer
        let colorSchemeSize = MemoryLayout<RDColorScheme>.stride
        colorSchemeBuffer = device.makeBuffer(length: colorSchemeSize, options: .storageModeShared)!
        colorSchemeBuffer.label = "ReactionDiffusion.ColorSchemeBuffer"
        
        updateColorSchemeBuffer()
    }
    
    private func setupPipelines() {
        guard let library = device.makeDefaultLibrary() else {
            fatalError("Could not create Metal library")
        }
        
        // Simulation pipeline
        guard let simulationFunction = library.makeFunction(name: "reactionDiffusionStep") else {
            fatalError("Could not find reactionDiffusionStep function")
        }
        
        do {
            simulationPipeline = try device.makeComputePipelineState(function: simulationFunction)
        } catch {
            fatalError("Could not create simulation pipeline: \(error)")
        }
        
        // Display pipeline
        guard let displayFunction = library.makeFunction(name: "renderReactionDiffusion") else {
            fatalError("Could not find renderReactionDiffusion function")
        }
        
        do {
            displayPipeline = try device.makeComputePipelineState(function: displayFunction)
        } catch {
            fatalError("Could not create display pipeline: \(error)")
        }
        
        // Initialize pipeline
        guard let initFunction = library.makeFunction(name: "initializeReactionDiffusion") else {
            fatalError("Could not find initializeReactionDiffusion function")
        }
        
        do {
            initializePipeline = try device.makeComputePipelineState(function: initFunction)
        } catch {
            fatalError("Could not create initialize pipeline: \(error)")
        }
        
        print("Metal pipelines created successfully")
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
        
        // Debug output to verify parameters are updating
        print("Parameters: F=\(params.feedRate), K=\(params.killRate), Da=\(params.diffusionA), Db=\(params.diffusionB), dt=\(params.deltaTime)")
    }
    
    private func updateColorSchemeBuffer() {
        let colorSchemePointer = colorSchemeBuffer.contents().bindMemory(to: RDColorScheme.self, capacity: 1)
        colorSchemePointer[0] = currentColorScheme
    }
    
    // MARK: - Simulation Control
    
    func step() {
        guard isInitialized && isRunning else { return }
        
        updateParametersBuffer()
        
        // Run multiple simulation steps per frame for better temporal resolution
        // This matches how the Python version runs many timesteps
        let stepsPerFrame = 2
        for _ in 0..<stepsPerFrame {
            runSimulationStep()
        }
        
        // Run display step
        runDisplayStep()
        
        // Update performance
        updateFPS()
        
        // Reset brush strength after each frame
        settings.brushStrength = 0.0
    }
    
    private func runSimulationStep() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(simulationPipeline)
        
        // Set textures - double buffering
        let currentSim = currentTextureIndex == 0 ? textureA! : textureB!
        let nextSim = currentTextureIndex == 0 ? textureB! : textureA!
        
        encoder.setTexture(currentSim, index: 0)  // Read from current
        encoder.setTexture(nextSim, index: 1)     // Write to next
        
        // Set parameters buffer
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        
        // Dispatch threads
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
        
        // Swap buffers
        currentTextureIndex = 1 - currentTextureIndex
    }
    
    private func runDisplayStep() {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        encoder.setComputePipelineState(displayPipeline)
        
        // Set textures
        let currentSim = currentTextureIndex == 0 ? textureA! : textureB!
        encoder.setTexture(currentSim, index: 0)        // Read from simulation
        encoder.setTexture(displayTexture, index: 1)    // Write to display
        
        // Set buffers
        encoder.setBuffer(parametersBuffer, offset: 0, index: 0)
        encoder.setBuffer(colorSchemeBuffer, offset: 0, index: 1)
        
        // Dispatch threads
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
        print("Simulation initialized")
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
        // Convert normalized coordinates to texture coordinates
        let texX = Float(point.x * CGFloat(settings.width))
        let texY = Float(point.y * CGFloat(settings.height))
        
        settings.brushPosition = SIMD2<Float>(texX, texY)
        settings.brushRadius = radius
        settings.brushStrength = strength
    }
    
    // Get the current display texture for rendering
    func getDisplayTexture() -> MTLTexture {
        return displayTexture
    }
    
    // Update texture size (for window resizing)
    func updateSize(width: Int32, height: Int32) {
        settings.updateSize(width: width, height: height)
        setupTextures()
        reset()
        print("Simulation size updated to: \(width)×\(height)")
    }
    
    // MARK: - Color Scheme Management
    
    func setColorScheme(_ scheme: RDColorScheme) {
        currentColorScheme = scheme
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
            scheme = RDColorScheme(
                colorA: SIMD3<Float>(0.1, 0.0, 0.5),
                colorB: SIMD3<Float>(0.0, 1.0, 1.0),
                colorC: SIMD3<Float>(1.0, 1.0, 1.0),
                mode: 1, intensity: 1.3, contrast: 1.4
            )
        case "Sunset":
            scheme = RDColorScheme(
                colorA: SIMD3<Float>(0.2, 0.0, 0.4),
                colorB: SIMD3<Float>(1.0, 0.4, 0.0),
                colorC: SIMD3<Float>(1.0, 1.0, 0.8),
                mode: 1, intensity: 1.1, contrast: 1.2
            )
        default:
            scheme = RDColorScheme.organic
        }
        
        setColorScheme(scheme)
        print("Color scheme changed to: \(name)")
    }
    
    func getSimulationInfo() -> String {
        return String(format: "FPS: %.1f | %dx%d | %@ | GPU: %@",
                     currentFPS,
                     Int(settings.width),
                     Int(settings.height),
                     isRunning ? "Running" : "Paused",
                     device.name)
    }
}
