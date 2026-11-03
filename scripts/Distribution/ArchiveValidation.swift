import Foundation

func validateArchivePath(_ path: String, link: String? = nil) throws {
    let parts = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
    guard !path.hasPrefix("/"), !path.contains("\0"), !path.contains("\n"), !path.contains("\r"), !parts.contains(".."), let root = parts.first, ["AppDabCLI.app", "__MACOSX"].contains(root) else { throw Failure("Unexpected archive path.") }
    if let link {
        guard !link.hasPrefix("/"), !link.contains("\0") else { throw Failure("Archive symlink leaves the bundle.") }
        var resolved = Array(parts.dropLast())
        for part in link.split(separator: "/").map(String.init) {
            if part == ".." {
                guard resolved.count > 1 else { throw Failure("Archive symlink leaves the bundle.") }
                resolved.removeLast()
            } else if part != "." {
                resolved.append(part)
            }
        }
    }
}

/// Inspect ZIP central directory metadata before allowing ditto to extract anything.
/// ZIP64 is unnecessary for these CLI packages and is deliberately rejected.
func validateArchive(_ archive: URL) throws {
    let data = try Data(contentsOf: archive, options: .mappedIfSafe)
    func integer(_ offset: Int, _ count: Int) throws -> Int {
        guard offset >= 0, offset <= data.count - count else { throw Failure("Truncated ZIP archive.") }
        return (0 ..< count).reduce(0) { $0 | Int(data[offset + $1]) << ($1 * 8) }
    }
    guard data.count >= 22 else { throw Failure("Invalid ZIP archive.") }
    let lower = max(0, data.count - 65557)
    var end: Int?
    for offset in stride(from: data.count - 22, through: lower, by: -1) {
        if try integer(offset, 4) == 0x0605_4B50, try offset + 22 + integer(offset + 20, 2) == data.count {
            end = offset; break
        }
    }
    guard let end else { throw Failure("Missing ZIP directory.") }
    let count = try integer(end + 10, 2)
    guard try integer(end + 4, 2) == 0, try integer(end + 6, 2) == 0, try integer(end + 8, 2) == count, count > 0, count < 65535 else { throw Failure("Unsupported ZIP directory.") }
    var offset = try integer(end + 16, 4)
    let directoryEnd = try offset + integer(end + 12, 4)
    guard directoryEnd == end else { throw Failure("Unsupported ZIP directory layout.") }
    var names: Set<String> = []
    for _ in 0 ..< count {
        guard try integer(offset, 4) == 0x0201_4B50 else { throw Failure("Invalid ZIP entry.") }
        let length = try integer(offset + 28, 2)
        let extra = try integer(offset + 30, 2)
        let comment = try integer(offset + 32, 2)
        let next = offset + 46 + length + extra + comment
        guard next <= directoryEnd else { throw Failure("Truncated ZIP entry.") }
        guard let name = String(data: data.subdata(in: offset + 46 ..< offset + 46 + length), encoding: .utf8), names.insert(name).inserted else { throw Failure("Invalid or duplicate ZIP path.") }
        try validateArchivePath(name)
        let mode = try integer(offset + 38, 4) >> 16
        if mode & 0o170000 == 0o120000 {
            guard try integer(offset + 24, 4) <= 4096 else { throw Failure("Oversized archive symlink.") }
            let target = try run(["unzip", "-p", archive.path, name], capture: true).output
            guard let link = String(data: target, encoding: .utf8) else { throw Failure("Invalid archive symlink.") }
            try validateArchivePath(name, link: link)
        }
        offset = next
    }
    guard offset == directoryEnd else { throw Failure("Invalid ZIP directory length.") }
}
