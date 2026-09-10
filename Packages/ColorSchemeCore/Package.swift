// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ColorSchemeCore",
    platforms: [.iOS(.v26), .macOS(.v15)],
    products: [
        .library(name: "ColorAnalysis", targets: ["ColorAnalysis"]),
        .library(name: "ImageDecoding", targets: ["ImageDecoding"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "AnalysisWorkflow", targets: ["AnalysisWorkflow"]),
        .library(name: "TestSupport", targets: ["TestSupport"]),
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.11.1"),
    ],
    targets: [
        .target(name: "ColorAnalysis"),
        .target(name: "ImageDecoding", dependencies: ["ColorAnalysis"]),
        .target(
            name: "Persistence",
            dependencies: ["ColorAnalysis", .product(name: "GRDB", package: "GRDB.swift")]
        ),
        .target(name: "AnalysisWorkflow", dependencies: ["ColorAnalysis", "ImageDecoding", "Persistence"]),
        .target(name: "TestSupport"),
        .testTarget(name: "ColorAnalysisTests", dependencies: ["ColorAnalysis"]),
        .testTarget(name: "ImageDecodingTests", dependencies: ["ImageDecoding", "TestSupport"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence"]),
        .testTarget(name: "AnalysisWorkflowTests", dependencies: ["AnalysisWorkflow", "TestSupport"]),
    ],
    swiftLanguageModes: [.v6]
)
