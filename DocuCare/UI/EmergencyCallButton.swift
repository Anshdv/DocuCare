import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A red "Emergency Call" button that confirms with the user, then dials the
/// device's local emergency services number (e.g. 911 in the US, 112 in much
/// of Europe, 999 in the UK).
///
/// Two visual styles are supported:
/// - `.prominent`: full-width red pill, suited for login / onboarding cards.
/// - `.compact`: a small circular icon button, suited for nav bar toolbars.
struct EmergencyCallButton: View {
    enum Style {
        case prominent
        case compact
    }

    let languageCode: String
    var style: Style = .prominent

    @State private var showingConfirm = false
    @State private var showingUnavailable = false

    private var number: String { EmergencyServices.localNumber }

    var body: some View {
        Button {
            showingConfirm = true
        } label: {
            content
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.string(.emergencyCallAccessibility, languageCode: languageCode))
        .accessibilityHint(L10n.emergencyAlertMessage(number: number, languageCode: languageCode))
        .alert(
            L10n.string(.emergencyAlertTitle, languageCode: languageCode),
            isPresented: $showingConfirm,
            actions: {
                Button(L10n.emergencyCallAction(number: number, languageCode: languageCode), role: .destructive) {
                    if !EmergencyServices.placeCall() {
                        showingUnavailable = true
                    }
                }
                Button(L10n.string(.cancel, languageCode: languageCode), role: .cancel) {}
            },
            message: {
                Text(L10n.emergencyAlertMessage(number: number, languageCode: languageCode))
            }
        )
        .alert(
            L10n.string(.emergencyUnavailableTitle, languageCode: languageCode),
            isPresented: $showingUnavailable,
            actions: {
                Button(L10n.string(.ok, languageCode: languageCode)) {}
            },
            message: {
                Text(L10n.emergencyUnavailableMessage(number: number, languageCode: languageCode))
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        switch style {
        case .prominent:
            HStack(spacing: 10) {
                Image(systemName: "phone.fill")
                Text(L10n.string(.emergencyCallButton, languageCode: languageCode))
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.86, green: 0.10, blue: 0.18),
                        Color(red: 0.95, green: 0.32, blue: 0.32)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: Color.red.opacity(0.30), radius: 10, y: 4)

        case .compact:
            Image(systemName: "phone.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(Circle().fill(Color.red))
                .shadow(color: Color.red.opacity(0.35), radius: 4, y: 2)
        }
    }
}

// MARK: - Emergency services lookup + dialer

/// Looks up the appropriate emergency number for the device's current region
/// and places a `tel://` call when invoked.
enum EmergencyServices {
    /// Best-effort emergency number for the device's current region.
    /// Falls back to `911` when the region is unknown or unmapped.
    static var localNumber: String {
        let region: String
        if #available(iOS 16.0, *) {
            region = Locale.current.region?.identifier ?? ""
        } else {
            region = Locale.current.regionCode ?? ""
        }
        return number(for: region.uppercased())
    }

    /// Maps an ISO 3166 region code to its primary emergency telephone number.
    /// Source: Wikipedia "List of emergency telephone numbers" (general/police).
    static func number(for regionCode: String) -> String {
        switch regionCode {
        case "US", "CA", "MX", "PA", "DO", "PR":
            return "911"
        case "GB", "IE", "BH", "MO", "PL":
            return "999"
        case "AU", "NZ":
            return "000"
        case "JP", "KR":
            return "119"
        case "CN", "HK", "TW":
            return "120"
        case "BR":
            return "192"
        case "IN", "NP", "BD", "PK":
            return "112"
        // EU / 112 region
        case "AT", "BE", "BG", "CH", "CY", "CZ", "DE", "DK", "EE", "ES", "FI", "FR",
             "GR", "HR", "HU", "IT", "LT", "LU", "LV", "MT", "NL", "NO", "PT", "RO",
             "RU", "SE", "SI", "SK", "TR", "UA", "IL", "ZA", "VN":
            return "112"
        default:
            return "911"
        }
    }

    /// Attempts to dial the local emergency number. Returns `false` when the
    /// device cannot place phone calls (e.g. iPad, Simulator), so the caller
    /// can show an "unavailable" message instead.
    @discardableResult
    static func placeCall() -> Bool {
        #if canImport(UIKit)
        guard let url = URL(string: "tel://\(localNumber)"),
              UIApplication.shared.canOpenURL(url) else {
            return false
        }
        UIApplication.shared.open(url)
        return true
        #else
        return false
        #endif
    }
}

// MARK: - L10n helpers

private extension L10n {
    static func emergencyAlertMessage(number: String, languageCode: String) -> String {
        let fmt = string(.emergencyAlertMessageFormat, languageCode: languageCode)
        return String(format: fmt, number)
    }

    static func emergencyCallAction(number: String, languageCode: String) -> String {
        let fmt = string(.emergencyCallActionFormat, languageCode: languageCode)
        return String(format: fmt, number)
    }

    static func emergencyUnavailableMessage(number: String, languageCode: String) -> String {
        let fmt = string(.emergencyUnavailableMessageFormat, languageCode: languageCode)
        return String(format: fmt, number)
    }
}

#if DEBUG
struct EmergencyCallButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            EmergencyCallButton(languageCode: "en", style: .prominent)
                .padding(.horizontal, 24)
            EmergencyCallButton(languageCode: "en", style: .compact)
        }
        .padding()
        .background(AppBackgroundView())
    }
}
#endif
