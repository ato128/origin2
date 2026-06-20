//
//  FeatureFlags.swift
//  DailyTodo
//
//  Central place for shipping-time feature toggles. Flipping a flag here is the
//  only change needed to show/hide a feature — the underlying code stays intact.
//

import Foundation

enum FeatureFlags {
    /// Community / Arena (leaderboards, department & global scope, rankings).
    /// Hidden for the initial App Store launch — will be enabled in a later update.
    /// All Community code (CrewCommunityContent, ArenaStore, CrewModeSwitch) is
    /// kept intact behind this flag; set to `true` to bring the whole feature back.
    static let communityEnabled = false
}
