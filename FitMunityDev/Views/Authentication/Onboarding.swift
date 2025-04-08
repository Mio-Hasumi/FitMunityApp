import SwiftUI
import UIKit

// MARK: - Core Models
struct AppTheme {
    static let primaryColor = Color(hex: "153E3D")
    static let accentColor = Color(hex: "FFD056")
    static let secondaryColor = Color(hex: "4A6866")
    static let backgroundColor = Color(hex: "FFF8E1")
    static let cardHighlightColor = Color(hex: "FFF0C8")
}

// MARK: - Data Models
enum Goal: String, CaseIterable, Identifiable {
    case loseWeight = "Lose weight"
    case gainWeight = "Gain weight"
    case stayHealthy = "Stay healthy"
    
    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .loseWeight: return "leaf.fill"
        case .gainWeight: return "dumbbell.fill"
        case .stayHealthy: return "heart.fill"
        }
    }
}

enum Gender: String, CaseIterable, Identifiable {
    case male = "Male"
    case female = "Female"
    
    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .male: return "person.fill"
        case .female: return "person.dress.fill"
        }
    }
}

enum MeasurementUnit: Identifiable {
    case weight(WeightUnit)
    case height(HeightUnit)
    
    var id: String {
        switch self {
        case .weight(let unit): return unit.rawValue
        case .height(let unit): return unit.rawValue
        }
    }
    
    enum WeightUnit: String, CaseIterable {
        case kg, lb
    }
    
    enum HeightUnit: String, CaseIterable {
        case cm, ft
    }
}

// MARK: - User Data Model
class UserData: ObservableObject {
    static let shared = UserData()
    
    // UserDefaults prefix for keys - will be combined with userId
    private let keyPrefix = "user_"
    private let defaultsKeyPrefix = "com.fitmunity.user."
    
    // Properties for the current user
    @Published var userId: String?
    @Published var goal: Goal?
    @Published var gender: Gender?
    @Published var age: Int = 23
    @Published var birthDate: Date = Date()
    @Published var height: Double = 175
    @Published var heightUnit: MeasurementUnit.HeightUnit = .cm
    @Published var currentWeight: Double = 60
    @Published var targetWeight: Double = 72
    @Published var weightUnit: MeasurementUnit.WeightUnit = .kg
    @Published var name: String = "User"
    @Published var avatar: String = "person.circle.fill"
    @Published var hasCompletedOnboarding: Bool = false
    
    // Authentication reference
    private var authManager: AuthManager?
    
    // Private initializer
    private init() {}
    
    // Get UserDefaults key for a specific user and property
    private func getKey(for property: String, userId: String) -> String {
        return "\(defaultsKeyPrefix)\(userId).\(property)"
    }
    
    // Set the auth manager and initialize user data
    func setAuthManager(_ manager: AuthManager) {
        self.authManager = manager
        
        // Reset user data when auth manager changes
        resetToDefaults()
        
        // If logged in, set the user ID and load data
        if manager.authState == .signedIn, let userId = manager.currentUser?.id {
            self.userId = userId
            loadUserData(userId: userId)
            
            // Fetch profile from Supabase
            Task {
                await fetchProfileFromSupabase()
            }
        }
        
        // Add observer for auth state changes
        NotificationCenter.default.addObserver(
            forName: .authStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let userInfo = notification.userInfo,
                  let authState = userInfo["authState"] as? AuthState else {
                return
            }
            
            DispatchQueue.main.async {
                switch authState {
                case .signedIn:
                    if let userId = self.authManager?.currentUser?.id {
                        self.userId = userId
                        self.loadUserData(userId: userId)
                        
                        // Fetch profile from Supabase
                        Task {
                            await self.fetchProfileFromSupabase()
                        }
                    }
                case .signedOut:
                    // Reset data when signed out
                    self.userId = nil
                    self.resetToDefaults()
                case .loading:
                    break
                }
            }
        }
    }
    
    // Reset to default values
    private func resetToDefaults() {
        goal = nil
        gender = nil
        age = 23
        birthDate = Date()
        height = 175
        heightUnit = .cm
        currentWeight = 60
        targetWeight = 72
        weightUnit = .kg
        name = "User"
        avatar = "person.circle.fill"
        hasCompletedOnboarding = false
    }
    
    // Save data to UserDefaults for the current user
    func saveUserData() {
        guard let userId = userId else {
            print("❌ Cannot save user data: No user ID available")
            return
        }
        
        let defaults = UserDefaults.standard
        
        // Save enums as raw values if they're not nil
        if let goal = goal {
            defaults.set(goal.rawValue, forKey: getKey(for: "goal", userId: userId))
        }
        
        if let gender = gender {
            defaults.set(gender.rawValue, forKey: getKey(for: "gender", userId: userId))
        }
        
        defaults.set(age, forKey: getKey(for: "age", userId: userId))
        defaults.set(birthDate, forKey: getKey(for: "birthDate", userId: userId))
        defaults.set(height, forKey: getKey(for: "height", userId: userId))
        defaults.set(heightUnit.rawValue, forKey: getKey(for: "heightUnit", userId: userId))
        defaults.set(currentWeight, forKey: getKey(for: "currentWeight", userId: userId))
        defaults.set(targetWeight, forKey: getKey(for: "targetWeight", userId: userId))
        defaults.set(weightUnit.rawValue, forKey: getKey(for: "weightUnit", userId: userId))
        defaults.set(name, forKey: getKey(for: "name", userId: userId))
        defaults.set(avatar, forKey: getKey(for: "avatar", userId: userId))
        defaults.set(true, forKey: getKey(for: "hasCompletedOnboarding", userId: userId))
        hasCompletedOnboarding = true
        
        // Also save to Supabase if authenticated
        if let authManager = authManager, authManager.authState == .signedIn {
            Task {
                await saveProfileToSupabase(userId: userId)
            }
        }
    }
    
