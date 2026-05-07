//
//  SteamMonitor.swift
//  CrossOver-Steam-Presence
//
//  Created by Rigz on 5/1/26.
//

import Foundation
import Combine
import AppKit

@MainActor
final class SteamMonitor: ObservableObject {
    
    @Published var statusText = "No game detected"
    @Published var currentAppID: String?
    @Published var isRunning = false
    private var timer: Timer?
    private var lastGameName: String?

    private var steamAPIKey: String {
        UserDefaults.standard.string(forKey: "STEAM_API_KEY") ?? ""
    }

    private var steamID64: String {
        UserDefaults.standard.string(forKey: "STEAM_ID_64") ?? ""
    }
    
    private let discord = DiscordRPCClient(clientID: "1499953407476105247")

    private func isCrossOverRunning() -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        for app in runningApps {
            let bundleID = app.bundleIdentifier?.lowercased() ?? ""
            if bundleID.contains("codeweavers.crossover") {
                return true
            }
        }
        return false
    }
    
    func start() {
        isRunning = true
        Task {
            await fetchCurrentGame()
        }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in
            Task {
                await self.fetchCurrentGame()
            }
        }
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        statusText = "Monitoring stopped"
        currentAppID = nil
    }

    func fetchCurrentGame() async {
        if !isCrossOverRunning() {
            statusText = "CrossOver not running"
            currentAppID = nil
            if lastGameName != nil {
                lastGameName = nil
                do {
                    try discord.clearActivity()
                } catch {
                    print("Discord clear error:", error.localizedDescription)
                }
            }
            return
        }
        
        guard let url = URL(string:
            "https://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=\(steamAPIKey)&steamids=\(steamID64)"
        ) else {
            statusText = "Invalid Steam API URL"
            return
        }
        
        let safeURL = url.absoluteString.replacingOccurrences(of: steamAPIKey, with: "REDACTED")
        print("Requesting:", safeURL)
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(SteamPlayerSummaryResponse.self, from: data)
            guard let player = decoded.response.players.first else {
                statusText = "Steam profile not found"
                currentAppID = nil
                return
            }
            if let gameID = player.gameid {
                currentAppID = gameID
                if let gameName = player.gameextrainfo {
                    if gameName != lastGameName {
                        lastGameName = gameName
                        do {
                            try discord.setActivity(gameName: gameName, appID: gameID)
                        } catch {
                            print("Discord RPC error:", error.localizedDescription)
                        }
                    }
                    statusText = "Playing: \(gameName)"
                } else {
                    statusText = "Playing Steam App \(gameID)"
                    do {
                        try discord.setActivity(
                            gameName: "Steam App \(gameID)",
                            appID: gameID
                        )
                    } catch {
                        print("Discord RPC error:", error.localizedDescription)
                    }
                }
            } else {
                statusText = "No game detected"
                currentAppID = nil
                if lastGameName != nil {
                    lastGameName = nil
                    do {
                        try discord.clearActivity()
                    } catch {
                        print("Discord clear error:", error.localizedDescription)
                    }
                }
            }
        }
        catch {
            statusText = "Steam API error: \(error.localizedDescription)"
            currentAppID = nil
            print("STEAM ERROR:", error.localizedDescription)
        }
    }
}

struct SteamPlayerSummaryResponse: Codable {
    let response: SteamPlayerSummaryContainer
}

struct SteamPlayerSummaryContainer: Codable {
    let players: [SteamPlayer]
}

struct SteamPlayer: Codable {
    let steamid: String
    let personaname: String?
    let gameid: String?
    let gameextrainfo: String?
}
