import SwiftUI

struct LibreLoopRecoveryView: View {
    let onContinue: (UInt32) -> Void

    @State private var receiverIDInput: String = ""
    @State private var validationError: String?

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "key.horizontal.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tint)
                        Text("Recover existing sensor")
                            .font(.title2.weight(.semibold))
                        Text("Enter the receiver ID this sensor was originally paired under. The sensor only accepts a switch-receiver command from the same ID it remembers — there's no way to recover without it.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Receiver ID")
                            .font(.subheadline.weight(.semibold))
                        TextField("8-character hex (little-endian)", text: $receiverIDInput)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .monospaced()
                            .onChange(of: receiverIDInput) { _, _ in validationError = nil }
                        Text("Example: `78563412`. If this sensor was paired with this app before, the value is shown as \"Receiver ID\" in the Debug Info section of the Libre 3 CGM settings page.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let validationError {
                            Text(validationError)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }

                    Text("The receiver ID is assigned by Loop when it first pairs a sensor. It's saved in this app and shown on the Libre 3 settings page — write it down if you want to re-pair this sensor after reinstalling Loop.")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 16)
                }
                .padding(24)
            }

            Button(action: tryContinue) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(receiverIDInput.isEmpty)
            .padding()
        }
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func tryContinue() {
        let cleaned = receiverIDInput
            .replacingOccurrences(of: "0x", with: "", options: [.caseInsensitive])
            .filter { $0.isHexDigit }
        guard cleaned.count == 8 else {
            validationError = "Enter exactly 8 hex characters."
            return
        }
        // Little-endian: first hex pair is the least-significant byte
        var bytes: [UInt8] = []
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            let next = cleaned.index(idx, offsetBy: 2)
            guard let b = UInt8(cleaned[idx..<next], radix: 16) else {
                validationError = "Couldn't parse hex."
                return
            }
            bytes.append(b)
            idx = next
        }
        let value = UInt32(bytes[0]) |
            (UInt32(bytes[1]) << 8) |
            (UInt32(bytes[2]) << 16) |
            (UInt32(bytes[3]) << 24)
        onContinue(value)
    }
}
