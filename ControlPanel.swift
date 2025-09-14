//
//  ControlPanel.swift
//  reaction-diffusion-metal
//
//  Created by suf on 13/09/2025.
//

import SwiftUI
import AppKit

// MARK: - Window Controller

class ControlPanelWindowController: NSWindowController {
    private var hostingView: NSHostingView<RDControlPanelContent>?
    private var controlPanelView: RDControlPanelContent?
    
    convenience init(renderer: MetalRenderer, cinematicMode: Bool) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Reaction-Diffusion Controls"
        window.minSize = NSSize(width: 320, height: 600)
        window.maxSize = NSSize(width: 500, height: 900)
        
        let contentView = RDControlPanelContent(
            renderer: renderer,
            initialCinematicMode: cinematicMode
        )
        
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        window.isReleasedWhenClosed = false
        window.center()
        
        self.init(window: window)
        self.hostingView = hostingView
        self.controlPanelView = contentView
    }
    
    func updateCinematicMode(_ enabled: Bool) {
        // Update the control panel's cinematic mode state
        if let contentView = hostingView?.rootView as? RDControlPanelContent {
            // This would need to be handled via a binding or observable
            // For now, we'll handle it through notifications
        }
    }
}

// MARK: - Main Control Panel View

struct RDControlPanelContent: View {
    let renderer: MetalRenderer
    @State private var selectedPreset = "Coral Growth"
    @State private var selectedColorScheme = "Organic"
    @State private var showAllPresets = false
    @State private var cinematicMode: Bool
    @State private var expandedSection: String? = "presets"
    
    @ObservedObject private var presetManager = RDPresetManager.shared
    @ObservedObject private var settings: RDSettings
    
    init(renderer: MetalRenderer, initialCinematicMode: Bool = false) {
        self.renderer = renderer
        self.settings = renderer.engine.settings
        self._cinematicMode = State(initialValue: initialCinematicMode)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                HeaderSection(cinematicMode: $cinematicMode)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                
                Divider()
                
                // Collapsible sections
                VStack(spacing: 1) {
                    // Presets Section
                    CollapsibleSection(
                        title: "Presets",
                        isExpanded: expandedSection == "presets"
                    ) {
                        expandedSection = expandedSection == "presets" ? nil : "presets"
                    } content: {
                        PresetsSection(
                            selectedPreset: $selectedPreset,
                            showAllPresets: $showAllPresets,
                            renderer: renderer
                        )
                    }
                    
                    Divider()
                    
                    // Parameters Section
                    CollapsibleSection(
                        title: "Parameters",
                        isExpanded: expandedSection == "parameters"
                    ) {
                        expandedSection = expandedSection == "parameters" ? nil : "parameters"
                    } content: {
                        ParametersSection(settings: settings)
                    }
                    
                    Divider()
                    
                    // Visual Section
                    CollapsibleSection(
                        title: "Visual",
                        isExpanded: expandedSection == "visual"
                    ) {
                        expandedSection = expandedSection == "visual" ? nil : "visual"
                    } content: {
                        VisualSection(
                            selectedColorScheme: $selectedColorScheme,
                            settings: settings,
                            renderer: renderer
                        )
                    }
                    
                    Divider()
                    
                    // Controls Section
                    CollapsibleSection(
                        title: "Controls",
                        isExpanded: expandedSection == "controls"
                    ) {
                        expandedSection = expandedSection == "controls" ? nil : "controls"
                    } content: {
                        ControlsSection(
                            renderer: renderer,
                            selectedPreset: $selectedPreset
                        )
                    }
                    
                    Divider()
                    
                    // Resolution Section
                    CollapsibleSection(
                        title: "Resolution",
                        isExpanded: expandedSection == "resolution"
                    ) {
                        expandedSection = expandedSection == "resolution" ? nil : "resolution"
                    } content: {
                        ResolutionSection(renderer: renderer)
                    }
                    
                    Divider()
                    
                    // Help Section
                    CollapsibleSection(
                        title: "Help",
                        isExpanded: expandedSection == "help"
                    ) {
                        expandedSection = expandedSection == "help" ? nil : "help"
                    } content: {
                        HelpSection()
                    }
                }
            }
        }
        .frame(minWidth: 320, idealWidth: 380, maxWidth: 500)
        .frame(minHeight: 600)
        .background(Color(NSColor.controlBackgroundColor))
        .onChange(of: cinematicMode) { newValue in
            NotificationCenter.default.post(
                name: NSNotification.Name("SetCinematicMode"),
                object: nil,
                userInfo: ["enabled": newValue]
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleCinematicMode"))) { _ in
            cinematicMode.toggle()
        }
        .onAppear {
            // Set initial preset
            renderer.changePreset(selectedPreset)
        }
    }
}