    // Save profile to Supabase
    @MainActor
    func saveProfileToSupabase(userId: String) async {
        do {
            // Create profile DTO
            let profileDTO = self.toProfileDTO(userId: userId)
            
            // Check if profile exists
            let existingProfiles = try await SupabaseConfig.shared.database
                .from("user_profiles")
                .select("*")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .data
            
            if let profiles = try? JSONDecoder().decode([UserProfileDTO].self, from: existingProfiles), !profiles.isEmpty {
                // Update existing profile
                try await SupabaseConfig.shared.database
                    .from("user_profiles")
                    .update(profileDTO)
                    .eq("user_id", value: userId)
                    .execute()
                print("✅ Profile updated in Supabase for user: \(userId)")
            } else {
                // Insert new profile
                try await SupabaseConfig.shared.database
                    .from("user_profiles")
                    .insert(profileDTO)
                    .execute()
                print("✅ Profile created in Supabase for user: \(userId)")
            }
        } catch {
            print("❌ Failed to save profile to Supabase: \(error.localizedDescription)")
        }
    }
    
    // Fetch profile data from Supabase
    @MainActor
    func fetchProfileFromSupabase() async {
        guard let authManager = authManager, 
              authManager.authState == .signedIn, 
              let userId = authManager.currentUser?.id else {
            print("❌ Cannot fetch profile: User not authenticated")
            return
        }
        
        do {
            print("🔍 Fetching profile for user: \(userId)")
            let response = try await SupabaseConfig.shared.database
                .from("user_profiles")
                .select("*")
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .data
            
            if let profiles = try? JSONDecoder().decode([UserProfileDTO].self, from: response), let profile = profiles.first {
                // Update local data with fetched profile
                print("✅ Profile found in Supabase for user: \(userId)")
                profile.updateUserData(self)
                print("🔄 Updated local user data with profile from Supabase")
            } else {
                print("ℹ️ No profile found for user: \(userId)")
                // Only create a profile if onboarding has been completed
                if hasCompletedOnboarding {
                    print("🔄 Creating new profile in Supabase")
                    await saveProfileToSupabase(userId: userId)
                }
            }
        } catch {
            print("❌ Failed to fetch profile from Supabase: \(error.localizedDescription)")
        }
    }
    
    // Load data from UserDefaults for a specific user
    private func loadUserData(userId: String) {
        print("🔄 Loading user data for user: \(userId)")
        let defaults = UserDefaults.standard
        
        // Load goal if available
        if let goalRawValue = defaults.string(forKey: getKey(for: "goal", userId: userId)),
           let loadedGoal = Goal(rawValue: goalRawValue) {
            goal = loadedGoal
        }
        
        // Load gender if available
        if let genderRawValue = defaults.string(forKey: getKey(for: "gender", userId: userId)),
           let loadedGender = Gender(rawValue: genderRawValue) {
            gender = loadedGender
        }
        
        // Load other values with defaults if not found
        age = defaults.integer(forKey: getKey(for: "age", userId: userId))
        if age == 0 { age = 23 } // Default if not set
        
        if let savedDate = defaults.object(forKey: getKey(for: "birthDate", userId: userId)) as? Date {
            birthDate = savedDate
        }
        
        height = defaults.double(forKey: getKey(for: "height", userId: userId))
        if height == 0 { height = 175 } // Default if not set
        
        if let heightUnitRawValue = defaults.string(forKey: getKey(for: "heightUnit", userId: userId)),
           let loadedHeightUnit = MeasurementUnit.HeightUnit(rawValue: heightUnitRawValue) {
            heightUnit = loadedHeightUnit
        }
        
        currentWeight = defaults.double(forKey: getKey(for: "currentWeight", userId: userId))
        if currentWeight == 0 { currentWeight = 60 } // Default if not set
        
        targetWeight = defaults.double(forKey: getKey(for: "targetWeight", userId: userId))
        if targetWeight == 0 { targetWeight = 72 } // Default if not set
        
        if let weightUnitRawValue = defaults.string(forKey: getKey(for: "weightUnit", userId: userId)),
           let loadedWeightUnit = MeasurementUnit.WeightUnit(rawValue: weightUnitRawValue) {
            weightUnit = loadedWeightUnit
        }
        
        if let savedName = defaults.string(forKey: getKey(for: "name", userId: userId)) {
            name = savedName
        }
        
        if let savedAvatar = defaults.string(forKey: getKey(for: "avatar", userId: userId)) {
            avatar = savedAvatar
        }
        
        // Load onboarding completion status
        hasCompletedOnboarding = defaults.bool(forKey: getKey(for: "hasCompletedOnboarding", userId: userId))
        
        print("✅ User data loaded for user: \(userId), onboarding completed: \(hasCompletedOnboarding)")
    }
    
