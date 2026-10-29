//
//  CategoryManager.swift
//  awesome_notifications
//

import Foundation
import UserNotifications

/// Keeps every notification category registered at the same time.
///
/// `UNUserNotificationCenter.setNotificationCategories` replaces the whole set.
/// Registering only the category of the notification being created dropped the
/// action buttons of every other pending or delivered notification: only the
/// last one created kept its buttons.
///
/// The registered categories are read from the system once per process (they
/// persist across launches) and kept in memory afterwards. Reading them back
/// before each write would race, because `setNotificationCategories` is applied
/// asynchronously: a quick sequence of notifications could read a stale set and
/// drop each other's categories again.
public class CategoryManager {

    static let TAG = "CategoryManager"

    // ************** SINGLETON PATTERN ***********************

    // A `let`, not the lazy `instance` of the other managers: categories are
    // registered from background threads, and a second instance would bring a
    // second queue, breaking the serialization below.
    public static let shared:CategoryManager = CategoryManager()
    private init(){}

    // ********************************************************

    private let queue = DispatchQueue(label: "me.carda.awesome_notifications.categories")
    private var categories:[String:UNNotificationCategory]?

    /// Registers `category` alongside the ones already registered, replacing a
    /// previous category with the same identifier. With `waitUntilDone`, returns
    /// only after the set was handed to the system, so a notification added right
    /// after finds its buttons.
    public func register(category:UNNotificationCategory, waitUntilDone:Bool = true) {
        let work = {
            var current = self.categories ?? self.loadRegisteredCategories()
            current[category.identifier] = category
            self.categories = current
            UNUserNotificationCenter.current().setNotificationCategories(Set(current.values))
        }
        if waitUntilDone {
            queue.sync(execute: work)
        } else {
            queue.async(execute: work)
        }
    }

    private func loadRegisteredCategories() -> [String:UNNotificationCategory] {
        let semaphore = DispatchSemaphore(value: 0)
        var registered:Set<UNNotificationCategory> = []
        UNUserNotificationCenter.current().getNotificationCategories(completionHandler: { results in
            registered = results
            semaphore.signal()
        })
        semaphore.wait()

        var categories:[String:UNNotificationCategory] = [:]
        for category in registered {
            categories[category.identifier] = category
        }
        return categories
    }
}
