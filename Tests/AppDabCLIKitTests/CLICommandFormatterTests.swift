@testable import AppDabCLIKit
import Foundation
import Testing

struct CLICommandFormatterTests {
    @Test func shellRoundTripPreservesLiteralArguments() throws {
        let values = ["", "a'b", "$(printf bad)", "`printf bad`", "a;b", "two words", "--verbose"]
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", "printf '%s\\0' " + values.map(CLICommandFormatter.quote).joined(separator: " ")]
        let pipe = Pipe()
        process.standardOutput = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(String(decoding: data, as: UTF8.self).components(separatedBy: "\0") == values + [""])
    }

    @Test func recoveryStripsPresentationAndRedactsSecrets() {
        let command = CLICommandFormatter.render(arguments: [
            "appVersion", "create", "--version", "--verbose",
            "--confirm=abc", "--idempotency-key", "key", "--format", "json",
            "--password", "sensitive", "--verbose",
        ])
        #expect(!command.contains("sensitive"))
        #expect(!command.contains("--format"))
        #expect(command.contains("'<redacted>'"))
        #expect(command.contains("--version --verbose"))
        #expect(command.contains("--confirm=abc"))
    }
}
