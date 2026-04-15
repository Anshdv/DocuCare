import SwiftUI

struct ConsentAndPrivacyView: View {
    let languageCode: String
    @State private var acknowledged = false
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            AppBackgroundView()
            VStack(alignment: .leading, spacing: 24) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(L10n.string(.consentPolicyTitle, languageCode: languageCode))
                            .font(.title)
                            .bold()
                            .foregroundStyle(AppTheme.softText)
                            .padding(.bottom, 8)

                        Text(L10n.string(.consentPolicyBody, languageCode: languageCode))
                            .font(.body)
                            .foregroundStyle(AppTheme.softText)

                        HStack(alignment: .top) {
                            Toggle(isOn: $acknowledged) {
                                Text(L10n.string(.consentToggleLabel, languageCode: languageCode))
                                    .font(.callout)
                                    .foregroundStyle(AppTheme.secondaryText)
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
                .appCardStyle()
                .padding(.horizontal, 18)
                .padding(.top, 20)

                Spacer()

                Button(action: {
                    if acknowledged {
                        onContinue()
                    }
                }) {
                    Text(L10n.string(.consentContinue, languageCode: languageCode))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(!acknowledged)
                .opacity(acknowledged ? 1 : 0.6)
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
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
