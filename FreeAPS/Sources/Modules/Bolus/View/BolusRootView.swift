import SwiftUI
import Swinject

extension Bolus {
    struct RootView: BaseView {
        let resolver: Resolver
        let waitForSuggestion: Bool
        let fetch: Bool
        @StateObject var state: StateModel

        @State private var keepForNextWiew: Bool = false

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        private var mealFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private func format(_ number: NSDecimalNumber?) -> String {
            guard let number = number else { return "" }
            return mealFormatter.string(from: number) ?? ""
        }

        @FetchRequest(
            entity: Meals.entity(),
            sortDescriptors: [NSSortDescriptor(key: "createdAt", ascending: false)]
        ) var meal: FetchedResults<Meals>

        init(
            resolver: Resolver,
            waitForSuggestion: Bool,
            fetch: Bool
        ) {
            self.resolver = resolver
            self.waitForSuggestion = waitForSuggestion
            self.fetch = fetch
            _state = StateObject(wrappedValue: StateModel(resolver: resolver))
        }

        var body: some View {
            if state.useCalc {
                if state.eventualBG {
                    DefaultBolusCalcRootView(
                        resolver: resolver,
                        waitForSuggestion: waitForSuggestion,
                        fetch: fetch,
                        meal: meal,
                        mealEntries: mealEntries
                    )
                    .onDisappear {
                        if state.eventualBG {
                            state.notActive()
                        }
                    }
                    .environmentObject(state)
                } else {
                    AlternativeBolusCalcRootView(
                        resolver: resolver,
                        waitForSuggestion: waitForSuggestion,
                        fetch: fetch,
                        meal: meal,
                        mealEntries: mealEntries
                    )
                    .onDisappear {
                        if !state.eventualBG {
                            state.notActive()
                        }
                    }
                    .environmentObject(state)
                }
            } else {
                cleanBolusView
            }
        }

        private var cleanBolusView: some View {
            Form {
                Section(header: Text("Recommendation")) {
                    if state.waitForSuggestion {
                        HStack {
                            Text("Wait please").foregroundColor(.secondary)
                            Spacer()
                        }
                    } else {
                        HStack {
                            Text("Insulin required").foregroundColor(.secondary)
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinRequired as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.secondary)
                        }.contentShape(Rectangle())
                            .onTapGesture {
                                state.amount = state.insulinRequired
                            }
                        HStack {
                            Text("Insulin recommended")
                            Spacer()
                            Text(
                                formatter
                                    .string(from: state.insulinRecommended as NSNumber)! +
                                    NSLocalizedString(" U", comment: "Insulin unit")
                            ).foregroundColor(.secondary)
                        }.contentShape(Rectangle())
                            .onTapGesture {
                                state.amount = state.insulinRecommended
                            }
                    }
                }

                if !state.waitForSuggestion {
                    Section(header: Text("Bolus")) {
                        HStack {
                            Text("Amount")
                            Spacer()
                            DecimalTextField(
                                "0",
                                value: $state.amount,
                                formatter: formatter,
                                autofocus: true,
                                cleanInput: true
                            )
                            Text("U").foregroundColor(.secondary)
                        }
                    }

                    Section {
                        Button { state.add() }
                        label: { Text("Enact bolus") }
                            .disabled(state.amount <= 0)
                    }

                    Section {
                        if waitForSuggestion {
                            Button { state.showModal(for: nil) }
                            label: { Text("Continue without bolus") }
                        }
                    }
                }
            }
            .navigationTitle("Enact Bolus")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
        }

        private var hasFatOrProtein: Bool {
            guard let meal = meal.first else { return false }
            return ((meal.fat ?? 0) != 0) || ((meal.protein ?? 0) != 0)
        }

        private var mealEntries: some View {
            VStack {
                if let carbs = meal.first?.carbs, carbs != 0 {
                    HStack {
                        Text("Carbs")
                        Spacer()
                        Text(format(carbs))
                        Text("g")
                    }.foregroundColor(.secondary)
                }
                if let fat = meal.first?.fat, fat != 0 {
                    HStack {
                        Text("Fat")
                        Spacer()
                        Text(format(fat))
                        Text("g")
                    }.foregroundColor(.secondary)
                }
                if let protein = meal.first?.protein, protein != 0 {
                    HStack {
                        Text("Protein")
                        Spacer()
                        Text(format(protein))
                        Text("g")
                    }.foregroundColor(.secondary)
                }
                if let note = meal.first?.note, note != "" {
                    HStack {
                        Text("Note")
                        Spacer()
                        Text(note)
                    }.foregroundColor(.secondary)
                }
            }
        }
    }
}

// fix iOS 15 bug
struct ActivityIndicator: UIViewRepresentable {
    @Binding var isAnimating: Bool
    let style: UIActivityIndicatorView.Style

    func makeUIView(context _: UIViewRepresentableContext<ActivityIndicator>) -> UIActivityIndicatorView {
        UIActivityIndicatorView(style: style)
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context _: UIViewRepresentableContext<ActivityIndicator>) {
        isAnimating ? uiView.startAnimating() : uiView.stopAnimating()
    }
}
