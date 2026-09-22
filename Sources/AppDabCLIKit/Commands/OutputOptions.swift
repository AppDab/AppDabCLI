import ArgumentParser

struct OutputOptions: ParsableArguments {
    @Option(help: "Output format. Text is the default.")
    var format: CLIOutputFormat = .text

    @Flag(help: "Include the stable error code and diagnostic details in text errors.")
    var verbose = false
}