// MARK: - Header Section

struct HeaderSection: View {
    @Binding var cinematicMode: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Reaction-Diffusion")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Control Panel")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: $cinematicMode)
                    .toggleStyle(SwitchToggleStyle())
                    .scaleEffect(0.8)
                
                Text("Cinematic")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Collapsible Section Component

struct CollapsibleSection<Content: View>: View {
    let title: String
    let isExpanded: Bool
    let toggle: () -> Void
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            
            if isExpanded {
                content()
                    .padding(.horizontal, 20)
                    .padding(.vertical, 15)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
    }
}

// MARK: - Presets Section

struct PresetsSection: View {
    @Binding var selectedPreset: String
    @Binding var showAllPresets: Bool
    let renderer: MetalRenderer
    @ObservedObject private var presetManager = RDPresetManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(showAllPresets ? "All Presets" : "Featured")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(showAllPresets ? "Featured" : "Show All") {
                    withAnimation {
                        showAllPresets.toggle()
                    }
                }
                .font(.caption)
            }
            
            let presetsToShow = showAllPresets ? presetManager.availablePresets : presetManager.featuredPresets
            
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(presetsToShow, id: \.name) { preset in
                    PresetButton(
                        preset: preset,
                        isSelected: selectedPreset == preset.name
                    ) {
                        selectedPreset = preset.name
                        renderer.changePreset(preset.name)
                    }
                }
            }
            
            // Preset info card
            if let preset = presetManager.getPreset(named: selectedPreset) {
                PresetInfoCard(preset: preset)
            }
        }
    }
}

struct PresetButton: View {
    let preset: RDPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(preset.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct PresetInfoCard: View {
    let preset: RDPreset
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preset.name)
                .font(.system(size: 11, weight: .semibold))
            
            if !preset.description.isEmpty {
                Text(preset.description)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            HStack(spacing: 12) {
                Label("\(preset.feedRate, specifier: "%.3f")", systemImage: "f.circle")
                Label("\(preset.killRate, specifier: "%.3f")", systemImage: "k.circle")
            }
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }
}

// MARK: - Parameters Section

struct ParametersSection: View {
    @ObservedObject var settings: RDSettings
    
    var body: some View {
        VStack(spacing: 16) {
            ParameterSlider(
                title: "Feed Rate (F)",
                value: $settings.feedRate,
                range: 0.0...0.1,
                step: 0.001,
                color: .blue
            )
            
            ParameterSlider(
                title: "Kill Rate (K)",
                value: $settings.killRate,
                range: 0.03...0.07,
                step: 0.001,
                color: .red
            )
            
            ParameterSlider(
                title: "Diffusion A",
                value: $settings.diffusionA,
                range: 0.0...2.0,
                step: 0.1,
                color: .green
            )
            
            ParameterSlider(
                title: "Diffusion B",
                value: $settings.diffusionB,
                range: 0.0...2.0,
                step: 0.1,
                color: .orange
            )
            
            ParameterSlider(
                title: "Time Step",
                value: $settings.deltaTime,
                range: 0.1...2.0,
                step: 0.1,
                color: .purple
            )
            
            ParameterSlider(
                title: "Brush Size",
                value: $settings.brushRadius,
                range: 5.0...50.0,
                step: 1.0,
                color: .cyan
            )
        }
    }
}

struct ParameterSlider: View {
    let title: String
    @Binding var value: Float
    let range: ClosedRange<Double>
    let step: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                
                Spacer()
                
