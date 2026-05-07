//
//  DiscordRPCClient.swift
//  CrossOver-Steam-Presence
//
//  Created by Rigz on 5/1/26.
//
import Foundation
import Darwin

final class DiscordRPCClient {
    private let clientID: String
    private var socketFD: Int32 = -1
    private var connected = false

    init(clientID: String) {
        self.clientID = clientID
    }

    func connect() throws {
        let tempDirs = [
            ProcessInfo.processInfo.environment["TMPDIR"] ?? "",
            NSTemporaryDirectory(),
            "/tmp/",
            "/var/tmp/",
            "/var/folders/3v/gcp3sp5x6vg1t92nw255kk9m0000gn/T/"
        ]
        let paths = tempDirs.flatMap { dir in
            (0...9).map { "\(dir)discord-ipc-\($0)" }
        }
        print("Checking Discord IPC paths:")
        paths.forEach { print($0) }
        for path in paths {
            print("Trying Discord IPC:", path)
            socketFD = socket(AF_UNIX, SOCK_STREAM, 0)
            guard socketFD >= 0 else {
                continue
            }

            var addr = sockaddr_un()
            addr.sun_family = sa_family_t(AF_UNIX)
            let maxLen = MemoryLayout.size(ofValue: addr.sun_path)
            _ = withUnsafeMutablePointer(to: &addr.sun_path) {
                $0.withMemoryRebound(to: CChar.self, capacity: maxLen) { dest in
                    strncpy(dest, path, maxLen)
                }
            }
            let addrSize = socklen_t(MemoryLayout<sockaddr_un>.size)
            let result = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    Darwin.connect(socketFD, $0, addrSize)
                }
            }
            if result == 0 {
                print("Connected to Discord IPC:", path)
                try handshake()
                connected = true
                return
            } else {
                close(socketFD)
                socketFD = -1
            }
        }
        throw NSError(domain: "DiscordRPC", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Discord IPC socket not found. Is Discord open?"
        ])
    }

    private func handshake() throws {
        let payload: [String: Any] = [
            "v": 1,
            "client_id": clientID
        ]
        try send(opcode: 0, payload: payload)
        _ = try readFrame()
    }

    func setActivity(gameName: String, appID: String) throws {
        if !connected {
            try connect()
        }
        let steamImageURL = "https://cdn.cloudflare.steamstatic.com/steam/apps/\(appID)/header.jpg"
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": Int(ProcessInfo.processInfo.processIdentifier),
                "activity": [
                    "details": "\(gameName)",
                    "state": "Running on macOS",
                    "timestamps": [
                        "start": Int(Date().timeIntervalSince1970)
                    ],
                    "assets": [
                        "large_image": steamImageURL,
                        "large_text": gameName
                    ]
                ]
            ],
            "nonce": UUID().uuidString
        ]
        try send(opcode: 1, payload: payload)
        _ = try readFrame()
    }

    func clearActivity() throws {
        if !connected {
            try connect()
        }
        let payload: [String: Any] = [
            "cmd": "SET_ACTIVITY",
            "args": [
                "pid": Int(ProcessInfo.processInfo.processIdentifier),
                "activity": NSNull()
            ],
            "nonce": UUID().uuidString
        ]
        try send(opcode: 1, payload: payload)
        _ = try readFrame()
    }

    func disconnect() {
        if socketFD >= 0 {
            close(socketFD)
        }
        socketFD = -1
        connected = false
    }

    private func send(opcode: UInt32, payload: [String: Any]) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        var header = Data()
        var op = opcode.littleEndian
        var length = UInt32(jsonData.count).littleEndian
        header.append(Data(bytes: &op, count: 4))
        header.append(Data(bytes: &length, count: 4))
        let frame = header + jsonData
        try frame.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            let sent = write(socketFD, base, frame.count)
            if sent < 0 {
                throw NSError(domain: "DiscordRPC", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to write to Discord IPC socket"
                ])
            }
        }
    }

    private func readFrame() throws -> Data {
        var header = [UInt8](repeating: 0, count: 8)
        let headerBytes = read(socketFD, &header, 8)
        if headerBytes <= 0 {
            throw NSError(domain: "DiscordRPC", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read Discord IPC header"
            ])
        }
        let length = header[4..<8].withUnsafeBytes {
            $0.load(as: UInt32.self).littleEndian
        }
        var payload = [UInt8](repeating: 0, count: Int(length))
        let payloadBytes = read(socketFD, &payload, Int(length))
        if payloadBytes <= 0 {
            throw NSError(domain: "DiscordRPC", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read Discord IPC payload"
            ])
        }
        return Data(payload)
    }
}

