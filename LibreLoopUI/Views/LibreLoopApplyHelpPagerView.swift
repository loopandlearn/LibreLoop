import SwiftUI

struct LibreLoopApplyHelpPagerView: View {
    let onDone: () -> Void

    private let steps: [HelpStep] = [
        HelpStep(
            title: "STEP 1",
            image: .asset("ApplySensorStep1"),
            body: "Select a site on the back of your upper arm.",
            note: "Avoid scars, moles, stretch marks, lumps, and insulin injection sites. Rotate sites between applications."
        ),
        HelpStep(
            title: "STEP 2",
            image: .asset("ApplySensorStep2"),
            body: "Wash the site with plain soap, dry, then clean with an alcohol wipe.",
            note: "Let the area air-dry completely before applying."
        ),
        HelpStep(
            title: "STEP 3",
            image: .asset("ApplySensorStep3"),
            body: "Twist off the cap from the sensor applicator.",
            note: "Do not reuse the cap. The sterile barrier is broken once removed."
        ),
        HelpStep(
            title: "STEP 4",
            image: .asset("ApplySensorStep4"),
            body: "Press the applicator firmly against the prepared site.",
            note: "Hold steady for a moment so the sensor seats fully against the skin."
        ),
        HelpStep(
            title: "STEP 5",
            image: .asset("ApplySensorStep5"),
            body: "Lift the applicator straight away from your arm.",
            note: "The sensor stays on your arm; the applicator comes off empty."
        ),
        HelpStep(
            title: "STEP 6",
            image: .asset("ApplySensorStep6"),
            body: "Run a finger around the adhesive edge to make sure the sensor is secure.",
            note: nil
        )
    ]

    var body: some View {
        NavigationStack {
            TabView {
                ForEach(steps) { step in
                    HelpStepCard(step: step)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .navigationTitle("How to apply a Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}

struct HelpStep: Identifiable {
    let id = UUID()
    let title: String
    let image: HelpStepImage
    let body: String
    let note: String?
}

enum HelpStepImage {
    case systemSymbol(String)
    case asset(String)
}

struct HelpStepCard: View {
    let step: HelpStep

    var body: some View {
        VStack(spacing: 20) {
            stepImage
                .padding(.top, 32)

            Text(step.title)
                .font(.title3.weight(.bold))
                .tracking(2)

            Text(step.body)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let note = step.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var stepImage: some View {
        switch step.image {
        case .systemSymbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .foregroundStyle(.tint)
        case .asset(let name):
            // Asset-catalog SVG: load through UIImage from the framework
            // bundle for the same reason FSL3-sensor.png does -- SwiftUI's
            // Image(_:bundle:) is unreliable for plugin-framework assets.
            // The illustrations are drawn on a transparent background with
            // dark line work, so they need a light card behind them to read
            // in dark mode. Use a fixed light fill rather than a system
            // color so the contrast stays consistent in both modes.
            if let uiImage = UIImage(named: name,
                                     in: Bundle(for: LibreLoopSettingsViewModel.self),
                                     compatibleWith: nil) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 230)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.97))
                    )
                    .padding(.horizontal, 12)
            }
        }
    }
}
