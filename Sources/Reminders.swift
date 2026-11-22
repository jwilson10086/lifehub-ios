import Foundation
import EventKit
import UserNotifications

enum Reminders {
    /// 直接写入系统日历，提前 15 分钟提醒
    static func addToCalendar(title: String, note: String, date: Date) {
        let store = EKEventStore()
        let completion: (Bool, Error?) -> Void = { granted, _ in
            guard granted else { return }
            let event = EKEvent(eventStore: store)
            event.title = title
            event.startDate = date
            event.endDate = date.addingTimeInterval(30 * 60)
            event.notes = note
            event.calendar = store.defaultCalendarForNewEvents
            event.addAlarm(EKAlarm(relativeOffset: -15 * 60))
            try? store.save(event, span: .thisEvent)
        }
        if #available(iOS 17.0, *) {
            store.requestFullAccessToEvents { granted, error in completion(granted, error) }
        } else {
            store.requestAccess(to: .event, completion: completion)
        }
    }

    /// 本地通知，提前 15 分钟提醒
    static func scheduleNotification(title: String, note: String, date: Date) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "生活账 · " + title
            content.body = note.isEmpty ? "时间到了" : note
            content.sound = .default
            var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute],
                                                        from: date.addingTimeInterval(-15 * 60))
            comps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }

    static func remind(title: String, note: String, date: Date) {
        addToCalendar(title: title, note: note, date: date)
        scheduleNotification(title: title, note: note, date: date)
    }
}
