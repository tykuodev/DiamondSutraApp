import ProjectDescription

let project = Project(
    name: "DiamondSutraApp",
    organizationName: "kuotinyen",
    packages: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.19"),
    ],
    targets: [
        .target(
            name: "DiamondSutraApp",
            destinations: .iOS,
            product: .app,
            bundleId: "com.kuotinyen.DiamondSutraApp",
            deploymentTargets: .iOS("17.0"),
            infoPlist: .extendingDefault(with: [
                "UILaunchScreen": .dictionary([:]),
            ]),
            sources: ["Sources/**"],
            resources: ["Resources/**"],
            dependencies: [
                .package(product: "ZIPFoundation"),
            ]
        )
    ]
)
