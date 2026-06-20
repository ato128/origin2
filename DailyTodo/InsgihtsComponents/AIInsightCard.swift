//
//  AIInsightCard.swift
//  DailyTodo
//

import SwiftUI

struct AIInsightCard: View {
    let item: AIInsightItem

    @State private var appeared = false
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                expanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                // Always-visible header row
                HStack(alignment: .center, spacing: 14) {
                    iconView
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .padding(16)

                // Expandable body
                if expanded {
                    Text(item.body)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(3)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
        }
        .buttonStyle(.plain)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 10)
        .animation(.spring(response: 0.44, dampingFraction: 0.82), value: appeared)
        .onAppear { appeared = true }
    }

    private var accentColor: Color {
        Color(hex: item.accent) ?? .accentColor
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(accentColor.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: item.icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(accentColor)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(accentColor.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accentColor.opacity(0.18), lineWidth: 1)
            )
    }
}

struct AIInsightsSectionView: View {
    @ObservedObject var store: AISmartInsightsStore
    let onRefresh: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if store.isLoading {
                loadingView
            } else if let err = store.error {
                errorView(err)
            } else if store.insights.isEmpty {
                emptyView
            } else {
                ForEach(store.insights.prefix(3)) { item in
                    AIInsightCard(item: item)
                }
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("AI ANALYSIS")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .tracking(1.4)
                        .foregroundStyle(.secondary)
                }
                Text("Smart Insights")
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(.primary)
            }
            Spacer()
            if !store.isLoading {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(Color.primary.opacity(0.07)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var loadingView: some View {
        HStack(spacing: 12) {
            ProgressView().progressViewStyle(.circular).scaleEffect(0.9)
            Text(tr("aic_analyzing"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color.primary.opacity(0.05)))
    }

    private func errorView(_ msg: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            Text(msg)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.orange.opacity(0.08)))
    }

    private var emptyView: some View {
        HStack(spacing: 10) {
            Image(systemName: "chart.bar.fill").foregroundStyle(.secondary)
            Text(tr("aic_no_data"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color.primary.opacity(0.05)))
    }
}

private extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