                Text(String(format: step < 0.01 ? "%.3f" : "%.1f", value))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { value = Float($0) }
                ),
                in: range,
                step: step
            )
            .accentColor(color)
        }
    }
}

// MARK: - Visual Section

struct VisualSection: View {
    @Binding var selectedColorScheme: String
    @ObservedObject var settings: RDSettings
    let renderer: MetalRenderer
    
    let colorSchemes = ["Organic", "Fire", "Ocean", "Grayscale", "Electric", "Sunset"]
    
    var body: some View {
        VStack(spacing: 16) {
            // Color scheme grid
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 8),
                GridItem(.flexible(), spacing: 8)
            ], spacing: 8) {
                ForEach(colorSchemes, id: \.self) { scheme in
                    ColorSchemeButton(
                        name: scheme,
                        isSelected: selectedColorScheme == scheme
                    ) {
                        selectedColorScheme = scheme
                        renderer.setColorScheme(scheme)
                    }
                }
            }
            
            // Visual enhancement sliders
            VStack(spacing: 12) {
                Text("Enhancements")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                

                
                ParameterSlider(
                    title: "Contrast",
                    value: Binding(
                        get: { Float(1.0) }, // Default contrast
                        set: { _ in }
                    ),
                    range: 0.5...2.0,
                    step: 0.1,
                    color: .gray
                )
            }
        }
    }
}

struct ColorSchemeButton: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.orange : Color.secondary.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Controls Section

struct ControlsSection: View {
    let renderer: MetalRenderer
    @Binding var selectedPreset: String
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ControlButton(
                    title: renderer.engine.isRunning ? "Pause" : "Play",
                    icon: renderer.engine.isRunning ? "pause.fill" : "play.fill"
                ) {
                    renderer.togglePlayPause()
                }
                
                ControlButton(
                    title: "Reset",
                    icon: "arrow.clockwise"
                ) {
                    renderer.resetSimulation()
                }
            }
            
            HStack(spacing: 12) {
                ControlButton(
                    title: "Random",
                    icon: "dice"
                ) {
                    selectedPreset = "Random"
                    renderer.randomizeParameters()
                }
                
                ControlButton(
                    title: "Screenshot",
                    icon: "camera"
                ) {
                    renderer.captureScreenshot()
                }
            }
        }
    }
}

struct ControlButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Resolution Section

struct ResolutionSection: View {
    let renderer: MetalRenderer
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                ResolutionButton(title: "512²") {
                    renderer.setResolution(width: 512, height: 512)
                }
                
                ResolutionButton(title: "1024²") {
                    renderer.setResolution(width: 1024, height: 1024)
                }
                
                ResolutionButton(title: "2048²") {
                    renderer.setResolution(width: 2048, height: 2048)
                }
            }
            
            ResolutionButton(title: "HD (1920×1080)") {
                renderer.setResolution(width: 1920, height: 1080)
            }
            
            ResolutionButton(title: "4K (3840×2160)") {
                renderer.setResolution(width: 3840, height: 2160)
            }
        }
    }
}

struct ResolutionButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Help Section

struct HelpSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Keyboard Shortcuts", systemImage: "keyboard")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "Space", action: "Reset simulation")
                    HelpRow(key: "P", action: "Pause/Resume")
                    HelpRow(key: "Cmd+F", action: "Toggle cinematic mode")
                    HelpRow(key: "Cmd+C", action: "Show control panel")
                    HelpRow(key: "Cmd+R", action: "Random parameters")
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Mouse Controls", systemImage: "computermouse")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 4) {
                    HelpRow(key: "Click/Drag", action: "Add chemical B")
                    HelpRow(key: "Right-click", action: "Reset simulation")
                    HelpRow(key: "Scroll", action: "Change brush size")
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Cinematic Mode", systemImage: "tv")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Hides all UI elements for a clean, immersive view. Perfect for recordings and presentations.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct HelpRow: View {
    let key: String
    let action: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
            
            Text(action)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}
