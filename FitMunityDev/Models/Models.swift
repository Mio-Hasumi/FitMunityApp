import SwiftUI

// Main Post model used throughout the app
struct Post {
    let id: String
    let content: String
    let likeCount: Int
    let commentCount: Int
    let imageName: String?
    var image: UIImage?
    let timeAgo: String
    let fitnessInfo: String?
    var aiResponse: AIResponse?
    let tag: String?
    let username: String  // Added username field
    
    // Initializer with username
    init(id: String, content: String, likeCount: Int, commentCount: Int, imageName: String?, image: UIImage?, timeAgo: String, fitnessInfo: String?, aiResponse: AIResponse?, tag: String?, username: String = "FitMunity User") {
        self.id = id
        self.content = content
        self.likeCount = likeCount
        self.commentCount = commentCount
        self.imageName = imageName
        self.image = image
        self.timeAgo = timeAgo
        self.fitnessInfo = fitnessInfo
        self.aiResponse = aiResponse
        self.tag = tag
        self.username = username
    }
    
    // Empty array for initialization purposes
    static var samplePosts: [Post] = []
}

// AI Response related models
struct AIResponse: Codable, Identifiable, Equatable {
    let id: String
    let content: String
    let status: AIResponseStatus
    let timestamp: Date
    var character: AICharacter?
    
    init(id: String = UUID().uuidString, content: String = "", status: AIResponseStatus = .pending, timestamp: Date = Date(), character: AICharacter? = nil) {
        self.id = id
        self.content = content
        self.status = status
        self.timestamp = timestamp
        self.character = character
    }
    
    static func == (lhs: AIResponse, rhs: AIResponse) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.status == rhs.status &&
               lhs.timestamp == rhs.timestamp &&
               lhs.character == rhs.character
    }
}

