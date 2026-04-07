import Foundation

/// Centralized UI strings keyed by `AppLanguage.rawValue`. Fallback: English.
enum L10n {
    enum Key: String {
        case welcomeTitle
        case welcomeSubtitle
        case email
        case password
        case language
        case chooseLanguage
        case logIn
        case signUpPrompt
        case createAccountTitle
        case createAccount
        case cancel
        case invalidCredentials
        case emailPasswordRequired
        case invalidEmail
        case accountExists
        case authenticating
        case reports
        case logOut
        case searchPlaceholder
        case scanMedicalReport
        case askQuestion
        case processing
        case importReport
        case takePicture
        case uploadPhotos
        case uploadFiles
        case noReportsFound
        case emptyScanPrompt
        case emptySearchPrompt
        case delete
        case openMedicalSummary
        case pageSingular
        case pagePlural
        case error
        case ok
        case chatErrorFormat
        case failedLoadImages
        case noSupportedFiles
        case reportDetails
        case reportTitlePlaceholder
        case briefSummary
        case scannedDocument
        case stopReadingSummary
        case readSummary
        case reportNotFound
        case reportMayBeDeleted
        case failedLoadReport
        case loading
        case locked
        case useFaceIDToUnlock
        case unlockWithFaceID
        case medicalReportFallback
        case changeLanguage
        case deleteReportTitle
        case deleteReportMessage
        case shareDialogTitle
        case shareSummary
        case shareScannedPDF
        case shareBoth
        case unablePreparePDFShare
        case unablePrepareDocumentShare
        case aiDisclaimer
        case consentPolicyTitle
        case consentPolicyBody
        case signUpErrorAlertTitle
        case consentRequiredNav
        case consentToggleLabel
        case consentContinue
        case accessibilityChecked
        case accessibilityUnchecked
        case unlockToAccessReports
        case biometricUnlockDocuCare
        case profileTitle
        case profileAccountSection
        case profileSecuritySection
        case profileNewEmailPlaceholder
        case profileCurrentPasswordForEmail
        case profileUpdateEmail
        case profileCurrentPassword
        case profileNewPassword
        case profileConfirmPassword
        case profileSavePassword
        case profilePrivacyButton
        case profileDone
        case profileSuccessTitle
        case profileEmailUpdated
        case profilePasswordUpdated
        case profilePasswordsMismatch
        case profileEmailUnchanged
        case incorrectPasswordError
    }

    private static let en: [Key: String] = [
        .welcomeTitle: "Welcome to DocuCare",
        .welcomeSubtitle: "AI-powered summaries for smarter care",
        .email: "Email",
        .password: "Password",
        .language: "Language",
        .chooseLanguage: "Choose your language",
        .logIn: "Log In",
        .signUpPrompt: "Don't have an account? Sign Up",
        .createAccountTitle: "Create a New Account",
        .createAccount: "Create Account",
        .cancel: "Cancel",
        .invalidCredentials: "Invalid email or password.",
        .emailPasswordRequired: "Email and password required.",
        .invalidEmail: "Please enter a valid email address.",
        .accountExists: "An account with this email already exists.",
        .authenticating: "Authenticating…",
        .reports: "Reports",
        .logOut: "Log Out",
        .searchPlaceholder: "Search by title or date",
        .scanMedicalReport: "Scan a medical report or image",
        .askQuestion: "Ask a question…",
        .processing: "Processing…",
        .importReport: "Import Report",
        .takePicture: "Take a picture",
        .uploadPhotos: "Upload from Photos",
        .uploadFiles: "Upload from Files",
        .noReportsFound: "No reports found",
        .emptyScanPrompt: "Scan a medical report to get started.",
        .emptySearchPrompt: "Try a different search or scan a new report.",
        .delete: "Delete",
        .openMedicalSummary: "Open Medical Summary",
        .pageSingular: "%d page",
        .pagePlural: "%d pages",
        .error: "Error",
        .ok: "OK",
        .chatErrorFormat: "Sorry, there was an error: %@",
        .failedLoadImages: "Failed to load images from selection.",
        .noSupportedFiles: "No supported images or PDFs found in selected files.",
        .reportDetails: "Report Details",
        .reportTitlePlaceholder: "Report Title",
        .briefSummary: "Brief Summary:",
        .scannedDocument: "Scanned Document",
        .stopReadingSummary: "Stop Reading Summary",
        .readSummary: "Read Summary",
        .reportNotFound: "Report not found",
        .reportMayBeDeleted: "The report may have been deleted.",
        .failedLoadReport: "Failed to load the report.",
        .loading: "Loading…",
        .locked: "Locked",
        .useFaceIDToUnlock: "Use Face ID to unlock your reports.",
        .unlockWithFaceID: "Unlock with Face ID",
        .medicalReportFallback: "Medical Report",
        .changeLanguage: "Language",
        .deleteReportTitle: "Delete Report?",
        .deleteReportMessage: "Are you sure you want to delete this report? This action cannot be undone.",
        .shareDialogTitle: "Share",
        .shareSummary: "Share Summary",
        .shareScannedPDF: "Share Scanned Document (PDF)",
        .shareBoth: "Share Both",
        .unablePreparePDFShare: "Unable to prepare PDF for sharing.",
        .unablePrepareDocumentShare: "Unable to prepare document for sharing.",
        .aiDisclaimer: "AI can make mistakes and may be wrong.",
        .consentPolicyTitle: "Consent & Privacy Policy",
        .consentPolicyBody: """
DocuCare uses artificial intelligence (AI) to help summarize and process your medical documents. While we take reasonable steps to protect your privacy and the security of your Protected Health Information (PHI), no system can guarantee 100% security.

Key Points:

• The AI may make mistakes or misinterpret documents.
• Sensitive information is processed using Apple platform security features and, when possible, is redacted before AI analysis.
• Your PHI is stored locally on your device and is accessible only to you when logged in.
• Sharing summaries or documents is at your discretion and may introduce privacy risks.
• We do not guarantee the prevention of all unauthorized access, loss, or misuse of your medical data.
• The use of this app is at your own risk, and you are ultimately responsible for how your data is handled, shared, and protected.

By continuing, you acknowledge that:
- You have read and understood this disclosure and privacy policy.
- You understand the risks and limitations of using DocuCare.
- You consent to the use of AI for document processing and the storage of PHI on your device.
""",
        .signUpErrorAlertTitle: "Sign Up Error",
        .consentRequiredNav: "Consent Required",
        .consentToggleLabel: "I acknowledge the information in the disclosure above.",
        .consentContinue: "Continue",
        .accessibilityChecked: "Checked",
        .accessibilityUnchecked: "Unchecked",
        .unlockToAccessReports: "Unlock to access your medical reports.",
        .biometricUnlockDocuCare: "Unlock DocuCare",
        .profileTitle: "Profile",
        .profileAccountSection: "Account",
        .profileSecuritySection: "Password",
        .profileNewEmailPlaceholder: "New email address",
        .profileCurrentPasswordForEmail: "Current password (to confirm)",
        .profileUpdateEmail: "Update email",
        .profileCurrentPassword: "Current password",
        .profileNewPassword: "New password",
        .profileConfirmPassword: "Confirm new password",
        .profileSavePassword: "Save new password",
        .profilePrivacyButton: "Privacy & consent",
        .profileDone: "Done",
        .profileSuccessTitle: "Success",
        .profileEmailUpdated: "Your email was updated.",
        .profilePasswordUpdated: "Your password was updated.",
        .profilePasswordsMismatch: "New passwords do not match.",
        .profileEmailUnchanged: "Enter a different email address than your current one.",
        .incorrectPasswordError: "The password you entered is incorrect.",
    ]

