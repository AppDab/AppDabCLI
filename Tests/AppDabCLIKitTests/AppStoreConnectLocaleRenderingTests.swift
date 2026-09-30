import AppDabAutomation
@testable import AppDabCLIKit
import AppDabServices
import Testing

struct AppStoreConnectLocaleRenderingTests {
    @Test func rendersBetaBuildLocalizationWithDisplayNameAndIdentifier() {
        let output = BetaBuildLocalizationTextRenderer().render(.init(
            localizationID: "localization-1",
            locale: "en-US",
            whatsNew: "Test the new flow",
        ))

        #expect(output == "Updated What to Test for English (United States) (en-US).\nID: localization-1\nTest the new flow")
    }

    @Test func rendersBetaAppLocalizationListWithDisplayNames() {
        let output = BetaAppLocalizationsTextRenderer().render(.object([
            "localizations": .array([
                .object(["locale": .string("en-US"), "localizationID": .string("localization-1")]),
                .object(["locale": .string("xx-ZZ"), "localizationID": .string("localization-2")]),
            ]),
        ]))

        #expect(output == "English (United States) (en-US)  localization-1\nxx-ZZ  localization-2")
    }

    @Test func rendersBetaAppLocalizationMutationsWithDisplayNames() {
        let output = JSONValue.object(["localization": .object([
            "locale": .string("en-US"),
            "localizationID": .string("localization-1"),
        ])])

        #expect(BetaAppLocalizationsTextRenderer().created(locale: "en-US") == "Created beta app localization for English (United States) (en-US).")
        #expect(BetaAppLocalizationsTextRenderer().updated(output, fallbackID: "fallback") == "Updated beta app localization for English (United States) (en-US).\nID: localization-1")
        #expect(BetaAppLocalizationsTextRenderer().deleted(output, fallbackID: "fallback") == "Deleted beta app localization for English (United States) (en-US).\nID: localization-1")
    }

    @Test func localizesBetaBuildMutationPreviewSummary() {
        let plan = AutomationMutationPlan(
            planID: "plan-1",
            actionID: .updateBetaBuildLocalization,
            targetIdentifiers: ["account-1", "localization-1"],
            redactedSummary: "Update What to Test text for en-US.",
            canonicalInputHash: "hash",
            confirmationFingerprint: "fingerprint",
            remotePreconditions: ["localization": .object(["locale": .string("en-US")])],
            createdAt: .init(timeIntervalSince1970: 0),
            expiresAt: .init(timeIntervalSince1970: 60),
        )

        #expect(MutationPlanTextRenderer().summary(for: plan) == "Update What to Test text for English (United States) (en-US).")
    }
}
