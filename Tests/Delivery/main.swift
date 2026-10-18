import AppKit

@MainActor func checkConfirmation() {
    let node = AXUIElementCreateApplication(getpid())
    func target(_ range: NSRange?) -> InsertionTarget {
        InsertionTarget(pid: getpid(), element: node, window: node, fingerprint: "test", initialValue: nil, initialSelection: range)
    }
    func check(_ condition: Bool, _ label: String) { precondition(condition, label); print("PASS \(label)") }
    check(TextDelivery.clipboardGrace(confirmed: true, elapsed: 0.1) == 0, "Confirmed consumer needs no extra clipboard delay")
    check(abs(TextDelivery.clipboardGrace(confirmed: false, elapsed: 0.1) - 0.8) < 0.0001, "Early unconfirmed paste retains original read window")
    check(TextDelivery.clipboardGrace(confirmed: false, elapsed: 1.2) == 0, "Polling time counts toward clipboard read window")
    check(TextDelivery.clipboardGrace(confirmed: false, elapsed: 0) == 0.9, "Unconfirmed event retains full read window")
    let end = target(NSRange(location: 6, length: 0))
    check(end.confirms("bonjour", before: "Avant ", after: "Avant bonjour"), "Exact insertion")
    check(!end.confirms("bonjour", before: "Avant bonjour", after: "Avant bonjour"), "Existing text cannot confirm an unchanged field")
    check(!end.confirms("bonjour", before: "Avant ", after: "Autre bonjour"), "Changed prefix cannot confirm the expected edit")
    check(target(NSRange(location: 2, length: 4)).confirms("oui", before: "😀test", after: "😀oui"), "UTF16 selected-range replacement")
    check(!end.confirms("bonjour", before: nil, after: "bonjour"), "Unreadable baseline is unconfirmed")
    check(!end.confirms("bonjour", before: "Avant ", after: nil), "Unreadable result is unconfirmed")
    check(!target(nil).confirms("Une phrase complète bonjour", before: "Avant ", after: "Avant bonjour"), "Suffix match alone cannot confirm")
    check(target(nil).confirms("bonjour", before: "Avant ", after: "Avant bonjour"), "Full text and changed value when selection unavailable")
}
MainActor.assumeIsolated { checkConfirmation() }
