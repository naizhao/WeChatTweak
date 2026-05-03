//
//  Command.swift
//
//  Created by Sunny Young.
//

import Foundation
import ArgumentParser

struct Command {
    enum Error: @unchecked Sendable, LocalizedError {
        case executing(command: String, error: NSDictionary)

        var errorDescription: String? {
            switch self {
            case let .executing(command, error):
                return "executing: \(command) error: \(error)"
            }
        }
    }

    static func version(app: URL) async throws -> String? {
        try await Command.execute(command: "defaults read \(app.appendingPathComponent("Contents/Info.plist").path) CFBundleVersion")
    }

    @discardableResult
    static func patch(app: URL, config: Config) async throws -> Set<String> {
        let defaultBinary = "Contents/MacOS/WeChat"
        let grouped = Dictionary(grouping: config.targets) { target in
            target.binary ?? defaultBinary
        }

        for (binary, targets) in grouped {
            let subConfig = Config(version: config.version, targets: targets)
            try Patcher.patch(binary: app.appendingPathComponent(binary), config: subConfig)
        }

        return Set(grouped.keys)
    }

    static func resign(app: URL, patchedBinaries: Set<String> = []) async throws {
        try await Command.execute(command: "codesign --remove-sign \(app.path)")
        try await Command.execute(command: "codesign --force --deep --sign - \(app.path)")

        // codesign --deep on macOS 14+ does not always recompute page hashes for
        // nested Mach-O files under Contents/Resources/. Re-sign each patched
        // binary explicitly so its page hashes match the new bytes; otherwise
        // the kernel kills the process with "Invalid Page" on first execution.
        for binary in patchedBinaries.sorted() {
            let path = app.appendingPathComponent(binary).path
            try await Command.execute(command: "codesign --force --sign - \(path)")
        }

        try await Command.execute(command: "xattr -cr \(app.path)")
    }

    @discardableResult
    private static func execute(command: String) async throws -> String? {
        guard let script = NSAppleScript(source: "do shell script \"\(command)\"") else {
            throw Error.executing(
                command: command,
                error: ["error": "Create script failed."]
            )
        }

        var error: NSDictionary?
        let descriptor = script.executeAndReturnError(&error)

        if let error = error {
            throw Error.executing(
                command: command,
                error: error
            )
        } else {
            return descriptor.stringValue
        }
    }
}
