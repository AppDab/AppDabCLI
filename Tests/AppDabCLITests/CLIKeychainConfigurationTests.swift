@testable import AppDabCLI
import Foundation
import Testing

struct CLIKeychainConfigurationTests {
    @Test(arguments: [false, true])
    func bundleSelectionSurvivesExternalSymlinks(shared: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("AppDabCLI.app/Contents/MacOS/dab")
        try FileManager.default.createDirectory(at: executable.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data().write(to: executable)
        let info: [String: Any] = [
            "CFBundleIdentifier": "app.AppDab.AppDabCLI",
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "dab",
            "AppDabSharedKeychain": shared,
        ]
        let plist = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try plist.write(to: root.appendingPathComponent("AppDabCLI.app/Contents/Info.plist"))
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        let link = bin.appendingPathComponent("dab")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../AppDabCLI.app/Contents/MacOS/dab")
        let alias = bin.appendingPathComponent("alias")
        try FileManager.default.createSymbolicLink(atPath: alias.path, withDestinationPath: "dab")

        let expected: CLIKeychainConfiguration = shared ? .sharedAppDab : .standalone
        for path in [executable, link, alias] {
            #expect(CLIKeychainConfiguration.configuration(forExecutableAt: path) == expected)
        }
        let otherExecutable = executable.deletingLastPathComponent().appendingPathComponent("other")
        try Data().write(to: otherExecutable)
        #expect(CLIKeychainConfiguration.configuration(forExecutableAt: otherExecutable) == .standalone)
    }

    @Test func sourceExecutableIgnoresAdjacentSharedStorageMetadata() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let executable = root.appendingPathComponent("dab")
        try Data().write(to: executable)
        let info = try PropertyListSerialization.data(fromPropertyList: ["AppDabSharedKeychain": true], format: .xml, options: 0)
        try info.write(to: root.appendingPathComponent("Info.plist"))
        #expect(CLIKeychainConfiguration.configuration(forExecutableAt: executable) == .standalone)
    }
}
