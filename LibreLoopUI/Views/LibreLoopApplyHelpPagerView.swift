import SwiftUI

struct LibreLoopApplyHelpPagerView: View {
    let onDone: () -> Void

    private let steps: [HelpStep] = [
        HelpStep(
            title: "STEP 1",
            symbol: "figure.arms.open",
            body: "Select a site on the back of your upper arm.",
            note: "Avoid scars, moles, stretch marks, lumps, and insulin injection sites. Rotate sites between applications."
        ),
        HelpStep(
            title: "STEP 2",
            symbol: "hand.wave",
            body: "Wash the site with plain soap, dry, then clean with an alcohol wipe.",
            note: "Let the area air-dry completely before applying."
        ),
        HelpStep(
            title: "STEP 3",
            symbol: "arrow.down.circle",
            body: "Remove the cap from the sensor applicator.",
            note: "Do not reuse the cap. The sterile barrier is broken once removed."
        ),
        HelpStep(
            title: "STEP 4",
            symbol: "checkmark.circle.fill",
            body: "Press the applicator firmly against the prepared site, then lift away.",
            note: "Run a finger around the adhesive edge to make sure the sensor is secure."
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
    let symbol: String
    let body: String
    let note: String?
}

struct HelpStepCard: View {
    let step: HelpStep

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: step.symbol)
                .resizable()
                .scaledToFit()
                .frame(height: 120)
                .foregroundStyle(.tint)
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
}
