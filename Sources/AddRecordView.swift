import SwiftUI

struct AddRecordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: Store

    let initial: Parsed
    @State private var type: String
    @State private var amount: String
    @State private var category: String
    @State private var date: Date
    @State private var title: String
    @State private var place: String
    @State private var person: String
    @State private var note: String
    @State private var rawText: String

    init(initial: Parsed) {
        self.initial = initial
        _type = State(initialValue: initial.type ?? "expense")
        _amount = State(initialValue: initial.amount.map { String($0) } ?? "")
        _category = State(initialValue: initial.category ?? "其他")
        _date = State(initialValue: initial.datetime ?? (initial.date.map(dateFromString) ?? Date()))
        _title = State(initialValue: initial.title ?? "")
        _place = State(initialValue: "")
        _person = State(initialValue: "")
        _note = State(initialValue: initial.text ?? "")
        _rawText = State(initialValue: initial.text ?? "")
    }

    private let types = [
        ("expense", "支出"), ("income", "收入"),
        ("appointment", "预约"), ("schedule", "日程"), ("note", "随手记")
    ]
    private let expenseCats = ["餐饮", "交通", "居住", "购物", "医疗", "娱乐", "其他"]
    private let incomeCats = ["收入", "工资", "报销", "其他"]

    var body: some View {
        NavigationStack {
            Form {
                Section("记录类型") {
                    Picker("类型", selection: $type) {
                        ForEach(types, id: \.0) { Text($0.1).tag($0.0) }
                    }
                    .pickerStyle(.segmented)
                }

                if type == "expense" || type == "income" {
                    Section("账目") {
                        TextField("金额", text: $amount).keyboardType(.decimalPad)
                        Picker("分类", selection: $category) {
                            ForEach(type == "income" ? incomeCats : expenseCats, id: \.self) { Text($0).tag($0) }
                        }
                        DatePicker("日期", selection: $date, displayedComponents: .date)
                        TextField("备注", text: $note)
                    }
                } else if type == "appointment" || type == "schedule" {
                    Section("安排") {
                        TextField(type == "appointment" ? "预约项目" : "日程标题", text: $title)
                        DatePicker("日期时间", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        if type == "appointment" {
                            TextField("地点", text: $place)
                            TextField("联系人", text: $person)
                        }
                        TextField("备注（航班号、预约码等）", text: $note)
                    }
                } else {
                    Section("随手记") {
                        TextEditor(text: $note).frame(minHeight: 90)
                        TextField("标签（可选）", text: $place)
                    }
                }

                if !rawText.isEmpty {
                    Section("识别到的原始文字") {
                        Text(rawText).font(.caption).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("新增记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("保存") { save() } }
            }
        }
    }

    private func save() {
        switch type {
        case "expense", "income":
            guard let value = Double(amount), value > 0 else { return }
            store.addLedger(LedgerRecord(type: type, amount: value,
                                         category: category.isEmpty ? "其他" : category,
                                         date: dateString(date), note: note))
        case "appointment", "schedule":
            guard !title.isEmpty else { return }
            let record = EventRecord(title: title, datetime: date, place: place, person: person, note: note)
            if type == "appointment" { store.addAppointment(record) } else { store.addSchedule(record) }
            Reminders.remind(title: title, note: [place, person, note].filter { !$0.isEmpty }.joined(separator: " / "), date: date)
        default:
            guard !note.isEmpty else { return }
            store.addNote(NoteRecord(text: note, tags: place))
        }
        dismiss()
    }
}
