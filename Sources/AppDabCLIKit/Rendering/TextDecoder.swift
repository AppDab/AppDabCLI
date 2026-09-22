import AppDabServices
import Foundation

enum TextDecoder {
    static func decode<Value: Decodable>(_ type: Value.Type, from content: JSONValue) throws -> Value {
        do {
            let data = try JSONEncoder().encode(content)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .custom { codingPath in
                let sourceKey = codingPath.last?.stringValue ?? ""
                return TextCodingKey(stringValue: modelKey(for: sourceKey))
            }
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            throw TextRenderingError.invalidStructuredContent(error.localizedDescription)
        }
    }

    private static func modelKey(for sourceKey: String) -> String {
        let knownKeys = [
            "account_id": "accountID",
            "app_id": "appID",
            "bundle_id": "bundleID",
            "icon_url": "iconURL",
            "version_id": "versionID",
            "review_id": "reviewID",
            "response_id": "responseID"
        ]
        if let knownKey = knownKeys[sourceKey] {
            return knownKey
        }
        let components = sourceKey.split(separator: "_")
        guard let first = components.first else {
            return sourceKey
        }
        return String(first) + components.dropFirst().map { $0.capitalized }.joined()
    }
}
