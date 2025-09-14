//
//  ReactionDiffusionApp.swift
//  reaction-diffusion-metal
//
//  Created by suf on 13/09/2025.
//

import SwiftUI

@main
struct ReactionDiffusionApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    setupWindow()
                }
        }
        .windowStyle(DefaultWindowStyle())
        .windowResizability(.contentSize)
        .defaultSize(width: 1400, height: 1024)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Remove default "New" menu item
            }
            
            CommandGroup(after: .newItem) {
                Menu("Presets") {
                    Button("Spots and Dots") {
                        NotificationCenter.default.post(name: NSNotification.Name("PresetSpotsAndDots"), object: nil)
                    }
                    .keyboardShortcut("1")
                    
                    Button("Stripes and Waves") {
                        NotificationCenter.default.post(name: NSNotification.Name("PresetStripesAndWaves"), object: nil)
                    }
                    .keyboardShortcut("2")
                    
                    Button("Coral Growth") {
                        NotificationCenter.default.post(name: NSNotification.Name("PresetCoral"), object: nil)
                    }
                    .keyboardShortcut("3")
                    
                    Button("Fingerprints") {
                        NotificationCenter.default.post(name: NSNotification.Name("PresetFingerprints"), object: nil)
                    }
                    .keyboardShortcut("4")
                    
                    Divider()
                    
                    Button("Randomize Parameters") {
                        NotificationCenter.default.post(name: NSNotification.Name("RandomizeParameters"), object: nil)
                    }
                    .keyboardShortcut("r")
                }
                
                Menu("Simulation") {
                    Button("Reset Simulation") {
                        NotificationCenter.default.post(name: NSNotification.Name("ResetSimulation"), object: nil)
                    }
                    .keyboardShortcut(" ", modifiers: [])
                    
                    Button("Toggle Play/Pause") {
                        NotificationCenter.default.post(name: NSNotification.Name("TogglePlayPause"), object: nil)
                    }
                    .keyboardShortcut("p", modifiers: [])
                    
                    Button("Show Control Panel") {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowControlPanel"), object: nil)
                    }
                    .keyboardShortcut("c", modifiers: [.command])
                    
                    Divider()
                    
                    Button("Toggle Cinematic Mode") {
                        NotificationCenter.default.post(name: NSNotification.Name("ToggleCinematicMode"), object: nil)
                    }
                    .keyboardShortcut("f", modifiers: [.command])
                }
                
                Menu("Resolution") {
                    Button("HD (1920×1080)") {
                        setWindowSize(width: 1920, height: 1080)
                    }
                    
                    Button("UHD 4K (3840×2160)") {
                        setWindowSize(width: 3840, height: 2160)
                    }
                    
                    Button("Square HD (1024×1024)") {
                        setWindowSize(width: 1024, height: 1024)
                    }
                    
                    Button("Default (1400×1024)") {
                        setWindowSize(width: 1400, height: 1024)
                    }
                }
            }
        }
    }
    
    private func setupWindow() {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                window.title = "Reaction-Diffusion Simulator - Metal"
                window.minSize = NSSize(width: 800, height: 600)
                window.maxSize = NSSize(width: 4096, height: 4096)
                window.center()
                window.styleMask.insert(.resizable)
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
    
    private func setWindowSize(width: Int, height: Int) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.windows.first {
                let newSize = NSSize(width: width, height: height)
                window.setContentSize(newSize)
                window.center()
                print("Window resized to: \(width)×\(height)")
            }
        }
    }
}
