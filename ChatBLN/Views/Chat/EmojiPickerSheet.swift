import SwiftUI

struct EmojiCategory: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let systemImage: String
    let items: [EmojiEntry]
}

struct EmojiEntry: Identifiable, Hashable, Sendable {
    var id: String { symbol }
    let symbol: String
    let keywords: String
}

struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onSelectEmoji: (String) -> Void

    @State private var searchText: String = ""
    @State private var selectedCategoryId: String = "popular"

    private static let categories: [EmojiCategory] = [
        EmojiCategory(
            id: "popular",
            title: "Phổ biến",
            systemImage: "sparkles",
            items: [
                EmojiEntry(symbol: "😀", keywords: "cuoi vui happy"),
                EmojiEntry(symbol: "😂", keywords: "haha lol cuoi ra nuoc mat"),
                EmojiEntry(symbol: "🥰", keywords: "yeu thuong tim love"),
                EmojiEntry(symbol: "😍", keywords: "me ly tim mat"),
                EmojiEntry(symbol: "🤩", keywords: "ngoi sao tuyet voi"),
                EmojiEntry(symbol: "😎", keywords: "ngau kinh ram cool"),
                EmojiEntry(symbol: "🥳", keywords: "chuc mung sinh nhat party"),
                EmojiEntry(symbol: "😭", keywords: "khoc buon cry"),
                EmojiEntry(symbol: "😡", keywords: "gian du tuc"),
                EmojiEntry(symbol: "👍", keywords: "like tot ok"),
                EmojiEntry(symbol: "❤️", keywords: "tim do yeu heart"),
                EmojiEntry(symbol: "🔥", keywords: "lua chay hot fire"),
                EmojiEntry(symbol: "🎉", keywords: "phao giay chuc mung"),
                EmojiEntry(symbol: "🙏", keywords: "cam on xin loi"),
                EmojiEntry(symbol: "✅", keywords: "xong dung check"),
                EmojiEntry(symbol: "💯", keywords: "100 tuyet doi")
            ]
        ),
        EmojiCategory(
            id: "smileys",
            title: "Cảm xúc",
            systemImage: "face.smiling",
            items: [
                EmojiEntry(symbol: "😃", keywords: "cuoi"),
                EmojiEntry(symbol: "😄", keywords: "vui"),
                EmojiEntry(symbol: "😁", keywords: "rang"),
                EmojiEntry(symbol: "😆", keywords: "haha"),
                EmojiEntry(symbol: "😅", keywords: "ngai mo hoi"),
                EmojiEntry(symbol: "🤣", keywords: "cuoi lan"),
                EmojiEntry(symbol: "😊", keywords: "mim cuoi"),
                EmojiEntry(symbol: "😇", keywords: "thien than"),
                EmojiEntry(symbol: "🙂", keywords: "nhe nhang"),
                EmojiEntry(symbol: "😉", keywords: "nhay mat"),
                EmojiEntry(symbol: "😌", keywords: "thu gian"),
                EmojiEntry(symbol: "😋", keywords: "ngon"),
                EmojiEntry(symbol: "😜", keywords: "leu leu"),
                EmojiEntry(symbol: "🤔", keywords: "suy nghi"),
                EmojiEntry(symbol: "🤗", keywords: "om"),
                EmojiEntry(symbol: "😴", keywords: "ngu"),
                EmojiEntry(symbol: "😮", keywords: "ngac nhien"),
                EmojiEntry(symbol: "😢", keywords: "buon khoc")
            ]
        ),
        EmojiCategory(
            id: "gestures",
            title: "Cử chỉ",
            systemImage: "hand.thumbsup",
            items: [
                EmojiEntry(symbol: "👋", keywords: "vay tay chao hello"),
                EmojiEntry(symbol: "👌", keywords: "ok tot"),
                EmojiEntry(symbol: "✌️", keywords: "peace hai"),
                EmojiEntry(symbol: "🤞", keywords: "may man"),
                EmojiEntry(symbol: "🫶", keywords: "tha tim tay"),
                EmojiEntry(symbol: "👏", keywords: "vo tay khen"),
                EmojiEntry(symbol: "🙌", keywords: "hoan ho"),
                EmojiEntry(symbol: "🤝", keywords: "bat tay hop tac"),
                EmojiEntry(symbol: "💪", keywords: "manh me co len"),
                EmojiEntry(symbol: "👀", keywords: "mat nhin"),
                EmojiEntry(symbol: "🫡", keywords: "chao ro"),
                EmojiEntry(symbol: "👎", keywords: "khong thich")
            ]
        ),
        EmojiCategory(
            id: "hearts",
            title: "Trái tim",
            systemImage: "heart",
            items: [
                EmojiEntry(symbol: "❤️", keywords: "tim do"),
                EmojiEntry(symbol: "🧡", keywords: "tim cam"),
                EmojiEntry(symbol: "💛", keywords: "tim vang"),
                EmojiEntry(symbol: "💚", keywords: "tim xanh la"),
                EmojiEntry(symbol: "💙", keywords: "tim xanh duong"),
                EmojiEntry(symbol: "💜", keywords: "tim tim"),
                EmojiEntry(symbol: "💖", keywords: "tim lap lanh"),
                EmojiEntry(symbol: "💘", keywords: "mui ten tinh yeu"),
                EmojiEntry(symbol: "💝", keywords: "qua tim"),
                EmojiEntry(symbol: "✨", keywords: "lap lanh sao"),
                EmojiEntry(symbol: "🌟", keywords: "ngoi sao"),
                EmojiEntry(symbol: "💬", keywords: "tin nhan chat")
            ]
        ),
        EmojiCategory(
            id: "objects",
            title: "Đời sống",
            systemImage: "cup.and.saucer",
            items: [
                EmojiEntry(symbol: "☕️", keywords: "ca phe coffee"),
                EmojiEntry(symbol: "🧋", keywords: "tra sua"),
                EmojiEntry(symbol: "🍜", keywords: "pho mi"),
                EmojiEntry(symbol: "🍕", keywords: "pizza"),
                EmojiEntry(symbol: "🎂", keywords: "banh sinh nhat"),
                EmojiEntry(symbol: "🚀", keywords: "ten lua nhanh deploy"),
                EmojiEntry(symbol: "💻", keywords: "laptop code may tinh"),
                EmojiEntry(symbol: "📱", keywords: "iphone dien thoai"),
                EmojiEntry(symbol: "📚", keywords: "sach hoc tap"),
                EmojiEntry(symbol: "🏆", keywords: "cup chien thang"),
                EmojiEntry(symbol: "🎵", keywords: "am nhac"),
                EmojiEntry(symbol: "🌈", keywords: "cau vong")
            ]
        )
    ]

    private let gridColumns = Array(repeating: GridItem(.adaptive(minimum: 48), spacing: 10), count: 1)

    private var visibleEmojis: [EmojiEntry] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !keyword.isEmpty {
            var seen = Set<String>()
            return Self.categories
                .flatMap(\.items)
                .filter { entry in
                    guard !seen.contains(entry.symbol) else { return false }
                    let matches = entry.symbol.contains(keyword) || entry.keywords.contains(keyword)
                    if matches {
                        seen.insert(entry.symbol)
                    }
                    return matches
                }
        }
        return Self.categories.first(where: { $0.id == selectedCategoryId })?.items ?? []
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Self.categories) { category in
                                let isSelected = category.id == selectedCategoryId
                                Button {
                                    selectedCategoryId = category.id
                                } label: {
                                    Label(category.title, systemImage: category.systemImage)
                                        .font(.footnote.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: 36)
                                        .foregroundStyle(isSelected ? Color.white : Color(.label))
                                        .background(
                                            isSelected ? Color.chatBLNPrimary : Color(.tertiarySystemFill),
                                            in: Capsule()
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(isSelected ? .isSelected : [])
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    Divider()
                }

                if visibleEmojis.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(visibleEmojis) { entry in
                                Button {
                                    onSelectEmoji(entry.symbol)
                                } label: {
                                    Text(entry.symbol)
                                        .font(.title2)
                                        .frame(minWidth: 48, minHeight: 48)
                                        .background(
                                            Color(.secondarySystemGroupedBackground),
                                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Chèn biểu tượng \(entry.symbol)")
                            }
                        }
                        .padding(16)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .searchable(text: $searchText, prompt: "Tìm biểu tượng cảm xúc...")
            .navigationTitle("Biểu tượng cảm xúc")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
