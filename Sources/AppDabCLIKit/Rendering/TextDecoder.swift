import AppDabServices
import Foundation

enum TextDecoder {
    static func decode<Value: Decodable>(_ type: Value.Type, from content: JSONValue) throws -> Value {
        do {
            let data = try JSONEncoder().encode(content)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(type, from: data)
        } catch {
            throw TextRenderingError.invalidStructuredContent(error.localizedDescription)
        }
    }
}
