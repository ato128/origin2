//
//  UniversityPickerSheet.swift
//  DailyTodo
//
//  Created by Atakan Ortaç on 23.04.2026.
//

import SwiftUI

struct UniversityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedUniversityID: UUID?
    @Binding var selectedUniversityName: String
    @Binding var selectedCountryCode: String

    @State private var searchText: String = ""
    @State private var universities: [CatalogUniversity] = []
    @State private var isLoading: Bool = false
    @State private var errorText: String?

    @State private var loadTask: Task<Void, Never>?
    @State private var latestLoadRequestID = UUID()
    @State private var didPerformInitialLoad = false
    @State private var isClosing = false

    var body: some View {
        NavigationStack {
            ZStack {
                UniversityPickerArenaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    heroHeader
                    topFilterBar

                    if isLoading && universities.isEmpty {
                        loadingState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 18) {
                                ForEach(groupedUniversities, id: \.key) { section in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(section.key)
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .tracking(2.0)
                                            .foregroundStyle(Color(universityPickerHex: UniversityPickerPalette.appCyan))
                                            .padding(.horizontal, 22)

                                        VStack(spacing: 10) {
                                            ForEach(section.value) { university in
                                                universityRow(university)
                                            }
                                        }
                                    }
                                }

                                if let errorText, universities.isEmpty {
                                    errorState(errorText)
                                } else if groupedUniversities.isEmpty && !isLoading {
                                    emptyState
                                }
                            }
                            .padding(.top, 14)
                            .padding(.bottom, 44)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        closeSheet()
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .black))

                            Text("Close")
                                .font(.system(size: 13, weight: .black, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.82))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.075))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            guard !didPerformInitialLoad else { return }
            didPerformInitialLoad = true
            scheduleUniversityLoad(debounceNanoseconds: 0)
        }
        .onChange(of: selectedCountryCode) { _, _ in
            guard !isClosing else { return }
            scheduleUniversityLoad(debounceNanoseconds: 120_000_000)
        }
        .onChange(of: searchText) { _, _ in
            guard !isClosing else { return }
            scheduleUniversityLoad(debounceNanoseconds: 420_000_000)
        }
        .onDisappear {
            isClosing = true
            loadTask?.cancel()
            loadTask = nil
        }
    }

    private var groupedUniversities: [(key: String, value: [CatalogUniversity])] {
        let grouped = Dictionary(grouping: universities) { university in
            String(university.name.prefix(1)).uppercased()
        }

        return grouped
            .map { (key: $0.key, value: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.key < $1.key }
    }

    private var heroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("— UNIVERSITY SETUP —")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2.5)
                .foregroundStyle(Color(universityPickerHex: UniversityPickerPalette.appCyan))

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("Choose")
                    .font(.system(size: 35, weight: .black))
                    .foregroundStyle(.white)

                Text("university")
                    .font(.system(size: 33, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(universityPickerHex: UniversityPickerPalette.appCyan),
                                Color(universityPickerHex: UniversityPickerPalette.appPurple)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Text("Search your university and continue with the matching department and course catalog.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.56))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.top, 18)
        .padding(.bottom, 14)
    }

    private var topFilterBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                countryButton(code: "tr", title: tr("up_turkey"))
                countryButton(code: "kktc", title: "KKTC")
            }

            HStack(spacing: 11) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .black))
                    .foregroundStyle(Color(universityPickerHex: UniversityPickerPalette.appCyan))

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search university").foregroundStyle(.white.opacity(0.32))
                )
                .textInputAutocapitalization(.words)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)

                if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white.opacity(0.38))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color.white.opacity(0.070))
                    .overlay(
                        RoundedRectangle(cornerRadius: 19, style: .continuous)
                            .stroke(Color.white.opacity(0.085), lineWidth: 1)
                    )
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private func countryButton(code: String, title: String) -> some View {
        let isSelected = selectedCountryCode == code

        return Button {
            guard selectedCountryCode != code else { return }

            withAnimation(.spring(response: 0.30, dampingFraction: 0.90)) {
                selectedCountryCode = code
                selectedUniversityID = nil
                selectedUniversityName = ""
                searchText = ""
                universities = []
                errorText = nil
            }

            scheduleUniversityLoad(debounceNanoseconds: 0)
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 15, weight: .black))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15, weight: .black))
                }
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.78))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        isSelected
                        ? AnyShapeStyle(UniversityPickerPalette.appGradient)
                        : AnyShapeStyle(Color.white.opacity(0.070))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(
                                isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.085),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func universityRow(_ university: CatalogUniversity) -> some View {
        let isSelected = selectedUniversityID == university.id || selectedUniversityName == university.name

        return Button {
            isClosing = true
            loadTask?.cancel()
            loadTask = nil

            selectedUniversityName = university.name
            selectedCountryCode = university.country_code
            selectedUniversityID = university.id

            dismiss()
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(
                        isSelected
                        ? UniversityPickerPalette.appGradient
                        : LinearGradient(
                            colors: [
                                Color(universityPickerHex: UniversityPickerPalette.appBlue).opacity(0.12),
                                Color(universityPickerHex: UniversityPickerPalette.appPurple).opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .overlay(
                        Image(systemName: "building.columns.fill")
                            .font(.system(size: 20, weight: .black))
                            .foregroundStyle(
                                isSelected
                                ? .black.opacity(0.76)
                                : Color(universityPickerHex: UniversityPickerPalette.appCyan)
                            )
                    )

                VStack(alignment: .leading, spacing: 6) {
                    Text(university.name)
                        .font(.system(size: 16, weight: .black))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    HStack(spacing: 7) {
                        Text(university.country_code == "tr" ? tr("up_turkey") : "KKTC")
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(
                                university.country_code == "tr"
                                ? Color(universityPickerHex: UniversityPickerPalette.appCyan)
                                : Color(universityPickerHex: UniversityPickerPalette.gold)
                            )

                        Text("·")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(.white.opacity(0.26))

                        Text("Catalog ready")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.42))
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.system(size: isSelected ? 20 : 13, weight: .black))
                    .foregroundStyle(
                        isSelected
                        ? Color(universityPickerHex: UniversityPickerPalette.appCyan)
                        : .white.opacity(0.28)
                    )
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 23, style: .continuous)
                    .fill(
                        isSelected
                        ? LinearGradient(
                            colors: [
                                Color(universityPickerHex: UniversityPickerPalette.appBlue).opacity(0.15),
                                Color(universityPickerHex: UniversityPickerPalette.appPurple).opacity(0.11),
                                Color.white.opacity(0.045)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : UniversityPickerPalette.cardGradient
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 23, style: .continuous)
                            .stroke(
                                isSelected
                                ? Color(universityPickerHex: UniversityPickerPalette.appBlue).opacity(0.26)
                                : Color.white.opacity(0.070),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.18), radius: 14, y: 8)
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.05)

            Text("Loading universities...")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.90))

            Text("Preparing the catalog list for your selected country.")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, 30)
    }

    private func errorState(_ text: String) -> some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(universityPickerHex: UniversityPickerPalette.coral).opacity(0.13))
                .frame(width: 66, height: 66)
                .overlay(
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(Color(universityPickerHex: UniversityPickerPalette.coral))
                )

            Text("Could not load universities")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.white)

            Text(text)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.54))
                .padding(.horizontal, 24)

            Button {
                scheduleUniversityLoad(debounceNanoseconds: 0)
            } label: {
                Text("Retry")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(
                        Capsule()
                            .fill(UniversityPickerPalette.appGradient)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.070))
                .frame(width: 66, height: 66)
                .overlay(
                    Image(systemName: "building.columns")
                        .font(.system(size: 27, weight: .black))
                        .foregroundStyle(.white.opacity(0.52))
                )

            Text("No university found")
                .font(.system(size: 19, weight: .black))
                .foregroundStyle(.white)

            Text("Try a different search or switch country.")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.54))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    private func closeSheet() {
        isClosing = true
        loadTask?.cancel()
        loadTask = nil
        dismiss()
    }

    private func scheduleUniversityLoad(debounceNanoseconds: UInt64) {
        guard !isClosing else { return }

        loadTask?.cancel()

        let requestID = UUID()
        latestLoadRequestID = requestID

        loadTask = Task {
            if debounceNanoseconds > 0 {
                try? await Task.sleep(nanoseconds: debounceNanoseconds)
            }

            guard !Task.isCancelled else { return }

            await loadUniversities(requestID: requestID)
        }
    }

    @MainActor
    private func loadUniversities(requestID: UUID) async {
        guard latestLoadRequestID == requestID, !isClosing else { return }

        isLoading = true
        errorText = nil

        let country = selectedCountryCode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let result = try await StudentCatalogService.fetchUniversities(
                countryCode: country,
                query: query
            )

            guard latestLoadRequestID == requestID, !Task.isCancelled, !isClosing else { return }

            universities = result
            errorText = nil
        } catch {
            guard latestLoadRequestID == requestID, !Task.isCancelled, !isClosing else { return }

            universities = []
            errorText = error.localizedDescription
        }

        guard latestLoadRequestID == requestID, !isClosing else { return }
        isLoading = false
    }
}