    func toggleHeightUnit() {
        if heightUnit == .cm {
            // Convert cm to inches (not feet)
            let newHeight = height / 2.54
            heightUnit = .ft
            height = newHeight
        } else {
            // Convert inches to cm
            let newHeight = height * 2.54
            heightUnit = .cm
            height = newHeight
        }
    }

    func toggleWeightUnit() {
        if weightUnit == .kg {
            weightUnit = .lb
            currentWeight = currentWeight * 2.20462 // Convert kg to lb
            targetWeight = targetWeight * 2.20462
        } else {
            weightUnit = .kg
            currentWeight = currentWeight / 2.20462 // Convert lb to kg
            targetWeight = targetWeight / 2.20462
        }
    }
    
    func getWeightUnitString() -> String {
        weightUnit.rawValue
    }
}

// MARK: - Reusable UI Components
struct UnitToggleButton: View {
    let isSelected: Bool
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(width: 60, height: 45)
                .background(isSelected ? AppTheme.primaryColor : Color.white)
                .foregroundColor(isSelected ? .white : AppTheme.primaryColor)
                .cornerRadius(isSelected ? 20 : 0)
        }
    }
}

struct UnitToggle: View {
    @Binding var selectedUnit: String
    let leftOption: String
    let rightOption: String
    let onSelect: (String) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            UnitToggleButton(
                isSelected: selectedUnit == leftOption,
                title: leftOption,
                action: { onSelect(leftOption) }
            )
            
            UnitToggleButton(
                isSelected: selectedUnit == rightOption,
                title: rightOption,
                action: { onSelect(rightOption) }
            )
        }
        .background(Color.white)
        .cornerRadius(20)
    }
}

struct NavigationButton: View {
    let isPrimary: Bool
    let action: () -> Void
    let icon: String
    let isDisabled: Bool
    
    init(isPrimary: Bool = true, icon: String = "chevron.right", isDisabled: Bool = false, action: @escaping () -> Void) {
        self.isPrimary = isPrimary
        self.icon = icon
        self.isDisabled = isDisabled
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isPrimary ?
                          (isDisabled ? Color.gray : AppTheme.primaryColor) :
                          Color.white)
                    .frame(width: isPrimary ? 70 : 50, height: isPrimary ? 70 : 50)
                    .shadow(color: Color.black.opacity(isPrimary ? 0.2 : 0.1),
                            radius: 5, x: 0, y: isPrimary ? 3 : 2)
                
                if isPrimary {
                    Circle()
                        .strokeBorder(isDisabled ? Color.gray.opacity(0.5) : AppTheme.accentColor, lineWidth: 3)
                        .frame(width: 80, height: 80)
                }
                
                Image(systemName: icon)
                    .foregroundColor(isPrimary ? .white : (isDisabled ? Color.gray : AppTheme.primaryColor))
                    .font(.system(size: isPrimary ? 24 : 20, weight: .bold))
            }
        }
        .disabled(isDisabled)
    }
}

struct OnboardingTitle: View {
    let regularText: String
    let highlightedText: String
    
    var body: some View {
        HStack(spacing: 0) {
            Text(regularText)
                .foregroundColor(AppTheme.primaryColor)
            Text(highlightedText)
                .foregroundColor(AppTheme.accentColor)
        }
        .font(.system(size: 28, weight: .bold))
        .padding(.bottom, 5)
    }
}

struct PageIndicator: View {
    let current: Int
    let total: Int
    
    var body: some View {
        Text("\(current) / \(total)")
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(AppTheme.primaryColor)
            .padding(.bottom, 15)
    }
}

struct InfoText: View {
    let text: String
    
    var body: some View {
            Text(text)
                .font(.system(size: 16))
                .foregroundColor(AppTheme.secondaryColor)
                .multilineTextAlignment(.center)
                .padding(.bottom, 20)
                .fixedSize(horizontal: false, vertical: true)
        }
}

struct CustomSlider: View {
    let minValue: Double
    let maxValue: Double
    let trackWidth: CGFloat
    let value: Double
    let onUpdate: (Double) -> Void
    let unit: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.3))
                .frame(width: trackWidth, height: 10)
            
            // Progress
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.accentColor)
                .frame(width: getProgressWidth(), height: 10)
            
            // Thumb
            Circle()
                .fill(AppTheme.primaryColor)
                .frame(width: 30, height: 30)
                .offset(x: getThumbOffset() - 15)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            updateValue(with: gesture.location.x)
                        }
                )
        }
    }
    
    private func getThumbOffset() -> CGFloat {
        let valueRange = maxValue - minValue
        let percentage = (value - minValue) / valueRange
        return max(0, min(trackWidth, CGFloat(percentage) * trackWidth))
    }
    
    private func getProgressWidth() -> CGFloat {
        return getThumbOffset()
    }
    
    private func updateValue(with xPosition: CGFloat) {
        // Constrain within track bounds
        let clampedX = max(0, min(trackWidth, xPosition))
        
        // Calculate value from position
        let percentage = clampedX / trackWidth
        let newValue = minValue + (maxValue - minValue) * Double(percentage)
        
        // Update with appropriate rounding
        onUpdate(Double(Int(newValue)))
    }
}


