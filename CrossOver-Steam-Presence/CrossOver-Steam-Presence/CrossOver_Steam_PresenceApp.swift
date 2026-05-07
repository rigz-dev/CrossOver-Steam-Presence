//
//  CrossOver_Steam_PresenceApp.swift
//  CrossOver-Steam-Presence
//
//  Created by Rigz on 5/1/26.
//
import SwiftUI

@main
struct SteamPresenceMenuApp: App {
    @StateObject private var steam = SteamMonitor()
    @Environment(\.openSettings) private var openSettings

    var body: some Scene {
        MenuBarExtra("Steam Presence", systemImage: "gamecontroller.fill") {
            Text(steam.statusText)
            Divider()
            Button("Refresh Now") {
                Task {
                    await steam.fetchCurrentGame()
                }
            }
            Button(steam.isRunning ? "Stop Monitoring" : "Start Monitoring") {
                steam.isRunning ? steam.stop() : steam.start()
            }
            Divider()
            Button("Settings") {
                openSettings()
            }
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        Settings {
            SettingsView()
        }
    }
}
