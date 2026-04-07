import SwiftUI

struct ConsentAndPrivacyView: View {
    let languageCode: String
    @State private var acknowledged = false
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(L10n.string(.consentPolicyTitle, languageCode: languageCode))
                        .font(.title)
                        .bold()
                        .padding(.bottom, 8)

                    Text(L10n.string(.consentPolicyBody, languageCode: languageCode))
                        .font(.body)
                        .foregroundStyle(.primary)

                    HStack(alignment: .top) {
                        Toggle(isOn: $acknowledged) {
                            Text(L10n.string(.consentToggleLabel, languageCode: languageCode))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .toggleStyle(CheckboxToggleStyle(
                            checkedLabel: L10n.string(.accessibilityChecked, languageCode: languageCode),
                            uncheckedLabel: L10n.string(.accessibilityUnchecked, languageCode: languageCode)
                        ))
                    }
                    .padding(.top, 12)
                }
                .padding(.horizontal)
                .padding(.top)
                .textSelection(.enabled)
            }

            Spacer()

            Button(action: {
                if acknowledged {
                    onContinue()
                }
            }) {
                Text(L10n.string(.consentContinue, languageCode: languageCode))
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(acknowledged ? Color.accentColor : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .disabled(!acknowledged)
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .navigationTitle(L10n.string(.consentRequiredNav, languageCode: languageCode))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - iOS Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    var checkedLabel: String = "Checked"
    var uncheckedLabel: String = "Unchecked"

    func makeBody(configuration: Configuration) -> some View {
        Button(action: { configuration.isOn.toggle() }) {
            HStack(alignment: .top) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .foregroundColor(configuration.isOn ? .accentColor : .secondary)
                    .font(.title3)
                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.isOn ? checkedLabel : uncheckedLabel)
    }
}

#Preview {
    ConsentAndPrivacyView(languageCode: AppLanguage.english.rawValue, onContinue: {})
}
