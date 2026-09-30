import AppDabAutomation
import AppDabLocales
import AppDabServices
import ArgumentParser

struct BetaAppTestingCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "betaAppTesting",
        abstract: "Manage TestFlight app localizations, review details, and license agreements.",
        subcommands: [
            BetaAppTestingListLocalizationsCommand.self,
            BetaAppTestingCreateLocalizationCommand.self,
            BetaAppTestingUpdateLocalizationCommand.self,
            BetaAppTestingDeleteLocalizationCommand.self,
            BetaAppTestingGetReviewDetailCommand.self,
            BetaAppTestingUpdateReviewDetailCommand.self,
            BetaAppTestingGetLicenseAgreementCommand.self,
            BetaAppTestingUpdateLicenseAgreementCommand.self,
        ],
    )
}

struct BetaAppTestingTargetOptions: ParsableArguments {
    @Option(name: .customLong("account-id"), help: "The AppDab account identifier.") var accountID: String
    @Option(name: .customLong("app-id"), help: "The App Store Connect app identifier.") var appID: String
    @OptionGroup var output: OutputOptions
}

struct BetaAppTestingLocalizationFields: ParsableArguments {
    @Option(help: "The beta testing description, up to 4000 characters.") var description: String
    @Option(name: .customLong("feedback-email"), help: "The tester feedback email address.") var feedbackEmail: String
    @Option(name: .customLong("marketing-url"), help: "The marketing URL.") var marketingURL: String
    @Option(name: .customLong("privacy-policy-url"), help: "The privacy policy URL.") var privacyPolicyURL: String
    @Option(name: .customLong("tvos-privacy-policy"), help: "Apple TV privacy policy text, up to 6000 characters.") var tvOSPrivacyPolicy: String

    mutating func validate() throws {
        if description.count > 4000 || tvOSPrivacyPolicy.count > 6000 {
            throw ValidationError("Beta localization text exceeds its character limit.")
        }
    }

    var changes: BetaAppLocalizationChanges {
        .init(description: description, feedbackEmail: feedbackEmail, marketingURL: marketingURL,
              privacyPolicyURL: privacyPolicyURL, tvOSPrivacyPolicy: tvOSPrivacyPolicy)
    }
}

struct BetaAppTestingListLocalizationsCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "listLocalizations", abstract: "List an app's beta testing localizations.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    var invocation: CLIInvocation {
        .read(ListBetaAppLocalizationsAction.self,
              input: .init(accountID: target.accountID, appID: target.appID),
              format: target.output.format, verbose: target.output.verbose,
              render: { value, _ in BetaAppLocalizationsTextRenderer().render(value) })
    }
}

struct BetaAppTestingCreateLocalizationCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "createLocalization", abstract: "Create a beta testing localization.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    @Option(help: "Locale identifier, such as en-US.") var locale: String
    @OptionGroup var execution: ExecutionOptions
    var invocation: CLIInvocation {
        let displayLocale = AppStoreConnectLocaleTextFormatter.format(locale)
        return .write(CreateBetaAppLocalizationAction.self,
                      input: .init(accountID: target.accountID, appID: target.appID, locale: locale),
                      format: target.output.format, verbose: target.output.verbose, executionContext: execution.context,
                      operationDescription: "create beta app localization \(displayLocale)",
                      render: { _, _ in BetaAppLocalizationsTextRenderer().created(locale: locale) })
    }
}

struct BetaAppTestingUpdateLocalizationCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "updateLocalization", abstract: "Update all fields of a beta testing localization.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    @Option(name: .customLong("localization-id"), help: "The beta app localization identifier.") var localizationID: String
    @OptionGroup var fields: BetaAppTestingLocalizationFields
    @OptionGroup var execution: ExecutionOptions
    var invocation: CLIInvocation {
        .write(UpdateBetaAppLocalizationAction.self,
               input: .init(accountID: target.accountID, appID: target.appID, localizationID: localizationID,
                            localizationChanges: fields.changes),
               format: target.output.format, verbose: target.output.verbose, executionContext: execution.context,
               operationDescription: "update beta app localization \(localizationID)",
               render: { localization, _ in BetaAppLocalizationsTextRenderer().updated(localization, fallbackID: localizationID) })
    }
}

struct BetaAppTestingDeleteLocalizationCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "deleteLocalization", abstract: "Delete a beta testing localization.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    @Option(name: .customLong("localization-id"), help: "The beta app localization identifier.") var localizationID: String
    @OptionGroup var execution: ExecutionOptions
    var invocation: CLIInvocation {
        .write(DeleteBetaAppLocalizationAction.self,
               input: .init(accountID: target.accountID, appID: target.appID, localizationID: localizationID),
               format: target.output.format, verbose: target.output.verbose, executionContext: execution.context,
               operationDescription: "delete beta app localization \(localizationID)",
               render: { localization, _ in BetaAppLocalizationsTextRenderer().deleted(localization, fallbackID: localizationID) })
    }
}

struct BetaAppTestingGetReviewDetailCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "getReviewDetail", abstract: "Get beta app review contact and demo account details.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    var invocation: CLIInvocation {
        .read(GetBetaAppReviewDetailAction.self,
              input: .init(accountID: target.accountID, appID: target.appID),
              format: target.output.format, verbose: target.output.verbose,
              render: { value, _ in
                  let detail = value.objectValue?["reviewDetail"]?.objectValue ?? [:]
                  return "Review detail ID: \(detail["reviewDetailID"]?.stringValue ?? "Unknown")\nContact: \(detail["contactEmail"]?.stringValue ?? "Unknown")"
              })
    }
}

struct BetaAppTestingReviewFields: ParsableArguments {
    @Option(name: .customLong("contact-first-name")) var contactFirstName: String
    @Option(name: .customLong("contact-last-name")) var contactLastName: String
    @Option(name: .customLong("contact-phone")) var contactPhone: String
    @Option(name: .customLong("contact-email")) var contactEmail: String
    @Option(name: .customLong("demo-account-required"), help: "Whether a demo account is required: true or false.") var demoAccountRequired: Bool
    @Option(name: .customLong("demo-account-name")) var demoAccountName: String
    @Option(name: .customLong("demo-account-password")) var demoAccountPassword: String
    @Option var notes: String

    var changes: BetaAppReviewDetailChanges {
        .init(contactFirstName: contactFirstName, contactLastName: contactLastName, contactPhone: contactPhone,
              contactEmail: contactEmail, demoAccountRequired: demoAccountRequired,
              demoAccountName: demoAccountName, demoAccountPassword: demoAccountPassword, notes: notes)
    }
}

struct BetaAppTestingUpdateReviewDetailCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "updateReviewDetail", abstract: "Update beta app review contact and demo account details.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    @OptionGroup var fields: BetaAppTestingReviewFields
    @OptionGroup var execution: ExecutionOptions
    var invocation: CLIInvocation {
        .write(UpdateBetaAppReviewDetailAction.self,
               input: .init(accountID: target.accountID, appID: target.appID, reviewDetailChanges: fields.changes),
               format: target.output.format, verbose: target.output.verbose, executionContext: execution.context,
               operationDescription: "update beta app review details for \(target.appID)",
               render: { _, _ in "Updated beta app review details for \(target.appID)." })
    }
}

struct BetaAppTestingGetLicenseAgreementCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "getLicenseAgreement", abstract: "Get an app's beta license agreement.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    var invocation: CLIInvocation {
        .read(GetBetaLicenseAgreementAction.self,
              input: .init(accountID: target.accountID, appID: target.appID),
              format: target.output.format, verbose: target.output.verbose,
              render: { value, _ in
                  let agreement = value.objectValue?["licenseAgreement"]?.objectValue ?? [:]
                  return agreement["agreementText"]?.stringValue ?? "No beta license agreement text."
              })
    }
}

struct BetaAppTestingUpdateLicenseAgreementCommand: ParsableCommand, InvokingCommand {
    static let configuration = CommandConfiguration(commandName: "updateLicenseAgreement", abstract: "Update an app's beta license agreement.")
    @OptionGroup var target: BetaAppTestingTargetOptions
    @Option(name: .customLong("agreement-text"), help: "The complete beta license agreement text.") var agreementText: String
    @OptionGroup var execution: ExecutionOptions
    var invocation: CLIInvocation {
        .write(UpdateBetaLicenseAgreementAction.self,
               input: .init(accountID: target.accountID, appID: target.appID, agreementText: agreementText),
               format: target.output.format, verbose: target.output.verbose, executionContext: execution.context,
               operationDescription: "update beta license agreement for \(target.appID)",
               render: { _, _ in "Updated beta license agreement for \(target.appID)." })
    }
}
