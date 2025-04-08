import Foundation
import SwiftUI
import Combine

// Extension to handle ISO8601 dates with fractional seconds
extension JSONDecoder.DateDecodingStrategy {
    static var iso8601WithFractionalSeconds: JSONDecoder.DateDecodingStrategy {
        return .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            
            // Configure date formatter for ISO8601 with fractional seconds
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            if let date = formatter.date(from: string) {
                return date
            }
            
            // Try again without fractional seconds if that fails
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: string) {
                return date
            }
            
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid date format: \(string)"
            )
        }
    }
}

// Add this struct before the PostsManager class
struct PostInsertDTO: Encodable {
    let id: String
    let user_id: String
    let content: String
    let tag: String?
    let username: String
    let fitness_info: String?
}

@MainActor
class PostsManager: ObservableObject {
    @Published var posts: [Post]
    @Published var isLoading = false
    @Published var error: String?
    
    // Reference to auth manager to get current user
    private var authManager: AuthManager?
    
    // Subscribers
    private var cancellables = Set<AnyCancellable>()
    
    // Shared singleton instance
    static let shared = PostsManager()
    
    // Last time posts were fetched
    private var lastFetchTime: Date? = nil
    // Minimum time between fetches (5 seconds)
    private let minFetchInterval: TimeInterval = 5.0
    
    // Cache for image URLs - persists between sessions
    private var imageURLCache: [String: String] = [:]
    private let imageURLCacheKey = "FitMunityImageURLCache"
    
    // In-memory image cache to avoid reloading images
    private var imageCache: [String: UIImage] = [:]
    
    init(initialPosts: [Post] = []) {
        self.posts = initialPosts
        print("📊 DEBUG: PostsManager initialized with \(initialPosts.count) posts")
        
        // Load image URL cache from UserDefaults
        if let cachedData = UserDefaults.standard.data(forKey: imageURLCacheKey),
           let cachedURLs = try? JSONDecoder().decode([String: String].self, from: cachedData) {
            self.imageURLCache = cachedURLs
            print("🔄 DEBUG: Loaded \(cachedURLs.count) image URLs from cache")
        }
        
        // Debug: Print all posts and their IDs
        for (index, post) in initialPosts.enumerated() {
            print("📱 Post #\(index + 1) - ID: \(post.id), Content: \(post.content.prefix(30))...")
        }
        
        // Listen for auth state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChanged),
            name: NSNotification.Name("AuthStateChanged"),
            object: nil
        )
        