    private static func stringDict(from pairs: [Key: String]) -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in pairs { out[k.rawValue] = v }
        return out
    }

    private static let es: [String: String] = stringDict(from: [
        .welcomeTitle: "Bienvenido a DocuCare",
        .welcomeSubtitle: "Resúmenes con IA para una atención más inteligente",
        .email: "Correo electrónico",
        .password: "Contraseña",
        .language: "Idioma",
        .chooseLanguage: "Elige tu idioma",
        .logIn: "Iniciar sesión",
        .signUpPrompt: "¿No tienes cuenta? Regístrate",
        .createAccountTitle: "Crear una cuenta nueva",
        .createAccount: "Crear cuenta",
        .cancel: "Cancelar",
        .invalidCredentials: "Correo o contraseña no válidos.",
        .emailPasswordRequired: "Se requieren correo y contraseña.",
        .invalidEmail: "Introduce un correo electrónico válido.",
        .accountExists: "Ya existe una cuenta con este correo.",
        .authenticating: "Autenticando…",
        .reports: "Informes",
        .logOut: "Cerrar sesión",
        .searchPlaceholder: "Buscar por título o fecha",
        .scanMedicalReport: "Escanear un informe o imagen médica",
        .askQuestion: "Haz una pregunta…",
        .processing: "Procesando…",
        .importReport: "Importar informe",
        .takePicture: "Tomar una foto",
        .uploadPhotos: "Subir desde Fotos",
        .uploadFiles: "Subir desde Archivos",
        .noReportsFound: "No se encontraron informes",
        .emptyScanPrompt: "Escanea un informe médico para empezar.",
        .emptySearchPrompt: "Prueba otra búsqueda o escanea un informe nuevo.",
        .delete: "Eliminar",
        .openMedicalSummary: "Abrir resumen médico",
        .pageSingular: "%d página",
        .pagePlural: "%d páginas",
        .error: "Error",
        .ok: "OK",
        .chatErrorFormat: "Lo sentimos, hubo un error: %@",
        .failedLoadImages: "No se pudieron cargar las imágenes seleccionadas.",
        .noSupportedFiles: "No se encontraron imágenes ni PDF compatibles en los archivos seleccionados.",
        .reportDetails: "Detalles del informe",
        .reportTitlePlaceholder: "Título del informe",
        .briefSummary: "Resumen breve:",
        .scannedDocument: "Documento escaneado",
        .stopReadingSummary: "Detener lectura del resumen",
        .readSummary: "Leer resumen",
        .reportNotFound: "Informe no encontrado",
        .reportMayBeDeleted: "Es posible que el informe se haya eliminado.",
        .failedLoadReport: "No se pudo cargar el informe.",
        .loading: "Cargando…",
        .locked: "Bloqueado",
        .useFaceIDToUnlock: "Usa Face ID para desbloquear tus informes.",
        .unlockWithFaceID: "Desbloquear con Face ID",
        .medicalReportFallback: "Informe médico",
        .changeLanguage: "Idioma",
        .deleteReportTitle: "¿Eliminar informe?",
        .deleteReportMessage: "¿Seguro que quieres eliminar este informe? Esta acción no se puede deshacer.",
        .shareDialogTitle: "Compartir",
        .shareSummary: "Compartir resumen",
        .shareScannedPDF: "Compartir documento escaneado (PDF)",
        .shareBoth: "Compartir ambos",
        .unablePreparePDFShare: "No se pudo preparar el PDF para compartir.",
        .unablePrepareDocumentShare: "No se pudo preparar el documento para compartir.",
        .aiDisclaimer: "La IA puede equivocarse y estar incorrecta.",
        .consentPolicyTitle: "Consentimiento y privacidad",
        .consentPolicyBody: """
DocuCare utiliza inteligencia artificial (IA) para ayudar a resumir y procesar sus documentos médicos. Aunque tomamos medidas razonables para proteger su privacidad y la seguridad de su Información de Salud Protegida (PHI), ningún sistema puede garantizar un 100% de seguridad.

Puntos clave:

• La IA puede cometer errores o malinterpretar documentos.
• La información sensible se procesa con las funciones de seguridad de Apple y, cuando es posible, se redacta antes del análisis por IA.
• Su PHI se almacena localmente en su dispositivo y solo usted puede acceder cuando ha iniciado sesión.
• Compartir resúmenes o documentos es su decisión y puede implicar riesgos de privacidad.
• No garantizamos evitar todo acceso no autorizado, pérdida o uso indebido de sus datos médicos.
• El uso de esta aplicación es bajo su propio riesgo; usted es responsable de cómo maneja, comparte y protege sus datos.

Al continuar, reconoce que ha leído y comprende esta información, entiende los riesgos y limitaciones, y consiente el uso de IA y el almacenamiento local de PHI en su dispositivo.
""",
        .signUpErrorAlertTitle: "Error de registro",
        .consentRequiredNav: "Consentimiento necesario",
        .consentToggleLabel: "Reconozco la información de la divulgación anterior.",
        .consentContinue: "Continuar",
        .accessibilityChecked: "Marcado",
        .accessibilityUnchecked: "Sin marcar",
        .unlockToAccessReports: "Desbloquea para acceder a tus informes médicos.",
        .biometricUnlockDocuCare: "Desbloquear DocuCare",
    ])

    private static let fr: [String: String] = stringDict(from: [
        .welcomeTitle: "Bienvenue sur DocuCare",
        .welcomeSubtitle: "Des résumés par IA pour des soins plus intelligents",
        .email: "E-mail",
        .password: "Mot de passe",
        .language: "Langue",
        .chooseLanguage: "Choisissez votre langue",
        .logIn: "Connexion",
        .signUpPrompt: "Pas de compte ? Inscrivez-vous",
        .createAccountTitle: "Créer un compte",
        .createAccount: "Créer le compte",
        .cancel: "Annuler",
        .invalidCredentials: "E-mail ou mot de passe invalide.",
        .emailPasswordRequired: "E-mail et mot de passe requis.",
        .invalidEmail: "Veuillez saisir une adresse e-mail valide.",
        .accountExists: "Un compte existe déjà avec cet e-mail.",
        .authenticating: "Authentification…",
        .reports: "Rapports",
        .logOut: "Déconnexion",
        .searchPlaceholder: "Rechercher par titre ou date",
        .scanMedicalReport: "Scanner un rapport ou une image médicale",
        .askQuestion: "Posez une question…",
        .processing: "Traitement…",
        .importReport: "Importer un rapport",
        .takePicture: "Prendre une photo",
        .uploadPhotos: "Importer depuis Photos",
        .uploadFiles: "Importer depuis Fichiers",
        .noReportsFound: "Aucun rapport trouvé",
        .emptyScanPrompt: "Scannez un rapport médical pour commencer.",
        .emptySearchPrompt: "Essayez une autre recherche ou scannez un nouveau rapport.",
        .delete: "Supprimer",
        .openMedicalSummary: "Ouvrir le résumé médical",
        .pageSingular: "%d page",
        .pagePlural: "%d pages",
        .error: "Erreur",
        .ok: "OK",
        .chatErrorFormat: "Désolé, une erreur s'est produite : %@",
        .failedLoadImages: "Impossible de charger les images sélectionnées.",
        .noSupportedFiles: "Aucune image ni PDF pris en charge dans les fichiers sélectionnés.",
        .reportDetails: "Détails du rapport",
        .reportTitlePlaceholder: "Titre du rapport",
        .briefSummary: "Résumé bref :",
        .scannedDocument: "Document numérisé",
        .stopReadingSummary: "Arrêter la lecture du résumé",
        .readSummary: "Lire le résumé",
        .reportNotFound: "Rapport introuvable",
        .reportMayBeDeleted: "Le rapport a peut-être été supprimé.",
        .failedLoadReport: "Échec du chargement du rapport.",
        .loading: "Chargement…",
        .locked: "Verrouillé",
        .useFaceIDToUnlock: "Utilisez Face ID pour déverrouiller vos rapports.",
        .unlockWithFaceID: "Déverrouiller avec Face ID",
        .medicalReportFallback: "Rapport médical",
        .changeLanguage: "Langue",
        .deleteReportTitle: "Supprimer le rapport ?",
        .deleteReportMessage: "Voulez-vous vraiment supprimer ce rapport ? Cette action est irréversible.",
        .shareDialogTitle: "Partager",
        .shareSummary: "Partager le résumé",
        .shareScannedPDF: "Partager le document numérisé (PDF)",
        .shareBoth: "Partager les deux",
        .unablePreparePDFShare: "Impossible de préparer le PDF pour le partage.",
        .unablePrepareDocumentShare: "Impossible de préparer le document pour le partage.",
        .aiDisclaimer: "L'IA peut se tromper et être incorrecte.",
        .consentPolicyTitle: "Consentement et confidentialité",
        .consentPolicyBody: """
DocuCare utilise l'intelligence artificielle (IA) pour résumer et traiter vos documents médicaux. Nous protégeons raisonnablement votre vie privée et vos informations de santé protégées (ISP), mais aucun système ne garantit une sécurité absolue.

Points clés :

• L'IA peut se tromper ou mal interpréter des documents.
• Les données sensibles sont traitées avec les fonctions de sécurité d'Apple et, si possible, masquées avant analyse par l'IA.
• Vos ISP sont stockées localement sur votre appareil et accessibles uniquement par vous lorsque vous êtes connecté.
• Partager des résumés ou documents est à votre discrétion et peut comporter des risques.
• Nous ne garantissons pas l'absence totale d'accès non autorisé, de perte ou d'usage abusif.
• L'utilisation de l'application est à vos risques ; vous restez responsable de vos données.

En continuant, vous confirmez avoir lu cette information, comprendre les risques et consentir au traitement par IA et au stockage local des ISP sur votre appareil.
""",
        .signUpErrorAlertTitle: "Erreur d'inscription",
        .consentRequiredNav: "Consentement requis",
        .consentToggleLabel: "Je reconnais avoir pris connaissance des informations ci-dessus.",
        .consentContinue: "Continuer",
        .accessibilityChecked: "Coché",
        .accessibilityUnchecked: "Non coché",
        .unlockToAccessReports: "Déverrouillez pour accéder à vos rapports médicaux.",
        .biometricUnlockDocuCare: "Déverrouiller DocuCare",
    ])

    private static let de: [String: String] = stringDict(from: [
        .welcomeTitle: "Willkommen bei DocuCare",
        .welcomeSubtitle: "KI-Zusammenfassungen für bessere Versorgung",
        .email: "E-Mail",
        .password: "Passwort",
        .language: "Sprache",
        .chooseLanguage: "Sprache wählen",
        .logIn: "Anmelden",
        .signUpPrompt: "Noch kein Konto? Registrieren",
        .createAccountTitle: "Neues Konto erstellen",
        .createAccount: "Konto erstellen",
        .cancel: "Abbrechen",
        .invalidCredentials: "Ungültige E-Mail oder Passwort.",
        .emailPasswordRequired: "E-Mail und Passwort erforderlich.",
        .invalidEmail: "Bitte geben Sie eine gültige E-Mail-Adresse ein.",
        .accountExists: "Ein Konto mit dieser E-Mail existiert bereits.",
        .authenticating: "Authentifizierung…",
        .reports: "Berichte",
        .logOut: "Abmelden",
        .searchPlaceholder: "Nach Titel oder Datum suchen",
        .scanMedicalReport: "Medizinischen Befund oder Bild scannen",
        .askQuestion: "Stellen Sie eine Frage…",
        .processing: "Verarbeitung…",
        .importReport: "Bericht importieren",
        .takePicture: "Foto aufnehmen",
        .uploadPhotos: "Aus Fotos hochladen",
        .uploadFiles: "Aus Dateien hochladen",
        .noReportsFound: "Keine Berichte gefunden",
        .emptyScanPrompt: "Scannen Sie einen medizinischen Bericht, um zu starten.",
        .emptySearchPrompt: "Andere Suche versuchen oder neuen Bericht scannen.",
        .delete: "Löschen",
        .openMedicalSummary: "Medizinische Zusammenfassung öffnen",
        .pageSingular: "%d Seite",
        .pagePlural: "%d Seiten",
        .error: "Fehler",
        .ok: "OK",
        .chatErrorFormat: "Entschuldigung, es ist ein Fehler aufgetreten: %@",
        .failedLoadImages: "Bilder aus der Auswahl konnten nicht geladen werden.",
        .noSupportedFiles: "Keine unterstützten Bilder oder PDFs in den ausgewählten Dateien.",
        .reportDetails: "Berichtsdetails",
        .reportTitlePlaceholder: "Berichtstitel",
        .briefSummary: "Kurzfassung:",
        .scannedDocument: "Gescanntes Dokument",
        .stopReadingSummary: "Vorlesen beenden",
        .readSummary: "Zusammenfassung vorlesen",
        .reportNotFound: "Bericht nicht gefunden",
        .reportMayBeDeleted: "Der Bericht wurde möglicherweise gelöscht.",
        .failedLoadReport: "Bericht konnte nicht geladen werden.",
        .loading: "Laden…",
        .locked: "Gesperrt",
        .useFaceIDToUnlock: "Face ID verwenden, um Ihre Berichte zu entsperren.",
        .unlockWithFaceID: "Mit Face ID entsperren",
        .medicalReportFallback: "Medizinischer Bericht",
        .changeLanguage: "Sprache",
        .deleteReportTitle: "Bericht löschen?",
        .deleteReportMessage: "Möchten Sie diesen Bericht wirklich löschen? Dies kann nicht rückgängig gemacht werden.",
        .shareDialogTitle: "Teilen",
        .shareSummary: "Zusammenfassung teilen",
        .shareScannedPDF: "Scan (PDF) teilen",
        .shareBoth: "Beides teilen",
        .unablePreparePDFShare: "PDF konnte nicht zum Teilen vorbereitet werden.",
        .unablePrepareDocumentShare: "Dokument konnte nicht zum Teilen vorbereitet werden.",
        .aiDisclaimer: "KI kann Fehler machen und Unrecht haben.",
        .consentPolicyTitle: "Einwilligung und Datenschutz",
        .consentPolicyBody: """
DocuCare nutzt künstliche Intelligenz (KI), um medizinische Dokumente zusammenzufassen und zu verarbeiten. Wir schützen Ihre Daten angemessen, doch kein System ist völlig sicher.

Wichtige Punkte:

• Die KI kann Fehler machen oder Dokumente missverstehen.
• Sensible Daten werden mit Apple-Sicherheitsfunktionen verarbeitet und wenn möglich vor der KI-Analyse geschwärzt.
• Ihre Gesundheitsdaten werden lokal auf dem Gerät gespeichert und sind nur für Sie zugänglich, wenn Sie angemeldet sind.
• Das Teilen von Inhalten liegt in Ihrer Verantwortung und kann Risiken bergen.
• Wir können nicht jede unbefugte Nutzung, jeden Verlust oder Missbrauch ausschließen.
• Die Nutzung erfolgt auf eigenes Risiko; Sie sind für den Umgang mit Ihren Daten verantwortlich.

Mit Fortfahren bestätigen Sie, dass Sie diese Hinweise gelesen haben, die Risiken verstehen und der KI-Verarbeitung sowie der lokalen Speicherung zustimmen.
""",
        .signUpErrorAlertTitle: "Registrierungsfehler",
        .consentRequiredNav: "Einwilligung erforderlich",
        .consentToggleLabel: "Ich bestätige, die obigen Informationen zur Kenntnis genommen zu haben.",
        .consentContinue: "Weiter",
        .accessibilityChecked: "Aktiviert",
        .accessibilityUnchecked: "Nicht aktiviert",
        .unlockToAccessReports: "Entsperren, um auf Ihre medizinischen Berichte zuzugreifen.",
        .biometricUnlockDocuCare: "DocuCare entsperren",
    ])

    private static let hi: [String: String] = stringDict(from: [
        .welcomeTitle: "DocuCare में आपका स्वागत है",
        .welcomeSubtitle: "स्मार्ट देखभाल के लिए AI-संचालित सारांश",
        .email: "ईमेल",
        .password: "पासवर्ड",
        .language: "भाषा",
        .chooseLanguage: "अपनी भाषा चुनें",
        .logIn: "लॉग इन",
        .signUpPrompt: "खाता नहीं है? साइन अप करें",
        .createAccountTitle: "नया खाता बनाएँ",
        .createAccount: "खाता बनाएँ",
        .cancel: "रद्द करें",
        .invalidCredentials: "अमान्य ईमेल या पासवर्ड।",
        .emailPasswordRequired: "ईमेल और पासवर्ड आवश्यक हैं।",
        .invalidEmail: "कृपया मान्य ईमेल पता दर्ज करें।",
        .accountExists: "इस ईमेल से पहले से एक खाता मौजूद है।",
        .authenticating: "प्रमाणीकरण…",
        .reports: "रिपोर्ट",
        .logOut: "लॉग आउट",
        .searchPlaceholder: "शीर्षक या तारीख से खोजें",
        .scanMedicalReport: "चिकित्सा रिपोर्ट या छवि स्कैन करें",
        .askQuestion: "एक प्रश्न पूछें…",
        .processing: "प्रसंस्करण…",
        .importReport: "रिपोर्ट आयात करें",
        .takePicture: "फ़ोटो लें",
        .uploadPhotos: "फ़ोटो से अपलोड करें",
        .uploadFiles: "फ़ाइलों से अपलोड करें",
        .noReportsFound: "कोई रिपोर्ट नहीं मिली",
        .emptyScanPrompt: "शुरू करने के लिए एक चिकित्सा रिपोर्ट स्कैन करें।",
        .emptySearchPrompt: "दूसरी खोज आज़माएँ या नई रिपोर्ट स्कैन करें।",
        .delete: "हटाएँ",
        .openMedicalSummary: "चिकित्सा सारांश खोलें",
        .pageSingular: "%d पृष्ठ",
        .pagePlural: "%d पृष्ठ",
        .error: "त्रुटि",
        .ok: "ठीक",
        .chatErrorFormat: "क्षमा करें, एक त्रुटि हुई: %@",
        .failedLoadImages: "चयन से छवियाँ लोड नहीं हो सकीं।",
        .noSupportedFiles: "चयनित फ़ाइलों में कोई समर्थित छवि या PDF नहीं मिला।",
        .reportDetails: "रिपोर्ट विवरण",
        .reportTitlePlaceholder: "रिपोर्ट शीर्षक",
        .briefSummary: "संक्षिप्त सारांश:",
        .scannedDocument: "स्कैन किया गया दस्तावेज़",
        .stopReadingSummary: "सारांश पढ़ना बंद करें",
        .readSummary: "सारांश पढ़ें",
        .reportNotFound: "रिपोर्ट नहीं मिली",
        .reportMayBeDeleted: "रिपोर्ट हटा दी गई हो सकती है।",
        .failedLoadReport: "रिपोर्ट लोड नहीं हो सकी।",
        .loading: "लोड हो रहा है…",
        .locked: "लॉक है",
        .useFaceIDToUnlock: "अपनी रिपोर्ट अनलॉक करने के लिए Face ID का उपयोग करें।",
        .unlockWithFaceID: "Face ID से अनलॉक करें",
        .medicalReportFallback: "चिकित्सा रिपोर्ट",
        .changeLanguage: "भाषा",
        .deleteReportTitle: "रिपोर्ट हटाएँ?",
        .deleteReportMessage: "क्या आप वाकई इस रिपोर्ट को हटाना चाहते हैं? यह पूर्ववत नहीं हो सकता।",
        .shareDialogTitle: "साझा करें",
        .shareSummary: "सारांश साझा करें",
        .shareScannedPDF: "स्कैन किया दस्तावेज़ (PDF) साझा करें",
        .shareBoth: "दोनों साझा करें",
        .unablePreparePDFShare: "PDF साझा करने के लिए तैयार नहीं हो सका।",
        .unablePrepareDocumentShare: "दस्तावेज़ साझा करने के लिए तैयार नहीं हो सका।",
        .aiDisclaimer: "AI गलतियाँ कर सकती है और गलत हो सकती है।",
        .consentPolicyTitle: "सहमति और गोपनीयता",
        .consentPolicyBody: """
DocuCare आपके चिकित्सा दस्तावेज़ों को संक्षेपित और संसाधित करने के लिए कृत्रिम बुद्धिमत्ता (AI) का उपयोग करता है। हम आपकी गोपनीयता और संरक्षित स्वास्थ्य जानकारी (PHI) की सुरक्षा के लिए उचित कदम उठाते हैं, फिर भी कोई भी प्रणाली 100% सुरक्षा की गारंटी नहीं दे सकती।

मुख्य बिंदु:

• AI गलतियाँ कर सकती है या दस्तावेज़ों को गलत समझ सकती है।
• संवेदनशील जानकारी Apple सुरक्षा सुविधाओं के साथ संसाधित होती है और जहाँ संभव हो AI विश्लेषण से पहले रिडैक्ट की जाती है।
• आपकी PHI आपके डिवाइस पर स्थानीय रूप से संग्रहीत है और लॉग इन होने पर केवल आपके लिए सुलभ है।
• सारांश या दस्तावेज़ साझा करना आपकी इच्छा पर निर्भर है और गोपनीयता जोखिम ला सकता है।
• हम सभी अनधिकृत पहुँच, हानि या दुरुपयोग को रोकने की गारंटी नहीं देते।
• ऐप का उपयोग आपके अपने जोखिम पर है; आप अपने डेटा के लिए जिम्मेदार हैं।

आगे बढ़कर आप स्वीकार करते हैं कि आपने यह जानकारी पढ़ ली है, जोखिम समझते हैं, और AI प्रसंस्करण तथा अपने डिवाइस पर PHI संग्रहण के लिए सहमति देते हैं।
""",
        .signUpErrorAlertTitle: "साइन अप त्रुटि",
        .consentRequiredNav: "सहमति आवश्यक",
        .consentToggleLabel: "मैं उपरोक्त प्रकटीकरण की जानकारी स्वीकार करता/करती हूँ।",
        .consentContinue: "जारी रखें",
        .accessibilityChecked: "चयनित",
        .accessibilityUnchecked: "अचयनित",
        .unlockToAccessReports: "अपनी चिकित्सा रिपोर्ट तक पहुँचने के लिए अनलॉक करें।",
        .biometricUnlockDocuCare: "DocuCare अनलॉक करें",
    ])

    private static let ja: [String: String] = stringDict(from: [
        .welcomeTitle: "DocuCareへようこそ",
        .welcomeSubtitle: "AIによる要約で、より賢いケアを",
        .email: "メール",
        .password: "パスワード",
        .language: "言語",
        .chooseLanguage: "言語を選択",
        .logIn: "ログイン",
        .signUpPrompt: "アカウントをお持ちでない方は登録",
        .createAccountTitle: "新しいアカウントを作成",
        .createAccount: "アカウントを作成",
        .cancel: "キャンセル",
        .invalidCredentials: "メールまたはパスワードが正しくありません。",
        .emailPasswordRequired: "メールとパスワードが必要です。",
        .invalidEmail: "有効なメールアドレスを入力してください。",
        .accountExists: "このメールのアカウントは既に存在します。",
        .authenticating: "認証中…",
        .reports: "レポート",
        .logOut: "ログアウト",
        .searchPlaceholder: "タイトルまたは日付で検索",
        .scanMedicalReport: "診療レポートまたは画像をスキャン",
        .askQuestion: "質問を入力…",
        .processing: "処理中…",
        .importReport: "レポートを読み込む",
        .takePicture: "写真を撮る",
        .uploadPhotos: "写真からアップロード",
        .uploadFiles: "ファイルからアップロード",
        .noReportsFound: "レポートが見つかりません",
        .emptyScanPrompt: "診療レポートをスキャンして始めましょう。",
        .emptySearchPrompt: "別のキーワードで探すか、新しいレポートをスキャンしてください。",
        .delete: "削除",
        .openMedicalSummary: "要約を開く",
        .pageSingular: "%d ページ",
        .pagePlural: "%d ページ",
        .error: "エラー",
        .ok: "OK",
        .chatErrorFormat: "エラーが発生しました: %@",
        .failedLoadImages: "選択した画像を読み込めませんでした。",
        .noSupportedFiles: "選択したファイルに対応する画像またはPDFがありません。",
        .reportDetails: "レポートの詳細",
        .reportTitlePlaceholder: "レポートのタイトル",
        .briefSummary: "簡潔な要約:",
        .scannedDocument: "スキャンした文書",
        .stopReadingSummary: "読み上げを停止",
        .readSummary: "要約を読み上げ",
        .reportNotFound: "レポートが見つかりません",
        .reportMayBeDeleted: "レポートは削除された可能性があります。",
        .failedLoadReport: "レポートを読み込めませんでした。",
        .loading: "読み込み中…",
        .locked: "ロック中",
        .useFaceIDToUnlock: "Face IDでレポートのロックを解除します。",
        .unlockWithFaceID: "Face IDでロック解除",
        .medicalReportFallback: "診療レポート",
        .changeLanguage: "言語",
        .deleteReportTitle: "レポートを削除しますか？",
        .deleteReportMessage: "このレポートを削除してもよろしいですか？この操作は取り消せません。",
        .shareDialogTitle: "共有",
        .shareSummary: "要約を共有",
        .shareScannedPDF: "スキャン文書（PDF）を共有",
        .shareBoth: "両方を共有",
        .unablePreparePDFShare: "共有用にPDFを準備できませんでした。",
        .unablePrepareDocumentShare: "共有用に文書を準備できませんでした。",
        .aiDisclaimer: "AIは誤ることがあります。",
        .consentPolicyTitle: "同意とプライバシー",
        .consentPolicyBody: """
DocuCareは人工知能（AI）を使用して医療文書の要約と処理を支援します。プライバシーと保護健康情報（PHI）の安全のために合理的な措置を講じますが、どのシステムも100%の安全を保証できません。

主なポイント：

• AIは誤りを起こしたり文書を誤解したりする場合があります。
• 機微な情報はAppleのセキュリティ機能で処理され、可能な場合はAI分析前にマスキングされます。
• PHIはデバイスにローカル保存され、ログイン中はあなただけがアクセスできます。
• 要約や文書の共有は自己責任で、プライバシーリスクが生じる場合があります。
• すべての不正アクセス・紛失・悪用を防ぐことは保証しません。
• アプリの利用は自己責任であり、データの取り扱いはあなたの責任です。

続行すると、本開示を読み理解し、リスクを認識し、AI処理とデバイス上のPHI保存に同意したことになります。
""",
        .signUpErrorAlertTitle: "登録エラー",
        .consentRequiredNav: "同意が必要です",
        .consentToggleLabel: "上記の開示内容を確認し、これに同意します。",
        .consentContinue: "続ける",
        .accessibilityChecked: "選択済み",
        .accessibilityUnchecked: "未選択",
        .unlockToAccessReports: "診療レポートにアクセスするにはロックを解除してください。",
        .biometricUnlockDocuCare: "DocuCareのロックを解除",
    ])

    private static let zhHans: [String: String] = stringDict(from: [
        .welcomeTitle: "欢迎使用 DocuCare",
        .welcomeSubtitle: "AI 摘要，让照护更智能",
        .email: "电子邮件",
        .password: "密码",
        .language: "语言",
        .chooseLanguage: "选择语言",
        .logIn: "登录",
        .signUpPrompt: "没有账户？注册",
        .createAccountTitle: "创建新账户",
        .createAccount: "创建账户",
        .cancel: "取消",
        .invalidCredentials: "电子邮件或密码无效。",
        .emailPasswordRequired: "需要填写电子邮件和密码。",
        .invalidEmail: "请输入有效的电子邮件地址。",
        .accountExists: "该电子邮件已注册账户。",
        .authenticating: "正在验证…",
        .reports: "报告",
        .logOut: "退出登录",
        .searchPlaceholder: "按标题或日期搜索",
        .scanMedicalReport: "扫描医疗报告或图像",
        .askQuestion: "提问…",
        .processing: "处理中…",
        .importReport: "导入报告",
        .takePicture: "拍照",
        .uploadPhotos: "从照片上传",
        .uploadFiles: "从文件上传",
        .noReportsFound: "未找到报告",
        .emptyScanPrompt: "扫描一份医疗报告以开始。",
        .emptySearchPrompt: "尝试其他搜索或扫描新报告。",
        .delete: "删除",
        .openMedicalSummary: "打开医疗摘要",
        .pageSingular: "%d 页",
        .pagePlural: "%d 页",
        .error: "错误",
        .ok: "好",
        .chatErrorFormat: "抱歉，出现错误：%@",
        .failedLoadImages: "无法加载所选图片。",
        .noSupportedFiles: "所选文件中没有支持的图片或 PDF。",
        .reportDetails: "报告详情",
        .reportTitlePlaceholder: "报告标题",
        .briefSummary: "简要摘要：",
        .scannedDocument: "扫描文档",
        .stopReadingSummary: "停止朗读摘要",
        .readSummary: "朗读摘要",
        .reportNotFound: "未找到报告",
        .reportMayBeDeleted: "报告可能已被删除。",
        .failedLoadReport: "无法加载报告。",
        .loading: "加载中…",
        .locked: "已锁定",
        .useFaceIDToUnlock: "使用面容 ID 解锁您的报告。",
        .unlockWithFaceID: "使用面容 ID 解锁",
        .medicalReportFallback: "医疗报告",
        .changeLanguage: "语言",
        .deleteReportTitle: "删除报告？",
        .deleteReportMessage: "确定要删除此报告吗？此操作无法撤销。",
        .shareDialogTitle: "共享",
        .shareSummary: "共享摘要",
        .shareScannedPDF: "共享扫描文档（PDF）",
        .shareBoth: "共享两者",
        .unablePreparePDFShare: "无法准备要共享的 PDF。",
        .unablePrepareDocumentShare: "无法准备要共享的文档。",
        .aiDisclaimer: "人工智能可能出错。",
        .consentPolicyTitle: "同意与隐私",
        .consentPolicyBody: """
DocuCare 使用人工智能（AI）帮助摘要和处理您的医疗文件。我们会采取合理措施保护您的隐私和受保护健康信息（PHI）的安全，但任何系统都无法保证绝对安全。

要点：

• AI 可能出错或误解文件。
• 敏感信息使用 Apple 平台安全功能处理，并在可能时在 AI 分析前进行脱敏。
• 您的 PHI 存储在设备本地，仅在您登录时由您本人访问。
• 共享摘要或文件由您自行决定，并可能带来隐私风险。
• 我们不保证防止所有未经授权的访问、丢失或滥用。
• 使用本应用的风险由您自行承担，您需对数据的处理与保护负责。

继续即表示您已阅读并理解本披露，了解相关风险，并同意在设备上使用 AI 处理并存储 PHI。
""",
        .signUpErrorAlertTitle: "注册错误",
        .consentRequiredNav: "需要同意",
        .consentToggleLabel: "我确认已阅读并理解上述披露信息。",
        .consentContinue: "继续",
        .accessibilityChecked: "已选中",
        .accessibilityUnchecked: "未选中",
        .unlockToAccessReports: "解锁以访问您的医疗报告。",
        .biometricUnlockDocuCare: "解锁 DocuCare",
    ])

    private static let ptBR: [String: String] = stringDict(from: [
        .welcomeTitle: "Bem-vindo ao DocuCare",
        .welcomeSubtitle: "Resumos com IA para cuidados mais inteligentes",
        .email: "E-mail",
        .password: "Senha",
        .language: "Idioma",
        .chooseLanguage: "Escolha seu idioma",
        .logIn: "Entrar",
        .signUpPrompt: "Não tem uma conta? Cadastre-se",
        .createAccountTitle: "Criar uma nova conta",
        .createAccount: "Criar conta",
        .cancel: "Cancelar",
        .invalidCredentials: "E-mail ou senha inválidos.",
        .emailPasswordRequired: "E-mail e senha são obrigatórios.",
        .invalidEmail: "Digite um endereço de e-mail válido.",
        .accountExists: "Já existe uma conta com este e-mail.",
        .authenticating: "Autenticando…",
        .reports: "Relatórios",
        .logOut: "Sair",
        .searchPlaceholder: "Pesquisar por título ou data",
        .scanMedicalReport: "Digitalizar um relatório ou imagem médica",
        .askQuestion: "Faça uma pergunta…",
        .processing: "Processando…",
        .importReport: "Importar relatório",
        .takePicture: "Tirar uma foto",
        .uploadPhotos: "Enviar das Fotos",
        .uploadFiles: "Enviar dos Arquivos",
        .noReportsFound: "Nenhum relatório encontrado",
        .emptyScanPrompt: "Digitalize um relatório médico para começar.",
        .emptySearchPrompt: "Tente outra pesquisa ou digitalize um novo relatório.",
        .delete: "Excluir",
        .openMedicalSummary: "Abrir resumo médico",
        .pageSingular: "%d página",
        .pagePlural: "%d páginas",
        .error: "Erro",
        .ok: "OK",
        .chatErrorFormat: "Desculpe, ocorreu um erro: %@",
        .failedLoadImages: "Falha ao carregar imagens da seleção.",
        .noSupportedFiles: "Nenhuma imagem ou PDF compatível nos arquivos selecionados.",
        .reportDetails: "Detalhes do relatório",
        .reportTitlePlaceholder: "Título do relatório",
        .briefSummary: "Resumo breve:",
        .scannedDocument: "Documento digitalizado",
        .stopReadingSummary: "Parar leitura do resumo",
        .readSummary: "Ler resumo",
        .reportNotFound: "Relatório não encontrado",
        .reportMayBeDeleted: "O relatório pode ter sido excluído.",
        .failedLoadReport: "Falha ao carregar o relatório.",
        .loading: "Carregando…",
        .locked: "Bloqueado",
        .useFaceIDToUnlock: "Use o Face ID para desbloquear seus relatórios.",
        .unlockWithFaceID: "Desbloquear com Face ID",
        .medicalReportFallback: "Relatório médico",
        .changeLanguage: "Idioma",
        .deleteReportTitle: "Excluir relatório?",
        .deleteReportMessage: "Tem certeza de que deseja excluir este relatório? Esta ação não pode ser desfeita.",
        .shareDialogTitle: "Compartilhar",
        .shareSummary: "Compartilhar resumo",
        .shareScannedPDF: "Compartilhar documento digitalizado (PDF)",
        .shareBoth: "Compartilhar ambos",
        .unablePreparePDFShare: "Não foi possível preparar o PDF para compartilhamento.",
        .unablePrepareDocumentShare: "Não foi possível preparar o documento para compartilhamento.",
        .aiDisclaimer: "A IA pode errar.",
        .consentPolicyTitle: "Consentimento e privacidade",
        .consentPolicyBody: """
O DocuCare usa inteligência artificial (IA) para ajudar a resumir e processar seus documentos médicos. Tomamos medidas razoáveis para proteger sua privacidade e a segurança das suas Informações de Saúde Protegidas (PHI), mas nenhum sistema garante 100% de segurança.

Pontos principais:

• A IA pode cometer erros ou interpretar mal documentos.
• Informações sensíveis são processadas com recursos de segurança da Apple e, quando possível, redigidas antes da análise por IA.
• Suas PHI ficam armazenadas localmente no dispositivo e acessíveis apenas a você quando estiver conectado.
• Compartilhar resumos ou documentos é por sua conta e risco e pode envolver riscos de privacidade.
• Não garantimos a prevenção de todo acesso não autorizado, perda ou uso indevido.
• O uso do app é por sua conta e risco; você é responsável pelo manuseio dos dados.

Ao continuar, você confirma que leu e entendeu esta divulgação, compreende os riscos e consente no uso de IA e no armazenamento local de PHI no seu dispositivo.
""",
        .signUpErrorAlertTitle: "Erro de cadastro",
        .consentRequiredNav: "Consentimento necessário",
        .consentToggleLabel: "Reconheço as informações da divulgação acima.",
        .consentContinue: "Continuar",
        .accessibilityChecked: "Marcado",
        .accessibilityUnchecked: "Desmarcado",
        .unlockToAccessReports: "Desbloqueie para acessar seus relatórios médicos.",
        .biometricUnlockDocuCare: "Desbloquear DocuCare",
    ])

    private static func table(for languageCode: String) -> [String: String] {
        switch languageCode {
        case AppLanguage.spanish.rawValue: return es
        case AppLanguage.french.rawValue: return fr
        case AppLanguage.german.rawValue: return de
        case AppLanguage.hindi.rawValue: return hi
        case AppLanguage.japanese.rawValue: return ja
        case AppLanguage.chineseSimplified.rawValue: return zhHans
        case AppLanguage.portugueseBrazil.rawValue: return ptBR
        default: return [:]
        }
    }

    static func string(_ key: Key, languageCode: String) -> String {
        let t = table(for: languageCode)
        if let s = t[key.rawValue] { return s }
        return en[key] ?? key.rawValue
    }

    static func pageLabel(count: Int, languageCode: String) -> String {
        let fmt = string(count == 1 ? .pageSingular : .pagePlural, languageCode: languageCode)
        let loc = Locale(identifier: AppLanguage.localeIdentifier(from: languageCode))
        return String(format: fmt, locale: loc, arguments: [count] as [CVarArg])
    }

    static func chatError(_ error: Error, languageCode: String) -> String {
        let fmt = string(.chatErrorFormat, languageCode: languageCode)
        let loc = Locale(identifier: AppLanguage.localeIdentifier(from: languageCode))
        return String(format: fmt, locale: loc, arguments: [error.localizedDescription] as [CVarArg])
    }
}
