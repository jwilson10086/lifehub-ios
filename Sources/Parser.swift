import Foundation

struct Parsed {
    var type: String?        // expense | income | appointment | schedule | note
    var amount: Double?
    var category: String?
    var date: String?
    var datetime: Date?
    var title: String?
    var text: String?

    init(type: String? = nil,
         amount: Double? = nil,
         category: String? = nil,
         date: String? = nil,
         datetime: Date? = nil,
         title: String? = nil,
         text: String? = nil) {
        self.type = type; self.amount = amount; self.category = category
        self.date = date; self.datetime = datetime; self.title = title; self.text = text
    }
}

private func match(_ pattern: String, in text: String) -> ([String], String)? {
    guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
    let ns = NSRange(text.startIndex..., in: text)
    guard let m = re.firstMatch(in: text, options: [], range: ns) else { return nil }
    var groups: [String] = []
    for i in 0..<m.numberOfRanges {
        if let r = Range(m.range(at: i), in: text) {
            groups.append(String(text[r]))
        } else {
            groups.append("")
        }
    }
    guard let wholeRange = Range(m.range, in: text) else { return nil }
    return (groups, String(text[wholeRange]))
}

private func guessCategory(_ t: String) -> String {
    if t.range(of: "吃|餐|饭|外卖|奶茶|咖啡|超市|菜", options: .regularExpression) != nil { return "餐饮" }
    if t.range(of: "车|油|打车|地铁|公交|机票|火车|高铁", options: .regularExpression) != nil { return "交通" }
    if t.range(of: "酒店|住宿|房租|水电", options: .regularExpression) != nil { return "居住" }
    if t.range(of: "药|医|医院|挂号|看病", options: .regularExpression) != nil { return "医疗" }
    if t.range(of: "衣|鞋|买", options: .regularExpression) != nil { return "购物" }
    return "其他"
}

/// 把挂号短信 / 机票确认 / 消费通知文字解析成记录字段
func parseText(_ input: String) -> Parsed {
    let t = input.trimmingCharacters(in: .whitespacesAndNewlines)
    var result = Parsed()
    result.text = t
    if t.isEmpty { return result }

    var drop: [String] = []
    var y: Int?, mo: Int?, da: Int?

    if let m = match("(20\\d{2})[-/.年](\\d{1,2})[-/.月](\\d{1,2})", in: t) {
        y = Int(m.0[1]); mo = Int(m.0[2]); da = Int(m.0[3]); drop.append(m.1)
    } else if let m = match("(\\d{1,2})[月/-](\\d{1,2})[日号]?", in: t) {
        let now = Date()
        y = Calendar.current.component(.year, from: now)
        mo = Int(m.0[1]); da = Int(m.0[2])
        let todayStart = Calendar.current.startOfDay(for: now)
        var comps = DateComponents(); comps.year = y; comps.month = mo; comps.day = da
        if let d = Calendar.current.date(from: comps), d < todayStart { y = y! + 1 }
        drop.append(m.1)
    }

    var hh: Int? = nil, mm = 0
    if let m = match("(上午|下午|晚上|中午)?\\s*(\\d{1,2})\\s*[:：]\\s*(\\d{2})", in: t) {
        hh = Int(m.0[2]); mm = Int(m.0[3]) ?? 0
        if ["下午", "晚上", "中午"].contains(m.0[1]) && hh! < 12 { hh! += 12 }
        drop.append(m.1)
    }
    if hh == nil {
        let m = match("(上午|下午|晚上|中午)\\s*(\\d{1,2})\\s*点\\s*(\\d{1,2})?\\s*分?", in: t)
            ?? match("(\\d{1,2})\\s*点\\s*(\\d{1,2})?\\s*分?", in: t)
        if let m = m {
            let hasMeridiem = ["上午", "下午", "晚上", "中午"].contains(m.0[1])
            hh = Int(hasMeridiem ? m.0[2] : m.0[1])
            mm = Int(hasMeridiem ? (m.0[3].isEmpty ? "0" : m.0[3]) : (m.0[2].isEmpty ? "0" : m.0[2])) ?? 0
            if m.1.contains("下午") || m.1.contains("晚上") || m.1.contains("中午") {
                if hh! < 12 { hh! += 12 }
            }
            drop.append(m.1)
        }
    }

    if t.range(of: "今天|明天|后天", options: .regularExpression) != nil,
       match("(\\d{1,2})[月/-](\\d{1,2})", in: t) == nil,
       let rel = match("今天|明天|后天", in: t)?.1 {
        var d = Date()
        if rel == "明天" { d = Calendar.current.date(byAdding: .day, value: 1, to: d)! }
        if rel == "后天" { d = Calendar.current.date(byAdding: .day, value: 2, to: d)! }
        y = Calendar.current.component(.year, from: d)
        mo = Calendar.current.component(.month, from: d)
        da = Calendar.current.component(.day, from: d)
        drop.append(rel)
    }

    if let y = y, let mo = mo, let da = da {
        let hour = hh ?? 9
        var comps = DateComponents()
        comps.year = y; comps.month = mo; comps.day = da
        comps.hour = min(max(hour, 0), 23); comps.minute = min(max(mm, 0), 59)
        result.datetime = Calendar.current.date(from: comps)
        result.date = String(format: "%04d-%02d-%02d", y, mo, da)
    }

    let amountMatch = match("(?:¥|￥|RMB|人民币)\\s*(\\d{1,6}(?:\\.\\d{1,2})?)", in: t)
        ?? match("(\\d{1,6}(?:\\.\\d{1,2})?)\\s*(?:元|块|RMB)", in: t)
        ?? match("(?:费|价|合计|共计|金额)\\s*[为:：]?\\s*(\\d{1,6}(?:\\.\\d{1,2})?)", in: t)
    if let m = amountMatch, let v = Double(m.0[1]), v > 0, v < 1_000_000 {
        result.amount = v
        drop.append(m.1)
    }

    let incomeWords = "工资|收入|入账|报销|收到|返现|退款|转账给你|到账"
    let eventWords = "挂号|医生|就诊|面诊|预约|机票|航班|火车|高铁|酒店|会议|面试|考试|演唱会|电影|聚餐|入住|出发"
    if t.range(of: incomeWords, options: .regularExpression) != nil {
        result.type = "income"; result.category = "收入"
    } else if t.range(of: eventWords, options: .regularExpression) != nil {
        result.type = t.range(of: "挂号|医生|就诊|面诊|预约", options: .regularExpression) != nil ? "appointment" : "schedule"
        if t.contains("机票") || t.contains("航班") || t.contains("火车") || t.contains("高铁") { result.category = "交通" }
        if t.contains("酒店") || t.contains("入住") { result.category = "住宿" }
    } else if result.amount != nil {
        result.type = "expense"
        result.category = guessCategory(t)
    }

    var clean = t
    drop.forEach { clean = clean.replacingOccurrences(of: $0, with: " ") }
    clean = clean.replacingOccurrences(of: "\\s{2,}", with: " ", options: .regularExpression)
    if let r = clean.range(of: "^[您好你预约提醒通知已在的了：:，,\\s]+", options: .regularExpression) {
        clean = String(clean[r.upperBound...])
    }
    clean = clean.trimmingCharacters(in: .whitespacesAndNewlines)
    if clean.isEmpty { clean = t }
    result.title = clean.count > 42 ? String(clean.prefix(42)) + "…" : clean
    return result
}
