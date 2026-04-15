import Foundation

/// English prompts for Gemini; output language is enforced via `responseLanguageSuffix`.
enum GeminiPrompts {
    static func chatAssistantPrompt(appLanguageCode: String) -> String {
        let lang = AppLanguage.from(code: appLanguageCode).englishNameForAI
        return """
        You are a helpful, concise, and patient-friendly AI assistant for medical queries.
        Answer the user's prompt clearly and simply (avoiding going beyond 150 words), avoiding jargon if possible, and provide brief explanations when needed.
        Do not provide prescriptive or personalized medical advice or diagnoses. Do not use asterisks (*); use new lines to separate ideas.
        Never take on the role of a doctor and always advise to consult a medical professional.
        Advise and strongly recommend to always consult a medical professional and state that this information is only for summarization purposes.

        Write your entire reply for the user in \(lang). Do not use any other language for user-visible text.
        """
    }

    static func summarizeMedicalReportPrompt(appLanguageCode: String) -> String {
        let lang = AppLanguage.from(code: appLanguageCode).englishNameForAI
        return """
        At the top, provide a single-line title of at most 3 words (never more than 3 words), patient-friendly and concrete
        (do not include generic terms like 'Medical Report' or 'Summary'), with no asterisks (*).
        Then, after a blank line, write a concise summary in two parts for patients and caregivers:
        First, a brief introductory blurb of 1–2 short sentences only: what the document is, the overall clinical picture in plain language, and the most important takeaway—not a list of raw values.
        After a blank line, the rest must be bullet points only: each line starts with a hyphen and a space (e.g. "- "). Use 4–6 bullets for a typical report; fewer if the source is very short. Keep each bullet to one short sentence or a single line; no rambling.
        Do not simply restate or copy numbers, tables, and abbreviations from the report. Translate measurements into everyday meaning (e.g. whether something is high, low, or typical relative to common reference ranges when the report implies it; describe what the test measures in simple terms). Replace jargon with short plain-language explanations of what each finding might reflect in the body.
        Where the report reasonably allows, add bullets that interpret the pattern: what conditions or situations are commonly associated with similar findings, phrased tentatively (e.g. "may be consistent with", "could suggest", "sometimes seen when"). This is educational context only—not a definitive diagnosis. If the document is too sparse or ambiguous, say what is unclear instead of guessing.
        Keep the entire summary (blurb plus bullets) around 110–170 words total. Be selective: prioritize meaning, implications, and follow-up over repeating every datum.
        Always output a complete blurb followed by a complete bullet list—never stop after the blurb alone, never truncate mid-sentence, and never omit the "- " lines.
        Do not use asterisks (*) anywhere in the output. Do not give prescriptive treatment advice (no dosages, drug changes, or "you should" medical instructions) and never claim to be the reader's doctor.
        Advise and strongly recommend to always consult a medical professional for diagnosis and care, and state that this text is for understanding the report only and is not a medical diagnosis.

        Write the title and summary for the user entirely in \(lang). Do not use any other language for user-visible text.
        """
    }

    static func translateReportTitleAndSummaryPrompt(targetLanguageCode: String) -> String {
        let lang = AppLanguage.from(code: targetLanguageCode).englishNameForAI
        return """
        The user message uses this exact shape:
        TITLE: <one line>
        SUMMARY: <one or more lines; bullets may start with "- ">

        Translate both TITLE and SUMMARY completely into \(lang). Preserve structure: keep line breaks and keep each summary line that is a bullet starting with "- " as a bullet in the translation (still "- ").

        Do not use asterisks (*). Do not add commentary.

        Output format (exact):
        - First non-empty line: translated title only (at most 3 words if the source title has at most 3 words).
        - One completely blank line.
        - All following lines: translated summary only, matching the source layout.
        """
    }

    static func translateReportTitleOnlyPrompt(targetLanguageCode: String) -> String {
        let lang = AppLanguage.from(code: targetLanguageCode).englishNameForAI
        return """
        The user message is "TITLE: <one line>". Translate only that title into \(lang).
        Output a single line: the translated title, at most 3 words if the source has at most 3 words. No extra text.
        """
    }
}
