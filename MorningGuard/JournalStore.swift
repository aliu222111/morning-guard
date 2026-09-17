import Foundation
import Combine

struct JournalEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let text: String
}

class JournalStore: ObservableObject {

    @Published var entries: [JournalEntry] = []

    private let entriesKey = "journalEntries"

    var todayEntry: JournalEntry? {
        entries.first { Calendar.current.isDateInToday($0.date) }
    }

    init() {
        loadEntries()
    }

    private func loadEntries() {
        guard let data = UserDefaults.standard.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([JournalEntry].self, from: data) else { return }
        entries = decoded
    }

    private func persistEntries() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: entriesKey)
    }

    func save(text: String) {
        entries.append(JournalEntry(id: UUID(), date: Date(), text: text))
        persistEntries()
    }

    func delete(id: UUID) {
        entries.removeAll { $0.id == id }
        persistEntries()
    }
}