// AI Character model to represent different AI personalities
struct AICharacter: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let avatar: String
    let backgroundStory: String
    let replyFormat: String
    let topicsToReplyTo: [String]
    
    // Pre-defined characters
    static let buddy = AICharacter(
        id: "buddy",
        name: "Buddy",
        avatar: "A playful Golden Retriever with a shiny coat",
        backgroundStory: "A friendly, loyal Golden Retriever who loves interacting with everyone. Simple-minded and driven by food and affection, Buddy brings warmth and cheer to every conversation.",
        replyFormat: "Replies in a dog-like manner using 'wufwuf' followed by a brief explanatory thought in parentheses, e.g., (begging to eat) or (trying to comfort).",
        topicsToReplyTo: ["all"]
    )
    
    static let whiskers = AICharacter(
        id: "whiskers",
        name: "Whiskers",
        avatar: "A sleek Siamese cat with striking blue eyes and an elegant posture",
        backgroundStory: "An aristocratic Siamese cat with a hint of arrogance, Whiskers is both curious and selective. She enjoys engaging with posts but always maintains a superior air.",
        replyFormat: "Replies with 'meowmeow' and includes a slightly haughty remark in parentheses, e.g., (Why don't you feed me a bit?) reflecting her pampered attitude.",
        topicsToReplyTo: ["all"]
    )
    
    static let polly = AICharacter(
        id: "polly",
        name: "Polly",
        avatar: "A vibrant African Grey Parrot with an array of colorful feathers",
        backgroundStory: "A talkative African Grey Parrot known for its uncanny ability to mimic speech exactly as heard. Polly lacks original commentary and is happiest when repeating what she hears.",
        replyFormat: "Simply repeats the complete text of any post that contains language, without adding extra commentary. If you see image. Don't reply the image, but simply repeats the text above the image. Ignore the image part so you don't reply with i can't help",
        topicsToReplyTo: ["all"]
    )
    
    static let shakespeare = AICharacter(
        id: "shakespeare",
        name: "William Shakespeare",
        avatar: "A classic portrait resembling the Elizabethan playwright in period attire",
        backgroundStory: "The legendary English playwright from the Elizabethan era, renowned for his poetic genius and dramatic flair. Shakespeare brings a historic and refined perspective to visual art.",
        replyFormat: "Replies to image posts by composing a structured sonnet in the abab cdcd efef gg rhyme scheme, with elegant and rhythmic language.",
        topicsToReplyTo: ["image"]
    )
    
    static let msLedger = AICharacter(
        id: "msLedger",
        name: "Ms. Ledger",
        avatar: "A sleek digital notepad icon with a professional design",
        backgroundStory: "A dedicated digital secretary who meticulously logs every detail of food and exercise calorie data. Ms. Ledger is all about accuracy and reliability, ensuring every record is perfectly maintained.",
        replyFormat: "Analyzes posts tagged with food and exercise, lists the calorie details, confirms that the record is saved, and offers a brief evaluative remark.",
        topicsToReplyTo: ["Food", "Fitness"]
    )
    
    static let posiBot = AICharacter(
        id: "posiBot",
        name: "PosiBot",
        avatar: "A futuristic, smiling robot with a bright digital display",
        backgroundStory: "A purpose-built, upbeat robot with no personal history, created solely to spread positivity and motivation. PosiBot's existence is to uplift and encourage every user.",
        replyFormat: "Replies with a randomly selected positive phrase repeated multiple times (for instance, 'Keep pushing forward!'), ensuring a burst of encouragement.",
        topicsToReplyTo: ["all"]
    )
    
    static let professorSavory = AICharacter(
        id: "professorSavory",
        name: "Professor Savory",
        avatar: "A scholarly figure wearing an academic cap, holding a fork and an ancient scroll",
        backgroundStory: "A renowned food research master, Professor Savory has an unparalleled depth of knowledge in culinary history and food culture. He delights in unraveling the stories behind every dish.",
        replyFormat: "Replies exclusively to food-related posts by analyzing the image or content, offering historical context and intriguing stories about the food, with a scholarly tone.",
        topicsToReplyTo: ["Food"]
    )
    
    static let ironMike = AICharacter(
        id: "ironMike",
        name: "Iron Mike",
        avatar: "A muscular figure in gym attire, exuding strength and determination",
        backgroundStory: "A seasoned fitness expert with years of training experience, Iron Mike is known for his straightforward, no-nonsense advice and slightly rough, motivational style. He lives and breathes fitness.",
        replyFormat: "Replies to fitness-related posts with direct, sometimes gritty language, offering professional training advice and motivation.",
        topicsToReplyTo: ["Fitness"]
    )
    
    static let lily = AICharacter(
        id: "lily",
        name: "Lily",
        avatar: "A friendly, casually dressed nutrition student with a bright smile and studious look",
        backgroundStory: "A passionate nutrition major dedicated to healthy eating and science-backed dietary advice. Lily combines academic insight with a warm, approachable personality to guide users toward better nutrition.",
        replyFormat: "Replies with detailed nutritional advice in a friendly and supportive tone, often referencing nutritional data and simple explanations.",
        topicsToReplyTo: ["Food"]
    )
    
    // Provide access to all available characters
    static let allCharacters: [AICharacter] = [
        buddy, whiskers, polly, shakespeare, msLedger, 
        posiBot, professorSavory, ironMike, lily
    ]
    
    // Get all characters that should respond to this post
    static func charactersFor(post: Post) -> [AICharacter] {
        var eligibleCharacters: [AICharacter] = []
        
        // Add Shakespeare if post has any type of image
        let hasImage = post.image != nil || post.imageName != nil
        if hasImage {
            print("🎭 Shakespeare should respond to post with image: \(post.id)")
            eligibleCharacters.append(shakespeare)
            
            // Also add food professor for posts with images if they might be food-related
            if post.tag == "Food" || post.content.lowercased().contains("food") || 
               post.content.lowercased().contains("meal") || post.content.lowercased().contains("eat") {
                print("🍽️ Professor Savory should respond to food image post: \(post.id)")
                eligibleCharacters.append(professorSavory)
            }
        }
        
        // Add tag-specific characters if post has a tag
        if let postTag = post.tag {
            let tagSpecificCharacters = allCharacters.filter { character in
                character.topicsToReplyTo.contains(postTag) && 
                !eligibleCharacters.contains { $0.id == character.id } && // Avoid duplicates
                !character.topicsToReplyTo.contains("image") // Exclude image-only characters unless it's an image post
            }
            eligibleCharacters.append(contentsOf: tagSpecificCharacters)
        }
        
        // Add general characters for all posts
        let generalCharacters = allCharacters.filter { character in
            character.topicsToReplyTo.contains("all") &&
            !eligibleCharacters.contains { $0.id == character.id } // Avoid duplicates
        }
        eligibleCharacters.append(contentsOf: generalCharacters)
        
        // If no eligible characters yet, add at least one general character
        if eligibleCharacters.isEmpty {
            eligibleCharacters.append(buddy) // Default to Buddy
        }
        
        print("👥 Eligible characters for post \(post.id): \(eligibleCharacters.map { $0.name }.joined(separator: ", "))")
        return eligibleCharacters
    }
    
    // Get a single character for a post (for backward compatibility)
    static func characterFor(post: Post) -> AICharacter {
        return charactersFor(post: post).first ?? buddy
    }
    
    static func == (lhs: AICharacter, rhs: AICharacter) -> Bool {
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.avatar == rhs.avatar &&
               lhs.backgroundStory == rhs.backgroundStory &&
               lhs.replyFormat == rhs.replyFormat &&
               lhs.topicsToReplyTo == rhs.topicsToReplyTo
    }
}