        // Listen for memory warnings to clear image cache if needed
        NotificationCenter.default.addObserver(
            self, 
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification, 
            object: nil
        )
    }
    
    // Set auth manager reference
    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }
    
    // Handle auth state changes
    @objc private func handleAuthStateChanged() {
        Task {
            if let authManager = authManager, authManager.authState == .signedIn {
                // User signed in, fetch posts
                try? await fetchPosts()
            } else {
                // User signed out, clear posts
                await MainActor.run {
                    self.posts = []
                }
            }
        }
    }
    
    // Handle memory warnings by clearing the image cache
    @objc private func handleMemoryWarning() {
        print("⚠️ Memory warning received, clearing image cache")
        imageCache.removeAll()
    }
    
    // MARK: - Supabase Integration
    
    // Fetch all posts from Supabase
    func fetchPosts() async throws {
        // Check if we've fetched recently to prevent constant polling
        if let lastFetch = lastFetchTime, Date().timeIntervalSince(lastFetch) < minFetchInterval {
            // Skip this fetch if it's too soon
            return
        }
        
        // Update last fetch time
        lastFetchTime = Date()
        
        await MainActor.run {
            isLoading = true
            error = nil
        }
        
        do {
            print("🔄 Fetching posts from Supabase...")
            
            // Fetch posts without trying to include nested data
            let query = SupabaseConfig.shared.database
                .from("posts")
                .select("*")
                .eq("is_deleted", value: false)
                .order("time_created", ascending: false)
            
            let response = try await query.execute()
            let data = response.data
            
            // Debug: Print the raw response data
            if let dataString = String(data: data, encoding: .utf8) {
                print("📊 DEBUG: Raw JSON response: \(dataString)")
            }
            
            // Try a manual approach instead of using decoder
            do {
                // Convert data to JSON array
                if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    print("✅ Successfully parsed JSON array with \(jsonArray.count) posts")
                    
                    // Convert manually to domain models
                    var domainPosts: [Post] = []
                    
                    for postDict in jsonArray {
                        guard let id = postDict["id"] as? String,
                              let content = postDict["content"] as? String,
                              let likeCount = postDict["like_count"] as? Int,
                              let commentCount = postDict["comment_count"] as? Int,
                              let username = postDict["username"] as? String,
                              let timeCreatedString = postDict["time_created"] as? String else {
                            print("⚠️ Skipping post due to missing required fields")
                            continue
                        }
                        
                        // Parse the ISO8601 date
                        let dateFormatter = ISO8601DateFormatter()
                        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                        
                        let timeCreated = dateFormatter.date(from: timeCreatedString) ?? Date()
                        let fitnessInfo = postDict["fitness_info"] as? String
                        let tag = postDict["tag"] as? String
                        
                        // Create the post model
                        let post = Post(
                            id: id,
                            content: content,
                            likeCount: likeCount,
                            commentCount: commentCount,
                            imageName: nil, 
                            image: nil,
                            timeAgo: formatTimeAgo(from: timeCreated),
                            fitnessInfo: fitnessInfo,
                            aiResponse: nil,
                            tag: tag,
                            username: username
                        )
                        
                        domainPosts.append(post)
                        
                        // Load AI responses and images asynchronously
                        Task {
                            if let aiResponse = await fetchAIResponseForPost(id: id) {
                                if let index = self.posts.firstIndex(where: { $0.id == id }) {
                                    var updatedPost = self.posts[index]
                                    
                                    let newPost = Post(
                                        id: updatedPost.id,
                                        content: updatedPost.content,
                                        likeCount: updatedPost.likeCount,
                                        commentCount: updatedPost.commentCount,
                                        imageName: updatedPost.imageName,
                                        image: updatedPost.image,
                                        timeAgo: updatedPost.timeAgo,
                                        fitnessInfo: updatedPost.fitnessInfo,
                                        aiResponse: aiResponse,
                                        tag: updatedPost.tag,
                                        username: updatedPost.username
                                    )
                                    
                                    await MainActor.run {
                                        self.posts[index] = newPost
                                    }
                                }
                            }
                            
                            // Also load the first image if any
                            let image = await fetchFirstImageForPost(id: id)
                            if let image = image, let index = self.posts.firstIndex(where: { $0.id == id }) {
                                await MainActor.run {
                                    var updatedPost = self.posts[index]
                                    
                                    let newPost = Post(
                                        id: updatedPost.id,
                                        content: updatedPost.content,
                                        likeCount: updatedPost.likeCount,
                                        commentCount: updatedPost.commentCount,
                                        imageName: updatedPost.imageName,
                                        image: image,
                                        timeAgo: updatedPost.timeAgo,
                                        fitnessInfo: updatedPost.fitnessInfo,
                                        aiResponse: updatedPost.aiResponse,
                                        tag: updatedPost.tag,
                                        username: updatedPost.username
                                    )
                                    
                                    self.posts[index] = newPost
                                }
                            }
                        }
                    }
                    
                    // Update the posts array immediately with what we have
                    await MainActor.run {
                        self.posts = domainPosts
                        self.isLoading = false
                        print("✅ Fetched \(domainPosts.count) posts from Supabase")
                        
                        // Debug: Print all post IDs to check uniqueness
                        var postIds = Set<String>()
                        var duplicateIds = Set<String>()
                        
                        for (index, post) in domainPosts.enumerated() {
                            print("🆔 Post #\(index + 1) - ID: \(post.id)")
                            
                            if postIds.contains(post.id) {
                                duplicateIds.insert(post.id)
                                print("⚠️ DUPLICATE POST ID DETECTED: \(post.id)")
                            } else {
                                postIds.insert(post.id)
                            }
                        }
                        
                        if !duplicateIds.isEmpty {
                            print("❌ ERROR: Found \(duplicateIds.count) duplicate post IDs: \(duplicateIds)")
                        }
                    }
                    
                    return
                } else {
                    print("❌ Failed to parse JSON as array")
                }
            } catch {
                print("❌ Error with manual JSON parsing: \(error.localizedDescription)")
            }
            
            // Fall back to decoder if needed
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Decode the posts as a flat array
            let decodedPosts = try decoder.decode([PostDTO].self, from: data)
            
            // Convert DTOs to domain models
            var domainPosts: [Post] = []
            
            for postDTO in decodedPosts {
                // Create the post model
                let post = Post(
                    id: postDTO.id,
                    content: postDTO.content,
                    likeCount: postDTO.like_count,
                    commentCount: postDTO.comment_count,
                    imageName: nil, // We'll use remote URLs instead
                    image: nil, // We'll load images separately
                    timeAgo: formatTimeAgo(from: postDTO.time_created),
                    fitnessInfo: postDTO.fitness_info,
                    aiResponse: nil,
                    tag: postDTO.tag,
                    username: postDTO.username
                )
                
                domainPosts.append(post)
            }
            
            // Update the posts array
            await MainActor.run {
                self.posts = domainPosts
                self.isLoading = false
                print("✅ Fetched \(domainPosts.count) posts from Supabase")
                
                // Debug: Print all post IDs to check uniqueness
                var postIds = Set<String>()
                var duplicateIds = Set<String>()
                
                for (index, post) in domainPosts.enumerated() {
                    print("🆔 Post #\(index + 1) - ID: \(post.id)")
                    
                    if postIds.contains(post.id) {
                        duplicateIds.insert(post.id)
                        print("⚠️ DUPLICATE POST ID DETECTED: \(post.id)")
                    } else {
                        postIds.insert(post.id)
                    }
                }
                
                if !duplicateIds.isEmpty {
                    print("❌ ERROR: Found \(duplicateIds.count) duplicate post IDs: \(duplicateIds)")
                }
            }
            
            // Load additional data asynchronously
            for post in domainPosts {
                Task {
                    async let aiResponse = fetchAIResponseForPost(id: post.id)
                    async let image = fetchFirstImageForPost(id: post.id)
                    
                    if let loadedResponse = await aiResponse,
                       let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        await MainActor.run {
                            var updatedPost = self.posts[index]
                            updatedPost.aiResponse = loadedResponse
                            self.posts[index] = updatedPost
                        }
                    }
                    
                    if let loadedImage = await image,
                       let index = self.posts.firstIndex(where: { $0.id == post.id }) {
                        await MainActor.run {
                            var updatedPost = self.posts[index]
                            updatedPost.image = loadedImage
                            self.posts[index] = updatedPost
                        }
                    }
                }
            }
        } catch {
            await MainActor.run {
                self.error = "Failed to fetch posts: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Error fetching posts: \(error.localizedDescription)")
            }
        }
    }
    
    // Helper to fetch the first AI response for a post
    private func fetchAIResponseForPost(id: String) async -> AIResponse? {
        do {
            // Fetch AI responses for this post
            let aiResponseQuery = SupabaseConfig.shared.database
                .from("ai_responses")
                .select("*")
                .eq("post_id", value: id)
                .limit(1)
            
            let aiResponseData = try await aiResponseQuery.execute().data
            
            // Debug the AI response data and check if empty
            let dataString = String(data: aiResponseData, encoding: .utf8) ?? "[]"
            // print("📊 DEBUG: AI response for post \(id): \(dataString)")
            
            if dataString == "[]" {
                return nil
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let aiResponses = try decoder.decode([AIResponseDTO].self, from: aiResponseData)
            
            // Convert to domain model
            if let firstResponse = aiResponses.first {
                return firstResponse.toAIResponse()
            }
        } catch {
            print("❌ Error fetching AI response: \(error.localizedDescription)")
        }
        return nil
    }
    
    // Helper to fetch the first image for a post
    private func fetchFirstImageForPost(id: String) async -> UIImage? {
        print("🔍 DEBUG: Fetching image for post ID: \(id)")
        
        // First check in-memory image cache
        if let cachedImage = imageCache[id] {
            print("💾 DEBUG: Using cached image from memory for post ID: \(id)")
            return cachedImage
        }
        
        // Then check if we have a cached URL for this post
        if let cachedURL = imageURLCache[id] {
            print("🎯 DEBUG: Found cached image URL for post ID: \(id): \(cachedURL)")
            
            // Validate the cached URL isn't empty
            if cachedURL.isEmpty {
                print("⚠️ Cached URL is empty, removing from cache")
                imageURLCache.removeValue(forKey: id)
                saveImageURLCache()
            } else {
                if let loadedImage = await loadImage(from: cachedURL) {
                    print("✅ DEBUG: Successfully loaded image from cached URL")
                    // Store in memory cache
                    imageCache[id] = loadedImage
                    return loadedImage
                } else {
                    print("⚠️ DEBUG: Failed to load image from cached URL, falling back to database query")
                    // Remove invalid URL from cache
                    imageURLCache.removeValue(forKey: id)
                    saveImageURLCache()
                }
            }
        }
        
        // If no cached URL or loading failed, fetch from Supabase
        do {
            // Fetch image URLs for this post
            let imageQuery = SupabaseConfig.shared.database
                .from("post_images")
                .select("*")
                .eq("post_id", value: id)
                .limit(1)
            
            let imageResponse = try await imageQuery.execute()
            let imageData = imageResponse.data
            
            // Log the raw data for debugging
            if let dataString = String(data: imageData, encoding: .utf8) {
                print("📊 DEBUG: Image data for post \(id): \(dataString)")
                
                if dataString == "[]" {
                    print("ℹ️ No images found for post ID: \(id)")
                    return nil
                }
                
                // Manually extract the image URL to bypass JSON decoding issues
                if let extractedURL = extractImageURLFromJSON(dataString) {
                    // Clean the URL - remove any quotes and whitespace
                    let cleanURL = extractedURL.trimmingCharacters(in: .whitespacesAndNewlines)
                                              .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    
                    print("🔧 DEBUG: Manually extracted and cleaned image URL: \(cleanURL)")
                    
                    // Cache this URL for future use - sanitized
                    let sanitizedURL = sanitizeImageURL(cleanURL)
                    imageURLCache[id] = sanitizedURL
                    saveImageURLCache()
                    print("🏪 DEBUG: Cached sanitized image URL: \(sanitizedURL)")
                    
                    // Load the image from the extracted URL
                    if let image = await loadImage(from: cleanURL) {
                        print("✅ Successfully loaded image via extractedURL")
                        // Store in memory cache
                        imageCache[id] = image
                        return image
                    } else {
                        print("⚠️ Failed to load image from extracted URL, trying sanitized version")
                        if let image = await loadImage(from: sanitizedURL) {
                            print("✅ Successfully loaded image from sanitized URL")
                            // Store in memory cache
                            imageCache[id] = image
                            return image
                        }
                    }
                }
            }
            
            // If manual extraction failed, try with decoder
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601WithFractionalSeconds
            
            do {
                let images = try decoder.decode([PostImageDTO].self, from: imageData)
                
                // Log how many images were found
                print("🖼️ DEBUG: Found \(images.count) images for post ID: \(id)")
                
                // Load the first image if any
                if let firstImage = images.first {
                    print("🔗 DEBUG: Loading image from URL: \(firstImage.image_url)")
                    
                    // Cache this URL for future use - sanitized
                    let sanitizedURL = sanitizeImageURL(firstImage.image_url)
                    imageURLCache[id] = sanitizedURL
                    saveImageURLCache()
                    print("🏪 DEBUG: Cached sanitized image URL: \(sanitizedURL)")
                    
                    if let image = await loadImage(from: firstImage.image_url) {
                        // Store in memory cache
                        imageCache[id] = image
                        return image
                    }
                }
            } catch {
                print("⚠️ DEBUG: JSON decoding error: \(error.localizedDescription)")
            }
        } catch {
            print("❌ Error fetching images: \(error.localizedDescription)")
        }
        return nil
    }
    
    // Helper to extract image URL from JSON string
    private func extractImageURLFromJSON(_ jsonString: String) -> String? {
        print("📄 DEBUG: Raw JSON for URL extraction: \(jsonString)")
        
        // Direct regex to extract URL from the image_url field
        let pattern = "\"image_url\"\\s*:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            print("❌ Failed to create regex for URL extraction")
            return nil
        }
        
        let nsString = jsonString as NSString
        let matches = regex.matches(in: jsonString, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = matches.first {
            // Extract the URL from the capture group
            let urlRange = match.range(at: 1)
            let extractedURL = nsString.substring(with: urlRange)
            print("💯 DEBUG: Successfully extracted URL: \(extractedURL)")
            return extractedURL
        }
        
        print("⚠️ No URL match found in JSON")
        return nil
    }
    
    // Add a new post to Supabase
    func addPost(content: String, image: UIImage? = nil, tag: String? = nil, username: String = "FitMunity User") async throws {
        // Ensure user is signed in
        guard let authManager = authManager,
              let currentUser = authManager.currentUser,
              let userIdString = currentUser.id,
              let userId = UUID(uuidString: userIdString) else {
            throw NSError(domain: "PostsManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        print("📝 DEBUG: Adding new post with content: \(content.prefix(20))...")
        
        // Generate a new UUID for the post
        let postId = UUID().uuidString
        
        // Create the post insertion DTO
        let postInsertDTO = PostInsertDTO(
            id: postId,
            user_id: userId.uuidString,
            content: content,
            tag: tag,
            username: username,
            fitness_info: nil
        )
        
        // Create the post in Supabase
        let query = try SupabaseConfig.shared.database
            .from("posts")
            .insert(postInsertDTO)
        
        do {
            // Execute the query
            try await query.execute()
            print("✅ Created post in Supabase with ID: \(postId)")
            
            // If there's an image, upload it to storage
            if let image = image {
                // Upload image to Supabase Storage
                let imageUrl = try await uploadImage(image: image, postId: postId)
                
                // Create entry in post_images table
                let imageQuery = try SupabaseConfig.shared.database
                    .from("post_images")
                    .insert([
                        "id": UUID().uuidString,
                        "post_id": postId,
                        "image_url": imageUrl
                    ])
                
                try await imageQuery.execute()
                print("✅ Added image URL to post: \(imageUrl)")
                
                // Save image URL to cache - ensuring we sanitize the URL
                // This ensures that the URL is properly formed and can be used later
                let sanitizedURL = sanitizeImageURL(imageUrl)
                imageURLCache[postId] = sanitizedURL
                saveImageURLCache()
                
                // Also store the image in the in-memory cache
                imageCache[postId] = image
                
                print("🏪 DEBUG: Stored image URL for post ID: \(postId) in persistent cache: \(sanitizedURL)")
                print("💾 DEBUG: Stored image in memory cache for post ID: \(postId)")
            }
            
            // Create a new post object for the UI
            let newPost = Post(
                id: postId,
                content: content,
                likeCount: 0,
                commentCount: 0,
                imageName: nil,
                image: image, // We keep the image in memory for immediate display
                timeAgo: "Just now",
                fitnessInfo: nil,
                aiResponse: nil,
                tag: tag,
                username: username
            )
            
            // Make sure the image is stored in our caches if provided
            if let image = image {
                // Store in memory cache immediately
                imageCache[postId] = image
                print("💾 DEBUG: Stored new post image in memory cache for immediate use")
            }
            
            // Add to the beginning of the array
            await MainActor.run {
                posts.insert(newPost, at: 0)
                print("📊 DEBUG: Posts array now has \(posts.count) posts")
            }
            
            // Process the post for calorie tracking if it's a food or fitness post
            if let tag = tag, (tag == "Food" || tag == "Fitness") {
                CalorieManager.shared.processPost(post: newPost)
            }
        } catch {
            print("❌ Failed to add post: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Like a post in Supabase
    func likePost(id: String) async {
        // Ensure user is signed in
        guard let authManager = authManager,
              let currentUser = authManager.currentUser,
              let userId = currentUser.id else {
            print("⚠️ Cannot like post: User not authenticated")
            return
        }
        
        do {
            // First, check if the user has already liked this post
            let checkQuery = SupabaseConfig.shared.database
                .from("post_likes")
                .select("*")
                .eq("post_id", value: id)
                .eq("user_id", value: userId)
            
            let checkResponse = try await checkQuery.execute()
            let checkData = checkResponse.data
            
            // MARK: - Improved error handling for decoding
            // First check if we have an empty array
            if let dataStr = String(data: checkData, encoding: .utf8), dataStr == "[]" {
                await addLike(postId: id, userId: userId)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let likes = try decoder.decode([PostLikeDTO].self, from: checkData)
                
                if likes.isEmpty {
                    await addLike(postId: id, userId: userId)
                } else {
                    await removeLike(postId: id, likeId: likes[0].id)
                }
            } catch {
                print("⚠️ Warning: Could not decode likes data, assuming no likes: \(error)")
                await addLike(postId: id, userId: userId)
            }
        } catch {
            print("❌ Error updating like status: \(error.localizedDescription)")
        }
    }
    
    // Helper to add a like
    private func addLike(postId: String, userId: String) async {
        do {
            let insertQuery = try SupabaseConfig.shared.database
                .from("post_likes")
                .insert([
                    "post_id": postId,
                    "user_id": userId
                ])
            
            try await insertQuery.execute()
            
            // Update like count in posts table by computing the new value locally
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let currentLikeCount = posts[index].likeCount
                let newLikeCount = currentLikeCount + 1
                
                let updateQuery = try SupabaseConfig.shared.database
                    .from("posts")
                    .update(["like_count": newLikeCount])
                    .eq("id", value: postId)
                
                try await updateQuery.execute()
                
                // Update local state
                await MainActor.run {
                    var updatedPost = posts[index]
                    let post = Post(
                        id: updatedPost.id,
                        content: updatedPost.content,
                        likeCount: newLikeCount,
                        commentCount: updatedPost.commentCount,
                        imageName: updatedPost.imageName,
                        image: updatedPost.image,
                        timeAgo: updatedPost.timeAgo,
                        fitnessInfo: updatedPost.fitnessInfo,
                        aiResponse: updatedPost.aiResponse,
                        tag: updatedPost.tag,
                        username: updatedPost.username
                    )
                    
                    posts[index] = post
                    print("👍 Liked post: \(postId)")
                }
            }
        } catch {
            print("❌ Error adding like: \(error.localizedDescription)")
        }
    }
    
    // Helper to remove a like
    private func removeLike(postId: String, likeId: String) async {
        do {
            let deleteQuery = try SupabaseConfig.shared.database
                .from("post_likes")
                .delete()
                .eq("id", value: likeId)
            
            try await deleteQuery.execute()
            
            // Update like count in posts table by computing the new value locally
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                let currentLikeCount = posts[index].likeCount
                let newLikeCount = max(0, currentLikeCount - 1) // Ensure we don't go below 0
                
                let updateQuery = try SupabaseConfig.shared.database
                    .from("posts")
                    .update(["like_count": newLikeCount])
                    .eq("id", value: postId)
                
                try await updateQuery.execute()
                
                // Update local state
                await MainActor.run {
                    var updatedPost = posts[index]
                    let post = Post(
                        id: updatedPost.id,
                        content: updatedPost.content,
                        likeCount: newLikeCount,
                        commentCount: updatedPost.commentCount,
                        imageName: updatedPost.imageName,
                        image: updatedPost.image,
                        timeAgo: updatedPost.timeAgo,
                        fitnessInfo: updatedPost.fitnessInfo,
                        aiResponse: updatedPost.aiResponse,
                        tag: updatedPost.tag,
                        username: updatedPost.username
                    )
                    
                    posts[index] = post
                    print("👎 Unliked post: \(postId)")
                }
            }
        } catch {
            print("❌ Error removing like: \(error.localizedDescription)")
        }
    }
    
    // Delete a post by ID from Supabase
    func deletePost(id: String) async {
        // Ensure user is signed in
        guard let authManager = authManager, authManager.currentUser != nil else {
            print("⚠️ Cannot delete post: User not authenticated")
            return
        }
        
        print("🗑️ DEBUG: Attempting to delete post with ID: \(id)")
        
        do {
            // Set is_deleted flag to true instead of actually deleting
            let query = try SupabaseConfig.shared.database
                .from("posts")
                .update(["is_deleted": true])
                .eq("id", value: id)
            
            try await query.execute()
            
            // Remove the post from the local array
            await MainActor.run {
                posts.removeAll(where: { $0.id == id })
                print("📊 DEBUG: Posts array now has \(posts.count) posts after deletion")
            }
        } catch {
            print("❌ Error deleting post: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Helper Methods
    
    // Upload an image to Supabase Storage
    private func uploadImage(image: UIImage, postId: String) async throws -> String {
        print("📸 Uploading image for post: \(postId)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "PostsManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        // Create a unique filename
        let filename = "\(postId)/\(UUID().uuidString).jpg"
        
        // Upload to storage (removed the extra fileOptions parameter)
        try await SupabaseConfig.shared.client.storage
            .from("post-images")
            .upload(
                path: filename,
                file: imageData
            )
        
        // Get the public URL and convert to String
        let imageUrl = try SupabaseConfig.shared.client.storage
            .from("post-images")
            .getPublicURL(path: filename)
        
        print("✅ Uploaded image to: \(imageUrl)")
        return imageUrl.absoluteString
    }
    
    // Load an image from a URL
    private func loadImage(from urlString: String) async -> UIImage? {
        print("🔎 DEBUG: Attempting to load image from URL string: \(urlString)")
        
        // Check for empty URL
        if urlString.isEmpty {
            print("⚠️ Empty URL string provided")
            return nil
        }
        
        // Handle URL encoding/escaping issues
        var processedURLString = urlString
        
        // Replace any unescaped spaces with %20
        if processedURLString.contains(" ") {
            processedURLString = processedURLString.replacingOccurrences(of: " ", with: "%20")
        }
        
        // Try to create a URL
        guard let url = URL(string: processedURLString) else {
            print("⚠️ Invalid image URL: \(processedURLString)")
            
            // Try creating URL with percent encoding
            if let encodedString = processedURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
               let encodedURL = URL(string: encodedString) {
                print("🔧 DEBUG: Created URL with percent encoding: \(encodedURL)")
                return await loadImageFromURL(encodedURL)
            }
            
            // Try normalizing the URL if it contains uppercase characters
            if processedURLString.contains(where: { $0.isUppercase }) {
                let normalizedURLString = processedURLString.lowercased()
                print("🔧 DEBUG: Trying lowercase URL: \(normalizedURLString)")
                
                guard let normalizedURL = URL(string: normalizedURLString) else {
                    print("⚠️ Still invalid URL after normalization")
                    return nil
                }
                
                return await loadImageFromURL(normalizedURL)
            }
            
            // All attempts failed
            print("❌ All URL creation attempts failed")
            return nil
        }
        
        // If we got here, we have a valid URL
        return await loadImageFromURL(url)
    }
    
    // Helper to load image from a URL
    private func loadImageFromURL(_ url: URL) async -> UIImage? {
        print("🖼️ DEBUG: Loading image from URL: \(url)")
        
        // Configure session with appropriate settings for Supabase
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 5 // Limit connections to avoid throttling
        config.timeoutIntervalForResource = 30 // Increase timeout for slow connections
        config.waitsForConnectivity = true
        
        // Create custom session for this request
        let session = URLSession(configuration: config)
        
        do {
            // Create request with headers
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            
            // Add headers that might help with Supabase storage
            if url.absoluteString.contains("supabase") {
                request.addValue("*/*", forHTTPHeaderField: "Accept")
                request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
            }
            
            print("🌐 DEBUG: Sending request with URL: \(url)")
            let (data, response) = try await session.data(for: request)
            
            // Log HTTP response for debugging
            if let httpResponse = response as? HTTPURLResponse {
                print("🖼️ DEBUG: Image load HTTP status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    print("⚠️ Image load failed with status code: \(httpResponse.statusCode)")
                    
                    // Print response headers for debugging
                    print("📋 Response headers:")
                    for (key, value) in httpResponse.allHeaderFields {
                        print("   \(key): \(value)")
                    }
                    
                    return nil
                }
            }
            
            // Save data to file for debugging
            do {
                let tempDir = FileManager.default.temporaryDirectory
                let tempFile = tempDir.appendingPathComponent("debug_image_\(UUID().uuidString).jpg")
                try data.write(to: tempFile)
                print("💾 DEBUG: Saved image data to: \(tempFile)")
            } catch {
                print("⚠️ Failed to save debug file: \(error)")
            }
            
            if let image = UIImage(data: data) {
                print("✅ Successfully loaded image from URL, size: \(image.size)")
                return image
            } else {
                print("⚠️ Could not convert data to image. Data size: \(data.count) bytes")
                if data.count < 100 && data.count > 0 {
                    // Print data as string for small responses (likely error messages)
                    print("📄 Data content: \(String(data: data, encoding: .utf8) ?? "Not UTF-8 text")")
                }
                return nil
            }
        } catch {
            print("❌ Failed to load image: \(error.localizedDescription)")
            return nil
        }
    }
    
    // Format a date to a timeAgo string
    private func formatTimeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfMonth, .month, .year], from: date, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1y ago" : "\(year)y ago"
        } else if let month = components.month, month > 0 {
            return month == 1 ? "1mo ago" : "\(month)mo ago"
        } else if let week = components.weekOfMonth, week > 0 {
            return week == 1 ? "1w ago" : "\(week)w ago"
        } else if let day = components.day, day > 0 {
            return day == 1 ? "1d ago" : "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1h ago" : "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1m ago" : "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
    
    // Debug method to print the current state of posts
    func debugPostsState(context: String) {
        print("🔍 DEBUG: PostsManager state - \(context)")
        print("📊 DEBUG: Total posts: \(posts.count)")
        
        if posts.isEmpty {
            print("⚠️ DEBUG: Posts array is empty!")
        } else {
            for (index, post) in posts.enumerated() {
                print("📌 DEBUG: Post[\(index)] - ID: \(post.id), Content: \(post.content.prefix(20))..., Comments: \(post.commentCount)")
            }
        }
    }
    
    // Add comment to a post (for compatibility)
    func addComment(to postId: String) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            let newCommentCount = updatedPost.commentCount + 1
            
            let post = Post(
                id: updatedPost.id,
                content: updatedPost.content,
                likeCount: updatedPost.likeCount,
                commentCount: newCommentCount,
                imageName: updatedPost.imageName,
                image: updatedPost.image,
                timeAgo: updatedPost.timeAgo,
                fitnessInfo: updatedPost.fitnessInfo,
                aiResponse: updatedPost.aiResponse,
                tag: updatedPost.tag,
                username: updatedPost.username
            )
            
            posts[index] = post
            print("💬 DEBUG: Added comment to post \(postId), new count: \(newCommentCount)")
            
            // Also update in Supabase
            Task {
                do {
                    let query = try SupabaseConfig.shared.database
                        .from("posts")
                        .update(["comment_count": newCommentCount])
                        .eq("id", value: postId)
                    
                    try await query.execute()
                } catch {
                    print("❌ Error updating comment count: \(error.localizedDescription)")
                }
            }
        } else {
            print("⚠️ DEBUG: Could not find post with ID \(postId) to add comment")
        }
    }
    
    // Increment comment count
    func incrementCommentCount(for postId: String) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            let newCommentCount = updatedPost.commentCount + 1
            
            let post = Post(
                id: updatedPost.id,
                content: updatedPost.content,
                likeCount: updatedPost.likeCount,
                commentCount: newCommentCount,
                imageName: updatedPost.imageName,
                image: updatedPost.image,
                timeAgo: updatedPost.timeAgo,
                fitnessInfo: updatedPost.fitnessInfo,
                aiResponse: updatedPost.aiResponse,
                tag: updatedPost.tag,
                username: updatedPost.username
            )
            
            posts[index] = post
            print("💬 DEBUG: Incremented comment count for post \(postId), new count: \(newCommentCount)")
            
            // Also update in Supabase
            Task {
                do {
                    let query = try SupabaseConfig.shared.database
                        .from("posts")
                        .update(["comment_count": newCommentCount])
                        .eq("id", value: postId)
                    
                    try await query.execute()
                } catch {
                    print("❌ Error updating comment count: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Set comment count
    func setCommentCount(for postId: String, count: Int) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            var updatedPost = posts[index]
            
            let post = Post(
                id: updatedPost.id,
                content: updatedPost.content,
                likeCount: updatedPost.likeCount,
                commentCount: count,
                imageName: updatedPost.imageName,
                image: updatedPost.image,
                timeAgo: updatedPost.timeAgo,
                fitnessInfo: updatedPost.fitnessInfo,
                aiResponse: updatedPost.aiResponse,
                tag: updatedPost.tag,
                username: updatedPost.username
            )
            
            posts[index] = post
            print("💬 DEBUG: Set comment count for post \(postId) to \(count)")
            
            // Also update in Supabase
            Task {
                do {
                    let query = try SupabaseConfig.shared.database
                        .from("posts")
                        .update(["comment_count": count])
                        .eq("id", value: postId)
                    
                    try await query.execute()
                } catch {
                    print("❌ Error updating comment count: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Public interface to fetch image for a post with retries
    func fetchImageForPost(id: String) async -> UIImage? {
        print("🔍 Public method: Fetching image for post ID: \(id)")
        
        // First, check in-memory cache
        if let cachedImage = imageCache[id] {
            print("✅ Cache hit: Using cached image from memory for post ID: \(id)")
            return cachedImage
        }
        
        // Try to fetch the image with up to 3 retries
        for attempt in 1...3 {
            print("🔄 Attempt \(attempt) to fetch image for post ID: \(id)")
            
            if let image = await fetchFirstImageForPost(id: id) {
                print("✅ Successfully fetched image on attempt \(attempt) for post ID: \(id)")
                // Add to memory cache to avoid future fetches
                imageCache[id] = image
                return image
            }
            
            if attempt < 3 {
                // Wait before retrying (exponential backoff)
                let delaySeconds = Double(attempt) * 0.5
                print("⏱️ Waiting \(delaySeconds) seconds before retry...")
                
                do {
                    if #available(iOS 16.0, *) {
                        try await Task.sleep(for: .seconds(delaySeconds))
                    } else {
                        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                    }
                } catch {
                    print("⚠️ Sleep interrupted: \(error.localizedDescription)")
                }
            }
        }
        
        print("❌ Failed to fetch image after 3 attempts for post ID: \(id)")
        return nil
    }
    
    // Helper to sanitize image URL for storage
    func sanitizeImageURL(_ url: String) -> String {
        print("🧹 DEBUG: Sanitizing URL: \(url)")
        
        var sanitizedURL = url
        
        // Check if this is a Supabase URL and needs special handling
        if url.contains("supabase") {
            print("🔧 DEBUG: Sanitizing Supabase URL")
            
            // Extract the base URL and storage path
            if let baseURLEndIndex = url.range(of: "/object/public/")?.upperBound {
                let baseURL = String(url.prefix(upTo: baseURLEndIndex))
                let storagePath = String(url.suffix(from: baseURLEndIndex))
                
                print("🧹 DEBUG: Base URL: \(baseURL)")
                print("🧹 DEBUG: Storage path: \(storagePath)")
                
                // Convert any uppercase characters to lowercase in the storage path
                let sanitizedPath = storagePath.lowercased()
                
                sanitizedURL = baseURL + sanitizedPath
            }
        }
        
        // Replace any double slashes (except for https://)
        if sanitizedURL.contains("//") {
            var components = sanitizedURL.components(separatedBy: "://")
            if components.count > 1 {
                let protocolPart = components[0]
                var path = components[1]
                
                while path.contains("//") {
                    path = path.replacingOccurrences(of: "//", with: "/")
                }
                
                sanitizedURL = protocolPart + "://" + path
            }
        }
        
        return sanitizedURL
    }
    
    // Save image URL cache to UserDefaults
    private func saveImageURLCache() {
        let cachedData = try? JSONEncoder().encode(imageURLCache)
        UserDefaults.standard.set(cachedData, forKey: imageURLCacheKey)
    }
    
    // Refresh post images
    func refreshPostImages() async {
        print("🔄 DEBUG: Refreshing post images")
        
        // Process each post to ensure images are loaded
        for (index, post) in posts.enumerated() {
            // Skip posts that already have images
            if post.image != nil {
                // If the post already has an image, make sure it's in our cache
                imageCache[post.id] = post.image
                continue
            }
            
            // Check if image is in memory cache
            if let cachedImage = imageCache[post.id] {
                // Update the post with the cached image
                await MainActor.run {
                    let updatedPost = Post(
                        id: post.id,
                        content: post.content,
                        likeCount: post.likeCount,
                        commentCount: post.commentCount,
                        imageName: post.imageName,
                        image: cachedImage,
                        timeAgo: post.timeAgo,
                        fitnessInfo: post.fitnessInfo,
                        aiResponse: post.aiResponse,
                        tag: post.tag,
                        username: post.username
                    )
                    
                    self.posts[index] = updatedPost
                    print("💾 DEBUG: Updated post image from memory cache for post ID: \(post.id)")
                }
                continue
            }
            
            // If not in memory cache, try to fetch it
            if let image = await fetchFirstImageForPost(id: post.id) {
                // Update the post with the loaded image
                await MainActor.run {
                    let updatedPost = Post(
                        id: post.id,
                        content: post.content,
                        likeCount: post.likeCount,
                        commentCount: post.commentCount,
                        imageName: post.imageName,
                        image: image,
                        timeAgo: post.timeAgo,
                        fitnessInfo: post.fitnessInfo,
                        aiResponse: post.aiResponse,
                        tag: post.tag,
                        username: post.username
                    )
                    
                    self.posts[index] = updatedPost
                    print("✅ DEBUG: Updated post image for post ID: \(post.id)")
                }
            }
        }
    }
    
    // Update a specific post with its image
    func updatePostImage(id: String) async -> Bool {
        print("📸 DEBUG: Attempting to update image for post ID: \(id)")
        
        // Skip if post not found
        guard let index = posts.firstIndex(where: { $0.id == id }) else {
            print("⚠️ DEBUG: Post not found with ID: \(id)")
            return false
        }
        
        // Skip if image already loaded
        if posts[index].image != nil {
            print("ℹ️ DEBUG: Post already has image, updating memory cache for ID: \(id)")
            // Make sure it's in our memory cache
            imageCache[id] = posts[index].image
            return true
        }
        
        // Check if image is in memory cache
        if let cachedImage = imageCache[id] {
            // Update the post with the cached image
            await MainActor.run {
                let updatedPost = Post(
                    id: posts[index].id,
                    content: posts[index].content,
                    likeCount: posts[index].likeCount,
                    commentCount: posts[index].commentCount,
                    imageName: posts[index].imageName,
                    image: cachedImage,
                    timeAgo: posts[index].timeAgo,
                    fitnessInfo: posts[index].fitnessInfo,
                    aiResponse: posts[index].aiResponse,
                    tag: posts[index].tag,
                    username: posts[index].username
                )
                
                self.posts[index] = updatedPost
            }
            print("💾 DEBUG: Successfully updated image from memory cache for post ID: \(id)")
            return true
        }
        
        // Fetch the image if not in memory
        if let image = await fetchFirstImageForPost(id: id) {
            // Update the post with the loaded image
            await MainActor.run {
                let updatedPost = Post(
                    id: posts[index].id,
                    content: posts[index].content,
                    likeCount: posts[index].likeCount,
                    commentCount: posts[index].commentCount,
                    imageName: posts[index].imageName,
                    image: image,
                    timeAgo: posts[index].timeAgo,
                    fitnessInfo: posts[index].fitnessInfo,
                    aiResponse: posts[index].aiResponse,
                    tag: posts[index].tag,
                    username: posts[index].username
                )
                
                self.posts[index] = updatedPost
            }
            print("✅ DEBUG: Successfully updated image for post ID: \(id)")
            return true
        }
        
        print("⚠️ DEBUG: Failed to fetch image for post ID: \(id)")
        return false
    }
    
    // Public method to test image loading from a specific URL (for debugging)
    func testImageLoading(urlString: String) async -> Bool {
        print("🧪 TEST: Attempting to load image from URL: \(urlString)")
        
        // Try direct load
        if let image = await loadImage(from: urlString) {
            print("✅ TEST PASSED: Successfully loaded image directly from URL")
            return true
        }
        
        // Try with sanitized URL
        let sanitized = sanitizeImageURL(urlString)
        if sanitized != urlString {
            print("🧪 TEST: Trying with sanitized URL: \(sanitized)")
            if let image = await loadImage(from: sanitized) {
                print("✅ TEST PASSED: Successfully loaded image from sanitized URL")
                
                // Cache the working URL
                if let postId = extractPostIdFromURL(sanitized) {
                    print("📝 Caching working URL for post ID: \(postId)")
                    imageURLCache[postId] = sanitized
                    saveImageURLCache()
                }
                
                return true
            }
        }
        
        print("❌ TEST FAILED: Could not load image from URL")
        return false
    }
    
    // Helper to extract post ID from a URL
    private func extractPostIdFromURL(_ url: String) -> String? {
        // Look for post ID pattern in the URL path
        // This pattern finds UUIDs like 6B6D772F-5931-45D9-A8C1-DACC14216293
        let pattern = "[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        
        let nsString = url as NSString
        let matches = regex.matches(in: url, options: [], range: NSRange(location: 0, length: nsString.length))
        
        if let match = matches.first {
            let idRange = match.range
            let extractedId = nsString.substring(with: idRange)
            print("🔍 Extracted post ID from URL: \(extractedId)")
            return extractedId
        }
        
        return nil
    }
    
    // Initialize storage buckets in Supabase
    deinit {
        print("🧹 PostsManager being deallocated")
        // Need to use sync version for deinit since we can't use async
        saveImageURLCacheSync()
        
        // Clear the memory image cache
        imageCache.removeAll()
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
    }
    
    // Synchronous version of saveImageURLCache for use in deinit
    @MainActor(unsafe) private func saveImageURLCacheSync() {
        // This is safe to call from deinit since UserDefaults is thread-safe
        let cachedData = try? JSONEncoder().encode(imageURLCache)
        UserDefaults.standard.set(cachedData, forKey: imageURLCacheKey)
    }
    
    // Method to clear all caches
    func clearCaches() {
        print("🧹 Clearing all caches")
        imageCache.removeAll()
        // Keep the URL cache as it's persisted and helpful for future sessions
    }
    
    // Method to preload images for all posts
    func preloadAllImages() async {
        print("📥 Preloading images for all posts")
        for post in posts {
            if post.image == nil {
                if let image = await fetchFirstImageForPost(id: post.id) {
                    // We fetched the image which will be added to the cache
                    print("✅ Preloaded image for post ID: \(post.id)")
                }
            } else {
                // Add existing image to cache
                imageCache[post.id] = post.image
                print("✅ Cached existing image for post ID: \(post.id)")
            }
        }
    }
}
