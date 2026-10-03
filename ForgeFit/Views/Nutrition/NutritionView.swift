import PhotosUI
import SwiftUI
import UIKit

/// Food log for a day: totals against targets, and ways to add meals.
struct NutritionView: View {
    enum StartAction {
        case none, snap
    }

    var startWith: StartAction = .none

    @Environment(AppStore.self) private var store
    @State private var day = Date()
    @State private var capture: MealCaptureRequest?
    @State private var editing: MealEntry?
    @State private var showTargets = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var libraryItem: PhotosPickerItem?
    @State private var didAutoStart = false

    private var isToday: Bool { Calendar.current.isDateInToday(day) }

    var body: some View {
        let meals = store.meals(on: day)
        let totals = NutritionTotals(meals: meals)
        let targets = store.nutritionTargets
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                dayPicker
                NutritionSummaryCard(totals: totals, targets: targets)
                if targets.isRough {
                    Label("Add your weight, height and age in Profile for more accurate targets.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                addButtons
                VStack(alignment: .leading, spacing: 10) {
                    Text(meals.isEmpty ? "No meals logged" : "Meals")
                        .font(.headline)
                    ForEach(meals) { meal in
                        Button {
                            editing = meal
                        } label: {
                            MealRow(meal: meal)
                        }
                        .buttonStyle(PressableStyle())
                        .contextMenu {
                            Button(role: .destructive) {
                                MealPhotoStore.delete(id: meal.id)
                                store.deleteMeal(id: meal.id)
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                    if meals.isEmpty {
                        Text("Snap a photo of your plate and the AI estimates calories and protein. You can edit everything before saving.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .appBackground()
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Targets") { showTargets = true }
            }
        }
        .resumeWorkoutBar()
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { image in
                showCamera = false
                if let image { capture = MealCaptureRequest(mode: .photo(image), day: day) }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showLibrary, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    capture = MealCaptureRequest(mode: .photo(image), day: day)
                }
                libraryItem = nil
            }
        }
        .sheet(item: $capture) { request in
            MealCaptureView(request: request)
                .environment(store)
        }
        .sheet(item: $editing) { meal in
            NavigationStack { MealEditor(meal: meal, estimateNote: nil, isNew: false) }
                .environment(store)
        }
        .sheet(isPresented: $showTargets) {
            NavigationStack { NutritionTargetsView() }
                .environment(store)
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            guard !didAutoStart else { return }
            didAutoStart = true
            if startWith == .snap { snap() }
        }
    }

    private var dayPicker: some View {
        HStack {
            Button {
                day = Calendar.current.date(byAdding: .day, value: -1, to: day) ?? day
            } label: {
                Image(systemName: "chevron.left").frame(width: 36, height: 36).background(Circle().fill(Theme.surfaceRaised))
            }
            .accessibilityLabel("Previous day")
            Spacer()
            Text(isToday ? "Today" : day.formatted(.dateTime.weekday(.wide).day().month()))
                .font(.headline)
            Spacer()
            Button {
                day = Calendar.current.date(byAdding: .day, value: 1, to: day) ?? day
            } label: {
                Image(systemName: "chevron.right").frame(width: 36, height: 36).background(Circle().fill(Theme.surfaceRaised))
            }
            .disabled(isToday)
            .opacity(isToday ? 0.3 : 1)
            .accessibilityLabel("Next day")
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var addButtons: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            addButton("Snap a meal", symbol: "camera.fill", highlighted: true) { snap() }
            addButton("From photos", symbol: "photo.on.rectangle") { showLibrary = true }
            addButton("Describe it", symbol: "text.bubble") { capture = MealCaptureRequest(mode: .describe, day: day) }
            addButton("Add manually", symbol: "square.and.pencil") { capture = MealCaptureRequest(mode: .manual, day: day) }
        }
    }

    private func addButton(_ title: String, symbol: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(highlighted ? Theme.ink : .white)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(highlighted ? AnyShapeStyle(Theme.sage) : AnyShapeStyle(Theme.surface)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(highlighted ? Color.clear : Theme.stroke))
        }
        .buttonStyle(PressableStyle())
    }

    private func snap() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCamera = true
        } else {
            showLibrary = true
        }
    }
}

/// Calorie ring plus protein, carb and fat bars.
struct NutritionSummaryCard: View {
    let totals: NutritionTotals
    let targets: NutritionTargets

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RingView(progress: Double(totals.calories) / Double(max(targets.calories, 1)), color: Theme.sage,
                         lineWidth: 9, size: 104)
                VStack(spacing: 0) {
                    Text("\(totals.calories)")
                        .font(.system(size: 24, weight: .semibold).monospacedDigit())
                    Text("of \(targets.calories) kcal")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                macro("Protein", value: totals.proteinG, target: targets.proteinG, color: Theme.rose)
                macro("Carbs", value: totals.carbsG, target: targets.carbsG, color: Theme.sand)
                macro("Fat", value: totals.fatG, target: targets.fatG, color: Theme.sky)
            }
        }
        .cardStyle()
        .accessibilityElement(children: .combine)
    }

    private func macro(_ name: String, value: Double, target: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name).font(.caption.weight(.medium))
                Spacer()
                Text("\(Int(value.rounded())) / \(target) g")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.textSecondary)
            }
            ProgressBar(value: value / Double(max(target, 1)), fill: color, height: 6)
        }
    }
}

