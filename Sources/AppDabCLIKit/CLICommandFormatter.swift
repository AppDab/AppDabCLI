import Foundation

enum CLICommandFormatter {
    static func render(arguments: [String], executable: String = "dab", reconcile: Bool = true) -> String {
        var cleaned: [String] = []
        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            let option = String(argument.prefix { $0 != "=" })
            if ["--verbose", "--preview", "--reconcile"].contains(option) {
                index += 1
                continue
            }
            if option == "--format" {
                index += argument.contains("=") ? 1 : 2
                continue
            }
            if option.hasPrefix("--"), isSensitive(option) {
                cleaned.append(argument.contains("=") ? "\(option)=<redacted>" : option)
                if !argument.contains("=") {
                    cleaned.append("<redacted>")
                    index += 1
                }
            } else {
                cleaned.append(argument)
                if option.hasPrefix("--"), !argument.contains("="), index + 1 < arguments.count {
                    cleaned.append(arguments[index + 1])
                    index += 1
                }
            }
            index += 1
        }
        if reconcile {
            cleaned.append("--reconcile")
        }
        var lines = [quote(executable)]
        var expectsValue = false
        for argument in cleaned {
            if expectsValue {
                lines[lines.count - 1] += " " + quote(argument)
                expectsValue = false
                continue
            }
            if argument.hasPrefix("--") {
                lines.append("  " + quote(argument))
                expectsValue = !argument.contains("=") && argument != "--reconcile"
            } else {
                lines[lines.count - 1] += " " + quote(argument)
            }
        }
        return lines.joined(separator: " \\\n")
    }

    static func quote(_ value: String) -> String {
        let safe = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._/:@")
        if !value.isEmpty, value.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return value
        }
        return "'\(value.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
    }

    private static func isSensitive(_ option: String) -> Bool {
        ["token", "secret", "password", "private-key", "api-key"].contains { option.lowercased().contains($0) }
    }
}
