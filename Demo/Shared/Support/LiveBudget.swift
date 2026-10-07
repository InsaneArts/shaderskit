import SwiftUI

/// Caps how many cards run a live Metal view at once. The most recently visible cards win;
/// the others show their cached snapshot.
@Observable
final class LiveBudget {
    var limit: Int
    private(set) var live: [String] = []

    init(limit: Int) {
        self.limit = limit
    }

    func setVisible(_ id: String, _ visible: Bool) {
        if visible {
            if live.last == id { return }
            live.removeAll { $0 == id }
            live.append(id)
            if live.count > limit { live.removeFirst(live.count - limit) }
        } else if live.contains(id) {
            live.removeAll { $0 == id }
        }
    }

    func isLive(_ id: String) -> Bool { live.contains(id) }
}
