//
//  ControlPanel.swift
//  reaction-diffusion-metal
//  Enhanced version with dramatic 3D lighting and wider parameter ranges
//

import SwiftUI
import AppKit

// MARK: - Window Controller

class ControlPanelWindowController: NSWindowController {
    private var hostingView: NSHostingView<RDControlPanelContent>?
    private var controlPanelView: RDControlPanelContent?
    
    convenience init(renderer: MetalRenderer, cinematicMode: Bool) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "Reaction-Diffusion Controls"
        window.minSize = NSSize(width: 320, height: 600)
        window.maxSize = NSSize(width: 500, height: 950)
        
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
        // Handled through notifications
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
                        ParametersSection(settings: settings, renderer: renderer)
                    }
                    
                    Divider()
                    
                    // Visual & 3D Section
                    CollapsibleSection(
                        title: "Visual & 3D",
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
                    
                    // Glow Section
                    CollapsibleSection(
                        title: "Glow Effects",
                        isExpanded: expandedSection == "glow"
                    ) {
                        expandedSection = expandedSection == "glow" ? nil : "glow"
                    } content: {
                        GlowSection(settings: settings, renderer: renderer)
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
                
                Text("Enhanced 3D Control")
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
            
            if let preset = presetManager.getPreset(named: selectedPreset) {
                PresetInfoCard(preset: preset)
            }
        }
    }
}

// MARK: - Parameters Section

struct ParametersSection: View {
    @ObservedObject var settings: RDSettings
    let renderer: MetalRenderer
    
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

// MARK: - Visual & 3D Section with Enhanced Ranges

struct VisualSection: View {
    @Binding var selectedColorScheme: String
    @ObservedObject var settings: RDSettings
    let renderer: MetalRenderer
    @State private var showAdvanced3D = false
    
