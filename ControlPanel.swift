//
//  ControlPanel.swift
//  reaction-diffusion-metal
//
//  Created by suf on 13/09/2025.
//

import SwiftUI
import AppKit

// Detachable control panel as a separate window
class ControlPanelWindowController: NSWindowController {
    convenience init(renderer: MetalRenderer) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Reaction-Diffusion Controls"
        window.contentView = NSHostingView(rootView: RDControlPanelContent(renderer: renderer))
        window.isReleasedWhenClosed = false
        window.center()
        
        self.init(window: window)
    }
}

// The actual control panel content
struct RDControlPanelContent: View {
    let renderer: MetalRenderer
    @State private var selectedPreset = "Default"
    @State private var selectedColorScheme = "Organic"
    @State private var showAllPresets = false
    @ObservedObject private var presetManager = RDPresetManager.shared
    @ObservedObject private var settings: RDSettings
    
    init(renderer: MetalRenderer) {
        self.renderer = renderer
        self.settings = renderer.engine.settings
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Title
                Text("Reaction-Diffusion Controls")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top, 10)
                
                Divider()
                
                // Preset selection
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Presets")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(showAllPresets ? "Featured" : "All") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showAllPresets.toggle()
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    let presetsToShow = showAllPresets ? presetManager.availablePresets : presetManager.featuredPresets
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        ForEach(presetsToShow, id: \.name) { preset in
                            Button(preset.name) {
                                selectedPreset = preset.name
                                renderer.changePreset(preset.name)
                            }
                            .buttonStyle(PresetButtonStyle(isSelected: selectedPreset == preset.name))
                        }
                    }
                    
                    // Preset info
                    if let preset = presetManager.getPreset(named: selectedPreset) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(preset.name)
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            if !preset.description.isEmpty {
                                Text(preset.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            Text("F: \(preset.feedRate, specifier: "%.3f") • K: \(preset.killRate, specifier: "%.3f")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(6)
                    }
                }
                
                Divider()
                
                // Parameter controls
                VStack(alignment: .leading, spacing: 15) {
                    Text("Parameters")
                        .font(.headline)
                    
                    // Feed Rate
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Feed Rate (F)")
                                .font(.caption)
                            Spacer()
                            Text("\(settings.feedRate, specifier: "%.3f")")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.feedRate, in: 0.0...0.1, step: 0.001)
                            .accentColor(.blue)
                            .onChange(of: settings.feedRate) { _ in
                                print("Feed rate changed to: \(settings.feedRate)")
                            }
                    }
                    
                    // Kill Rate
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Kill Rate (K)")
                                .font(.caption)
                            Spacer()
                            Text("\(settings.killRate, specifier: "%.3f")")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.killRate, in: 0.03...0.07, step: 0.001)
                            .accentColor(.red)
                            .onChange(of: settings.killRate) { _ in
                                print("Kill rate changed to: \(settings.killRate)")
                            }
                    }
                    
                    // Diffusion A
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Diffusion A (Da)")
                                .font(.caption)
                            Spacer()
                            Text("\(settings.diffusionA, specifier: "%.2f")")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.diffusionA, in: 0.0...2.0, step: 0.1)
                            .accentColor(.green)
                            .onChange(of: settings.diffusionA) { _ in
                                print("Diffusion A changed to: \(settings.diffusionA)")
                            }
                    }
                    
                    // Diffusion B
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Diffusion B (Db)")
                                .font(.caption)
                            Spacer()
                            Text("\(settings.diffusionB, specifier: "%.2f")")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.diffusionB, in: 0.0...2.0, step: 0.1)
                            .accentColor(.orange)
                            .onChange(of: settings.diffusionB) { _ in
                                print("Diffusion B changed to: \(settings.diffusionB)")
                            }
                    }
                    
                    // Time Step
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Time Step (Δt)")
                                .font(.caption)
                            Spacer()
                            Text("\(settings.deltaTime, specifier: "%.2f")")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.deltaTime, in: 0.1...2.0, step: 0.1)
                            .accentColor(.purple)
                    }
                    
                    // Brush Size
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Brush Size")
                                .font(.caption)
                            Spacer()
                            Text("\(settings.brushRadius, specifier: "%.0f")")
                                .font(.caption.monospacedDigit())
                                .foregroundColor(.secondary)
                        }
                        
                        Slider(value: $settings.brushRadius, in: 5.0...50.0, step: 1.0)
                            .accentColor(.cyan)
                    }
                }
                
                Divider()
                
                // Color scheme controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Color Scheme")
                        .font(.headline)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
                        Button("Organic") {
                            selectedColorScheme = "Organic"
                            renderer.setColorScheme("Organic")
                        }
                        .buttonStyle(ColorButtonStyle(isSelected: selectedColorScheme == "Organic"))
                        
                        Button("Fire") {
                            selectedColorScheme = "Fire"
                            renderer.setColorScheme("Fire")
                        }
                        .buttonStyle(ColorButtonStyle(isSelected: selectedColorScheme == "Fire"))
                        
                        Button("Ocean") {
                            selectedColorScheme = "Ocean"
                            renderer.setColorScheme("Ocean")
                        }
                        .buttonStyle(ColorButtonStyle(isSelected: selectedColorScheme == "Ocean"))
                        
                        Button("Grayscale") {
                            selectedColorScheme = "Grayscale"
                            renderer.setColorScheme("Grayscale")
                        }
                        .buttonStyle(ColorButtonStyle(isSelected: selectedColorScheme == "Grayscale"))
                        
                        Button("Electric") {
                            selectedColorScheme = "Electric"
                            renderer.setColorScheme("Electric")
                        }
                        .buttonStyle(ColorButtonStyle(isSelected: selectedColorScheme == "Electric"))
                        
                        Button("Sunset") {
                            selectedColorScheme = "Sunset"
                            renderer.setColorScheme("Sunset")
                        }
                        .buttonStyle(ColorButtonStyle(isSelected: selectedColorScheme == "Sunset"))
                    }
                }
                
                Divider()
                
                // Simulation controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Simulation")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        Button(renderer.engine.isRunning ? "Pause" : "Play") {
                            renderer.togglePlayPause()
                        }
                        .buttonStyle(ActionButtonStyle())
                        
                        Button("Reset") {
                            renderer.resetSimulation()
                        }
                        .buttonStyle(ActionButtonStyle())
                    }
                    
                    HStack(spacing: 12) {
                        Button("Random") {
                            selectedPreset = "Random"
                            renderer.randomizeParameters()
                        }
                        .buttonStyle(ActionButtonStyle())
                        
                        Button("Screenshot") {
                            renderer.captureScreenshot()
                        }
                        .buttonStyle(ActionButtonStyle())
                    }
                }
                
                Divider()
                
                // Resolution controls
                VStack(alignment: .leading, spacing: 12) {
                    Text("Resolution")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            Button("512²") {
                                setResolution(width: 512, height: 512)
                            }
                            .buttonStyle(ActionButtonStyle())
                            
                            Button("1024²") {
                                setResolution(width: 1024, height: 1024)
                            }
                            .buttonStyle(ActionButtonStyle())
                            
                            Button("2048²") {
                                setResolution(width: 2048, height: 2048)
                            }
                            .buttonStyle(ActionButtonStyle())
                        }
                        
                        Button("HD (1920×1080)") {
                            setResolution(width: 1920, height: 1080)
                        }
                        .buttonStyle(ActionButtonStyle())
                        
                        Button("4K UHD (3840×2160)") {
                            setResolution(width: 3840, height: 2160)
                        }
                        .buttonStyle(ActionButtonStyle())
                    }
                }
                
                Divider()
                
                // Instructions
                VStack(alignment: .leading, spacing: 8) {
                    Text("Instructions")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• Click/drag to add chemical B")
                        Text("• Right-click to reset simulation")
                        Text("• Scroll to change brush size")
                        Text("• Use spacebar to reset quickly")
                        Text("• Press 'p' to pause/resume")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(20)
        }
        .frame(minWidth: 320, minHeight: 600)
        .onAppear {
            // Start with first preset
            if let firstPreset = presetManager.featuredPresets.first {
                selectedPreset = firstPreset.name
                renderer.changePreset(firstPreset.name)
            }
        }
    }
    
    private func setResolution(width: Int, height: Int) {
        renderer.setResolution(width: Int32(width), height: Int32(height))
        print("Resolution set to: \(width)×\(height)")
    }
}

// MARK: - Button Styles

struct PresetButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ColorButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.orange : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ActionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
