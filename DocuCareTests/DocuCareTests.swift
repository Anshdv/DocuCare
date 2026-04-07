//
//  DocuCareTests.swift
//  DocuCareTests
//
//  Created by Ansh D on 8/14/25.
//

import Testing
@testable import DocuCare

struct DocuCareTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    // MARK: - PII redaction heuristics

    @Test func redaction_skipsClinicalDurations() {
        #expect(!PIIRedactor.containsPII(text: "Symptoms present for 2 years"))
        #expect(!PIIRedactor.containsPII(text: "follow-up for 10 yrs"))
    }

    @Test func redaction_catchesLabeledDemographicsAndIds() {
        #expect(PIIRedactor.containsPII(text: "Age: 67"))
        #expect(PIIRedactor.containsPII(text: "Pt age 34"))
        #expect(PIIRedactor.containsPII(text: "DOB: 03/14/1972"))
        #expect(PIIRedactor.containsPII(text: "MRN: 001234567"))
        #expect(PIIRedactor.containsPII(text: "Sex: Female"))
    }

    @Test func redaction_catchesNamesAndTitles() {
        #expect(PIIRedactor.containsPII(text: "Patient: Jane Doe"))
        #expect(PIIRedactor.containsPII(text: "Dr. Helen Park"))
        #expect(PIIRedactor.containsPII(text: "SMITH, JOHN MICHAEL"))
    }
}