    let colorSchemes = ["Organic", "Fire", "Ocean", "Grayscale", "Electric", "Sunset", "Metallic", "Neon", "Blood"]
    
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
                        // Auto-enable glow for Neon
                        if scheme == "Neon" {
                            settings.glowEnabled = true
                            renderer.engine.forceUpdateLighting()
                        }
                    }
                }
            }
            
            Divider()
            
            // 3D Lighting Controls with Enhanced Ranges
            VStack(spacing: 12) {
                HStack {
                    Label("3D Lighting", systemImage: "light.max")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(showAdvanced3D ? "Simple" : "Advanced") {
                        withAnimation {
                            showAdvanced3D.toggle()
                        }
                    }
                    .font(.caption)
                }
                
                VStack(spacing: 12) {
                    ParameterSlider(
                        title: "Height",
                        value: $settings.heightScale,
                        range: 0.0...1.0,  // Increased from 0.0...0.5
                        step: 0.01,
                        color: .blue
                    )
                    .help("Controls the 3D embossing depth")
                    .onChange(of: settings.heightScale) { _ in
                        renderer.engine.forceUpdateLighting()
                    }
                    
                    ParameterSlider(
                        title: "Shininess",
                        value: $settings.shininess,
                        range: 4.0...512.0,  // Increased from 4.0...256.0
                        step: 4.0,
                        color: .yellow
                    )
                    .help("Specular highlight sharpness")
                    .onChange(of: settings.shininess) { _ in
                        renderer.engine.forceUpdateLighting()
                    }
                    
                    if showAdvanced3D {
                        ParameterSlider(
                            title: "Ambient",
                            value: $settings.ambientStrength,
                            range: 0.05...0.8,  // Adjusted for more dramatic shadows
                            step: 0.05,
                            color: .gray
                        )
                        .help("Base lighting level")
                        .onChange(of: settings.ambientStrength) { _ in
                            renderer.engine.forceUpdateLighting()
                        }
                        
                        ParameterSlider(
                            title: "Diffuse",
                            value: $settings.diffuseStrength,
                            range: 0.2...1.2,  // Increased upper range
                            step: 0.05,
                            color: .green
                        )
                        .help("Surface light scattering")
                        .onChange(of: settings.diffuseStrength) { _ in
                            renderer.engine.forceUpdateLighting()
                        }
                        
                        ParameterSlider(
                            title: "Specular",
                            value: $settings.specularStrength,
                            range: 0.0...3.0,  // Increased from 0.0...2.0
                            step: 0.1,
                            color: .white
                        )
                        .help("Highlight intensity")
                        .onChange(of: settings.specularStrength) { _ in
                            renderer.engine.forceUpdateLighting()
                        }
                        
                        HStack {
                            Toggle("Animate Light", isOn: Binding(
                                get: { renderer.engine.lightAnimationEnabled },
                                set: { enabled in
                                    renderer.engine.lightAnimationEnabled = enabled
                                    renderer.engine.forceUpdateLighting()
                                }
                            ))
                            .toggleStyle(SwitchToggleStyle(tint: .orange))
                            
                            if renderer.engine.lightAnimationEnabled {
                                Slider(
                                    value: Binding(
                                        get: { Double(renderer.engine.lightAnimationSpeed) },
                                        set: { speed in
                                            renderer.engine.lightAnimationSpeed = Float(speed)
                                            renderer.engine.forceUpdateLighting()
                                        }
                                    ),
                                    in: 0.1...2.0,
                                    step: 0.1
                                )
                                .frame(width: 80)
                                .help("Animation speed")
                            }
                        }
                        .font(.caption)
                    }
                }
                
                if showAdvanced3D {
                    VStack(spacing: 8) {
                        Text("Lighting Presets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            LightingPresetButton(title: "Subtle") {
                                settings.heightScale = 0.15
                                settings.shininess = 32
                                settings.ambientStrength = 0.5
                                settings.diffuseStrength = 0.5
                                settings.specularStrength = 0.3
                                renderer.engine.forceUpdateLighting()
                            }
                            
                            LightingPresetButton(title: "Standard") {
                                settings.heightScale = 0.25
                                settings.shininess = 64
                                settings.ambientStrength = 0.35
                                settings.diffuseStrength = 0.65
                                settings.specularStrength = 0.8
                                renderer.engine.forceUpdateLighting()
                            }
                            
                            LightingPresetButton(title: "Dramatic") {
                                settings.heightScale = 0.45      // Increased from 0.25
                                settings.shininess = 256         // Increased from 64
                                settings.ambientStrength = 0.15  // Decreased from 0.25
                                settings.diffuseStrength = 0.8   // Increased from 0.7
                                settings.specularStrength = 1.5  // Increased from 0.8
                                renderer.engine.forceUpdateLighting()
                            }
                            
                            LightingPresetButton(title: "Ultra 3D") {
                                settings.heightScale = 0.6
                                settings.shininess = 384
                                settings.ambientStrength = 0.1
                                settings.diffuseStrength = 0.9
                                settings.specularStrength = 2.5
                                renderer.engine.forceUpdateLighting()
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Glow Section

struct GlowSection: View {
    @ObservedObject var settings: RDSettings
    let renderer: MetalRenderer
    @State private var showAdvancedGlow = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Main glow toggle
            HStack {
                Label("Glow Effect", systemImage: "sparkles")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Toggle("", isOn: $settings.glowEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: .purple))
                    .onChange(of: settings.glowEnabled) { _ in
                        renderer.engine.forceUpdateLighting()
                    }
                
                Button(showAdvancedGlow ? "Simple" : "Advanced") {
                    withAnimation {
                        showAdvancedGlow.toggle()
                    }
                }
                .font(.caption)
            }
            
            // Basic glow controls
            if settings.glowEnabled {
                VStack(spacing: 12) {
                    ParameterSlider(
                        title: "Intensity",
                        value: $settings.glowIntensity,
                        range: 0.0...3.0,
                        step: 0.1,
                        color: .purple
                    )
                    .help("Brightness of the glow effect")
                    .onChange(of: settings.glowIntensity) { _ in
                        renderer.engine.forceUpdateLighting()
                    }
                    
                    ParameterSlider(
                        title: "Threshold",
                        value: $settings.glowThreshold,
                        range: 0.0...1.0,
                        step: 0.05,
                        color: .pink
                    )
                    .help("Minimum concentration to start glowing")
                    .onChange(of: settings.glowThreshold) { _ in
                        renderer.engine.forceUpdateLighting()
                    }
                    
                    if showAdvancedGlow {
                        ParameterSlider(
                            title: "Falloff",
                            value: $settings.glowFalloff,
                            range: 0.5...5.0,
                            step: 0.1,
                            color: .orange
                        )
                        .help("How quickly glow fades from bright areas")
                        .onChange(of: settings.glowFalloff) { _ in
                            renderer.engine.forceUpdateLighting()
                        }
                        
                        // Glow color picker
                        HStack {
                            Text("Glow Color")
                                .font(.caption)
                            
                            Spacer()
                            
                            HStack(spacing: 4) {
                                GlowColorButton(color: Color.white) {
                                    settings.glowColor = SIMD3<Float>(1.0, 1.0, 1.0)
                                    renderer.engine.forceUpdateLighting()
                                }
                                
                                GlowColorButton(color: Color.yellow) {
                                    settings.glowColor = SIMD3<Float>(1.0, 0.8, 0.4)
                                    renderer.engine.forceUpdateLighting()
                                }
                                
                                GlowColorButton(color: Color.cyan) {
                                    settings.glowColor = SIMD3<Float>(0.4, 0.8, 1.0)
                                    renderer.engine.forceUpdateLighting()
                                }
                                
                                GlowColorButton(color: Color.purple) {
                                    settings.glowColor = SIMD3<Float>(1.0, 0.2, 1.0)
                                    renderer.engine.forceUpdateLighting()
                                }
                                
                                GlowColorButton(color: Color.green) {
                                    settings.glowColor = SIMD3<Float>(0.4, 1.0, 0.4)
                                    renderer.engine.forceUpdateLighting()
                                }
                            }
                        }
                    }
                }
                
                // Glow presets
                if showAdvancedGlow {
                    VStack(spacing: 8) {
                        Text("Glow Presets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 8) {
                            GlowPresetButton(title: "Subtle") {
                                settings.glowIntensity = 0.5
                                settings.glowThreshold = 0.8
                                settings.glowFalloff = 3.0
                                renderer.engine.forceUpdateLighting()
                            }
                            
                            GlowPresetButton(title: "Standard") {
                                settings.glowIntensity = 1.0
                                settings.glowThreshold = 0.7
                                settings.glowFalloff = 2.0
                                renderer.engine.forceUpdateLighting()
                            }
                            
                            GlowPresetButton(title: "Intense") {
                                settings.glowIntensity = 2.0
                                settings.glowThreshold = 0.5
                                settings.glowFalloff = 1.5
                                renderer.engine.forceUpdateLighting()
                            }
                            
                            GlowPresetButton(title: "Plasma") {
                                settings.glowIntensity = 2.5
                                settings.glowThreshold = 0.3
                                settings.glowFalloff = 1.0
                                renderer.engine.forceUpdateLighting()
                            }
                        }
                    }
                }
            }
        }
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
            
            ResolutionButton(title: "Retina (3456×2234)") {
                renderer.setResolution(width: 3456, height: 2234)
            }
            
            ResolutionButton(title: "4K (3840×2160)") {
                renderer.setResolution(width: 3840, height: 2160)
            }
        }
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
                Label("Enhanced 3D Effect", systemImage: "cube.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("For maximum 3D pop effect, try the 'Ultra 3D' preset or adjust Height (0.4-0.6) and Shininess (256-512).")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Label("Glow Effect", systemImage: "sparkles")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("Glow adds emission based on chemical concentration, with pulse effects on rapid changes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• Intensity: Overall glow brightness")
                    Text("• Threshold: Minimum concentration to glow")
                    Text("• Falloff: Glow fade rate from bright areas")
                    Text("• Color: Emission color tint")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Supporting Components

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

struct LightingPresetButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GlowColorButton: View {
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct GlowPresetButton: View {
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
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
