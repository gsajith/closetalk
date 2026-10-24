// Lists the running Closetalk's windows: title, bounds, and whether each is on screen.
// Run with `swift scripts/windows.swift`. Window titles need no Screen Recording permission for
// windows the window server reports as owned by Closetalk.
import CoreGraphics

let windows = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
let mine = windows.filter { ($0[kCGWindowOwnerName as String] as? String) == "Closetalk" }
if mine.isEmpty { print("No Closetalk windows. Is it running?") }
for window in mine {
    let title = window[kCGWindowName as String] as? String ?? ""
    let onScreen = window[kCGWindowIsOnscreen as String] as? Bool ?? false
    let b = window[kCGWindowBounds as String] as? [String: Double] ?? [:]
    let bounds = "\(Int(b["Width"] ?? 0))x\(Int(b["Height"] ?? 0)) at \(Int(b["X"] ?? 0)),\(Int(b["Y"] ?? 0))"
    print("\(onScreen ? "on screen " : "off screen") \(bounds)  \(title.isEmpty ? "(untitled)" : title)")
}
