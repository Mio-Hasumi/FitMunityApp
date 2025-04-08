import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var authManager: AuthManager
    @ObservedObject var userData = UserData.shared
    @State private var showSignOutConfirmation = false
    @State private var showingEditView = false
    @State private var editViewType: EditViewType = .name
    @State private var isLoading = false
    
    enum EditViewType {
        case name
        case age
        case weight
        case height
        case gender
        case goal
    }
    
    private var background: some View {
        AppTheme.backgroundColor
            .ignoresSafeArea()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                background
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            Spacer()
                            Text("Home")
                                .font(.title)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.primaryColor)
                            Spacer()
                            
                            // Add refresh button
                            Button(action: { refreshProfileData() }) {
                                Image(systemName: "arrow.clockwise")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(
                                        Circle()
                                            .fill(AppTheme.cardHighlightColor)
                                    )
                            }
                            .disabled(isLoading)
                        }
                        .padding(.top)
                        .padding(.horizontal)
                        
                        // User info card
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(hex: "E6F2D9"))
                            
                            HStack(spacing: 16) {
                                // Profile picture
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: userData.avatar)
                                            .resizable()
                                            .scaledToFit()
                                            .padding(15)
                                            .foregroundColor(.purple)
                                    )
                                
                                Text(userData.name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppTheme.primaryColor)
                                
                                Spacer()
                                
                                Button(action: {
                                    editViewType = .name
                                    showingEditView = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                        .padding(8)
                                        .background(Circle().fill(Color.white))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                        }
                        .padding(.horizontal)
                        
                        // Goal Set Section
                        SectionHeader(title: "Goal Set")
                        
                        Button(action: {
                            editViewType = .goal
                            showingEditView = true
                        }) {
                            InfoRow(
                                icon: "key.fill",
                                iconBackgroundColor: .yellow,
                                title: "My current goal set",
                                value: userData.goal?.rawValue ?? "Not set",
                                showChevron: true,
                                showEditButton: false
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // User Information Section
                        SectionHeader(title: "Your Information")
                        
                        // Age
                        InfoRow(
                            icon: "calendar",
                            iconBackgroundColor: .red.opacity(0.2),
                            title: "Age",
                            value: "\(userData.age) yo",
                            showChevron: false,
                            showEditButton: true
                        ) {
                            editViewType = .age
                            showingEditView = true
                        }
                        
                        // Weight
                        InfoRow(
                            icon: "scale.3d",
                            iconBackgroundColor: .blue.opacity(0.2),
                            title: "Weight",
                            value: "\(Int(userData.currentWeight)) \(userData.weightUnit.rawValue)",
                            showChevron: false,
                            showEditButton: true
                        ) {
                            editViewType = .weight
                            showingEditView = true
                        }
                        
                        // Height
                        InfoRow(
                            icon: "ruler",
                            iconBackgroundColor: .blue.opacity(0.2),
                            title: "Height",
                            value: getFormattedHeight(),
                            showChevron: false,
                            showEditButton: true
                        ) {
                            editViewType = .height
                            showingEditView = true
                        }
                        
                        // Gender
                        InfoRow(
                            icon: "person.2.fill",
                            iconBackgroundColor: .blue.opacity(0.2),
                            title: "Gender",
                            value: userData.gender?.rawValue ?? "Not set",
                            showChevron: false,
                            showEditButton: true
                        ) {
                            editViewType = .gender
                            showingEditView = true
                        }
                        
                        // Sign out button
                        Button(action: {
                            showSignOutConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Sign Out")
                                    .foregroundColor(.white)
                                    .font(.headline)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red)
                            .cornerRadius(10)
                            .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 50)
                        
                        Spacer()
                            .frame(height: 80)
                    }
                    .padding(.horizontal)
                }
                
                // Loading overlay
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.accentColor))
                        .scaleEffect(1.5)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white)
                                .frame(width: 60, height: 60)
                        )
                }
            }
            .alert(isPresented: $showSignOutConfirmation) {
                Alert(
                    title: Text("Sign Out"),
                    message: Text("Are you sure you want to sign out?"),
                    primaryButton: .destructive(Text("Sign Out")) {
                        // Sign out the user
                        authManager.signOut()
                        
                        // Force UI update by posting a notification
                        NotificationCenter.default.post(name: NSNotification.Name("ForceSignOut"), object: nil)
                    },
                    secondaryButton: .cancel()
                )
            }
            .fullScreenCover(isPresented: $showingEditView) {
                EditViewRouter(editViewType: editViewType, isPresented: $showingEditView)
            }
            .onAppear {
                refreshProfileData()
            }
        }
    }
    
    // Function to refresh profile data from Supabase
    private func refreshProfileData() {
        guard authManager.authState == .signedIn else { return }
        
        isLoading = true
        Task {
            await userData.fetchProfileFromSupabase()
            
            // Update UI on main thread
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    // Helper function to format height properly based on unit
    private func getFormattedHeight() -> String {
        switch userData.heightUnit {
        case .cm:
            return "\(Int(userData.height)) cm"
        case .ft:
            let inches = userData.height
            let feet = Int(inches / 12)
            let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12))
            return "\(feet)'\(remainingInches)\" ft"
        }
    }
}

