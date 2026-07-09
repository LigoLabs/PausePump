// swift-tools-version: 5.9
// Moteur de séance PausePump pour l'app watchOS — Swift pur (Foundation
// uniquement), testable par `swift test` sur n'importe quel Mac, sans Xcode
// project ni simulateur. Les sources sont AUSSI compilées directement dans la
// target watch (ajoutées par ios/scripts/setup_ios_targets.rb).
import PackageDescription

let package = Package(
    name: "WatchEngine",
    platforms: [.watchOS(.v9), .iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "WatchEngine", targets: ["WatchEngine"]),
    ],
    targets: [
        .target(name: "WatchEngine"),
        .testTarget(name: "WatchEngineTests", dependencies: ["WatchEngine"]),
    ]
)