struct SelectionCard<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    let content: Content
    
    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }
    
    var body: some View {
        Button(action: action) {
            content
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(isSelected ? AppTheme.cardHighlightColor : Color.white)
                .cornerRadius(20)
        }
    }
}

struct MeasurementSelector: View {
    let value: Double
    let onChange: (Double) -> Void
    let range: ClosedRange<Double>
    let indicator: String
    let options: [Double]
    
    var body: some View {
        ZStack {
            Image(systemName: "arrowtriangle.down.fill")
                .foregroundColor(AppTheme.accentColor)
                .offset(y: -40)
            
            HStack(spacing: 15) {
                ForEach(options, id: \.self) { option in
                    Button(action: { onChange(option) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(value == option ? AppTheme.cardHighlightColor : Color.white)
                                .frame(width: 100, height: 120)
                            
                            Text("\(Int(option))")
                                .font(.system(size: value == option ? 48 : 36, weight: .bold))
                                .foregroundColor(value == option ? AppTheme.primaryColor : Color.gray)
                        }
                    }
                }
            }
            
            VStack(spacing: 20) {
                Spacer()
                
                ZStack(alignment: .leading) {
                    HStack(spacing: 4) {
                        ForEach(0..<30, id: \.self) { _ in
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 1, height: 12)
                        }
                    }
                    
                    Rectangle()
                        .fill(AppTheme.accentColor)
                        .frame(width: 2, height: 30)
                        .offset(x: getOffsetForValue(value, range: range))
                }
                
                HStack {
                    Text("\(Int(range.lowerBound))")
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(Int(range.upperBound))")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 20)
    }
    
    private func getOffsetForValue(_ value: Double, range: ClosedRange<Double>) -> CGFloat {
        let percentage = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return CGFloat(percentage * 300) // Width of the track
    }
}

// MARK: - View Protocol for Screens
protocol OnboardingScreenView: View {
    var userData: UserData { get }
    var onNext: () -> Void { get }
    var onBack: () -> Void { get }
}

// MARK: - Screen Layout Components
struct OnboardingScreenLayout<Content: View>: View {
    let current: Int
    let total: Int
    let title: String
    let highlight: String
    let info: String
    let showBackButton: Bool
    let showNextButton: Bool
    let isNextButtonDisabled: Bool
    let onNext: () -> Void
    let onBack: () -> Void
    let content: Content
    
    init(
        current: Int,
        total: Int,
        title: String,
        highlight: String,
        info: String,
        showBackButton: Bool = true,
        showNextButton: Bool = true,
        isNextButtonDisabled: Bool = false,
        onNext: @escaping () -> Void,
        onBack: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.current = current
        self.total = total
        self.title = title
        self.highlight = highlight
        self.info = info
        self.showBackButton = showBackButton
        self.showNextButton = showNextButton
        self.isNextButtonDisabled = isNextButtonDisabled
        self.onNext = onNext
        self.onBack = onBack
        self.content = content()
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main content
                VStack(spacing: 20) {
                    // Spacer to push content down and make room for back button
                    Spacer()
                        .frame(height: 80)
                    
                    // Page indicator
                    PageIndicator(current: current, total: total)
                    
                    // Title
                    OnboardingTitle(regularText: title, highlightedText: highlight)
                    
                    // Information text
                    InfoText(text: info)
                    
                    // Content area
                    content
                    
                    Spacer()
                    
                    // Bottom navigation button - conditionally shown
                    if showNextButton {
                        NavigationButton(
                            isPrimary: true,
                            icon: "chevron.right",
                            isDisabled: isNextButtonDisabled,
                            action: onNext
                        )
                        .padding(.bottom, 20)
                    } else {
                        // Empty space to maintain layout
                        Spacer()
                            .frame(height: 90)
                    }
                }
                
                // Fixed position back button
                VStack {
                    HStack {
                        if showBackButton {
                            NavigationButton(
                                isPrimary: false,
                                icon: "chevron.left",
                                isDisabled: false,
                                action: onBack
                            )
                            .padding(.top, 40)
                        } else {
                            Spacer()
                                .frame(width: 50, height: 50) // Placeholder to maintain layout
                        }
                        Spacer()
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                .padding(.top, 16)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea(.all, edges: .bottom)
    }
}

// MARK: - Screen Views
struct GoalSelectionView: View, OnboardingScreenView {
    @ObservedObject var userData: UserData
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        OnboardingScreenLayout(
            current: 1,
            total: 7,
            title: "What is your",
            highlight: " goal?",
            info: "Select your primary goal and\nwe'll customize your dashboard",
            isNextButtonDisabled: userData.goal == nil,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                ForEach(Goal.allCases) { goal in
                    SelectionCard(isSelected: userData.goal == goal, action: { userData.goal = goal }) {
                        HStack {
                            Text(goal.rawValue)
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.secondaryColor)
                            
                            Spacer()
                            
                            Image(systemName: goal.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 40)
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }
}

struct GenderSelectionView: View, OnboardingScreenView {
    @ObservedObject var userData: UserData
    let onNext: () -> Void
    let onBack: () -> Void
    
    var body: some View {
        OnboardingScreenLayout(
            current: 2,
            total: 7,
            title: "Your ",
            highlight: "biological gender?",
            info: "We will use this data to give you\na better plan for you",
            isNextButtonDisabled: userData.gender == nil,
            onNext: onNext,
            onBack: onBack
        ) {
            HStack(spacing: 20) {
                ForEach(Gender.allCases) { gender in
                    SelectionCard(isSelected: userData.gender == gender, action: { userData.gender = gender }) {
                        VStack {
                            Image(systemName: gender.iconName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 100)
                                .padding(.bottom, 20)
                            
                            Text(gender.rawValue)
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.secondaryColor)
                        }
                    }
                }
            }
        }
    }
}

struct AgeSelectionView: View, OnboardingScreenView {
    @ObservedObject var userData: UserData
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var ageString: String = ""
    @State private var isInputValid: Bool = true
    
    var body: some View {
        OnboardingScreenLayout(
            current: 3,
            total: 7,
            title: "Your ",
            highlight: "age",
            info: "We will use this data to give you\na better diet type for you",
            isNextButtonDisabled: ageString.isEmpty ? (userData.age < 1 || userData.age > 120) : !isInputValid,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardHighlightColor)
                        .frame(height: 120)
                    
                    // When ageString is empty, show current userData.age
                    if ageString.isEmpty {
                        Text("\(userData.age)")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(AppTheme.primaryColor.opacity(0.7))
                    }
                    
                    TextField("", text: $ageString)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(AppTheme.primaryColor)
                        .onChange(of: ageString) { oldValue, newValue in
                            let filtered = newValue.filter { $0.isNumber }
                            if filtered != newValue {
                                ageString = filtered
                            }
                            
                            if let age = Int(filtered) {
                                if age >= 1 && age <= 120 {
                                    userData.age = age
                                    isInputValid = true
                                } else {
                                    isInputValid = false
                                }
                            }
                        }
                }
                .padding(.horizontal, 50)
                
                // Instructional or error text
                if ageString.isEmpty {
                    Text("Tap the text box to enter your age")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryColor)
                } else if !isInputValid {
                    Text("Number out of range. Please enter your real age")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                
                Spacer().frame(height: 10)
            }
            .onAppear {
                // Reset text field each time view appears
                ageString = ""
            }
        }
    }
}

struct HeightSelectionView: View, OnboardingScreenView {
    @ObservedObject var userData: UserData
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var selectedUnit: String = "cm"
    
    // Height range constants
    private let minHeight: Double = 100
    private let maxHeight: Double = 230
    private let trackWidth: CGFloat = 300
    
    var body: some View {
        OnboardingScreenLayout(
            current: 4,
            total: 7,
            title: "How ",
            highlight: "tall are you?",
            info: "We will use this data to give you\na better diet type for you",
            isNextButtonDisabled: userData.height < 100 || userData.height > 230,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                // Unit toggle
                UnitToggle(
                    selectedUnit: $selectedUnit,
                    leftOption: "ft",
                    rightOption: "cm",
                    onSelect: toggleUnits
                )
                .padding(.bottom, 20)
                
                // Height display
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardHighlightColor)
                        .frame(height: 120)
                        .padding(.horizontal, 50)
                    
                    if selectedUnit == "cm" {
                        Text("\(Int(userData.height))")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(AppTheme.primaryColor)
                    } else {
                        // Display feet and inches
                        let feetValue = getFeetFromCm(userData.height)
                        Text(feetValue)
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(AppTheme.primaryColor)
                    }
                }
                .padding(.bottom, 30)
                
                // Custom slider
                CustomSlider(
                    minValue: minHeight,
                    maxValue: maxHeight,
                    trackWidth: trackWidth,
                    value: userData.height,
                    onUpdate: { newHeight in
                        userData.height = newHeight
                    },
                    unit: selectedUnit
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                
                // Scale indicators
                HStack {
                    Text(selectedUnit == "cm" ? "100 cm" : getFeetFromCm(100))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(selectedUnit == "cm" ? "165 cm" : getFeetFromCm(165))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(selectedUnit == "cm" ? "230 cm" : getFeetFromCm(230))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    // Helper methods with corrected conversion logic
    private func toggleUnits(_ unit: String) {
        if unit == selectedUnit { return }
        
        // Keep height value in cm internally, only change display
        selectedUnit = unit
        userData.heightUnit = unit == "cm" ? .cm : .ft
    }
    
    private func cmToFeet(_ cm: Double) -> (feet: Int, inches: Int) {
        let inches = cm / 2.54
        let feet = Int(inches / 12)
        let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12))
        return (feet, remainingInches)
    }
    
    private func getFeetFromCm(_ cm: Double) -> String {
        let conversion = cmToFeet(cm)
        return "\(conversion.feet)'\(conversion.inches)\""
    }
}

struct WeightSelectionView: View, OnboardingScreenView {
    @ObservedObject var userData: UserData
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var selectedUnit: String = "kg"
    
    // Weight range constants
    private let minWeight: Double = 30
    private let maxWeight: Double = 200
    private let trackWidth: CGFloat = 300
    
    var body: some View {
        OnboardingScreenLayout(
            current: 5,
            total: 7,
            title: "Your ",
            highlight: "current weight",
            info: "We will use this data to give you\na better diet type for you",
            isNextButtonDisabled: userData.currentWeight < minWeight || userData.currentWeight > maxWeight,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                // Unit toggle
                UnitToggle(
                    selectedUnit: $selectedUnit,
                    leftOption: "kg",
                    rightOption: "lb",
                    onSelect: toggleUnits
                )
                .padding(.bottom, 20)
                
                // Weight display
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardHighlightColor)
                        .frame(height: 120)
                        .padding(.horizontal, 50)
                    
                    if selectedUnit == "kg" {
                        Text("\(Int(userData.currentWeight))")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(AppTheme.primaryColor)
                    } else {
                        // Display weight in pounds
                        Text("\(Int(kgToLbs(userData.currentWeight)))")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(AppTheme.primaryColor)
                    }
                }
                .padding(.bottom, 30)
                
                // Custom slider
                CustomSlider(
                    minValue: minWeight,
                    maxValue: maxWeight,
                    trackWidth: trackWidth,
                    value: userData.currentWeight,
                    onUpdate: { newWeight in
                        userData.currentWeight = newWeight
                    },
                    unit: selectedUnit
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                
                // Scale indicators
                HStack {
                    Text(selectedUnit == "kg" ? "30 kg" : "\(Int(kgToLbs(30))) lb")
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(selectedUnit == "kg" ? "100 kg" : "\(Int(kgToLbs(100))) lb")
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(selectedUnit == "kg" ? "200 kg" : "\(Int(kgToLbs(200))) lb")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 40)
            }
        }
    }
    
