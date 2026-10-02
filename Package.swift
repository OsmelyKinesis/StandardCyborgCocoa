//swift-tools-version:6.0

import PackageDescription

/// Builds the package's own code as Release even when the app runs in Debug.
///
/// Xcode's Debug configuration defines DEBUG=1, enables libc++'s debug hardening mode and leaves
/// assertions on. Besides slowing down reconstruction (Eigen and checked containers in every inner
/// loop), DEBUG switches PBFModel to a fixed 1/30 s frame interval meant for very slow debug runs,
/// so tracking degrades in apps launched from Xcode. Passed as unsafe flags, these come after
/// Xcode's own and override them.
let releaseFlags = [
    "-Os",
    "-UDEBUG",
    "-DNDEBUG",
    "-U_LIBCPP_HARDENING_MODE",
    "-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_NONE",
]

let package = Package(
    name: "StandardCyborg",
    platforms: [
        .iOS(.v16), .macOS(.v12)
    ],
    products: [
        .library(
            name: "StandardCyborgFusion",
            type: .dynamic,
            targets: ["StandardCyborgFusion"]
        ),
        .library(
            name: "scsdk",
            type: .dynamic,
            targets: ["standard_cyborg"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/ZipArchive/ZipArchive.git", from: "2.6.0"),
    ],
    targets: [
        // MARK: - C++ Dependencies

        .target(
            name: "Eigen",
            path: "CppDependencies/Eigen",
            exclude: ["Package.swift"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "happly",
            path: "CppDependencies/happly",
            exclude: ["Package.swift"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "json",
            path: "CppDependencies/json",
            exclude: ["Package.swift"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "nanoflann",
            path: "CppDependencies/nanoflann",
            exclude: ["Package.swift"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "PoissonRecon",
            path: "CppDependencies/PoissonRecon/Sources",
            publicHeadersPath: "include",
            cxxSettings: [
                .define("STD_LIB_FLAG"),
                .unsafeFlags(["-Wno-dangling-else", "-Wno-nontrivial-memcall"] + releaseFlags),
            ],
            linkerSettings: [
                .linkedFramework("Foundation"),
            ]
        ),
        .target(
            name: "SparseICP",
            path: "CppDependencies/SparseICP",
            exclude: ["Package.swift"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "stb",
            path: "CppDependencies/stb",
            exclude: ["Package.swift"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "tinygltf",
            path: "CppDependencies/tinygltf",
            exclude: ["Package.swift"],
            publicHeadersPath: "include"
        ),
        .target(
            name: "doctest",
            path: "CppDependencies/doctest",
            publicHeadersPath: "include"
        ),

        // MARK: - Core C++ SDK

        .target(
            name: "standard_cyborg",
            dependencies: [
                "Eigen", "happly", "json", "nanoflann", "PoissonRecon", "SparseICP", "stb", "tinygltf"
            ],
            path: "scsdk/Sources/standard_cyborg",
            publicHeadersPath: "include",
            cxxSettings: [
                .unsafeFlags(["-fobjc-arc", "-fno-math-errno"] + releaseFlags),
                .define("FMT_HEADER_ONLY", to: "1", .when(platforms: [.iOS, .macOS])),
                .define("HAVE_CONFIG_H", to: "1", .when(platforms: [.iOS, .macOS])),
                .define("HAVE_PTHREAD", to: "1", .when(platforms: [.iOS, .macOS])),
                .define("GUID_LIBUUID", .when(platforms: [.iOS, .macOS])),
            ]
        ),

        // MARK: - StandardCyborgFusion

        .target(
            name: "StandardCyborgFusion",
            dependencies: [
                "json",
                "standard_cyborg",
                "PoissonRecon",
                "ZipArchive",
            ],
            path: "StandardCyborgFusion/Sources",
            // The Core ML models (ear landmarking, ear and foot tracking) are only loaded when an app passes
            // their URL to SCEarTracking, SCFootTracking or EarLandmarkingAnalysis, so they're not bundled:
            // they'd add ~28 MB to every app. Compiling the .mlmodel sources would also fail on Xcode 27
            // (Core ML header generation tries to install into /usr/local/include). To use those features,
            // copy the precompiled ModelsCompiled/*.mlmodelc as resources again.
            exclude: [
                "StandardCyborgFusion/Models",
                "StandardCyborgFusion/ModelsCompiled",
            ],
            publicHeadersPath: "include",
            cSettings: [
                // The Objective-C (.m) sources too, which cxxSettings doesn't cover
                .unsafeFlags(releaseFlags),
            ],
            cxxSettings: [
                // Always optimize, even for debug builds, in order to be usable while debugging the rest of an app
                .unsafeFlags(["-fobjc-arc", "-fno-math-errno", "-ffast-math"] + releaseFlags),
                .headerSearchPath("."),
                .headerSearchPath("../libigl/include"),
                .headerSearchPath("StandardCyborgFusion/Algorithm"),
                .headerSearchPath("StandardCyborgFusion/DataStructures"),
                .headerSearchPath("StandardCyborgFusion/EarLandmarking"),
                .headerSearchPath("StandardCyborgFusion/Helpers"),
                .headerSearchPath("StandardCyborgFusion/IO"),
                .headerSearchPath("StandardCyborgFusion/MetalDepthProcessor"),
                .headerSearchPath("StandardCyborgFusion/Private"),
                .headerSearchPath("include/StandardCyborgFusion"),
            ]
        ),

        // MARK: - Tests

        .testTarget(
            name: "scsdkTests",
            dependencies: ["standard_cyborg", "doctest"],
            path: "scsdk/Tests",
            resources: [
                .copy("test_fixture_data"),
            ],
            cxxSettings: [
                .headerSearchPath("scsdk_test"),
            ],
            linkerSettings: [
                .linkedFramework("XCTest"),
            ]
        ),
        .testTarget(
            name: "StandardCyborgFusionTests",
            dependencies: ["StandardCyborgFusion"],
            path: "StandardCyborgFusion/Tests",
            resources: [
                .copy("StandardCyborgFusionTests/Data")
            ],
            cxxSettings: [
                .define("DEBUG", .when(configuration: .debug)),
                .define("PROJECT_DIR", to: "\".\""),
                .unsafeFlags(["-fobjc-arc"]),
                .headerSearchPath("."),
                .headerSearchPath("../libigl/include"),
                .headerSearchPath("../Sources/StandardCyborgFusion/Algorithm"),
                .headerSearchPath("../Sources/StandardCyborgFusion/DataStructures"),
                .headerSearchPath("../Sources/StandardCyborgFusion/Helpers"),
                .headerSearchPath("../Sources/StandardCyborgFusion/IO"),
                .headerSearchPath("../Sources/StandardCyborgFusion/MetalDepthProcessor"),
                .headerSearchPath("../Sources/StandardCyborgFusion/Private"),
                .headerSearchPath("../Sources/include/StandardCyborgFusion"),
            ],
            swiftSettings: [
                .define("ONLY_IOS", .when(platforms: [.iOS]))
            ],
            linkerSettings: [
                .linkedFramework("XCTest"),
            ]
        ),
    ],
    swiftLanguageModes: [.v5],
    cxxLanguageStandard: .cxx17
)
