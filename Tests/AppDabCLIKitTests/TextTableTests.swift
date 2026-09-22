@testable import AppDabCLIKit
import Testing

struct TextTableTests {
    @Test func usesLabeledRecordsWhenTableExceedsTerminalWidth() {
        let rendered = TextTable(
            headers: ["Name", "Bundle ID", "App ID"],
            rows: [["A very long app name", "com.example.very.long.bundle", "app-1"]]
        ).render(style: .init(supportsColor: false, maximumWidth: 30))

        #expect(rendered.contains("Name: A very long app name"))
        #expect(rendered.contains("App ID: app-1"))
        #expect(!rendered.contains("  Bundle ID"))
    }

    @Test func preservesWideCharactersAndNeutralizesTerminalControls() {
        let rendered = TextTable(
            headers: ["Name", "ID"],
            rows: [["😀\u{001B}[31mred", "a"]]
        ).render(style: .init(supportsColor: false))

        #expect(rendered.contains("😀�[31mred"))
        #expect(!rendered.contains("\u{001B}"))
    }
}