struct SectionHeader: View {
    var title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.primaryColor)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

struct InfoRow: View {
    var icon: String
    var iconBackgroundColor: Color
    var title: String
    var value: String
    var showChevron: Bool
    var showEditButton: Bool
    var editAction: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(AppTheme.cardHighlightColor)
            
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryColor)
                    
                    if !value.isEmpty {
                        Text(value)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                if showEditButton {
                    Button(action: {
                        editAction?()
                    }) {
                        Image(systemName: "pencil")
                            .font(.headline)
                            .foregroundColor(.green)
                            .padding(8)
                            .background(Circle().fill(Color.white))
                    }
                }
                
                if showChevron {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.green)
                        .font(.system(size: 18, weight: .medium))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 15)
        }
        .padding(.horizontal)
    }
}

// Router to handle which edit view to show
struct EditViewRouter: View {
    let editViewType: HomeView.EditViewType
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.backgroundColor.ignoresSafeArea()
                
                VStack {
                    switch editViewType {
                    case .name:
                        EditProfileView(isPresented: $isPresented)
                    case .age:
                        AgeEditView(isPresented: $isPresented)
                    case .weight:
                        WeightEditView(isPresented: $isPresented)
                    case .height:
                        HeightEditView(isPresented: $isPresented)
                    case .gender:
                        GenderEditView(isPresented: $isPresented)
                    case .goal:
                        GoalEditView(isPresented: $isPresented)
                    }
                }
            }
        }
    }
}

struct EditProfileView: View {
    @ObservedObject var userData = UserData.shared
    @Binding var isPresented: Bool
    @State private var username: String
    @State private var showImagePicker = false
    @State private var inputImage: UIImage?
    @State private var isSaving = false
    @EnvironmentObject private var authManager: AuthManager
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._username = State(initialValue: UserData.shared.name)
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Circle()
                            .fill(AppTheme.cardHighlightColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            )
                    }
                    
                    Spacer()
                    
                    Text("Edit Profile")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Profile avatar with tap to change
                Button(action: {
                    showImagePicker = true
                }) {
                    Circle()
                        .fill(Color.purple.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            Image(systemName: userData.avatar)
                                .resizable()
                                .scaledToFit()
                                .padding(20)
                                .foregroundColor(.purple)
                        )
                }
                .padding(.bottom, 50)
                .sheet(isPresented: $showImagePicker) {
                    UIImagePickerView(selectedImage: $inputImage)
                }
                .onChange(of: inputImage) { _, newValue in
                    if let newImage = newValue {
                        // Here you would save the image and update userData.avatar
                        let imageName = saveImage(newImage)
                        userData.avatar = imageName
                    }
                }
                
                // Username field inside light yellow card
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(AppTheme.cardHighlightColor)
                        .frame(height: 60)
                    
                    HStack {
                        // Editable text field for username
                        TextField("Username", text: $username)
                            .font(.title3)
                            .foregroundColor(AppTheme.primaryColor)
                            .padding(.leading)
                        
                        Spacer()
                        
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.green)
                            .padding()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save button at bottom
                Button(action: {
                    saveProfile()
                }) {
                    HStack {
                        Text("Save profile")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(isSaving ? AppTheme.primaryColor.opacity(0.7) : AppTheme.primaryColor)
                    )
                }
                .disabled(isSaving)
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
    
    private func saveProfile() {
        isSaving = true
        
        // Update local data
        userData.name = username
        
        // Save to Supabase if authenticated
        if authManager.authState == .signedIn, let userId = authManager.currentUser?.id {
            Task {
                await userData.saveProfileToSupabase(userId: userId)
                
                // Update UI on main thread
                await MainActor.run {
                    // Save to UserDefaults as well
                    userData.saveUserData()
                    isSaving = false
                    isPresented = false
                }
            }
        } else {
            // Just save to UserDefaults if not authenticated
            userData.saveUserData()
            isSaving = false
            isPresented = false
        }
    }
    
    func saveImage(_ image: UIImage) -> String {
        // Here you would implement your image saving logic
        return "person.circle.fill" // Default system icon as fallback
    }
}

