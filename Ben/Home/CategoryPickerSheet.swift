import SwiftData
import SwiftUI

/// Pick or create a category for a bill. Customs are name-only —
/// Ben assigns the styling so everything stays in the palette.
struct CategoryPickerSheet: View {
    let bill: Bill
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var customName = ""
    @State private var refresh = false

    private var categories: [String] {
        _ = refresh  // re-read after adding a custom
        return BillCategory.all()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Category")
                    .font(.benTitle)
                    .foregroundStyle(Color.forestInk)
                    .padding(.top, 28)

                VStack(spacing: 10) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            select(category)
                        } label: {
                            HStack(spacing: 12) {
                                BenIconCircle(
                                    systemName: BillCategory.symbol(for: category),
                                    fill: BillCategory.wash(for: category).bg,
                                    iconColor: BillCategory.wash(for: category).fg,
                                    size: 38
                                )
                                Text(BillCategory.label(for: category))
                                    .font(.benLabel)
                                    .foregroundStyle(Color.onCream)
                                Spacer()
                                if bill.resolvedCategory == category {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Color.onCreamStrong)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(BenPressable())
                        .benShadow(.floating)
                    }
                }

                Text("Or make your own")
                    .font(.benCardTitle)
                    .foregroundStyle(Color.forestInk)
                    .padding(.top, 10)

                HStack(spacing: 10) {
                    BenField("New category") {
                        TextField("Body corporate, school fees…", text: $customName)
                            .submitLabel(.done)
                            .onSubmit(addCustom)
                    }
                    BenCircleButton(systemName: "checkmark", accessibilityLabel: "Add category") {
                        addCustom()
                    }
                    .opacity(customName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func select(_ category: String) {
        bill.category = category
        try? modelContext.save()
        dismiss()
    }

    private func addCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let canonical = BillCategory.addCustom(trimmed)
        customName = ""
        refresh.toggle()
        select(canonical)
    }
}
