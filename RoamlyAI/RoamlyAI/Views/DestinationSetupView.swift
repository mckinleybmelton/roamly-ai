import SwiftUI

struct DestinationSetupView: View {
    @ObservedObject var factsStore: GeoFactsStore
    @Environment(\.dismiss) private var dismiss

    @State private var cityQuery = ""
    @State private var candidates: [GeocodedCity] = []
    @State private var isSearching = false
    @State private var searchError: String?
    @State private var showingCandidatePicker = false

    var body: some View {
        NavigationView {
            List {
                Section("Add a destination") {
                    HStack {
                        TextField("City name (e.g. Lisbon)", text: $cityQuery)
                            .textInputAutocapitalization(.words)
                            .disableAutocorrection(true)
                            .onSubmit { search() }

                        if isSearching || factsStore.isDownloading {
                            ProgressView()
                        } else {
                            Button("Search") {
                                search()
                            }
                            .disabled(cityQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }

                    if let searchError {
                        Text(searchError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if let downloadError = factsStore.downloadError {
                        Text(downloadError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }

                if !factsStore.downloadedCities.isEmpty {
                    Section("Downloaded cities") {
                        ForEach(factsStore.downloadedCities, id: \.self) { city in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(city)
                                    .font(.body)
                                if let info = factsStore.recordInfo(for: city) {
                                    Text("\(info.factCount) facts cached")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            // Resolve names against the stable snapshot before any deletion —
                            // deleteCity mutates downloadedCities synchronously, so indices would
                            // shift mid-loop if resolved one at a time instead.
                            let citiesToDelete = indexSet.map { factsStore.downloadedCities[$0] }
                            for city in citiesToDelete {
                                factsStore.deleteCity(city)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Destinations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Multiple matches found",
                isPresented: $showingCandidatePicker,
                titleVisibility: .visible
            ) {
                ForEach(candidates) { candidate in
                    Button(candidate.displayName) {
                        download(candidate)
                    }
                }
                Button("Cancel", role: .cancel) {
                    candidates = []
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    private func search() {
        let query = cityQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        searchError = nil
        isSearching = true

        Task {
            defer { isSearching = false }
            do {
                let results = try await factsStore.geocodeCandidates(for: query)
                if results.count == 1, let only = results.first {
                    download(only)
                } else if results.count > 1 {
                    candidates = results
                    showingCandidatePicker = true
                } else {
                    searchError = "Couldn't find that city. Try a more specific name."
                }
            } catch {
                searchError = error.localizedDescription
            }
        }
    }

    private func download(_ city: GeocodedCity) {
        Task {
            do {
                try await factsStore.downloadCity(city)
                cityQuery = ""
            } catch {
                // factsStore.downloadError is already set by downloadCity for display above.
            }
        }
    }
}

#Preview {
    DestinationSetupView(factsStore: GeoFactsStore())
}