// Age Edit View
struct AgeEditView: View {
    @ObservedObject var userData = UserData.shared
    @Binding var isPresented: Bool
    @State private var ageString: String = ""
    @State private var isInputValid: Bool = true
    @State private var isSaving: Bool = false
    @EnvironmentObject private var authManager: AuthManager
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Circle()
                            .fill(AppTheme.cardHighlightColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            )
                    }
                    
                    Spacer()
                    
                    Text("Edit Age")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Title and info
                Text("Your age")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryColor)
                    .padding(.bottom, 5)
                
                Text("We use this data to customize your diet plan")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.secondaryColor)
                    .padding(.bottom, 40)
                
                // Age input
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardHighlightColor)
                        .frame(height: 120)
                        .padding(.horizontal, 50)
                    
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
                .padding(.bottom, 20)
                
                // Instructional or error text
                if ageString.isEmpty {
                    Text("Tap the text box to enter your age")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.secondaryColor)
                } else if !isInputValid {
                    Text("Please enter an age between 1 and 120")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
                
                Spacer()
                
                // Save button
                Button(action: {
                    saveAge()
                }) {
                    HStack {
                        Text("Save")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if isSaving {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(isInputValid && !isSaving ? AppTheme.primaryColor : Color.gray)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                .disabled(!isInputValid || isSaving)
            }
        }
        .onAppear {
            ageString = ""
        }
    }
    
    private func saveAge() {
        if isInputValid && (userData.age >= 1 && userData.age <= 120) {
            isSaving = true
            
            // Save to Supabase if authenticated
            if authManager.authState == .signedIn, let userId = authManager.currentUser?.id {
                Task {
                    await userData.saveProfileToSupabase(userId: userId)
                    
                    // Update UI on main thread
                    await MainActor.run {
                        // Save to UserDefaults as well
                        userData.saveUserData()
                        isSaving = false
                        isPresented = false
                    }
                }
            } else {
                // Just save to UserDefaults if not authenticated
                userData.saveUserData()
                isSaving = false
                isPresented = false
            }
        }
    }
}

// Weight Edit View
struct WeightEditView: View {
    @ObservedObject var userData = UserData.shared
    @Binding var isPresented: Bool
    @State private var selectedUnit: String = "kg"
    @State private var weight: Double
    
    // Weight range constants
    private let minWeight: Double = 30
    private let maxWeight: Double = 200
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._weight = State(initialValue: UserData.shared.currentWeight)
        self._selectedUnit = State(initialValue: UserData.shared.weightUnit.rawValue)
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Circle()
                            .fill(AppTheme.cardHighlightColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            )
                    }
                    
                    Spacer()
                    
                    Text("Edit Weight")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Title and info
                Text("Your current weight")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryColor)
                    .padding(.bottom, 5)
                
                Text("We use this data to customize your diet plan")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.secondaryColor)
                    .padding(.bottom, 40)
                
                // Unit toggle
                HomeUnitToggle(
                    selectedUnit: $selectedUnit,
                    leftOption: "kg",
                    rightOption: "lb",
                    onSelect: toggleUnits
                )
                .padding(.bottom, 30)
                
                // Weight display
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardHighlightColor)
                        .frame(height: 120)
                        .padding(.horizontal, 50)
                    
                    Text("\(Int(weight))")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(AppTheme.primaryColor)
                }
                .padding(.bottom, 30)
                
                // Weight slider
                HStack {
                    Text("\(Int(minWeight))")
                        .foregroundColor(.gray)
                    
                    Slider(value: $weight, in: minWeight...maxWeight, step: 1)
                        .accentColor(AppTheme.accentColor)
                    
                    Text("\(Int(maxWeight))")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                
                Spacer()
                
                // Save button
                Button(action: {
                    // Save with proper unit conversion
                    if selectedUnit != userData.weightUnit.rawValue {
                        userData.toggleWeightUnit()
                    }
                    userData.currentWeight = weight
                    userData.saveUserData()
                    isPresented = false
                }) {
                    HStack {
                        Text("Save")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(AppTheme.primaryColor)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Initialize with current values
            weight = userData.currentWeight
            selectedUnit = userData.weightUnit.rawValue
        }
    }
    
    // Helper methods for unit conversion
    private func toggleUnits(_ unit: String) {
        if unit == selectedUnit { return }
        
        if unit == "kg" && selectedUnit == "lb" {
            // Convert from lb to kg
            weight = weight / 2.20462
        } else if unit == "lb" && selectedUnit == "kg" {
            // Convert from kg to lb
            weight = weight * 2.20462
        }
        
        selectedUnit = unit
    }
}

