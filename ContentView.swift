//
//  ContentView.swift
//  reaction-diffusion-metal
//
//  Created by suf on 13/09/2025.
//

import SwiftUI
import MetalKit

struct ContentView: View {
    @State private var metalRenderer: MetalRenderer? = nil
    @State private var controlPanelController: ControlPanelWindowController? = nil
    @State private var cinematicMode = false
    @State private var showPerformanceOverlay = true
    
    var body: some View {
        ZStack {
            if let renderer = metalRenderer {
                MetalViewWrapper(renderer: renderer)
                    .ignoresSafeArea()
                
                // Overlay controls - only show when not in cinematic mode
                if !cinematicMode {
                    OverlayControls(
                        showPerformanceOverlay: $showPerformanceOverlay,
                        renderer: renderer,
                        onShowControlPanel: { showControlPanel() }
                    )
                }
                
                // Performance overlay
                if showPerformanceOverlay && !cinematicMode {
                    PerformanceOverlay(renderer: renderer)
                }
            } else {
                // Loading state
                Rectangle()
                    .fill(Color.black)
                    .ignoresSafeArea()
                
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Initializing Reaction-Diffusion...")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 20)
                }
            }
        }
        .onAppear {
            setupMetal()
        }
        // Handle menu commands
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresetSpotsAndDots"))) { _ in
            metalRenderer?.changePreset("Spots and Dots")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresetStripesAndWaves"))) { _ in
            metalRenderer?.changePreset("Stripes and Waves")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresetCoral"))) { _ in
            metalRenderer?.changePreset("Coral")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresetFingerprints"))) { _ in
            metalRenderer?.changePreset("Fingerprints")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RandomizeParameters"))) { _ in
            metalRenderer?.randomizeParameters()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetSimulation"))) { _ in
            metalRenderer?.resetSimulation()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TogglePlayPause"))) { _ in
            metalRenderer?.togglePlayPause()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowControlPanel"))) { _ in
            showControlPanel()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleCinematicMode"))) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                cinematicMode.toggle()
            }
        }
    }
    
    private func setupMetal() {
        DispatchQueue.main.async {
            let mtkView = MTKView()
            metalRenderer = MetalRenderer(mtkView: mtkView)
            print("Metal setup completed in ContentView")
            
            // Show control panel by default after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !cinematicMode {
                    showControlPanel()
                }
            }
        }
    }
    
    private func showControlPanel() {
        guard let renderer = metalRenderer else { return }
        
        if controlPanelController == nil {
            controlPanelController = ControlPanelWindowController(renderer: renderer)
        }
        
        controlPanelController?.showWindow(nil)
        controlPanelController?.window?.orderFront(nil)
    }
}

// Wrapper for MTKView
struct MetalViewWrapper: NSViewRepresentable {
    let renderer: MetalRenderer
    
    func makeNSView(context: Context) -> MTKView {
        return renderer.mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Updates handled by renderer
    }
}

// Performance overlay showing FPS and simulation info
struct PerformanceOverlay: View {
    let renderer: MetalRenderer
    @State private var performanceInfo = "Initializing..."
    @State private var timer: Timer?
    
    var body: some View {
        VStack {
            HStack {
                Text(performanceInfo)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(6)
                    .padding(.leading, 10)
                    .padding(.top, 10)
                
                Spacer()
            }
            
            Spacer()
        }
        .onAppear {
            startPerformanceTimer()
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
    
    private func startPerformanceTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            performanceInfo = renderer.engine.getSimulationInfo()
        }
    }
}

// Simplified overlay controls
struct OverlayControls: View {
    @Binding var showPerformanceOverlay: Bool
    let renderer: MetalRenderer
    let onShowControlPanel: () -> Void
    @State private var showBasicControls = false
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                
                VStack(spacing: 10) {
                    // Control panel button
                    Button("Controls") {
                        onShowControlPanel()
                    }
                    .buttonStyle(OverlayButtonStyle())
                    
                    // Toggle for basic controls
                    Button(showBasicControls ? "Hide" : "Quick") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showBasicControls.toggle()
                        }
                    }
                    .buttonStyle(OverlayButtonStyle())
                    
                    if showBasicControls {
                        VStack(spacing: 8) {
                            Button("Reset") {
                                renderer.resetSimulation()
                            }
                            .buttonStyle(OverlayButtonStyle())
                            
                            Button("Random") {
                                renderer.randomizeParameters()
                            }
                            .buttonStyle(OverlayButtonStyle())
                            
                            Button(renderer.engine.isRunning ? "Pause" : "Play") {
                                renderer.togglePlayPause()
                            }
                            .buttonStyle(OverlayButtonStyle())
                            
                            Button("Info") {
                                showPerformanceOverlay.toggle()
                            }
                            .buttonStyle(OverlayButtonStyle())
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .padding(.trailing, 20)
                .padding(.top, 20)
            }
            
            Spacer()
            
            // Instructions at bottom
            if showBasicControls {
                VStack(spacing: 4) {
                    Text("• Click/drag to add chemical")
                    Text("• Right-click to reset")
                    Text("• Scroll to change brush size")
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.black.opacity(0.7))
                .cornerRadius(6)
                .padding(.bottom, 20)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
    }
}

// Button style for overlay controls
struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    ContentView()
}
