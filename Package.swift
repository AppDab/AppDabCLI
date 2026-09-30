// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "AppDabCLI",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "dab", targets: ["AppDabCLI"]),
        .library(name: "AppDabCLIKit", targets: ["AppDabCLIKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/AppDab/AppDabKit", branch: "main"),
        .package(url: "https://github.com/MortenGregersen/AppStoreConnectKit", from: "4.2.0"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.7.0"),
    ],
    targets: [
        .executableTarget(name: "AppDabCLI", dependencies: [
            "AppDabCLIKit",
            .product(name: "AppDabAutomation", package: "AppDabKit"),
            .product(name: "AppDabServices", package: "AppDabKit"),
            .product(name: "ConnectAccounts", package: "AppStoreConnectKit"),
            .product(name: "ConnectKeychain", package: "AppStoreConnectKit"),
        ]),
        .target(name: "AppDabCLIKit", dependencies: [
            .product(name: "AppDabAutomation", package: "AppDabKit"),
            .product(name: "AppDabServices", package: "AppDabKit"),
            .product(name: "AppDabLocales", package: "AppDabKit"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ]),
        .testTarget(name: "AppDabCLIKitTests", dependencies: [
            "AppDabCLIKit",
            .product(name: "AppDabServices", package: "AppDabKit"),
            .product(name: "AppDabKitTestSupport", package: "AppDabKit"),
        ]),
        .testTarget(name: "AppDabCLITests", dependencies: [
            "AppDabCLI",
            .product(name: "ConnectAccounts", package: "AppStoreConnectKit"),
            .product(name: "ConnectKeychain", package: "AppStoreConnectKit"),
        ]),
    ],
)
