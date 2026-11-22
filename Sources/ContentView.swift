import SwiftUI
import UniformTypeIdentifiers

extension Notification.Name {
    static let lifehubCapture = Notification.Name("lifehubCapture")
}

struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var text: String
    init(text: String = "") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        text = String(data: configuration.file.regularFileContents ?? Data(), encoding: .utf8) ?? ""
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: text.data(using: .utf8) ?? Data())
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: Store
    @State private var showAdd = false
    @State private var addInitial = Parsed()
    @State private var showExport = false
    @State private var showImport = false
    @State private var alertText = ""

    var body: some View {
        TabView {
            home.tabItem { Label("总览", systemImage: "house") }
            ledgerView.tabItem { Label("账本", systemImage: "yuan.sign") }
            eventView(appointments: true).tabItem { Label("预约", systemImage: "calendar") }
            eventView(appointments: false).tabItem { Label("日程", systemImage: "pin") }
            notesView.tabItem { Label("随手记", systemImage: "note.text") }
        }
        .sheet(isPresented: $showAdd) {
            AddRecordView(initial: addInitial).environmentObject(store)
        }
        .fileExporter(isPresented: $showExport,
                      document: BackupDocument(text: String(data: store.exportData, encoding: .utf8) ?? ""),
                      contentType: .json, defaultFilename: "生活账备份") { _ in }
        .fileImporter(isPresented: $showImport, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            guard url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let d = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(AppData.self, from: d)
                store.merge(decoded)
                alertText = "导入完成"
            } catch {
                alertText = "导入失败：备份文件格式不对"
            }
        }
        .alert(alertText, isPresented: .constant(!alertText.isEmpty)) {
            Button("好") { alertText = "" }
        }
        .onReceive(NotificationCenter.default.publisher(for: .lifehubCapture)) { note in
            if let text = note.object as? String {
                addInitial = parseText(text)
                showAdd = true
            }
        }
    }

    // MARK: - 总览

    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 10) {
                        statCard("本月收入", moneyString(monthIncome), .green)
                        statCard("本月支出", moneyString(monthExpense), .red)
                        statCard("结余", moneyString(monthIncome - monthExpense), .primary)
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("接下来").font(.headline).padding(.bottom, 6)
                        if upcoming.isEmpty {
                            Text("暂无安排").foregroundColor(.secondary).font(.subheadline).padding(.vertical, 12)
                        } else {
                            ForEach(upcoming.prefix(5), id: \.id) { item in
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(item.title.isEmpty ? "未命名" : item.title)
                                        Text(dayLabel(item.datetime) + " " + dateTimeString(item.datetime))
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Text(dayLabel(item.datetime)).font(.caption).foregroundColor(.secondary)
                                }
                                .padding(.vertical, 7)
                            }
                        }
                    }
                    .cardStyle()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("快捷记录").font(.headline)
                        Text("背敲三下手机 → 快捷指令截屏识别 → 自动弹出确认窗口。")
                            .font(.caption).foregroundColor(.secondary)
                        Button("新增记录") {
                            addInitial = Parsed()
                            showAdd = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .cardStyle()
                }
                .padding()
            }
            .navigationTitle("生活账")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showExport = true } label { Image(systemName: "square.and.arrow.up") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showImport = true } label { Image(systemName: "square.and.arrow.down") }
                }
            }
        }
    }

    private func statCard(_ label: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text(value).font(.system(.headline, design: .rounded)).foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var monthIncome: Double {
        let prefix = String(dateString().prefix(7))
        return store.data.ledger.filter { $0.type == "income" && $0.date.hasPrefix(prefix) }.reduce(0) { $0 + $1.amount }
    }
    private var monthExpense: Double {
        let prefix = String(dateString().prefix(7))
        return store.data.ledger.filter { $0.type == "expense" && $0.date.hasPrefix(prefix) }.reduce(0) { $0 + $1.amount }
    }
    private var upcoming: [EventRecord] {
        let cutoff = Date().addingTimeInterval(-3600)
        return (store.data.appointments + store.data.schedules)
            .filter { $0.datetime >= cutoff }
            .sorted { $0.datetime < $1.datetime }
    }

    // MARK: - 账本

    private var ledgerView: some View {
        NavigationStack {
            List {
                ForEach(store.data.ledger) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.category)
                            Text(item.note.isEmpty ? item.date : item.note + " · " + item.date)
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text((item.type == "income" ? "+" : "−") + moneyString(item.amount))
                            .foregroundColor(item.type == "income" ? .green : .red)
                    }
                }
                .onDelete { idx in
                    let ids = idx.compactMap { store.data.ledger.indices.contains($0) ? store.data.ledger[$0].id : nil }
                    ids.forEach { store.deleteLedger($0) }
                }
            }
            .navigationTitle("账本")
            .toolbar {
                Button { addInitial = Parsed(type: "expense"); showAdd = true } label {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - 预约 / 日程

    private func eventView(appointments: Bool) -> some View {
        NavigationStack {
            List {
                ForEach(appointments ? store.data.appointments : store.data.schedules) { item in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(item.title.isEmpty ? "未命名" : item.title)
                            Text(dateTimeString(item.datetime) + (item.place.isEmpty ? "" : " · " + item.place))
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            Reminders.remind(title: item.title, note: item.note, date: item.datetime)
                        } label { Image(systemName: "bell.badge") }
                        .buttonStyle(.borderless)
                    }
                }
                .onDelete { idx in
                    let list = appointments ? store.data.appointments : store.data.schedules
                    idx.forEach { i in
                        if appointments { store.deleteAppointment(list[i].id) }
                        else { store.deleteSchedule(list[i].id) }
                    }
                }
            }
            .navigationTitle(appointments ? "预约" : "日程")
            .toolbar {
                Button { addInitial = Parsed(type: appointments ? "appointment" : "schedule"); showAdd = true } label {
                    Image(systemName: "plus")
                }
            }
        }
    }

    // MARK: - 随手记

    private var notesView: some View {
        NavigationStack {
            List {
                ForEach(store.data.notes) { item in
                    VStack(alignment: .leading) {
                        Text(item.text)
                        if !item.tags.isEmpty {
                            Text(item.tags).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    let ids = idx.compactMap { store.data.notes.indices.contains($0) ? store.data.notes[$0].id : nil }
                    ids.forEach { store.deleteNote($0) }
                }
            }
            .navigationTitle("随手记")
            .toolbar {
                Button { addInitial = Parsed(type: "note"); showAdd = true } label {
                    Image(systemName: "plus")
                }
            }
        }
    }
}

private extension View {
    func cardStyle() -> some View {
        self.padding(14)
            .background(.background, in: RoundedRectangle(cornerRadius: 14))
    }
}
