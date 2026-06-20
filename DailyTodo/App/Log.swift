//
//  Log.swift
//  DailyTodo
//
//  Lightweight logging facade. In RELEASE builds every call compiles to a
//  no-op, so console noise and the small cost of building log strings never
//  ship to users. In DEBUG it forwards to Swift.print unchanged.
//
//  Drop-in for print: `Log.debug("foo", value)` behaves like `print("foo", value)`.
//

import Foundation

enum Log {
    /// Debug-only log. No-op in RELEASE.
    static func debug(
        _ items: Any...,
        separator: String = " ",
        terminator: String = "\n"
    ) {
        #if DEBUG
        let text = items.map { String(describing: $0) }.joined(separator: separator)
        Swift.print(text, terminator: terminator)
        #endif
    }
}
