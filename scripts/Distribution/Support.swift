import CryptoKit
import Foundation

// Configuration and process helpers shared by the distribution commands.
let team = "R7YA4RGA8U"
let bundleID = "app.AppDab.AppDabCLI"
let accessGroup = team + ".app.AppDab.AppDab"
let files = FileManager.default
let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

struct Failure: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) {
        description = message
    }
}

struct Result {
    let status: Int32
    let output: Data
    let error: Data
    var text: String {
        String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

@discardableResult
func run(_ arguments: [String], capture: Bool = false, allowFailure: Bool = false, timeout: TimeInterval? = nil) throws -> Result {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    // Files avoid pipe deadlocks when a tool produces substantial output.
    let directory = try temporaryDirectory()
    defer { try? files.removeItem(at: directory) }
    let outputURL = directory.appendingPathComponent("stdout")
    let errorURL = directory.appendingPathComponent("stderr")
    files.createFile(atPath: outputURL.path, contents: nil)
    files.createFile(atPath: errorURL.path, contents: nil)
    let output = try FileHandle(forWritingTo: outputURL)
    let error = try FileHandle(forWritingTo: errorURL)
    defer { try? output.close(); try? error.close() }
    if capture {
        process.standardOutput = output; process.standardError = error
    }
    try process.run()
    let timer = timeout.map { interval in
        let timer = DispatchSource.makeTimerSource()
        timer.schedule(deadline: .now() + interval)
        timer.setEventHandler {
            if process.isRunning {
                process.terminate()
            }
        }
        timer.resume()
        return timer
    }
    process.waitUntilExit()
    timer?.cancel()
    if timeout != nil, process.terminationReason == .uncaughtSignal, process.terminationStatus == SIGTERM {
        throw Failure("The command exceeded its time limit.")
    }
    let result = try Result(status: process.terminationStatus, output: Data(contentsOf: outputURL), error: Data(contentsOf: errorURL))
    if result.status != 0, !allowFailure {
        // Captured account responses are never included in diagnostics.
        throw Failure("\(arguments.prefix(2).joined(separator: " ")) failed (status \(result.status)).")
    }
    return result
}

func temporaryDirectory(in parent: URL = files.temporaryDirectory) throws -> URL {
    let directory = parent.appendingPathComponent("appdab-distribution-" + UUID().uuidString)
    try files.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    return directory
}

func plist(_ data: Data) throws -> [String: Any] {
    guard let value = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else { throw Failure("Expected a property list dictionary.") }
    return value
}

func writePlist(_ value: [String: Any], to url: URL) throws {
    try PropertyListSerialization.data(fromPropertyList: value, format: .xml, options: 0).write(to: url)
}

func validateVersion(_ version: String) throws {
    guard version.range(of: #"\A[0-9]+\.[0-9]+\.[0-9]+\z"#, options: .regularExpression) != nil else { throw Failure("Version must contain three numeric components, such as 1.0.0.") }
}

func checksum(_ url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hash = SHA256()
    while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
        hash.update(data: data)
    }
    return hash.finalize().map { String(format: "%02x", $0) }.joined()
}