// MARK: - Palette

private enum UniversityPickerPalette {
    static let backgroundTop = "#05060D"
    static let backgroundMid = "#070713"
    static let backgroundBottom = "#07040C"

    static let appBlue = "#1593FF"
    static let appBlueSoft = "#1E6BFF"
    static let appCyan = "#2DD4FF"
    static let appPurple = "#7C3AED"
    static let coral = "#FF5A44"
    static let gold = "#FBBF24"

    static var appGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(universityPickerHex: appBlueSoft),
                Color(universityPickerHex: appPurple)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var cardGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(universityPickerHex: appBlue).opacity(0.045),
                Color(universityPickerHex: appPurple).opacity(0.055),
                Color.white.opacity(0.040)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Background

private struct UniversityPickerArenaBackground: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(universityPickerHex: UniversityPickerPalette.backgroundTop),
                    Color(universityPickerHex: UniversityPickerPalette.backgroundMid),
                    Color(universityPickerHex: UniversityPickerPalette.backgroundBottom)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(universityPickerHex: UniversityPickerPalette.appBlue).opacity(0.12))
                .frame(width: 270, height: 270)
                .blur(radius: 98)
                .offset(x: 165, y: -220)

            Circle()
                .fill(Color(universityPickerHex: UniversityPickerPalette.appPurple).opacity(0.16))
                .frame(width: 330, height: 330)
                .blur(radius: 115)
                .offset(x: -180, y: 500)

            Circle()
                .fill(Color(universityPickerHex: UniversityPickerPalette.coral).opacity(0.070))
                .frame(width: 280, height: 280)
                .blur(radius: 105)
                .offset(x: 170, y: 285)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.16),
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.42)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Color Hex

private extension Color {
    init(universityPickerHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)

        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)

        let a: UInt64
        let r: UInt64
        let g: UInt64
        let b: UInt64

        switch cleaned.count {
        case 3:
            a = 255
            r = (int >> 8) * 17
            g = ((int >> 4) & 0xF) * 17
            b = (int & 0xF) * 17

        case 6:
            a = 255
            r = int >> 16
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        case 8:
            a = int >> 24
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF

        default:
            a = 255
            r = 21
            g = 147
            b = 255
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
