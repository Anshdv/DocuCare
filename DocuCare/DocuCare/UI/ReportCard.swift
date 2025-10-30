import SwiftUI

struct ReportCard: View {
    let report: MedicalReport

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(report.title)
                .font(.title2)
                .bold()
                .foregroundColor(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            HStack(spacing: 8) {
                Text(report.createdAt, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if report.pageCount > 0 {
                    Text("• \(report.pageCount) page\(report.pageCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            if let summary = report.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .lineLimit(3)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.systemBackground))
                .shadow(color: Color(.black).opacity(0.07), radius: 7, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }
}