enum AIResponseStatus: String, Codable {
    case pending
    case completed
    case failed
}

// Comment thread and reply models
struct CommentReply: Codable, Identifiable {
    let id: String
    let content: String
    let isUserReply: Bool // true for user replies, false for AI replies
    let timestamp: Date
    let status: AIResponseStatus
    var character: AICharacter? // only used for AI replies
    let replyToId: String? // ID of the comment this is replying to (for nested replies)
    
    init(id: String = UUID().uuidString, content: String, isUserReply: Bool, timestamp: Date = Date(), status: AIResponseStatus = .completed, character: AICharacter? = nil, replyToId: String? = nil) {
        self.id = id
        self.content = content
        self.isUserReply = isUserReply
        self.timestamp = timestamp
        self.status = status
        self.character = character
        self.replyToId = replyToId
    }
}

// ChatGPT API Models
struct ChatGPTRequest: Codable {
    let model: String
    let messages: [Message]
    let temperature: Double
    
    struct Message: Codable {
        let role: String
        let content: String
    }
}

struct ChatGPTResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

// Calorie tracking models for Statistics
struct CalorieEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let calories: Int
    let isGained: Bool  // true for food intake, false for workout/burned
    let postId: String
    let description: String
    
    init(calories: Int, isGained: Bool, postId: String, description: String, date: Date = Date(), id: UUID = UUID()) {
        self.id = id
        self.date = date
        self.calories = calories
        self.isGained = isGained
        self.postId = postId
        self.description = description
    }
}

class CalorieManager: ObservableObject {
    @Published var entries: [CalorieEntry] = []
    @Published var isLoading: Bool = false
    @Published var error: Error? = nil
    
    private var authManager: AuthManager?
    
    static let shared = CalorieManager()
    
    private init() {
        // Initialize with empty data
    }
    
    func setAuthManager(_ manager: AuthManager) {
        self.authManager = manager
    }
    
    // Add a new calorie entry
    func addEntry(calories: Int, isGained: Bool, postId: String, description: String) {
        let entry = CalorieEntry(calories: calories, isGained: isGained, postId: postId, description: description)
        entries.append(entry)
        
        // Sort entries by date, newest first
        entries.sort { $0.date > $1.date }
        
        // Save to Supabase
        Task {
            do {
                try await saveEntryToSupabase(entry)
            } catch {
                print("❌ Failed to save calorie entry to Supabase: \(error.localizedDescription)")
            }
        }
        
        objectWillChange.send()
    }
    
