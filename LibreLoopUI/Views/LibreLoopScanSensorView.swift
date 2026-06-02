import SwiftUI

struct LibreLoopScanSensorView: View {
    let onScan: () -> Void
    let onShowHelp: () -> Void
    let onShowRecovery: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 140)
                        .foregroundStyle(.tint)
                        .padding(.top, 32)

                    Text("Scan new Sensor")
                        .font(.title2.weight(.semibold))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hold the top of your phone against the sensor.")
                        Text("Keep it still — your phone will vibrate once the sensor is paired.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 24)

                    Button(action: onShowHelp) {
                        HStack(spacing: 8) {
                            Image(systemName: "questionmark.circle.fill")
                            Text("HOW TO SCAN A SENSOR")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 16)
            }

            VStack(spacing: 12) {
                Button(action: onScan) {
                    Text("Start pairing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)

                Button("Recover existing sensor", action: onShowRecovery)
                    .font(.subheadline)
            }
            .padding()
        }
        .navigationTitle("FreeStyle Libre 3")
        .navigationBarTitleDisplayMode(.inline)
    }
}