// Height Edit View
struct HeightEditView: View {
    @ObservedObject var userData = UserData.shared
    @Binding var isPresented: Bool
    @State private var selectedUnit: String = "cm"
    @State private var height: Double
    
    // Height range constants
    private let minHeightCm: Double = 100
    private let maxHeightCm: Double = 230
    private let minHeightFt: Double = 39.37 // 100cm in inches
    private let maxHeightFt: Double = 90.55 // 230cm in inches
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._height = State(initialValue: UserData.shared.height)
        self._selectedUnit = State(initialValue: UserData.shared.heightUnit.rawValue)
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Circle()
                            .fill(AppTheme.cardHighlightColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            )
                    }
                    
                    Spacer()
                    
                    Text("Edit Height")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Title and info
                Text("How tall are you?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryColor)
                    .padding(.bottom, 5)
                
                Text("We use this data to customize your diet plan")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.secondaryColor)
                    .padding(.bottom, 40)
                
                // Unit toggle
                HomeUnitToggle(
                    selectedUnit: $selectedUnit,
                    leftOption: "ft",
                    rightOption: "cm",
                    onSelect: toggleUnits
                )
                .padding(.bottom, 30)
                
                // Height display
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(AppTheme.cardHighlightColor)
                        .frame(height: 120)
                        .padding(.horizontal, 50)
                    
                    if selectedUnit == "cm" {
                        Text("\(Int(height))")
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(AppTheme.primaryColor)
                    } else {
                        // Display feet and inches
                        let feetValue = getFeetFromInches(height)
                        Text(feetValue)
                            .font(.system(size: 64, weight: .bold))
                            .foregroundColor(AppTheme.primaryColor)
                    }
                }
                .padding(.bottom, 30)
                
                // Height slider
                HStack {
                    Text(selectedUnit == "cm" ? "100" : "3'3\"")
                        .foregroundColor(.gray)
                    
                    Slider(
                        value: $height,
                        in: selectedUnit == "cm" ? minHeightCm...maxHeightCm : minHeightFt...maxHeightFt,
                        step: 1
                    )
                    .accentColor(AppTheme.accentColor)
                    
                    Text(selectedUnit == "cm" ? "230" : "7'7\"")
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
                
                Spacer()
                
                // Save button
                Button(action: {
                    // Save with proper unit conversion
                    userData.height = height
                    userData.heightUnit = selectedUnit == "cm" ? .cm : .ft
                    userData.saveUserData()
                    isPresented = false
                }) {
                    HStack {
                        Text("Save")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(AppTheme.primaryColor)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onAppear {
            // Initialize with current values
            height = userData.height
            selectedUnit = userData.heightUnit.rawValue
        }
    }
    
    // Helper methods for unit conversion
    private func toggleUnits(_ unit: String) {
        if unit == selectedUnit { return }
        
        if unit == "cm" && selectedUnit == "ft" {
            // Convert from inches to cm
            height = height * 2.54
        } else if unit == "ft" && selectedUnit == "cm" {
            // Convert from cm to inches
            height = height / 2.54
        }
        
        selectedUnit = unit
    }
    
    private func getFeetFromInches(_ inches: Double) -> String {
        let feet = Int(inches / 12)
        let remainingInches = Int(inches.truncatingRemainder(dividingBy: 12))
        return "\(feet)'\(remainingInches)\""
    }
}

// Gender Edit View
struct GenderEditView: View {
    @ObservedObject var userData = UserData.shared
    @Binding var isPresented: Bool
    @State private var selectedGender: Gender
    
    private let genderOptions: [Gender] = [.male, .female]
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._selectedGender = State(initialValue: UserData.shared.gender ?? .male)
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Circle()
                            .fill(AppTheme.cardHighlightColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            )
                    }
                    
                    Spacer()
                    
                    Text("Edit Gender")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Title and info
                Text("What's your gender?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryColor)
                    .padding(.bottom, 5)
                
                Text("We use this data to customize your diet plan")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.secondaryColor)
                    .padding(.bottom, 40)
                
                // Gender options
                VStack(spacing: 15) {
                    ForEach(genderOptions, id: \.self) { gender in
                        Button(action: {
                            selectedGender = gender
                        }) {
                            HStack {
                                Text(gender.rawValue)
                                    .font(.title3)
                                    .foregroundColor(AppTheme.primaryColor)
                                
                                Spacer()
                                
                                if selectedGender == gender {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(AppTheme.accentColor)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 15)
                                    .fill(AppTheme.cardHighlightColor)
                            )
                        }
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Save button
                Button(action: {
                    userData.gender = selectedGender
                    userData.saveUserData()
                    isPresented = false
                }) {
                    HStack {
                        Text("Save")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(AppTheme.primaryColor)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

// Goal Edit View
struct GoalEditView: View {
    @ObservedObject var userData = UserData.shared
    @Binding var isPresented: Bool
    @State private var selectedGoal: Goal
    
    private let goalOptions: [(Goal, String)] = [
        (.loseWeight, "Achieve a healthy weight through balanced nutrition and exercise"),
        (.gainWeight, "Build lean muscle mass with strength training and proper nutrition"),
        (.stayHealthy, "Maintain current weight and improve overall fitness")
    ]
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        self._selectedGoal = State(initialValue: UserData.shared.goal ?? .stayHealthy)
    }
    
    var body: some View {
        ZStack {
            AppTheme.backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: {
                        isPresented = false
                    }) {
                        Circle()
                            .fill(AppTheme.cardHighlightColor)
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "chevron.left")
                                    .foregroundColor(AppTheme.primaryColor)
                                    .font(.system(size: 16, weight: .semibold))
                            )
                    }
                    
                    Spacer()
                    
                    Text("Edit Goal")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryColor)
                    
                    Spacer()
                    
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                .padding(.top, 40)
                .padding(.bottom, 30)
                
                // Title and info
                Text("What's your goal?")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.primaryColor)
                    .padding(.bottom, 5)
                
                Text("Choose your primary fitness goal")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.secondaryColor)
                    .padding(.bottom, 40)
                
                // Goal options
                ScrollView {
                    VStack(spacing: 15) {
                        ForEach(goalOptions, id: \.0) { goal, description in
                            Button(action: {
                                selectedGoal = goal
                            }) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(goal.rawValue)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(AppTheme.primaryColor)
                                        
                                        Spacer()
                                        
                                        if selectedGoal == goal {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(AppTheme.accentColor)
                                        }
                                    }
                                    
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(AppTheme.secondaryColor)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 15)
                                        .fill(AppTheme.cardHighlightColor)
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Save button
                Button(action: {
                    userData.goal = selectedGoal
                    userData.saveUserData()
                    isPresented = false
                }) {
                    HStack {
                        Text("Save")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 25)
                            .fill(AppTheme.primaryColor)
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
    }
}

// Unit Toggle View
struct HomeUnitToggle: View {
    @Binding var selectedUnit: String
    let leftOption: String
    let rightOption: String
    let onSelect: (String) -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Left option
            Button(action: {
                onSelect(leftOption)
            }) {
                Text(leftOption.uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selectedUnit == leftOption ? .white : AppTheme.primaryColor)
                    .frame(width: 60, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(selectedUnit == leftOption ? AppTheme.primaryColor : Color.clear)
                    )
            }
            
            // Right option
            Button(action: {
                onSelect(rightOption)
            }) {
                Text(rightOption.uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(selectedUnit == rightOption ? .white : AppTheme.primaryColor)
                    .frame(width: 60, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(selectedUnit == rightOption ? AppTheme.primaryColor : Color.clear)
                    )
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(AppTheme.cardHighlightColor)
        )
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthManager())
    }
}