    // Helper methods for unit conversion
    private func toggleUnits(_ unit: String) {
        if unit == selectedUnit { return }
        
        // Keep weight value in kg internally, only change display
        selectedUnit = unit
        userData.weightUnit = unit == "kg" ? .kg : .lb
    }
    
    private func kgToLbs(_ kg: Double) -> Double {
        return kg * 2.20462
    }
    
    private func lbsToKg(_ lbs: Double) -> Double {
        return lbs / 2.20462
    }
}

//Target weight1
struct TargetWeightView: View, OnboardingScreenView {
    @ObservedObject var userData: UserData
    let onNext: () -> Void
    let onBack: () -> Void
    @State private var targetWeightString: String = ""
    @State private var isInputValid: Bool = true
    
    // limitation
    private let minWeightKg: Double = 20
    private let maxWeightKg: Double = 200
    
    // calcules the toggle limitation
    private var minWeightInCurrentUnit: Double {
        userData.weightUnit == .kg ? minWeightKg : minWeightKg * 2.20462
    }
    
    private var maxWeightInCurrentUnit: Double {
        userData.weightUnit == .kg ? maxWeightKg : maxWeightKg * 2.20462
    }
    
    // test function
    private var isWeightValid: Bool {
        return userData.targetWeight >= minWeightKg && userData.targetWeight <= maxWeightKg
    }
    
