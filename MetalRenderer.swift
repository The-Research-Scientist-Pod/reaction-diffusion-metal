//
//  MetalRenderer.swift
//  reaction-diffusion-metal
//
//  Created by suf on 13/09/2025.
//

import Metal
import MetalKit
import SwiftUI

class MetalRenderer: NSObject, MTKViewDelegate, ObservableObject {
    var mtkView: MTKView
    var device: MTLDevice
    var commandQueue: MTLCommandQueue
    var renderPipelineState: MTLRenderPipelineState
    var vertexBuffer: MTLBuffer
    var engine: ReactionDiffusionEngine
    
    // Mouse interaction state
    private var lastMouseLocation: CGPoint = .zero
    private var isMouseDown = false
    
    init(mtkView: MTKView) {
        // Setup Metal device
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Metal is not supported on this device")
        }
        
        guard let commandQueue = device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        
        self.mtkView = mtkView
        self.device = device
        self.commandQueue = commandQueue
        
        // Create simulation engine
        self.engine = ReactionDiffusionEngine()
        
        // Setup vertex buffer for full-screen quad
        let vertices: [Float] = [
            // Position (x, y)  TexCoord (u, v)
            -1.0, -1.0,         0.0, 1.0,  // Bottom-left
             1.0, -1.0,         1.0, 1.0,  // Bottom-right
            -1.0,  1.0,         0.0, 0.0,  // Top-left
             1.0,  1.0,         1.0, 0.0,  // Top-right
        ]
        
        guard let vertexBuffer = device.makeBuffer(bytes: vertices,
                                                 length: vertices.count * MemoryLayout<Float>.stride,
                                                 options: .storageModeShared) else {
            fatalError("Could not create vertex buffer")
        }
        self.vertexBuffer = vertexBuffer
        vertexBuffer.label = "QuadVertexBuffer"
        
        // Setup render pipeline
        guard let library = device.makeDefaultLibrary(),
              let vertexFunction = library.makeFunction(name: "vertex_main"),
              let fragmentFunction = library.makeFunction(name: "fragment_main") else {
            fatalError("Could not load shader functions")
        }
        
        let pipelineDescriptor = MTLRenderPipelineDescriptor()
        pipelineDescriptor.vertexFunction = vertexFunction
        pipelineDescriptor.fragmentFunction = fragmentFunction
        pipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        
        do {
            self.renderPipelineState = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
        } catch {
            fatalError("Could not create render pipeline state: \(error)")
        }
        
        super.init()
        
        // Configure MTKView
        mtkView.device = device
        mtkView.delegate = self
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        mtkView.framebufferOnly = false
        
        // Setup mouse tracking
        setupMouseTracking()
        
