import SwiftUI

struct LibreLoopApplySensorView: View {
    let onNext: () -> Void
    let onShowHelp: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "figure.arms.open")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .foregroundStyle(.tint)
                        .padding(.top, 32)

                    Text("Apply a new Sensor")
                        .font(.title2.weight(.semibold))

                    VStack(alignment: .leading, spacing: 16) {
                        Text("The sensor should only be applied to the back of your upper arm.")
                        Text("Do not remove the cap from the sensor applicator until you're ready to apply the sensor.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)

                    Button(action: onShowHelp) {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                            Text("HOW TO APPLY A SENSOR")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            }

            Button(action: onNext) {
                Text("Next")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding()
        }
        .navigationTitle("FreeStyle Libre 3")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
    }
}
