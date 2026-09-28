import ArgumentParser
import BagbutikAppStoreModels

struct AppVersionStateArgument: ExpressibleByArgument {
    let value: AppVersionState

    init?(argument: String) {
        guard let value = AppVersionState(rawValue: argument) else {
            return nil
        }
        self.value = value
    }
}
