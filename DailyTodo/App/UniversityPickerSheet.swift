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

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 0) {
                    topFilterBar

                    if isLoading && universities.isEmpty {
                        loadingState
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(alignment: .leading, spacing: 18) {
                                ForEach(groupedUniversities, id: \.key) { section in
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(section.key)
                                            .font(.system(size: 14, weight: .heavy))
                                            .foregroundStyle(.white.opacity(0.55))
                                            .padding(.horizontal, 20)

                                        VStack(spacing: 10) {
                                            ForEach(section.value) { university in
                                                universityRow(university)
                                            }
                                        }
                                    }
                                }

                                if let errorText, universities.isEmpty {
                                    errorState(errorText)
                                } else if groupedUniversities.isEmpty {
                                    emptyState
                                }
                            }
                            .padding(.top, 18)
                            .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationTitle("University")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await loadUniversities()
        }
        .onChange(of: selectedCountryCode) { _, _ in
            Task { await loadUniversities() }
        }
        .onChange(of: searchText) { _, _ in
            Task { await loadUniversities() }
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

    private var topFilterBar: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                countryButton(code: "tr", title: "Türkiye")
                countryButton(code: "kktc", title: "KKTC")
            }

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.white.opacity(0.45))

                TextField(
                    "",
                    text: $searchText,
                    prompt: Text("Search university").foregroundStyle(.white.opacity(0.35))
                )
                .textInputAutocapitalization(.words)
                .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.08))
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .background(.ultraThinMaterial.opacity(0.3))
    }

    private func countryButton(code: String, title: String) -> some View {
        let isSelected = selectedCountryCode == code

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                selectedCountryCode = code
                searchText = ""
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(isSelected ? .blue.opacity(0.22) : .white.opacity(0.07))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(isSelected ? .blue.opacity(0.7) : .white.opacity(0.08), lineWidth: 1.1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func universityRow(_ university: CatalogUniversity) -> some View {
        let isSelected = selectedUniversityName == university.name

        return Button {
            selectedUniversityID = university.id
            selectedUniversityName = university.name
            selectedCountryCode = university.country_code
            dismiss()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(university.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)

                    Text(university.country_code == "tr" ? "Türkiye" : "KKTC")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isSelected ? .blue.opacity(0.16) : .white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(isSelected ? .blue.opacity(0.65) : .white.opacity(0.06), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
        .buttonStyle(.plain)
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .tint(.white)

            Text("Loading universities...")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private func errorState(_ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.orange)

            Text("Could not load universities")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.55))
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.columns")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))

            Text("No university found")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)

            Text("Try a different search.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 44)
    }

    private func loadUniversities() async {
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            universities = try await StudentCatalogService.fetchUniversities(
                countryCode: selectedCountryCode,
                query: searchText
            )
        } catch {
            universities = []
            errorText = error.localizedDescription
        }
    }
}