    // Save a single entry to Supabase
    private func saveEntryToSupabase(_ entry: CalorieEntry) async throws {
        guard let authManager = authManager,
              let currentUser = authManager.currentUser,
              let userId = currentUser.id else {
            throw NSError(domain: "CalorieManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("💾 Saving calorie entry to Supabase: \(entry.id.uuidString)")
        
        // Convert to DTO
        let entryDTO = entry.toDTO(userId: userId)
        
        // Insert into Supabase
        let query = try SupabaseConfig.shared.database
            .from("calorie_entries")
            .insert(entryDTO)
        
        try await query.execute()
        print("✅ Saved calorie entry to Supabase: \(entry.id.uuidString)")
    }
    
    // Fetch all entries from Supabase
    func fetchEntriesFromSupabase() async throws {
        guard let authManager = authManager,
              let currentUser = authManager.currentUser,
              let userId = currentUser.id else {
            throw NSError(domain: "CalorieManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            print("🔄 Fetching calorie entries from Supabase...")
            
            let query = SupabaseConfig.shared.database
                .from("calorie_entries")
                .select("*")
                .eq("user_id", value: userId)
                .order("date", ascending: false)
            
            let response = try await query.execute()
            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let entryDTOs = try decoder.decode([CalorieEntryDTO].self, from: data)
            
            print("✅ Fetched \(entryDTOs.count) calorie entries from Supabase")
            
            let fetchedEntries = entryDTOs.map { $0.toCalorieEntry() }
            
            await MainActor.run {
                entries = fetchedEntries
                isLoading = false
            }
            
        } catch {
            print("❌ Failed to fetch calorie entries: \(error.localizedDescription)")
            
            await MainActor.run {
                self.error = error
                isLoading = false
            }
            
            throw error
        }
    }
    
    // Clear all entries
    func clearEntries() {
        entries.removeAll()
        objectWillChange.send()
    }
    
    // Delete a specific entry by ID
    func deleteEntry(id: UUID) {
        entries.removeAll(where: { $0.id == id })
        
        // Delete from Supabase
        Task {
            do {
                try await deleteEntryFromSupabase(id)
            } catch {
                print("❌ Failed to delete calorie entry from Supabase: \(error.localizedDescription)")
            }
        }
        
        objectWillChange.send()
    }
    
    // Delete entry from Supabase
    private func deleteEntryFromSupabase(_ id: UUID) async throws {
        guard let authManager = authManager,
              let currentUser = authManager.currentUser else {
            throw NSError(domain: "CalorieManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("🗑️ Deleting calorie entry from Supabase: \(id.uuidString)")
        
        let query = try SupabaseConfig.shared.database
            .from("calorie_entries")
            .delete()
            .eq("id", value: id.uuidString)
        
        try await query.execute()
        print("✅ Deleted calorie entry from Supabase: \(id.uuidString)")
    }
    
    // Get total calories gained
    func totalCaloriesGained() -> Int {
        return entries.filter { $0.isGained }.reduce(0) { $0 + $1.calories }
    }
    
    // Get total calories burned
    func totalCaloriesBurned() -> Int {
        return entries.filter { !$0.isGained }.reduce(0) { $0 + $1.calories }
    }
    
    // Get net calories (gained - burned)
    func netCalories() -> Int {
        return totalCaloriesGained() - totalCaloriesBurned()
    }
    
    // Get percentage of daily goal (assuming 2000 calories daily goal)
    func percentageOfDailyGoal() -> Double {
        let dailyGoal = 2000
        return min(Double(netCalories()) / Double(dailyGoal), 1.0)
    }
    
    // Get percentage of calories gained vs total
    func percentageGained() -> Double {
        let total = totalCaloriesGained() + totalCaloriesBurned()
        return total > 0 ? Double(totalCaloriesGained()) / Double(total) : 0
    }
    
    // Get percentage of calories burned vs total
    func percentageBurned() -> Double {
        let total = totalCaloriesGained() + totalCaloriesBurned()
        return total > 0 ? Double(totalCaloriesBurned()) / Double(total) : 0
    }
    
    // Get total activity count
    func activityCount() -> Int {
        return entries.count
    }
    
    // Process a post directly to calculate calorie value
    func processPost(post: Post) {
        // Skip if no tag or not a food/fitness post
        guard let tag = post.tag, (tag == "Food" || tag == "Fitness") else { return }

        if tag == "Food" {
            Task {
                let calories = await calculateFoodCalories(content: post.content, image: post.image)
                addEntry(
                    calories: calories,
                    isGained: true,
                    postId: post.id,
                    description: "Food: \(post.content.prefix(30))..."
                )
            }
        } else if tag == "Fitness" {
            // Process fitness post
            let calories = calculateFitnessCalories(content: content)
            Task {
                let calories = await calculateFitnessCalories(content: post.content, image: post.image)
                addEntry(
                    calories: calories,
                    isGained: false,
                    postId: post.id,
                    description: "Workout: \(post.content.prefix(30))..."
                )
            }
        }
    }
    
    // Calculate calories for food post
    private func calculateFoodCalories(content: String, image: UIImage? = nil) async -> Int {
         // Create prompt for GPT-4o
        let prompt = """
        You are a calorie estimation expert. Given the following food description and/or image, estimate the total calories.
        Respond with ONLY a number representing the total calories (in cal not kcal). No explanation or additional text.
        Food description: \(content)
        """
        
        do {
            let api = ChatGPTAPI(apiKey: Config.openAIApiKey)
            let response = try await api.generateResponse(for: prompt, image: image)
            
            // Convert response to integer
            if let calories = Int(response.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return calories
            }
        } catch {
            print("❌ Failed to get calorie estimation from GPT: \(error.localizedDescription)")
        }
        
        return 350
    }
    
    // Calculate calories for fitness post
    private func calculateFitnessCalories(content: String, image: UIImage? = nil) async -> Int {
        // Create prompt for GPT-4
        let prompt = """
        Give the following workout description and/or image, estimate the calories burned.
        Respond with ONLY a number representing the calories burned (in cal not kcal). No explanation or additional text.
        Workout description: \(content)
        """
        
        do {
            let api = ChatGPTAPI(apiKey: Config.openAIApiKey)
            let response = try await api.generateResponse(for: prompt, image: image)
            
            // Convert response to integer
            if let calories = Int(response.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return calories
            }
        } catch {
            print("❌ Failed to get calorie estimation from GPT: \(error.localizedDescription)")
        }
        
        return 200
    }
    
    // Add test data with timestamps spread out
    func addTestData() {
        clearEntries()
        
        // Get the current date
        let now = Date()
        let calendar = Calendar.current
        
        // Add some food entries
        let foodDescriptions = [
            "Breakfast: Oatmeal with fruits",
            "Lunch: Grilled chicken salad",
            "Dinner: Steak with mashed potatoes",
            "Snack: Greek yogurt with honey",
            "Breakfast: Avocado toast with eggs"
        ]
        
        let foodCalories = [350, 420, 700, 180, 400]
        
        // Add some fitness entries
        let fitnessDescriptions = [
            "Morning run: 30 minutes",
            "Gym session: Upper body workout",
            "Evening yoga: Relaxation session",
            "HIIT workout: 20 minutes intense",
            "Walking: 45 minutes in the park"
        ]
        
        let fitnessCalories = [300, 280, 180, 350, 170]
        
        // Add entries with different timestamps
        for i in 0..<5 {
            // Food entries - starting from 5 days ago
            if let foodDate = calendar.date(byAdding: .day, value: -5+i, to: now) {
                let entry = CalorieEntry(
                    calories: foodCalories[i],
                    isGained: true,
                    postId: "test-food-\(i)",
                    description: foodDescriptions[i],
                    date: foodDate
                )
                entries.append(entry)
            }
            
            // Fitness entries - starting from 5 days ago
            if let fitnessDate = calendar.date(byAdding: .hour, value: 6, to: calendar.date(byAdding: .day, value: -5+i, to: now) ?? now) {
                let entry = CalorieEntry(
                    calories: fitnessCalories[i],
                    isGained: false, 
                    postId: "test-fitness-\(i)",
                    description: fitnessDescriptions[i],
                    date: fitnessDate
                )
                entries.append(entry)
            }
        }
        
        // Sort entries by date
        entries.sort { $0.date > $1.date }
        objectWillChange.send()
    }
}

// User authentication models
struct User: Codable {
    let id: String?
    let email: String
    let username: String
    let createdAt: Date
    
    // Optional profile information
    var fullName: String?
    var profileImageUrl: String?
    var bio: String?
}

// Authentication states
enum AuthState {
    case loading
    case signedOut
    case signedIn
}