        print("MetalRenderer initialized successfully")
    }
    
    private func setupMouseTracking() {
        mtkView.wantsLayer = true
        
        // Add click gesture recognizer
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick(_:)))
        mtkView.addGestureRecognizer(clickGesture)
        
        // Add pan gesture for drawing
        let panGesture = NSPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        mtkView.addGestureRecognizer(panGesture)
        
        // Add right-click for reset
        let rightClickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleRightClick(_:)))
        rightClickGesture.buttonMask = 0x2  // Right mouse button
        mtkView.addGestureRecognizer(rightClickGesture)
    }
    
    @objc private func handleClick(_ gesture: NSClickGestureRecognizer) {
        let location = gesture.location(in: mtkView)
        let normalizedPoint = normalizePoint(location)
        engine.injectChemical(at: normalizedPoint, radius: engine.settings.brushRadius, strength: 1.0)
    }
    
    @objc private func handlePan(_ gesture: NSPanGestureRecognizer) {
        let location = gesture.location(in: mtkView)
        let normalizedPoint = normalizePoint(location)
        
        switch gesture.state {
        case .began:
            isMouseDown = true
            lastMouseLocation = normalizedPoint
            engine.injectChemical(at: normalizedPoint, radius: engine.settings.brushRadius, strength: 1.0)
            
        case .changed:
            if isMouseDown {
                // Smooth drawing by interpolating between points
                let steps = Int(max(1, distance(from: lastMouseLocation, to: normalizedPoint) * 100))
                for i in 0...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let interpolatedPoint = CGPoint(
                        x: lastMouseLocation.x + (normalizedPoint.x - lastMouseLocation.x) * t,
                        y: lastMouseLocation.y + (normalizedPoint.y - lastMouseLocation.y) * t
                    )
                    engine.injectChemical(at: interpolatedPoint, radius: engine.settings.brushRadius, strength: 0.8)
                }
                lastMouseLocation = normalizedPoint
            }
            
        case .ended, .cancelled:
            isMouseDown = false
            
        default:
            break
        }
    }
    
    @objc private func handleRightClick(_ gesture: NSClickGestureRecognizer) {
        engine.reset()
    }
    
    private func normalizePoint(_ point: CGPoint) -> CGPoint {
        return CGPoint(
            x: point.x / mtkView.bounds.width,
            y: 1.0 - (point.y / mtkView.bounds.height)  // Flip Y coordinate
        )
    }
    
    private func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // MARK: - MTKViewDelegate
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        print("MTKView size changed to: \(size.width)×\(size.height)")
    }
    
    func draw(in view: MTKView) {
        // Step simulation
        engine.step()
        
        // Render to screen
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let renderPassDescriptor = view.currentRenderPassDescriptor,
              let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }
        
        // Set render state
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setFragmentTexture(engine.getDisplayTexture(), index: 0)
        
        // Draw full-screen quad
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
        
        // Present
        if let drawable = view.currentDrawable {
            commandBuffer.present(drawable)
        }
        
        commandBuffer.commit()
    }
    
    // MARK: - Public Interface
    
    func changePreset(_ preset: String) {
        engine.changePreset(to: preset)
        print("Changed to preset: \(preset)")
    }
    
    func randomizeParameters() {
        engine.randomizeParameters()
        print("Parameters randomized")
    }
    
    func resetSimulation() {
        engine.reset()
        print("Reset simulation")
    }
    
    func togglePlayPause() {
        engine.togglePlayPause()
        print("Toggled play/pause")
    }
    
    func setResolution(width: Int32, height: Int32) {
        engine.updateSize(width: width, height: height)
        print("Simulation resolution set to: \(width)×\(height)")
        
        // Resize the window to match and center it
        DispatchQueue.main.async { [weak self] in
            if let window = self?.mtkView.window {
                let screen = window.screen ?? NSScreen.main!
                let screenFrame = screen.visibleFrame
                
                let newSize = NSSize(width: Int(width), height: Int(height))
                let centerX = screenFrame.midX - newSize.width / 2
                let centerY = screenFrame.midY - newSize.height / 2
                
                let newFrame = NSRect(x: centerX, y: centerY, width: newSize.width, height: newSize.height)
                window.setFrame(newFrame, display: true, animate: true)
                
                print("Window resized and centered at: \(width)×\(height)")
            }
        }
    }
    
    func setColorScheme(_ schemeName: String) {
        engine.setPresetColorScheme(named: schemeName)
        print("Color scheme changed to: \(schemeName)")
    }
    
    func captureScreenshot() {
        let displayTexture = engine.getDisplayTexture()
        let width = displayTexture.width
        let height = displayTexture.height
        
        print("Capturing screenshot: \(width)×\(height)")
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            print("Failed to create command buffer for screenshot")
            return
        }
        
        let bytesPerPixel = 16 // RGBA32Float = 4 * 4 bytes
        let bytesPerRow = width * bytesPerPixel
        let bufferSize = height * bytesPerRow
        
        guard let buffer = device.makeBuffer(length: bufferSize, options: .storageModeShared) else {
            print("Failed to create buffer for screenshot")
            return
        }
        
        guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
            print("Failed to create blit encoder")
            return
        }
        
        blitEncoder.copy(from: displayTexture,
                        sourceSlice: 0,
                        sourceLevel: 0,
                        sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                        sourceSize: MTLSize(width: width, height: height, depth: 1),
                        to: buffer,
                        destinationOffset: 0,
                        destinationBytesPerRow: bytesPerRow,
                        destinationBytesPerImage: bufferSize)
        
        blitEncoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        
        saveBufferAsImage(buffer: buffer, width: width, height: height)
    }
    
    private func saveBufferAsImage(buffer: MTLBuffer, width: Int, height: Int) {
        let rawData = buffer.contents().bindMemory(to: Float.self, capacity: width * height * 4)
        
        var imageData = Data()
        imageData.reserveCapacity(width * height * 4)
        
        for i in 0..<(width * height) {
            let r = max(0.0, min(1.0, rawData[i * 4 + 0]))
            let g = max(0.0, min(1.0, rawData[i * 4 + 1]))
            let b = max(0.0, min(1.0, rawData[i * 4 + 2]))
            let a = max(0.0, min(1.0, rawData[i * 4 + 3]))
            
            imageData.append(UInt8(r * 255.0))
            imageData.append(UInt8(g * 255.0))
            imageData.append(UInt8(b * 255.0))
            imageData.append(UInt8(a * 255.0))
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let provider = CGDataProvider(data: imageData as CFData),
              let cgImage = CGImage(width: width,
                                   height: height,
                                   bitsPerComponent: 8,
                                   bitsPerPixel: 32,
                                   bytesPerRow: width * 4,
                                   space: colorSpace,
                                   bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
                                   provider: provider,
                                   decode: nil,
                                   shouldInterpolate: false,
                                   intent: .defaultIntent) else {
            print("Failed to create CGImage from data")
            return
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmapRep = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            print("Failed to convert to PNG data")
            return
        }
        
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "reaction_diffusion_\(width)x\(height)_\(timestamp).png"
        let fileURL = desktopURL.appendingPathComponent(filename)
        
        do {
            try pngData.write(to: fileURL)
            print("Screenshot saved: \(fileURL.path)")
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: desktopURL.path)
        } catch {
            print("Failed to save screenshot: \(error)")
        }
    }
    
    func getDisplayTexture() -> MTLTexture? {
        return engine.getDisplayTexture()
    }
}
