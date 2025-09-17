// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Epilogue",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "Epilogue",
            targets: ["Epilogue"]),
    ],
    dependencies: [
        // UIImageColors for Apple Music quality color extraction
        .package(url: "https://github.com/jathu/UIImageColors.git", from: "2.2.0")
    ],
    targets: [
        .target(
            name: "Epilogue",
            dependencies: ["UIImageColors"]),
        .testTarget(
            name: "EpilogueTests",
            dependencies: ["Epilogue"]),
    ]
)