    var body: some View {
        OnboardingScreenLayout(
            current: 6,
            total: 7,
            title: "Your ",
            highlight: "target weight",
            info: "We will use this data to give you\na better diet type for you",
            isNextButtonDisabled: !isWeightValid,
            onNext: onNext,
            onBack: onBack
        ) {
            VStack(spacing: 20) {
                // change the unit
                UnitToggle(
                    selectedUnit: .init(get: { userData.getWeightUnitString() },
                                      set: { _ in }),
                    leftOption: "kg",
                    rightOption: "lb",
                    onSelect: { unit in
                        // empty current input
                        targetWeightString = ""
                        // toggle the current input
                        userData.toggleWeightUnit()
                    }
                )
                .padding(.bottom, 20)
                
                // reset the select
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white)
                            .frame(width: 150, height: 120)
                        
                        Text("\(Int(userData.currentWeight))")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(Color.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    
                    // arrow
                    Image(systemName: "arrowtriangle.right.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 30, height: 30)
                        .foregroundColor(AppTheme.accentColor)
                    
                    // input target number
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(AppTheme.cardHighlightColor)
                            .frame(width: 150, height: 120)
                        
                        if targetWeightString.isEmpty {
                            // defualt
                            Text("\(Int(userData.targetWeight))")
                                .font(.system(size: 64, weight: .bold))
                                .foregroundColor(AppTheme.primaryColor.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        

                        Color.clear
                            .frame(width: 150, height: 120)
                            .contentShape(Rectangle())
                            .overlay(
                                TextField("", text: $targetWeightString)
                                    .keyboardType(.numberPad)
                                    .multilineTextAlignment(.center)
                                    .font(.system(size: 64, weight: .bold))
                                    .foregroundColor(AppTheme.primaryColor)
                                    .frame(maxWidth: 150)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                            )
                            .onChange(of: targetWeightString) { oldValue, newValue in
                                // filter non integer numbers
                                let filtered = newValue.filter { $0.isNumber }
                                if filtered != newValue {
                                    targetWeightString = filtered
                                }
                                
                                if let targetWeight = Double(filtered), !filtered.isEmpty {
                                    // test
                                    let weightInKg = userData.weightUnit == .kg ?
                                        targetWeight : targetWeight / 2.20462
                                    
                                    if weightInKg >= minWeightKg && weightInKg <= maxWeightKg {
                                        // save to data directly
                                        userData.targetWeight = weightInKg
                                        isInputValid = true
                                    } else {
                                     
                                        userData.targetWeight = weightInKg
                                        isInputValid = false
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal, 20)
                

                if targetWeightString.isEmpty {
                    Text("Tap the text box to enter your target weight")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryColor)
                } else if !isInputValid {
                    Text("Weight out of range. Please enter a valid weight")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                
                Spacer().frame(height: 10)
            }
            .onAppear {

                targetWeightString = ""

                isInputValid = isWeightValid
            }
            .ignoresSafeArea(.keyboard)
        }
    }
}

struct ProfileCreationView: View {
    @ObservedObject var userData: UserData
    let onFinish: () -> Void
    let onBack: () -> Void
    @State private var name = "User"
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    
    var body: some View {
        OnboardingScreenLayout(
            current: 7,
            total: 7,
            title: "Ready to ",
            highlight: "start your journey?",
            info: "Setup your profile and jump into the app",
            showNextButton: false,
            isNextButtonDisabled: userData.goal == nil,
            onNext: onFinish,
            onBack: onBack
        ) {
            VStack(spacing: 30) {
                // Profile avatar with circle overlay and tap gesture
                Button(action: {
                    showImagePicker = true
                }) {
                    if userData.avatar.isEmpty {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(.gray)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.accentColor, lineWidth: 3)
                            )
                    } else {
                        Image(systemName: userData.avatar)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.accentColor, lineWidth: 3)
                            )
                    }
                }
                .padding(.bottom, 20)
                .sheet(isPresented: $showImagePicker) {
                    UIImagePickerView(selectedImage: $inputImage)
                }
                .onChange(of: inputImage) { _, newValue in
                    if let newImage = newValue {
                        // Here you would save the image and update userData.avatar
                        // For example:
                        let imageName = saveImage(newImage)
                        userData.avatar = imageName
                    }
                }
                
                // Enhanced text field with larger size, rounded corners, border and light yellow background
                TextField("Your name", text: $name)
                    .font(.system(size: 22))
                    .multilineTextAlignment(.center)
                    .padding()
                    .frame(height: 60)
                    .background(AppTheme.cardHighlightColor.opacity(0.5))
                    .cornerRadius(30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 30)
                            .stroke(AppTheme.primaryColor, lineWidth: 2)
                    )
                    .padding(.horizontal, 30)
                    .onChange(of: name) { oldValue, newValue in
                        userData.name = newValue
                    }
                
                Spacer()
                
                // Custom button for finishing onboarding
                Button(action: onFinish) {
                    HStack {
                        Text("Start Your Journey")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [AppTheme.primaryColor, AppTheme.secondaryColor]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .padding(.vertical, 30)
        }
    }
    
    // Function to save the image and return its name/path
    func saveImage(_ image: UIImage) -> String {
        // Here you would implement your image saving logic
        // For example, save to documents directory or app's asset catalog
        
        // For this example, we'll just return a placeholder name
        // In a real app, you'd save the image and return its identifier/path
        return "savedImage_\(UUID().uuidString)"
    }
}

// Renamed Image Picker to avoid conflicts
struct UIImagePickerView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: UIImagePickerView
        
        init(_ parent: UIImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.editedImage] as? UIImage {
                parent.selectedImage = image
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - Main Onboarding Container
struct OnboardingView: View {
    @StateObject private var userData = UserData.shared
    @State private var currentPage = 0
    var onFinishOnboarding: () -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundColor.ignoresSafeArea()
                
                VStack {
                    currentScreen
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
    }
    
    @ViewBuilder
    private var currentScreen: some View {
        switch currentPage {
        case 0:
            GoalSelectionView(
                userData: userData,
                onNext: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage += 1
                }},
                onBack: {} // First screen, so no back action
            )
        case 1:
            GenderSelectionView(
                userData: userData,
                onNext: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage += 1
                }},
                onBack: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage -= 1
                }}
            )
        case 2:
            AgeSelectionView(
                userData: userData,
                onNext: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage += 1
                }},
                onBack: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage -= 1
                }}
            )
        case 3:
            HeightSelectionView(
                userData: userData,
                onNext: { withAnimation(.easeInOut(duration: 0.1)) {
                    currentPage += 1
                }},
                onBack: { withAnimation(.easeInOut(duration: 0.1)) {
                    currentPage -= 1
                }}
            )
        case 4:
            WeightSelectionView(
                userData: userData,
                onNext: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage += 1
                }},
                onBack: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage -= 1
                }}
            )
        case 5:
            TargetWeightView(
                userData: userData,
                onNext: { withAnimation(.easeInOut(duration: 0.1)) {
                    currentPage += 1
                }},
                onBack: { withAnimation(.easeInOut(duration: 0.1)) {
                    currentPage -= 1
                }}
            )
        case 6:
            ProfileCreationView(
                userData: userData,
                onFinish: { 
                    userData.saveUserData()
                    print("Onboarding completed")
                    onFinishOnboarding()
                },
                onBack: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage -= 1
                }}
            )
        default:
            GoalSelectionView(
                userData: userData,
                onNext: { withAnimation(.easeInOut(duration: 0.05)) {
                    currentPage += 1
                }},
                onBack: {}
            )
        }
    }
}

