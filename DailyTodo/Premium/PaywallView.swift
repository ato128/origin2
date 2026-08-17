import SwiftUI
import Combine
import RevenueCat

struct PaywallView: View {
    let context: String
    var onDismiss: (() -> Void)?

    @StateObject private var manager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTier: TierType = .premiumAI
    @State private var selectedPlan: PlanType = .annual
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var appeared = false

    enum PlanType { case monthly, annual }
    enum TierType { case premium, premiumAI }

    // MARK: – Palette (gold = premium, gold+cyan = premium AI)

    private let bg       = Color(arenaHex: "#080A12")
    private let card     = Color(arenaHex: "#121624")
    private let cardHi   = Color(arenaHex: "#171C2E")
    private let gold     = Color(arenaHex: "#FBBF24")
    private let goldSoft = Color(arenaHex: "#FFD166")
    private let cyan     = Color(arenaHex: "#2DD4FF")
    private let ink      = Color(arenaHex: "#1A1206")

    private var goldGradient: LinearGradient {
        LinearGradient(colors: [goldSoft, gold], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var aiGradient: LinearGradient {
        LinearGradient(colors: [goldSoft, gold, cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var tierGradient: LinearGradient {
        selectedTier == .premiumAI ? aiGradient : goldGradient
    }

    private var accent: Color {
        selectedTier == .premiumAI ? cyan : gold
    }

    // MARK: – Products

    private var productID: String {
        switch (selectedTier, selectedPlan) {
        case (.premium, .annual):    return "com.updo.pro.annual"
        case (.premium, .monthly):   return "com.updo.pro.monthly"
        case (.premiumAI, .annual):  return "com.updo.premiumai.annual"
        case (.premiumAI, .monthly): return "com.updo.premiumai.monthly"
        }
    }

    private func storePrice(_ productID: String) -> String? {
        // Canlı StoreKit 2 fiyatı ÖNCELİKLİ — satın almayla birebir aynı vitrin
        // (para birimi dahil). Yoksa RevenueCat'in fiyatına düş.
        if let live = manager.storeKitDisplayPrices[productID] { return live }
        return manager.availablePackages
            .first { $0.storeProduct.productIdentifier == productID }?
            .storeProduct.localizedPriceString
    }

    // Store fiyatları yüklenemediğinde gösterilen planlanan fiyatlar —
    // App Store Connect ürünleri bu değerlerle oluşturulmalı.
    private var monthlyPrice: String {
        let id = selectedTier == .premiumAI ? "com.updo.premiumai.monthly" : "com.updo.pro.monthly"
        return storePrice(id) ?? (selectedTier == .premiumAI ? "149,99 ₺" : "99,99 ₺")
    }

    private var annualPrice: String {
        let id = selectedTier == .premiumAI ? "com.updo.premiumai.annual" : "com.updo.pro.annual"
        return storePrice(id) ?? (selectedTier == .premiumAI ? "1.299,99 ₺" : "999,99 ₺")
    }

    private var savingsText: String {
        tr("pw_save_42")
    }

    // MARK: – Body

    var body: some View {
        ZStack(alignment: .top) {
            backgroundLayer

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    header.padding(.top, 44)
                    tierSelector.padding(.top, 24)
                    benefitsCard.padding(.top, 16)
                    planSelector.padding(.top, 16)
                    renewalLine.padding(.top, 12)
                    ctaSection.padding(.top, 16)
                    trustRow.padding(.top, 14)
                    legal.padding(.top, 16).padding(.bottom, 40)
                }
                .padding(.horizontal, 20)
            }

            closeButton
        }
        .onAppear {
            Analytics.shared.track("paywall_viewed", properties: ["context": context])
            Task {
                await manager.loadOfferings()
                await manager.refreshStoreKitPrices()
            }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.05)) { appeared = true }
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            bg.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.22), Color.clear], center: .top, startRadius: 0, endRadius: 380)
                .frame(height: 400).ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: selectedTier)
            Circle().fill(accent.opacity(selectedTier == .premiumAI ? 0.10 : 0.06))
                .frame(width: 340, height: 340)
                .blur(radius: 120).offset(x: 150, y: 520).ignoresSafeArea()
                .animation(.easeInOut(duration: 0.35), value: selectedTier)
        }
    }

    // MARK: – Header

    private var header: some View {
        VStack(spacing: 14) {
            emblem
                .frame(height: 96)
                .scaleEffect(appeared ? 1 : 0.82)
                .animation(.easeInOut(duration: 0.25), value: selectedTier)

            Text(selectedTier == .premiumAI ? "UPDO PREMIUM AI" : "UPDO PREMIUM")
                .font(.system(size: 13, weight: .black)).tracking(5)
                .foregroundStyle(tierGradient)

            (
                Text(tr("pw_line1") + "\n")
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                + Text(tr("pw_unlimited_w"))
                    .font(.system(size: 30, weight: .bold)).foregroundStyle(.white)
                + Text(tr("pw_grow_w"))
                    .font(.system(size: 30, weight: .bold, design: .serif)).italic().foregroundStyle(accent)
            )
            .multilineTextAlignment(.center)

            Text(tr("pw_subtitle"))
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
    }

    private var emblem: some View {
        ZStack {
            Circle().fill(accent.opacity(0.18)).frame(width: 128, height: 128).blur(radius: 24)

            if selectedTier == .premiumAI {
                UpdoAIOrb(size: 68)
                    .overlay(
                        Circle().strokeBorder(goldGradient, lineWidth: 1.5)
                            .frame(width: 90, height: 90).opacity(0.85)
                    )
                    .shadow(color: cyan.opacity(0.45), radius: 24, y: 9)
            } else {
                Circle().fill(goldGradient).frame(width: 80, height: 80)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1))
                    .shadow(color: gold.opacity(0.55), radius: 24, y: 9)
                Image(systemName: "crown.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(ink)
            }
        }
    }

    // MARK: – Tier selector (Premium AI / Premium)

    private var tierSelector: some View {
        HStack(spacing: 12) {
            premiumAITierCard
            premiumTierCard
        }
    }

    private var premiumAITierCard: some View {
        let isSelected = selectedTier == .premiumAI
        return Button {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) { selectedTier = .premiumAI }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tr("pw_ai_included_caps"))
                        .font(.system(size: 8.5, weight: .black)).tracking(0.5).foregroundStyle(ink)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(aiGradient, in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 13).padding(.top, 12)

                HStack(spacing: 8) {
                    UpdoAIOrb(size: 20)
                    Text("Premium AI").font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                }
                .padding(.horizontal, 13).padding(.top, 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text((storePrice("com.updo.premiumai.monthly") ?? "149,99 ₺") + tr("pw_per_mo"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? cyan : cyan.opacity(0.45))
                    Text(tr("pw_tier_ai_sub")).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : .white.opacity(0.3))
                }
                .padding(.horizontal, 13).padding(.top, 4).padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? cardHi : card)
            .overlay(tierBorder(isSelected, gradient: aiGradient))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: cyan.opacity(isSelected ? 0.22 : 0), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var premiumTierCard: some View {
        let isSelected = selectedTier == .premium
        return Button {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.2)) { selectedTier = .premium }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tr("pw_byo_tag"))
                        .font(.system(size: 8.5, weight: .black)).tracking(0.5).foregroundStyle(ink)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(goldGradient, in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 13).padding(.top, 12)

                HStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(goldGradient)
                    Text("Premium").font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                }
                .padding(.horizontal, 13).padding(.top, 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text((storePrice("com.updo.pro.monthly") ?? "99,99 ₺") + tr("pw_per_mo"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? gold : gold.opacity(0.45))
                    Text(tr("pw_tier_byo_sub")).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : .white.opacity(0.3))
                }
                .padding(.horizontal, 13).padding(.top, 4).padding(.bottom, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? cardHi : card)
            .overlay(tierBorder(isSelected, gradient: goldGradient))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: gold.opacity(isSelected ? 0.20 : 0), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }

    private func tierBorder(_ isSelected: Bool, gradient: LinearGradient) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .strokeBorder(
                isSelected ? AnyShapeStyle(gradient) : AnyShapeStyle(Color.white.opacity(0.08)),
                lineWidth: isSelected ? 2 : 1
            )
    }

    // MARK: – Benefits checklist (tier-aware)

    private var benefits: [String] {
        var list: [String] = []
        // Headline AI feature differs by tier.
        if selectedTier == .premiumAI {
            list.append(tr("pw_feat_ai_expanded"))     // Updo AI included
        } else {
            list.append(tr("pw_feat_byo_chatgpt"))     // Connect your own ChatGPT
        }
        list.append(contentsOf: [
            tr("pw_feat_crew"),
            tr("pw_feat_analytics"),
            tr("pw_b_future_weeks"),
            tr("pw_b_best_hours"),
            tr("pw_feat_app_icon"),
            tr("pw_feat_widget_style"),
            tr("pw_feat_support"),
            tr("pw_b_all_future")
        ])
        return list
    }

    private var benefitsCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(tr("pw_whats_included"))
                    .font(.system(size: 12, weight: .black, design: .monospaced)).tracking(1.4)
                    .foregroundStyle(accent)
                Spacer()
            }
            .padding(.bottom, 14)

            ForEach(Array(benefits.enumerated()), id: \.element) { idx, b in
                benefitRow(index: idx, text: b)
                if idx < benefits.count - 1 {
                    Rectangle().fill(Color.white.opacity(0.05)).frame(height: 1)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous).fill(card)
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(accent.opacity(0.15), lineWidth: 1))
        )
    }

    @ViewBuilder
    private func benefitRow(index idx: Int, text b: String) -> some View {
        HStack(spacing: 12) {
            benefitIcon(index: idx)
            Text(b)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 9)
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : -10)
        .animation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.05 * Double(idx)), value: appeared)
    }

    @ViewBuilder
    private func benefitIcon(index idx: Int) -> some View {
        if idx == 0 && selectedTier == .premiumAI {
            UpdoAIOrb(size: 18)
        } else if idx == 0 {
            Image(systemName: "key.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(goldGradient)
                .frame(width: 18)
        } else {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(goldGradient)
        }
    }

    // MARK: – Plan selector (annual / monthly)

    private var planSelector: some View {
        HStack(spacing: 12) {
            annualCard
            monthlyCard
        }
    }

    private var annualCard: some View {
        let isSelected = selectedPlan == .annual
        return Button {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = .annual }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(tr("pw_best_value"))
                        .font(.system(size: 9, weight: .black)).tracking(0.5).foregroundStyle(ink)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(tierGradient, in: Capsule())
                    Spacer()
                }
                .padding(.horizontal, 14).padding(.top, 12)

                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("pw_annual")).font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                    Text(annualPrice + tr("pw_per_yr")).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : .white.opacity(0.3))
                    Text(savingsText).font(.system(size: 11, weight: .black))
                        .foregroundStyle(isSelected ? accent : accent.opacity(0.45))
                }
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? cardHi : card)
            .overlay(planBorder(isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private var monthlyCard: some View {
        let isSelected = selectedPlan == .monthly
        return Button {
            HapticManager.shared.selection()
            withAnimation(.easeInOut(duration: 0.15)) { selectedPlan = .monthly }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Color.clear.frame(height: 29)
                VStack(alignment: .leading, spacing: 3) {
                    Text(tr("pw_monthly")).font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                    Text(monthlyPrice + tr("pw_per_mo")).font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.6) : .white.opacity(0.3))
                    Text(tr("pw_renews_monthly")).font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.45) : .white.opacity(0.25))
                }
                .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? cardHi : card)
            .overlay(planBorder(isSelected))
            .clipShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    private func planBorder(_ isSelected: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18)
            .strokeBorder(
                isSelected ? AnyShapeStyle(tierGradient) : AnyShapeStyle(Color.white.opacity(0.08)),
                lineWidth: isSelected ? 2 : 1
            )
    }

    // MARK: – Renewal clarity line

    private var renewalLine: some View {
        let priceText = selectedPlan == .annual ? annualPrice + tr("pw_per_yr") : monthlyPrice + tr("pw_per_mo")
        return Text("\(priceText) · \(tr("pw_cancel_anytime"))")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white.opacity(0.42))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    // MARK: – CTA

    private var ctaSection: some View {
        VStack(spacing: 12) {
            Button(action: purchase) {
                ZStack {
                    tierGradient.clipShape(RoundedRectangle(cornerRadius: 18))
                    if isPurchasing || manager.isLoading {
                        ProgressView().tint(ink)
                    } else {
                        Text(ctaLabel).font(.system(size: 17, weight: .black)).foregroundStyle(ink)
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 58)
            }
            .disabled(isPurchasing || manager.isLoading)
            .shadow(color: accent.opacity(0.35), radius: 20, y: 10)

            if let error = errorMessage {
                Text(error).font(.caption).foregroundStyle(.red.opacity(0.75)).multilineTextAlignment(.center)
            }

            Button { Task { await restore() } } label: {
                Text(tr("pw_restore")).font(.system(size: 13, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4)).underline(color: .white.opacity(0.22))
            }
            .buttonStyle(.plain)
        }
    }

    private var ctaLabel: String {
        selectedTier == .premiumAI ? tr("pw_go_pro_ai") : tr("pw_go_pro")
    }

    // MARK: – Trust

    private var trustRow: some View {
        HStack(spacing: 16) {
            trustItem(icon: "xmark.circle.fill", text: tr("pw_cancel_anytime"))
            trustItem(icon: "checkmark.shield.fill", text: tr("pw_secured"))
        }
    }

    private func trustItem(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 12)).foregroundStyle(accent.opacity(0.8))
            Text(text).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: – Purchase logic

    private func purchase() {
        guard let pkg = manager.availablePackages.first(where: {
            $0.storeProduct.productIdentifier == productID
        }) else {
            errorMessage = tr("pw_products_loading")
            Task { await manager.loadOfferings() }
            return
        }
        isPurchasing = true
        errorMessage = nil
        Task {
            do {
                try await manager.purchase(package: pkg)
                dismiss(); onDismiss?()
            } catch {
                errorMessage = error.localizedDescription
            }
            isPurchasing = false
        }
    }

    private func restore() async {
        do {
            try await manager.restorePurchases()
            if manager.isPro { dismiss(); onDismiss?() }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: – Legal

    private var legal: some View {
        VStack(spacing: 8) {
            Text(tr("pw_legal")).font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.25)).multilineTextAlignment(.center)
            HStack(spacing: 4) {
                Link(tr("pw_privacy"), destination: URL(string: "https://ato128.github.io/updo-support/privacy.html")!)
                Text("·")
                Link(tr("pw_terms"), destination: URL(string: "https://ato128.github.io/updo-support/terms.html")!)
            }
            .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.30))
        }
    }

    // MARK: – Dismiss

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                Analytics.shared.track("paywall_dismissed", properties: ["context": context])
                dismiss(); onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26)).symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.top, 16).padding(.trailing, 20)
        }
    }
}
