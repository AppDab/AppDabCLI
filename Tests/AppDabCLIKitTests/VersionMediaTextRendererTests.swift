import AppDabAutomation
@testable import AppDabCLIKit
import AppDabServices
import Foundation
import Testing

struct VersionMediaTextRendererTests {
    @Test func listFitsTypicalTerminalAndPreservesPlacementOrder() throws {
        let fileName = String(repeating: "long_filename_", count: 10) + ".png"
        let ids = ["8ec00002-c124-8d2c-8f26-7cd37638f3e1", "11800002-c124-8d2c-8f1a-a0983e2fb926"]
        let placements = ids.map { placement($0, fileName: fileName) }
        let list = VersionMediaActionOutput(list: .init(appID: "app", localizationID: "locale", placements: placements, requirements: [requirement]))
        let rendered = VersionMediaTextRenderer().render(list, style: .init(supportsColor: false, maximumWidth: 80), showRequirements: true)
        #expect(rendered.split(separator: "\n").allSatisfy { $0.count <= 80 })
        #expect(rendered.contains("IPHONE_FACE_ID_LARGE_PROFILE (2/10)"))
        let first = try #require(rendered.range(of: ids[0]))
        let second = try #require(rendered.range(of: ids[1]))
        #expect(first.lowerBound < second.lowerBound)
        let tableLines = rendered.split(separator: "\n").filter { line in ids.contains { line.contains($0) } }
        #expect(tableLines.count == 2)
        #expect(tableLines.allSatisfy { $0.contains(".png") && $0.contains("Active") })
        #expect(rendered.contains("Placement ID"))
        #expect(rendered.contains("Asset state: Prepare For Submission"))
        #expect(!rendered.contains(fileName))
        #expect(!rendered.contains("asset-secret"))
        #expect(rendered.contains("Active"))
        #expect(rendered.contains("max 500 MiB"))
        #expect(rendered.contains("886 × 1920 px"))
        #expect(!rendered.contains("maxFileSize"))
        #expect(!rendered.contains("specId"))
        #expect(rendered.contains("--format json"))
        let detail = VersionMediaActionOutput(result: .init(placements: [placements[0]]))
        let full = VersionMediaTextRenderer().render(detail, style: .init(supportsColor: false))
        #expect(full.contains(fileName))
        #expect(full.contains("asset-secret"))
        let encoded = try JSONValueEncoding.string(fromEncodable: list)
        #expect(encoded.contains(fileName))
        #expect(encoded.contains("asset-secret"))
        #expect(encoded.contains("specId"))
    }

    @Test func previewRequirementsDescribeDurationFrameRateAndAudio() {
        let output = VersionMediaActionOutput(list: .init(appID: "app", localizationID: "locale", placements: [], requirements: [requirement]))
        let rendered = VersionMediaTextRenderer().render(output, style: .init(supportsColor: false), showRequirements: true)
        #expect(rendered.contains("No media placements."))
        #expect(rendered.contains("15 s to 30 s"))
        #expect(rendered.contains("23 to 30 fps"))
        #expect(rendered.contains("audio required"))
        #expect(rendered.contains(".mp4, .mov"))
        // Identical reference specifications do not repeat the same requirement line.
        #expect(rendered.components(separatedBy: "886 × 1920 px").count == 2)
    }

    @Test func unknownSpecificationsAndDiagnosticsRemainDiscoverable() {
        let unknown = VersionMediaRequirement(placementGroup: "FUTURE_GROUP", specs: [.object(["newField": .string("new value")])])
        let item = VersionMediaPlacement(id: "p", assetID: "a", placementGroup: "FUTURE_GROUP", fileName: "future.mov", assetState: "FAILED", placementState: "FAILED", stateDetails: [.object(["code": .string("INVALID_MEDIA"), "description": .string("Apple explains the failure")])])
        let output = VersionMediaActionOutput(list: .init(appID: "app", localizationID: "locale", placements: [item], requirements: [unknown]))
        let rendered = VersionMediaTextRenderer().render(output, style: .init(supportsColor: false), showRequirements: true)
        #expect(rendered.contains("INVALID_MEDIA: Apple explains the failure"))
        #expect(rendered.contains("Additional specifications available with --format json."))
        #expect(!rendered.contains("newField"))
    }

    @Test func profilesHaveSeparateTablesAndMixedAssetStatesRemainVisible() {
        let placements = [
            placement("p1", fileName: "first.png"),
            VersionMediaPlacement(id: "p2", assetID: "a2", placementGroup: "IPHONE_FACE_ID_LARGE_PROFILE", fileName: "second.png", assetState: "FAILED", placementState: "FAILED"),
            VersionMediaPlacement(id: "p3", assetID: "a3", placementGroup: "IPAD_13_PROFILE", fileName: "third.png", assetState: "COMPLETE", placementState: "ACTIVE"),
        ]
        let output = VersionMediaActionOutput(list: .init(appID: "app", localizationID: "locale", placements: placements, requirements: []))
        let rendered = VersionMediaTextRenderer().render(output, style: .init(supportsColor: false), showRequirements: true)
        #expect(rendered.components(separatedBy: "Placement ID").count == 3)
        #expect(rendered.contains("1. Asset state: Prepare For Submission"))
        #expect(rendered.contains("2. Asset state: Failed"))
        #expect(rendered.contains("IPAD_13_PROFILE (1)"))
        #expect(rendered.contains("Asset state: Complete"))
    }

    private func placement(_ id: String, fileName: String) -> VersionMediaPlacement {
        .init(id: id, assetID: "asset-secret", placementGroup: "IPHONE_FACE_ID_LARGE_PROFILE", fileName: fileName, assetState: "PREPARE_FOR_SUBMISSION", placementState: "ACTIVE")
    }

    private var requirement: VersionMediaRequirement {
        let spec: JSONValue = .object([
            "specId": .string("specification-id"),
            "dimensions": .object(["minWidth": .integer(886), "maxWidth": .integer(886), "minHeight": .integer(1920), "maxHeight": .integer(1920)]),
            "fileExtensions": .array([.string(".mp4"), .string(".mov")]),
            "maxFileSize": .integer(524_288_000),
            "duration": .object(["min": .string("PT15S"), "max": .string("PT30S")]),
            "frameRates": .array([.object(["minFps": .integer(23), "maxFps": .integer(30)])]),
            "audioRequired": .bool(true),
        ])
        return .init(placementGroup: "IPHONE_FACE_ID_LARGE_PROFILE", specs: [spec, spec], maximumCount: 10)
    }
}