// MARK: - Helper Components
struct WeightGauge: View {
    let currentWeight: Double
    let targetWeight: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        ZStack {
            // Background track
            Arc(startAngle: .degrees(180), endAngle: .degrees(0))
                .stroke(Color.gray.opacity(0.3), lineWidth: 10)
                .frame(width: 240, height: 120)
            
            // Highlight section from currentWeight to targetWeight
            Arc(
                startAngle: .degrees(180 - getAngleForWeight(currentWeight)),
                endAngle: .degrees(180 - getAngleForWeight(targetWeight))
            )
            .stroke(AppTheme.cardHighlightColor, lineWidth: 20)
            .frame(width: 240, height: 120)
            
            // Tick marks
            ForEach(0..<7, id: \.self) { i in
                Rectangle()
                    .fill(Color.gray.opacity(0.5))
                    .frame(width: 1, height: 10)
                    .offset(y: -60)
                    .rotationEffect(.degrees(Double(i) * 30 - 90))
            }
            
            // Labels
            Text("60")
                .font(.system(size: 14))
                .offset(x: -100, y: 40)
            
            Text("70")
                .font(.system(size: 14))
                .offset(y: 0)
            
            Text("80")
                .font(.system(size: 14))
                .offset(x: 60, y: 20)
            
            Text("90")
                .font(.system(size: 14))
                .offset(x: 100, y: 40)
        }
    }
    
    private func getAngleForWeight(_ weight: Double) -> Double {
        let percentage = (weight - range.lowerBound) / (range.upperBound - range.lowerBound)
        return percentage * 180
    }
}

struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        path.addArc(
            center: center,
            radius: radius,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        
        return path
    }
}
// MARK: - Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview all screens
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .previewDisplayName("Full Flow")
            
            // Preview individual screens for easier testing
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .onAppear {
                // Mock the currentPage to show goal view
            }
            .previewDisplayName("Goal View")
            
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .onAppear {
                let view = OnboardingView(onFinishOnboarding: {})
                // Access the internal state to set the page to gender view
                if let vm = Mirror(reflecting: view).children.first(where: { $0.label == "_currentPage" })?.value as? State<Int> {
                    vm.wrappedValue = 1
                }
            }
            .previewDisplayName("Gender View")
            
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .onAppear {
                let view = OnboardingView(onFinishOnboarding: {})
                // Access the internal state to set the page to birth date view
                if let vm = Mirror(reflecting: view).children.first(where: { $0.label == "_currentPage" })?.value as? State<Int> {
                    vm.wrappedValue = 2
                }
            }
            .previewDisplayName("Birth Date View")
            
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .onAppear {
                let view = OnboardingView(onFinishOnboarding: {})
                // Access the internal state to set the page to height view
                if let vm = Mirror(reflecting: view).children.first(where: { $0.label == "_currentPage" })?.value as? State<Int> {
                    vm.wrappedValue = 3
                }
            }
            .previewDisplayName("Height View")
            
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .onAppear {
                let view = OnboardingView(onFinishOnboarding: {})
                // Access the internal state to set the page to current weight view
                if let vm = Mirror(reflecting: view).children.first(where: { $0.label == "_currentPage" })?.value as? State<Int> {
                    vm.wrappedValue = 4
                }
            }
            .previewDisplayName("Current Weight View")
            
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .onAppear {
                let view = OnboardingView(onFinishOnboarding: {})
                // Access the internal state to set the page to target weight view
                if let vm = Mirror(reflecting: view).children.first(where: { $0.label == "_currentPage" })?.value as? State<Int> {
                    vm.wrappedValue = 5
                }
            }
            .previewDisplayName("Target Weight View")
            
            OnboardingView(onFinishOnboarding: {
                print("Onboarding finished")
            })
            .onAppear {
                let view = OnboardingView(onFinishOnboarding: {})
                // Access the internal state to set the page to profile creation view
                if let vm = Mirror(reflecting: view).children.first(where: { $0.label == "_currentPage" })?.value as? State<Int> {
                    vm.wrappedValue = 6
                }
            }
            .previewDisplayName("Profile Creation View")
        }
    }
}
