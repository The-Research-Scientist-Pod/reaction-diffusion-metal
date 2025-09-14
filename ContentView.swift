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
                // Metal view always visible
                MetalViewWrapper(renderer: renderer)
                    .ignoresSafeArea()
                
                // Overlay controls - only show when NOT in cinematic mode
                if !cinematicMode {
                    VStack {
                        // Top-right controls
                        HStack {
                            Spacer()
                            
                            OverlayControls(
                                showPerformanceOverlay: $showPerformanceOverlay,
                                cinematicMode: $cinematicMode,
                                renderer: renderer,
                                onShowControlPanel: { showControlPanel() }
                            )
                        }
                        
                        Spacer()
                        
                        // Bottom instructions
                        HStack {
                            Spacer()
                            
                            InstructionsOverlay()
                                .padding(.bottom, 20)
                                .padding(.trailing, 20)
                        }
                    }
                    
                    // Performance overlay in top-left
                    if showPerformanceOverlay {
                        VStack {
                            HStack {
                                PerformanceOverlay(renderer: renderer)
                                    .padding(.leading, 10)
                                    .padding(.top, 10)
                                
                                Spacer()
                            }
                            
                            Spacer()
                        }
                    }
                }
            } else {
                // Loading state
                LoadingView()
            }
        }
        .onAppear {
            setupMetal()
        }
        // Handle all notifications
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresetSpotsAndDots"))) { _ in
            metalRenderer?.changePreset("Spots and Dots")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresetStripesAndWaves"))) { _ in
            metalRenderer?.changePreset("Stripes and Waves")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PresetCoral"))) { _ in
            metalRenderer?.changePreset("Coral Growth")
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
                // Update control panel if it exists
                if let controller = controlPanelController {
                    controller.updateCinematicMode(cinematicMode)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SetCinematicMode"))) { notification in
            if let enabled = notification.userInfo?["enabled"] as? Bool {
                withAnimation(.easeInOut(duration: 0.3)) {
                    cinematicMode = enabled
                }
            }
        }
    }
    
    private func setupMetal() {
        DispatchQueue.main.async {
            let mtkView = MTKView()
            metalRenderer = MetalRenderer(mtkView: mtkView)
            print("Metal setup completed")
            
            // Show control panel after a short delay
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
            controlPanelController = ControlPanelWindowController(
                renderer: renderer,
                cinematicMode: cinematicMode
            )
        }
        
        controlPanelController?.showWindow(nil)
        controlPanelController?.window?.orderFront(nil)
    }
}

// MARK: - Supporting Views

struct LoadingView: View {
    var body: some View {
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

struct MetalViewWrapper: NSViewRepresentable {
    let renderer: MetalRenderer
    
    func makeNSView(context: Context) -> MTKView {
        return renderer.mtkView
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Updates handled by renderer
    }
}

struct PerformanceOverlay: View {
    let renderer: MetalRenderer
    @State private var performanceInfo = "Initializing..."
    @State private var timer: Timer?
    
    var body: some View {
        Text(performanceInfo)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(.white)
            .padding(8)
            .background(Color.black.opacity(0.7))
            .cornerRadius(6)
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

struct OverlayControls: View {
    @Binding var showPerformanceOverlay: Bool
    @Binding var cinematicMode: Bool
    let renderer: MetalRenderer
    let onShowControlPanel: () -> Void
    @State private var showQuickControls = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Main controls button
            Button {
                onShowControlPanel()
            } label: {
                Label("Controls", systemImage: "slider.horizontal.3")
            }
            .buttonStyle(OverlayButtonStyle())
            
            // Quick controls toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showQuickControls.toggle()
                }
            } label: {
                Image(systemName: showQuickControls ? "chevron.up" : "chevron.down")
                    .frame(width: 80)
            }
            .buttonStyle(OverlayButtonStyle())
            
            // Quick controls panel
            if showQuickControls {
                VStack(spacing: 8) {
                    Button {
                        renderer.resetSimulation()
                    } label: {
                        Label("Reset", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(OverlayButtonStyle())
                    
                    Button {
                        renderer.randomizeParameters()
                    } label: {
                        Label("Random", systemImage: "dice")
                    }
                    .buttonStyle(OverlayButtonStyle())
                    
                    Button {
                        renderer.togglePlayPause()
                    } label: {
                        Label(renderer.engine.isRunning ? "Pause" : "Play",
                              systemImage: renderer.engine.isRunning ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(OverlayButtonStyle())
                    
                    Divider()
                        .frame(width: 60)
                    
                    Button {
                        showPerformanceOverlay.toggle()
                    } label: {
                        Label("Stats", systemImage: showPerformanceOverlay ? "eye.slash" : "eye")
                    }
                    .buttonStyle(OverlayButtonStyle())
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            cinematicMode = true
                        }
                    } label: {
                        Label("Cinema", systemImage: "tv")
                    }
                    .buttonStyle(OverlayButtonStyle())
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(.trailing, 20)
        .padding(.top, 20)
    }
}

struct InstructionsOverlay: View {
    @State private var showInstructions = true
    
    var body: some View {
        if showInstructions {
            VStack(spacing: 4) {
                HStack {
                    Text("Controls")
                        .font(.caption)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button {
                        withAnimation {
                            showInstructions = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("• Click/drag: Add chemical")
                    Text("• Right-click: Reset")
                    Text("• Scroll: Change brush size")
                    Text("• Space: Quick reset")
                    Text("• Cmd+F: Cinematic mode")
                    Text("• Cmd+C: Control panel")
                }
                .font(.caption2)
            }
            .foregroundColor(.white)
            .padding(10)
            .background(Color.black.opacity(0.7))
            .cornerRadius(8)
            .frame(maxWidth: 180)
        }
    }
}

struct OverlayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(minWidth: 80)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(configuration.isPressed ? 0.8 : 0.6))
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
