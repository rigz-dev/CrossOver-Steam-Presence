//
//  SettingsView.swift
//  CrossOver-Steam-Presence
//
//  Created by Rigz on 5/1/26.
//

import SwiftUI

struct SettingsView: View {
    
    @AppStorage("STEAM_API_KEY") private var steamAPIKey = ""
    @AppStorage("STEAM_ID_64") private var steamID64 = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Steam Settings")
                .font(.title2)
                .bold()
            VStack(alignment: .leading) {
                Text("Steam API Key")
                SecureField("Enter Steam API Key", text: $steamAPIKey)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading) {
                Text("Numerical Steam ID")
                TextField("Enter Numerical Steam ID", text: $steamID64)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
    }
}
