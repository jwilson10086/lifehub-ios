import Foundation
import Combine

// MARK: - 数据模型

struct LedgerRecord: Codable, Identifiable, Hashable {
    var id: String
    var type: String          // expense | income
    var amount: Double
    var category: String
    var date: String          // yyyy-MM-dd
    var note: String
    var createdAt: Double

    init(id: String = UUID().uuidString,
         type: String = "expense",
         amount: Double = 0,
         category: String = "其他",
         date: String = dateString(),
         note: String = "",
         createdAt: Double = Date().timeIntervalSince1970) {
        self.id = id; self.type = type; self.amount = amount
        self.category = category; self.date = date; self.note = note
        self.createdAt = createdAt
    }
}

struct EventRecord: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var datetime: Date
    var place: String
    var person: String
    var note: String
    var createdAt: Double

    init(id: String = UUID().uuidString,
         title: String = "",
         datetime: Date = Date(),
         place: String = "",
         person: String = "",
         note: String = "",
         createdAt: Double = Date().timeIntervalSince1970) {
        self.id = id; self.title = title; self.datetime = datetime
        self.place = place; self.person = person; self.note = note
        self.createdAt = createdAt
    }
}

struct NoteRecord: Codable, Identifiable, Hashable {
    var id: String
    var text: String
    var tags: String
    var createdAt: Double

    init(id: String = UUID().uuidString,
         text: String = "",
         tags: String = "",
         createdAt: Double = Date().timeIntervalSince1970) {
        self.id = id; self.text = text; self.tags = tags; self.createdAt = createdAt
    }
}

struct AppData: Codable {
    var ledger: [LedgerRecord] = []
    var appointments: [EventRecord] = []
    var schedules: [EventRecord] = []
    var notes: [NoteRecord] = []
}

// MARK: - 本地存储（Documents/lifehub.json）

final class Store: ObservableObject {
    @Published var data: AppData

    init() { self.data = Store.load() }

    static func fileURL() -> URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("lifehub.json")
    }

    static func load() -> AppData {
        guard let d = try? Data(contentsOf: fileURL()),
              let decoded = try? JSONDecoder().decode(AppData.self, from: d) else {
            return AppData()
        }
        return decoded
    }

    func save() {
        guard let d = try? JSONEncoder().encode(data) else { return }
        try? d.write(to: Store.fileURL(), options: .atomic)
    }

    func addLedger(_ r: LedgerRecord) { data.ledger.insert(r, at: 0); save() }
    func addAppointment(_ r: EventRecord) { data.appointments.insert(r, at: 0); save() }
    func addSchedule(_ r: EventRecord) { data.schedules.insert(r, at: 0); save() }
    func addNote(_ r: NoteRecord) { data.notes.insert(r, at: 0); save() }

    func deleteLedger(_ id: String) { data.ledger.removeAll { $0.id == id }; save() }
    func deleteAppointment(_ id: String) { data.appointments.removeAll { $0.id == id }; save() }
    func deleteSchedule(_ id: String) { data.schedules.removeAll { $0.id == id }; save() }
    func deleteNote(_ id: String) { data.notes.removeAll { $0.id == id }; save() }

    func merge(_ other: AppData) {
        func mergeById<T: Identifiable>(_ incoming: [T], _ existing: inout [T]) {
            var seen = Set<String>()
            for item in existing { seen.insert(String(describing: item.id)) }
            for item in incoming where !seen.contains(String(describing: item.id)) {
                existing.append(item)
            }
        }
        mergeById(other.ledger, &data.ledger)
        mergeById(other.appointments, &data.appointments)
        mergeById(other.schedules, &data.schedules)
        mergeById(other.notes, &data.notes)
        save()
    }

    var exportData: Data { (try? JSONEncoder().encode(data)) ?? Data() }
}

// MARK: - 日期工具

func dateString(_ date: Date = Date()) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

func dateTimeString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "M月d日 HH:mm"
    return f.string(from: date)
}

func dayLabel(_ date: Date) -> String {
    let cal = Calendar.current
    if cal.isDateInToday(date) { return "今天" }
    if cal.isDateInTomorrow(date) { return "明天" }
    let f = DateFormatter()
    f.dateFormat = "M月d日"
    return f.string(from: date)
}

func moneyString(_ value: Double) -> String {
    String(format: "%.2f", value)
}

func dateFromString(_ s: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.date(from: s) ?? Date()
}
