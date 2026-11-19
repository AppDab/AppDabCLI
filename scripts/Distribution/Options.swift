import Foundation

struct Options {
    var values: [String: String] = [:]
    var flags: Set<String> = []
    init(_ arguments: [String], required: [String], optional: [String] = [], flags allowedFlags: [String] = []) throws {
        var index = 0
        while index < arguments.count {
            let key = arguments[index]
            guard values[key] == nil, !flags.contains(key) else { throw Failure("Duplicate option: \(key)") }
            if allowedFlags.contains(key) {
                flags.insert(key)
            } else {
                guard (required + optional).contains(key), index + 1 < arguments.count else { throw Failure("Unknown or incomplete option: \(key)") }
                index += 1
                values[key] = arguments[index]
            }
            index += 1
        }
        for key in required where values[key] == nil {
            throw Failure("Missing required option: \(key)")
        }
    }

    subscript(_ key: String) -> String {
        values[key] ?? ""
    }

    func url(_ key: String) -> URL {
        URL(fileURLWithPath: self[key]).standardizedFileURL
    }
}
