import SwiftUI

struct LibreLoopScanHelpPagerView: View {
    let onDone: () -> Void

    private let steps: [HelpStep] = [
        HelpStep(
            title: "STEP 1",
            image: .systemSymbol("iphone.gen3.radiowaves.left.and.right"),
            body: "Hold the BACK of your phone against the sensor.",
            note: nil
        ),
        HelpStep(
            title: "STEP 2",
            image: .systemSymbol("hand.raised.fill"),
            body: "Keep the phone still. Pairing takes a few seconds.",
            note: "If your phone moves away, the scan will fail and you'll need to try again."
        ),
        HelpStep(
            title: "STEP 3",
            image: .systemSymbol("checkmark.seal.fill"),
            body: "Your phone will vibrate when pairing succeeds.",
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
            .navigationTitle("How to scan a Sensor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }
}
