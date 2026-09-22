import ArgumentParser
import BagbutikCore

struct PlatformArgument: ExpressibleByArgument {
    let value: Platform

    init?(argument: String) {
        guard let value = Platform.allCases.first(where: { $0.prettyName == argument }) else {
            return nil
        }
        self.value = value
    }
}