struct MealRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if meal.hasPhoto, let image = MealPhotoStore.image(id: meal.id) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: meal.source == .photo ? "photo" : "fork.knife")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .frame(width: 52, height: 52)
            .background(Theme.surfaceRaised)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(meal.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("\(meal.date.formatted(date: .omitted, time: .shortened)) · \(Int(meal.proteinG)) g protein")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text("\(meal.calories)")
                .font(.system(size: 17, weight: .semibold).monospacedDigit())
            Text("kcal")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
        }
        .cardStyle(padding: 10, radius: 20)
    }
}

// MARK: - Capture

struct MealCaptureRequest: Identifiable {
    enum Mode {
        case photo(UIImage)
        case describe
        case manual
    }

    let id = UUID()
    let mode: Mode
    let day: Date
}

/// Estimates a meal with AI (from a photo or a description) and lets the user review it.
struct MealCaptureView: View {
    let request: MealCaptureRequest

    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var description = ""
    @State private var isEstimating = false
    @State private var errorText: String?
    @State private var draft: MealEntry?
    @State private var note: String?

    var body: some View {
        NavigationStack {
            Group {
                if let draft {
                    MealEditor(meal: draft, estimateNote: note, isNew: true, photo: photo) { dismiss() }
                } else {
                    input
                }
            }
            .toolbar {
                if draft == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .task {
            switch request.mode {
            case .photo:
                if store.hasAPIKey { await estimate() } else { startManual(note: "Add a Gemini API key in Profile → AI Coach to estimate meals automatically.") }
            case .manual:
                startManual(note: nil)
            case .describe:
                break
            }
        }
    }

    private var photo: UIImage? {
        if case .photo(let image) = request.mode { return image }
        return nil
    }

    private var input: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 260)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What did you eat?")
                            .font(.system(size: 30, weight: .light))
                        Text("E.g. \"chicken burrito bowl with rice, beans and guacamole\" or \"2 eggs on toast and a latte\".")
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)
                    }
                    TextField("Describe your meal", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface))
                        .accessibilityIdentifier("mealDescription")
                }

                if isEstimating {
                    HStack(spacing: 12) {
                        CoachOrb(size: 34, animating: true)
                        Text("Estimating calories and protein…")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                if let errorText {
                    Label(errorText, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(Theme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                    Button("Enter it manually") { startManual(note: nil) }
                        .buttonStyle(SecondaryButtonStyle())
                }
                if photo == nil {
                    Button {
                        Task { await estimate() }
                    } label: {
                        Label("Estimate with AI", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(description.trimmingCharacters(in: .whitespaces).count < 3 || isEstimating || !store.hasAPIKey)
                    .opacity(description.trimmingCharacters(in: .whitespaces).count < 3 || !store.hasAPIKey ? 0.5 : 1)
                    if !store.hasAPIKey {
                        Text("Add a Gemini API key in Profile → AI Coach to use AI estimates.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else if !isEstimating && errorText != nil {
                    Button("Try again") { Task { await estimate() } }
                        .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
        .navigationTitle(photo == nil ? "Describe a meal" : "Meal photo")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var mealDate: Date {
        if Calendar.current.isDateInToday(request.day) { return Date() }
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: request.day) ?? request.day
    }

    private func startManual(note: String?) {
        self.note = note
        draft = MealEntry(date: mealDate, name: "", calories: 0, proteinG: 0, source: .manual, hasPhoto: photo != nil)
    }

    private func estimate() async {
        isEstimating = true
        errorText = nil
        do {
            let jpeg = photo.flatMap { $0.resized(maxDimension: 1024).jpegData(compressionQuality: 0.7) }
            let result = try await MealAnalyzer.analyze(photoJPEG: jpeg, description: description, model: store.aiModel)
            if !result.isFood {
                errorText = result.note?.isEmpty == false ? result.note : "That doesn't look like food. Try another photo."
            } else {
                note = [result.confidence.map { "Confidence: \($0)." }, result.note].compactMap { $0 }.joined(separator: " ")
                draft = MealAnalyzer.entry(from: result, date: mealDate, source: photo == nil ? .description : .photo,
                                           hasPhoto: photo != nil)
                Haptics.success()
            }
        } catch {
            errorText = error.localizedDescription
            Haptics.warning()
        }
        isEstimating = false
    }
}

/// Review or edit a meal's name and numbers.
struct MealEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var meal: MealEntry
    let estimateNote: String?
    let isNew: Bool
    var photo: UIImage? = nil
    var onSaved: (() -> Void)? = nil

    init(meal: MealEntry, estimateNote: String?, isNew: Bool, photo: UIImage? = nil, onSaved: (() -> Void)? = nil) {
        _meal = State(initialValue: meal)
        self.estimateNote = estimateNote
        self.isNew = isNew
        self.photo = photo
        self.onSaved = onSaved
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                }
                TextField("Meal name", text: $meal.name)
                    .font(.system(size: 24, weight: .semibold))
                    .accessibilityIdentifier("mealName")
                if let estimateNote, !estimateNote.isEmpty {
                    Label(estimateNote, systemImage: "sparkles")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(spacing: 10) {
                    numberRow("Calories", unit: "kcal", value: Binding(get: { Double(meal.calories) },
                                                                      set: { meal.calories = max(0, Int($0.rounded())) }))
                    numberRow("Protein", unit: "g", value: $meal.proteinG)
                    numberRow("Carbs", unit: "g", value: $meal.carbsG)
                    numberRow("Fat", unit: "g", value: $meal.fatG)
                }
                .cardStyle()
                if !meal.items.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What the AI saw").font(.headline)
                        ForEach(meal.items, id: \.self) { item in
                            Label(item, systemImage: "circle.fill")
                                .font(.footnote)
                                .foregroundStyle(Theme.textSecondary)
                                .labelStyle(CompactLabelStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }
                DatePicker("Time", selection: $meal.date, displayedComponents: [.date, .hourAndMinute])
                    .cardStyle(padding: 12, radius: 18)
                Button {
                    save()
                } label: {
                    Label(isNew ? "Save meal" : "Save changes", systemImage: "checkmark")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(meal.name.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(meal.name.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                if !isNew {
                    Button(role: .destructive) {
                        MealPhotoStore.delete(id: meal.id)
                        store.deleteMeal(id: meal.id)
                        dismiss()
                    } label: {
                        Text("Delete meal").foregroundStyle(Theme.danger)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
        .appBackground()
        .navigationTitle(isNew ? "Review meal" : "Edit meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
        }
    }

    private func numberRow(_ title: String, unit: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            NumberField(placeholder: "0", value: value, decimals: false)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.surfaceRaised))
            Text(unit)
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 32, alignment: .leading)
        }
    }

    private func save() {
        meal.name = meal.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if isNew {
            if let photo {
                MealPhotoStore.save(photo, id: meal.id)
                meal.hasPhoto = true
            }
            store.addMeal(meal)
        } else if let index = store.meals.firstIndex(where: { $0.id == meal.id }) {
            store.meals[index] = meal
            store.meals.sort { $0.date < $1.date }
        }
        Haptics.success()
        if let onSaved { onSaved() } else { dismiss() }
    }
}

/// Custom calorie and protein targets, or automatic ones from the profile.
struct NutritionTargetsView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store
        let automatic = NutritionMath.targets(for: {
            var p = store.profile
            p.calorieTarget = nil
            p.proteinTarget = nil
            return p
        }())
        List {
            Section {
                Toggle("Set my own targets", isOn: Binding(
                    get: { store.profile.calorieTarget != nil || store.profile.proteinTarget != nil },
                    set: { custom in
                        store.profile.calorieTarget = custom ? automatic.calories : nil
                        store.profile.proteinTarget = custom ? automatic.proteinG : nil
                    }))
                    .tint(Theme.volt)
                if store.profile.calorieTarget != nil || store.profile.proteinTarget != nil {
                    HStack {
                        Text("Calories")
                        Spacer()
                        IntField(placeholder: "\(automatic.calories)", value: Binding(
                            get: { store.profile.calorieTarget ?? automatic.calories },
                            set: { store.profile.calorieTarget = $0 }))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("kcal").foregroundStyle(Theme.textSecondary)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        IntField(placeholder: "\(automatic.proteinG)", value: Binding(
                            get: { store.profile.proteinTarget ?? automatic.proteinG },
                            set: { store.profile.proteinTarget = $0 }))
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                        Text("g").foregroundStyle(Theme.textSecondary)
                    }
                }
            } footer: {
                Text("Automatic: \(automatic.calories) kcal and \(automatic.proteinG) g protein a day, from your weight, height, age, training days and goal (\(store.profile.goal.title)). These are estimates; adjust them to how your body responds.")
            }
            .listRowBackground(Theme.surface)
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle("Daily targets")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Camera and photos

struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onFinish: onFinish) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onFinish: (UIImage?) -> Void

        init(onFinish: @escaping (UIImage?) -> Void) { self.onFinish = onFinish }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            onFinish(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onFinish(nil)
        }
    }
}

/// Small meal thumbnails kept on this device only (not synced).
enum MealPhotoStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MealPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func url(_ id: UUID) -> URL { directory.appendingPathComponent("\(id.uuidString).jpg") }

    static func save(_ image: UIImage, id: UUID) {
        guard let data = image.resized(maxDimension: 360).jpegData(compressionQuality: 0.75) else { return }
        try? data.write(to: url(id), options: .atomic)
    }

    static func image(id: UUID) -> UIImage? {
        UIImage(contentsOfFile: url(id).path)
    }

    static func delete(id: UUID) {
        try? FileManager.default.removeItem(at: url(id))
    }
}

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
