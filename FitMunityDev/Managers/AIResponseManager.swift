import Foundation
import SwiftUI
import Combine

// Notification model to represent AI responses for notification center
struct AINotification: Identifiable {
    let id = UUID()
    let postId: String
    let postContent: String
    let responseId: String
    let character: AICharacter
    let content: String
    let timestamp: Date
    let read: Bool
    
    init(postId: String, postContent: String, responseId: String, character: AICharacter, content: String, timestamp: Date = Date(), read: Bool = false) {
        self.postId = postId
        self.postContent = postContent
        self.responseId = responseId
        self.character = character
        self.content = content
        self.timestamp = timestamp
        self.read = read
    }
}

// Add this struct before the AIResponseManager class
struct ReplyInsertDTO: Encodable {
    let id: String
    let response_id: String
    let content: String
    let is_user_reply: Bool
    let timestamp: String
    let status: String
    let character_id: String?
    let character_name: String?
    let character_avatar: String?
    let reply_to_id: String?
}

// Add this struct after the ReplyInsertDTO
struct AIResponseInsertDTO: Encodable {
    let id: String
    let post_id: String
    let content: String
    let status: String
    let timestamp: String
    let character_id: String
    let character_name: String
    let character_avatar: String
    let background_story: String
    let reply_format: String
}

@MainActor
class AIResponseManager: ObservableObject {
    private let api: ChatGPTAPI
    @Published private var responses: [String: [AIResponse]] = [:]
    @Published var errorMessage: String = ""
    @Published var isLoading = false
    
    // Track notifications for AI responses
    @Published private(set) var notifications: [AINotification] = []
    @Published private(set) var hasUnreadNotifications: Bool = false
    
    // Track replies to comments
    @Published private var commentReplies: [String: [CommentReply]] = [:] // [responseId: [CommentReply]]
    
    // Reference to PostsManager to update comment counts
    private let postsManager: PostsManager
    
    // Reference to auth manager to get current user
    private var authManager: AuthManager?
    
    // Track unique characters who have already responded to each post
    private var respondedCharacters: [String: Set<String>] = [:] // [postId: Set<characterId>]
    
    // Private tracking of in-progress responses (not visible to UI)
    private var pendingResponses: [String: Set<String>] = [:] // [postId: Set<characterId>]
    
    // Track in-progress replies
    private var pendingReplies: [String: Bool] = [:] // [responseId: Bool]
    
    // Subscribers
    private var cancellables = Set<AnyCancellable>()
    
    init(apiKey: String = Config.openAIApiKey, postsManager: PostsManager = PostsManager.shared) {
        self.api = ChatGPTAPI(apiKey: apiKey)
        self.postsManager = postsManager
        
        // Listen for auth state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAuthStateChanged),
            name: NSNotification.Name("AuthStateChanged"),
            object: nil
        )
    }
    
    // Set auth manager reference
    func setAuthManager(_ authManager: AuthManager) {
        self.authManager = authManager
    }
    
    // Handle auth state changes
    @objc private func handleAuthStateChanged() {
        resetNotificationState()
        
        Task {
            if let authManager = authManager,
               authManager.authState == .signedIn {
                // User signed in, preload responses and all nested replies for visible posts
                await MainActor.run {
                    print("👤 User signed in, preloading AI responses and nested replies for all visible posts")
                    
                    // For each visible post, load its responses and all nested replies
                    for post in postsManager.posts {
                        // Queue up complete response and reply loading for each post
                        Task {
                            await preloadAllResponsesAndReplies(for: post.id)
                        }
                    }
                }
            } else {
                // User signed out, clear responses
                await MainActor.run {
                    print("👋 User signed out, clearing response cache")
                    self.responses = [:]
                    self.commentReplies = [:]
                    self.respondedCharacters = [:]
                }
            }
        }
    }
    
    // Get all responses for a specific post
    func getResponses(for postId: String) -> [AIResponse] {
        // If we don't have responses for this post yet, fetch them
        if responses[postId] == nil {
            Task {
                try? await fetchResponses(for: postId)
            }
        }
        
        return responses[postId] ?? []
    }
    
    // Get all replies for a specific AI response
    func getReplies(for responseId: String) -> [CommentReply] {
        // If we don't have replies for this response yet, fetch them
        if commentReplies[responseId] == nil {
            Task {
                try? await fetchReplies(for: responseId)
            }
        }
        
        return commentReplies[responseId] ?? []
    }
    
    // Fetch AI responses from Supabase
    func fetchResponses(for postId: String) async throws {
        isLoading = true
        
        do {
            //print("🔄 Fetching AI responses for post: \(postId)")
            
            let query = SupabaseConfig.shared.database
                .from("ai_responses")
                .select("*")
                .eq("post_id", value: postId)
                .order("timestamp", ascending: true)
            
            let response = try await query.execute()
            let data = response.data
            
            // Debug raw response 
            if let dataString = String(data: data, encoding: .utf8) {
                //   print("📊 DEBUG: Raw AI responses data for post \(postId): \(dataString)")
            }
            
            // Decode the response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let decodedResponses = try decoder.decode([AIResponseDTO].self, from: data)
            
            // Extra verification that post_id matches
            let filteredResponses = decodedResponses.filter { $0.post_id == postId }
            if filteredResponses.count != decodedResponses.count {
                print("⚠️ WARNING: Found \(decodedResponses.count) responses but only \(filteredResponses.count) match post ID \(postId)")
            }
            
            // Convert DTOs to domain models
            let domainResponses = filteredResponses.map { $0.toAIResponse() }
            
            // Update the responses dictionary
            await MainActor.run {
                self.responses[postId] = domainResponses
                self.isLoading = false
                
                // Update the post's AI response if any
                if let firstResponse = domainResponses.first {
                    if let index = postsManager.posts.firstIndex(where: { $0.id == postId }) {
                        var updatedPost = postsManager.posts[index]
                        
                        let post = Post(
                            id: updatedPost.id,
                            content: updatedPost.content,
                            likeCount: updatedPost.likeCount,
                            commentCount: updatedPost.commentCount,
                            imageName: updatedPost.imageName,
                            image: updatedPost.image,
                            timeAgo: updatedPost.timeAgo,
                            fitnessInfo: updatedPost.fitnessInfo,
                            aiResponse: firstResponse,
                            tag: updatedPost.tag,
                            username: updatedPost.username
                        )
                        
                        postsManager.posts[index] = post
                    }
                }
                
                // print("✅ Fetched \(domainResponses.count) AI responses for post: \(postId)")
            }
            
            // For each response, fetch its replies
            for response in domainResponses {
                try? await fetchReplies(for: response.id)
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch AI responses: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Error fetching AI responses: \(error.localizedDescription)")
            }
        }
    }
    
    // Fetch replies for an AI response from Supabase and build complete reply tree
    func fetchReplies(for responseId: String) async throws {
        do {
            //print("🌳 Building TREE: Fetching replies for AI response: \(responseId)")
            
            // Fetch all replies for this response, regardless of parent
            let query = SupabaseConfig.shared.database
                .from("comment_replies")
                .select("*")
                .eq("response_id", value: responseId)
                .order("timestamp", ascending: true)
            
            let response = try await query.execute()
            let data = response.data
            
            // Log raw data for debugging
            if let dataString = String(data: data, encoding: .utf8) {
                // print("📊 TREE RAW DATA: \(dataString)")
            }
            
            // Decode the response
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let decodedReplies = try decoder.decode([CommentReplyDTO].self, from: data)
            // print("🔢 TREE NODE COUNT: Found \(decodedReplies.count) total replies for response \(responseId)")
            
            // Convert DTOs to domain models
            let domainReplies = decodedReplies.map { $0.toCommentReply() }
            
            // Build and log the tree structure
            let tree = buildReplyTreeStructure(from: domainReplies)
            logTreeStructure(tree, responseId: responseId)
            
            // Update the cache with all replies
            await MainActor.run {
                self.commentReplies[responseId] = domainReplies
                // print("✅ TREE COMPLETE: Loaded and cached \(domainReplies.count) replies for response \(responseId)")
            }
        } catch {
            print("❌ TREE ERROR: Failed to fetch and build reply tree: \(error.localizedDescription)")
        }
    }
    
    // Build a tree structure from flat replies array
    private func buildReplyTreeStructure(from replies: [CommentReply]) -> [String: Any] {
        // Create a dictionary to hold the tree
        var tree: [String: Any] = [:]
        
        // First, create a lookup table of all replies by ID
        var replyLookup: [String: CommentReply] = [:]
        for reply in replies {
            replyLookup[reply.id] = reply
        }
        
        // Group replies by their parent
        var repliesByParent: [String?: [String]] = [:]
        for reply in replies {
            if repliesByParent[reply.replyToId] == nil {
                repliesByParent[reply.replyToId] = []
            }
            repliesByParent[reply.replyToId]!.append(reply.id)
        }
        
        // Root replies (those without a parent)
        tree["rootReplies"] = repliesByParent[nil] ?? []
        
        // For each reply, record its children
        var replyChildren: [String: [String]] = [:]
        for reply in replies {
            replyChildren[reply.id] = repliesByParent[reply.id] ?? []
        }
        tree["replyChildren"] = replyChildren
        
        // Calculate the depth of each reply in the tree
        var replyDepth: [String: Int] = [:]
        
        // Function to recursively calculate depths
        func calculateDepth(replyId: String, currentDepth: Int) {
            replyDepth[replyId] = currentDepth
            
            // Process children
            if let children = replyChildren[replyId] {
                for childId in children {
                    calculateDepth(replyId: childId, currentDepth: currentDepth + 1)
                }
            }
        }
        
        // Calculate depths starting from root replies
        for rootReplyId in (repliesByParent[nil] ?? []) {
            calculateDepth(replyId: rootReplyId, currentDepth: 0)
        }
        
        tree["replyDepth"] = replyDepth
        tree["maxDepth"] = replyDepth.values.max() ?? 0
        
        return tree
    }
    
    // Log the tree structure with debugging information
    private func logTreeStructure(_ tree: [String: Any], responseId: String) {
        guard let rootReplies = tree["rootReplies"] as? [String],
              let replyChildren = tree["replyChildren"] as? [String: [String]],
              let replyDepth = tree["replyDepth"] as? [String: Int],
              let maxDepth = tree["maxDepth"] as? Int else {
            print("❌ TREE ERROR: Invalid tree structure")
            return
        }
        
        // print("🌲 TREE STRUCTURE for response \(responseId):")
        ///print("  📏 Maximum tree depth: \(maxDepth)")
        //print("  🌱 Root replies (\(rootReplies.count)): \(rootReplies)")
        
        // Show detailed breakdown of the tree
        //print("  🌳 Tree breakdown:")
        
        // Recursive function to print the tree
        func printTree(nodeId: String, depth: Int) {
            let indent = String(repeating: "  ", count: depth + 1)
            let children = replyChildren[nodeId] ?? []
            print("\(indent)└─ Reply \(nodeId) (Depth: \(replyDepth[nodeId] ?? -1), Children: \(children.count))")
            
            for childId in children {
                printTree(nodeId: childId, depth: depth + 1)
            }
        }
        
        for rootReplyId in rootReplies {
            printTree(nodeId: rootReplyId, depth: 0)
        }
    }
    
    // Get all notifications (filtered by read status if specified)
    func getNotifications(onlyUnread: Bool = false) -> [AINotification] {
        if onlyUnread {
            return notifications.filter { !$0.read }
        }
        return notifications.sorted(by: { $0.timestamp > $1.timestamp })
    }
    
    // Mark all notifications as read
    func clearUnreadNotifications() {
        print("👀 DEBUG: Clearing unread notifications")
        print("📊 DEBUG: Before clearing - Notifications count: \(notifications.count), HasUnread: \(hasUnreadNotifications)")
        let updatedNotifications = notifications.map { notification in
            AINotification(
                postId: notification.postId,
                postContent: notification.postContent,
                responseId: notification.responseId,
                character: notification.character,
                content: notification.content,
                timestamp: notification.timestamp,
                read: true
            )
        }
        
        notifications = updatedNotifications
        hasUnreadNotifications = false
        print("📊 DEBUG: After clearing - Notifications count: \(notifications.count), HasUnread: \(hasUnreadNotifications)")
        objectWillChange.send()
    }
    
    // Reset notification state (used when auth state changes)
    func resetNotificationState() {
        print("🔄 DEBUG: Resetting notification state")
        print("📊 DEBUG: Before reset - Notifications count: \(notifications.count), HasUnread: \(hasUnreadNotifications)")
        notifications = []
        hasUnreadNotifications = false
        print("📊 DEBUG: After reset - Notifications count: \(notifications.count), HasUnread: \(hasUnreadNotifications)")
        objectWillChange.send()
    }
    
    // Add a notification for an AI response
    private func addNotification(for response: AIResponse, postId: String, postContent: String) {
       // print("🔔 DEBUG: Attempting to add notification for response ID: \(response.id)")
        guard let character = response.character else {
            //print("⚠️ DEBUG: Failed to add notification - no character found")
            return
        }
        
        let notification = AINotification(
            postId: postId,
            postContent: postContent,
            responseId: response.id,
            character: character,
            content: response.content
        )
        
        notifications.append(notification)
        hasUnreadNotifications = true
        //print("✅ DEBUG: Successfully added notification. Total notifications: \(notifications.count)")
        //print("🔔 DEBUG: Notification details - Character: \(character.name), Content: \(notification.content.prefix(50))...")
        objectWillChange.send()
    }
    
    // Check if a response has any replies
    func hasReplies(for responseId: String) -> Bool {
        return !(commentReplies[responseId]?.isEmpty ?? true)
    }
    
    // Check if a reply is currently being generated for a response
    func isGeneratingReply(for responseId: String) -> Bool {
        return pendingReplies[responseId] ?? false
    }
    
    // Auto-generate AI responses for a post
    func autoGenerateResponses(for post: Post) {
        // CRITICAL: Verify post ID is valid
        guard !post.id.isEmpty else {
            print("⚠️ ERROR: Post has empty ID! Cannot generate responses.")
            return
        }
        
        print("🔄 Auto-generating responses for post with ID: \(post.id)")
        
        // First, check if we've already generated responses for this post
        Task {
            // Instead of relying on in-memory cache, check the database directly first
            do {
                let query = SupabaseConfig.shared.database
                    .from("ai_responses")
                    .select("*")
                    .eq("post_id", value: post.id)
                
                let response = try await query.execute()
                let data = response.data
                
                if let dataString = String(data: data, encoding: .utf8) {
                    // print("🔍 Checking existing responses in DB for post \(post.id): \(dataString)")
                }
                
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                
                // Try to decode the responses
                let existingResponses = try decoder.decode([AIResponseDTO].self, from: data)
                
                if !existingResponses.isEmpty {
                    print("⏩ Post \(post.id) already has \(existingResponses.count) responses in database, skipping generation")
                    
                    // Convert DTOs to domain models and update cache
                    let domainResponses = existingResponses.map { $0.toAIResponse() }
                    
        await MainActor.run {
                        // Update in-memory cache
                        self.responses[post.id] = domainResponses
                        
                        // Also update the post's aiResponse if needed
                        if post.aiResponse == nil, let firstResponse = domainResponses.first {
                            if let index = postsManager.posts.firstIndex(where: { $0.id == post.id }) {
                                var updatedPost = postsManager.posts[index]
                                updatedPost.aiResponse = firstResponse
                                postsManager.posts[index] = updatedPost
                            }
                        }
                        
                        // Update the responded characters set
                        if self.respondedCharacters[post.id] == nil {
                            self.respondedCharacters[post.id] = []
                        }
                        
                        for response in domainResponses {
                            if let characterId = response.character?.id {
                                self.respondedCharacters[post.id]!.insert(characterId)
                            }
                        }
                    }
                    
                    return
                }
                
                // If we get here, there are no responses in the database
                
                // As a second check, see if we already have responses in memory
                if let cachedResponses = self.responses[post.id], !cachedResponses.isEmpty {
                    print("ℹ️ Already have \(cachedResponses.count) responses in cache for post ID: \(post.id), skipping generation")
            return
        }
        
                // Skip if the post already has an AI response
                if post.aiResponse != nil {
                    print("🤖 Post already has an AI response, skipping: \(post.id)")
                    return
                }
                
                // If we get here, we need to generate new responses
                print("🆕 No existing responses found, generating new ones for post \(post.id)")
                
                // Get eligible characters for this post
                let characters = AICharacter.charactersFor(post: post)
                
                // Filter out characters that have already responded (additional safety check)
                let eligibleCharacters = characters.filter { character in
                    // Check both respondedCharacters and existing responses to prevent duplicates
                    let hasNotResponded = ((respondedCharacters[post.id]?.contains(character.id)) == nil) ?? true
                    let notInExistingResponses = !(self.responses[post.id]?.contains { $0.character?.id == character.id } ?? false)
                    return hasNotResponded && notInExistingResponses
                }
                
                if eligibleCharacters.isEmpty {
                    print("👥 No eligible characters to respond to post: \(post.id)")
                    return
                }
                
                // Generate responses only for eligible characters
                await self.generateResponses(for: post, with: eligibleCharacters)
                
            } catch {
                print("❌ Error checking for existing responses: \(error.localizedDescription)")
                
                // Fall back to in-memory checks
                if let cachedResponses = self.responses[post.id], !cachedResponses.isEmpty {
                    print("ℹ️ Already have \(cachedResponses.count) responses in cache, skipping generation")
                    return
                }
                
                if post.aiResponse != nil {
                    print("🤖 Post already has an AI response, skipping: \(post.id)")
                    return
                }
                
                // Get eligible characters for this post
                let characters = AICharacter.charactersFor(post: post)
                
                // Filter out characters that have already responded (additional safety check)
                let eligibleCharacters = characters.filter { character in
                    // Check both respondedCharacters and existing responses to prevent duplicates
                    let hasNotResponded = ((respondedCharacters[post.id]?.contains(character.id)) == nil) ?? true
                    let notInExistingResponses = !(self.responses[post.id]?.contains { $0.character?.id == character.id } ?? false)
                    return hasNotResponded && notInExistingResponses
                }
                
                if eligibleCharacters.isEmpty {
                    print("👥 No eligible characters to respond to post: \(post.id)")
                    return
                }
                
                // Generate responses only for eligible characters
                await self.generateResponses(for: post, with: eligibleCharacters)
            }
        }
    }
    
    // Generate AI responses for a post with specified characters
    func generateResponses(for post: Post, with characters: [AICharacter]) async {
        // print("🧠 Begin generating responses for post ID: \(post.id)")
        
        // Initialize the set of responded characters for this post if needed
        if respondedCharacters[post.id] == nil {
            respondedCharacters[post.id] = []
        }
        
        // Initialize the set of pending responses for this post if needed
        if pendingResponses[post.id] == nil {
            pendingResponses[post.id] = []
        }
        
        // Additional safety check: filter out any characters that already have responses
        let existingResponses = self.responses[post.id] ?? []
        let existingCharacterIds = Set(existingResponses.compactMap { $0.character?.id })
        
        // Filter out characters that have already responded or are in existing responses
        let newCharacters = characters.filter { character in
            !respondedCharacters[post.id]!.contains(character.id) &&
            !pendingResponses[post.id]!.contains(character.id) &&
            !existingCharacterIds.contains(character.id)
        }
        
        if newCharacters.isEmpty {
            print("👥 No new characters to respond to post: \(post.id)")
            return
        }
        
        print("👥 Generating responses for \(newCharacters.count) characters to post: \(post.id)")
        
        // Add all characters to pending set
        for character in newCharacters {
            pendingResponses[post.id]!.insert(character.id)
        }
        
        // Create initial response entries with pending status
        var pendingResponseObjects: [AIResponse] = []
        
        for character in newCharacters {
            let pendingResponse = AIResponse(
                id: UUID().uuidString,
                content: "Thinking...",
                status: .pending,
                    character: character
                )
                
            pendingResponseObjects.append(pendingResponse)
        }
        
        // Add pending responses to the responses dictionary
        await MainActor.run {
            var currentResponses = self.responses[post.id] ?? []
            currentResponses.append(contentsOf: pendingResponseObjects)
            self.responses[post.id] = currentResponses
            print("📋 Updated responses dictionary: post ID \(post.id) now has \(currentResponses.count) responses")
            
            // If this is the first response for the post, update the post's aiResponse
            if let firstResponse = pendingResponseObjects.first, post.aiResponse == nil {
                if let index = postsManager.posts.firstIndex(where: { $0.id == post.id }) {
                    var updatedPost = postsManager.posts[index]
                    
                    let newPost = Post(
                        id: updatedPost.id,
                        content: updatedPost.content,
                        likeCount: updatedPost.likeCount,
                        commentCount: updatedPost.commentCount,
                        imageName: updatedPost.imageName,
                        image: updatedPost.image,
                        timeAgo: updatedPost.timeAgo,
                        fitnessInfo: updatedPost.fitnessInfo,
                        aiResponse: firstResponse,
                        tag: updatedPost.tag,
                        username: updatedPost.username
                    )
                    
                    postsManager.posts[index] = newPost
                    print("🔄 Updated post \(post.id) with first AI response")
                }
            }
                
                // Notify observers
                objectWillChange.send()
        }
        
        // Generate responses for each character
        var generatedResponses: [AIResponse] = []
        
        for (index, character) in newCharacters.enumerated() {
            do {
                let pendingResponse = pendingResponseObjects[index]
                
                // Create a specific prompt for this character
                let prompt = generatePrompt(character: character, post: post)
                
                // Small delay to make it feel more natural and avoid rate limits
                let delay = Double(index) * 1.5
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
                // Get response from API
                print("🤖 Generating response with character: \(character.name) for post: \(post.id)")
                let result = try await api.generateResponse(for: prompt, image: post.image)
                
                // Create completed response
                let completedResponse = AIResponse(
                    id: pendingResponse.id,
                    content: result,
                    status: .completed,
                    timestamp: Date(),
                    character: character
                )
                
                generatedResponses.append(completedResponse)
                
                // Add to responded characters set
                respondedCharacters[post.id]!.insert(character.id)
                
                // Save response to Supabase
                try await saveResponse(completedResponse, for: post.id)
                
                // Add notification
                await MainActor.run {
                    addNotification(for: completedResponse, postId: post.id, postContent: post.content)
                }
                
                // Update the responses array
                await MainActor.run {
                    // Replace the pending response with the completed one
                    if let index = self.responses[post.id]?.firstIndex(where: { $0.id == pendingResponse.id }) {
                        self.responses[post.id]?[index] = completedResponse
                    }
                    
                    // If this is the first response and we're currently showing it as the post's aiResponse,
                    // update it to the completed version
                    if let postIndex = postsManager.posts.firstIndex(where: { $0.id == post.id }),
                       postsManager.posts[postIndex].aiResponse?.id == pendingResponse.id {
                        
                        var updatedPost = postsManager.posts[postIndex]
                        
                        let newPost = Post(
                            id: updatedPost.id,
                            content: updatedPost.content,
                            likeCount: updatedPost.likeCount,
                            commentCount: updatedPost.commentCount,
                            imageName: updatedPost.imageName,
                            image: updatedPost.image,
                            timeAgo: updatedPost.timeAgo,
                            fitnessInfo: updatedPost.fitnessInfo,
                            aiResponse: completedResponse,
                            tag: updatedPost.tag,
                            username: updatedPost.username
                        )
                        
                        postsManager.posts[postIndex] = newPost
                    }
                    
                    // Notify observers
            objectWillChange.send()
        }
        
                // Increment the comment count for the post
                postsManager.incrementCommentCount(for: post.id)
                
            } catch {
                // Handle error
                print("❌ Error generating response: \(error.localizedDescription)")
                
                let pendingResponse = pendingResponseObjects[index]
                
                // Create failed response
                let failedResponse = AIResponse(
                    id: pendingResponse.id,
                    content: "Sorry, I couldn't respond to this post. Please try again later.",
                    status: .failed,
                    timestamp: Date(),
                    character: character
                )
                
                // Update the responses array
                await MainActor.run {
                    // Replace the pending response with the failed one
                    if let index = self.responses[post.id]?.firstIndex(where: { $0.id == pendingResponse.id }) {
                        self.responses[post.id]?[index] = failedResponse
                    }
                    
                    // Notify observers
                    objectWillChange.send()
                }
                
                // Remove from pending set
                pendingResponses[post.id]!.remove(character.id)
            }
        }
        
        // Remove all characters from pending set
        pendingResponses[post.id] = []
    }
    
    // Save an AI response to Supabase
    private func saveResponse(_ response: AIResponse, for postId: String) async throws {
        guard let character = response.character else {
            throw NSError(domain: "AIResponseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Response has no character"])
        }
        
        // print("💾 Saving AI response to Supabase for post: \(postId), response ID: \(response.id)")
        
        // Create the DTO
        let responseDTO = AIResponseInsertDTO(
            id: response.id,
            post_id: postId,
            content: response.content,
            status: response.status.rawValue,
            timestamp: ISO8601DateFormatter().string(from: response.timestamp),
            character_id: character.id,
            character_name: character.name,
            character_avatar: character.avatar,
            background_story: character.backgroundStory ?? "",
            reply_format: character.replyFormat ?? ""
        )
        
        // Insert into Supabase
        let query = try SupabaseConfig.shared.database
            .from("ai_responses")
            .insert(responseDTO)
        
        try await query.execute()
        // print("✅ Saved AI response to Supabase: \(response.id) for post: \(postId)")
    }
    
    // Add a user reply to an AI response
    func addUserReply(to responseId: String, content: String, aiResponse: AIResponse, replyToId: String? = nil) async {
        // Ensure user is signed in
        guard let authManager = authManager, 
              authManager.currentUser != nil else {
            print("⚠️ Cannot add reply: User not authenticated")
            return
        }
        
        // Create user reply with reference to what it's replying to (if applicable)
        let userReply = CommentReply(
            content: content,
            isUserReply: true,
            replyToId: replyToId
        )
        
        do {
            // Save the user reply to Supabase
            try await saveReply(userReply, for: responseId)
        
            // Add to the replies array
                    await MainActor.run {
                var currentReplies = commentReplies[responseId] ?? []
                currentReplies.append(userReply)
                commentReplies[responseId] = currentReplies
                
                // Mark this response as having a pending reply
                pendingReplies[responseId] = true
                
                // Notify observers
                objectWillChange.send()
            }
        
            // Generate AI character reply to the user's comment
            await generateReplyToUser(responseId: responseId, userReply: userReply, originalResponse: aiResponse)
        } catch {
            print("❌ Error saving user reply: \(error.localizedDescription)")
        }
    }
    
    // Save a reply to Supabase
    private func saveReply(_ reply: CommentReply, for responseId: String) async throws {
        print("💾 Saving reply to Supabase for response: \(responseId)")
        
        // Create DTO for insertion
        let replyDTO = ReplyInsertDTO(
            id: reply.id,
            response_id: responseId,
            content: reply.content,
            is_user_reply: reply.isUserReply,
            timestamp: ISO8601DateFormatter().string(from: reply.timestamp),
            status: reply.status.rawValue,
            character_id: reply.character?.id,
            character_name: reply.character?.name,
            character_avatar: reply.character?.avatar,
            reply_to_id: reply.replyToId
        )
        
        // Insert into Supabase
        let query = try SupabaseConfig.shared.database
            .from("comment_replies")
            .insert(replyDTO)
        
        try await query.execute()
        print("✅ Saved reply to Supabase: \(reply.id)")
    }
    
    // Generate an AI reply to a user comment
    private func generateReplyToUser(responseId: String, userReply: CommentReply, originalResponse: AIResponse) async {
        // Ensure there's a character to reply
        guard let character = originalResponse.character else {
            await MainActor.run {
                // Mark as not pending anymore
                pendingReplies[responseId] = false
                objectWillChange.send()
            }
            return
        }
        
        // Declare postId at the top level of the function so it's available in all scopes
        var postId: String? = nil
        var imageToSend: UIImage? = nil
        var imageLoadAttempted = false
        
        print("🤖 Generating reply from character \(character.name) to user comment: \"\(userReply.content.prefix(50))...\"")
        
        do {
            // Create a specific prompt for a reply to user comment
            let prompt = generateReplyPrompt(character: character, originalResponse: originalResponse, userReply: userReply)
            print("📝 Generated prompt for reply (length: \(prompt.count))")
            
            // Find the original post that this comment is linked to
            print("🔍 DEBUG: Searching for post linked to response ID: \(responseId)")
            
            for (pid, postResponses) in responses {
                if postResponses.contains(where: { $0.id == responseId }) {
                    postId = pid
                    print("✅ DEBUG: Found matching post with ID: \(pid) for response: \(responseId)")
                    
                    // Found the post, now check if it has an image
                    if let post = postsManager.posts.first(where: { $0.id == pid }) {
                        print("📝 DEBUG: Checking post for image, post ID: \(post.id)")
                        
                        // Check for in-memory image first
                        imageToSend = post.image
                        if imageToSend != nil {
                            print("💾 DEBUG: Found in-memory image for post: \(post.id)")
                            imageLoadAttempted = true
                        }
                        
                        // If post has an asset catalog image, load it
                        if imageToSend == nil, let imageName = post.imageName {
                            imageToSend = UIImage(named: imageName)
                            print("📸 DEBUG: Loaded asset image for reply: \(imageName)")
                            imageLoadAttempted = true
                        }
                        
                        // If still no image, try to fetch it from the PostsManager with its improved retry mechanism
                        if imageToSend == nil {
                            print("🔄 DEBUG: No image found in post model, trying to fetch from PostsManager with retries")
                            // Use the enhanced fetchImageForPost method with retries
                            imageToSend = await postsManager.fetchImageForPost(id: post.id)
                            imageLoadAttempted = true
                            
                            if imageToSend != nil {
                                print("✅ DEBUG: Successfully fetched image from PostsManager for post: \(post.id)")
                            } else {
                                print("⚠️ DEBUG: Failed to fetch image from PostsManager for post: \(post.id) after retries")
                            }
                        }
                        
                        // Debug image availability
                        if imageToSend != nil {
                            print("📸 DEBUG: Using image for comment reply, size: \(imageToSend!.size)")
                        } else if imageLoadAttempted {
                            print("⚠️ DEBUG: All image loading attempts failed for post: \(post.id)")
                        } else {
                            print("⚠️ DEBUG: No image available for comment reply for post: \(post.id)")
                        }
                        
                        break
                    } else {
                        print("⚠️ DEBUG: Found post ID \(pid) in responses but not in postsManager.posts")
                    }
                }
            }
            
            // Small delay to make it feel more natural
            if #available(iOS 16.0, *) {
                try await Task.sleep(for: .seconds(1.0))
            } else {
                try await Task.sleep(nanoseconds: UInt64(1.0 * 1_000_000_000))
            }
            
            // First attempt: Try with image if we have one
            if let image = imageToSend {
                print("🔍 Calling API to generate reply with image...")
                do {
                    // Try with image first
                    let result = try await api.generateResponse(for: prompt, image: image)
                    print("✅ Got reply from API with image: \"\(result.prefix(50))...\"")
                    
                    // Create AI reply
                    let aiReply = CommentReply(
                        content: result,
                        isUserReply: false,
                        character: character,
                        replyToId: userReply.id
                    )
                    
                    // Save the AI reply to Supabase
                    try await saveReply(aiReply, for: responseId)
                    print("💾 Saved AI reply to Supabase")
                    
                    // Add to the replies array
                    await MainActor.run {
                        var currentReplies = commentReplies[responseId] ?? []
                        currentReplies.append(aiReply)
                        commentReplies[responseId] = currentReplies
                        
                        // Mark this response as not having a pending reply anymore
                        pendingReplies[responseId] = false
                        
                        // Notify observers
                        objectWillChange.send()
                        print("🎉 Successfully added AI reply to UI")
                    }
                    
                    return
                } catch {
                    // Image attempt failed, will fall back to text-only
                    print("⚠️ Image-based reply generation failed: \(error.localizedDescription)")
                    print("🔄 Falling back to text-only reply...")
                }
            }
            
            // Second attempt: Try without image as fallback
            print("🔍 Calling API to generate text-only reply...")
            let result = try await api.generateResponse(for: prompt, image: nil)
            print("✅ Got reply from API (text-only): \"\(result.prefix(50))...\"")
            
            // Create AI reply with text-only response
            let aiReply = CommentReply(
                content: result,
                isUserReply: false,
                character: character,
                replyToId: userReply.id
            )
            
            // Save the AI reply to Supabase
            try await saveReply(aiReply, for: responseId)
            print("💾 Saved AI reply to Supabase")
            
            // Add to the replies array
            await MainActor.run {
                var currentReplies = commentReplies[responseId] ?? []
                currentReplies.append(aiReply)
                commentReplies[responseId] = currentReplies
                
                // Mark this response as not having a pending reply anymore
                pendingReplies[responseId] = false
                
                // Notify observers
                objectWillChange.send()
                print("🎉 Successfully added AI reply to UI")
            }
        } catch {
            print("❌ Error generating reply: \(error.localizedDescription)")
            
            // Check if we have a valid API response despite the error
            var replyContent = "Sorry, I couldn't reply to your comment. Please try again."
            
            // Add more specific error messaging based on if we found an image
            if let postIdentifier = postId {
                print("🔍 DEBUG: Error occurred with post ID: \(postIdentifier)")
                replyContent = "Sorry, I couldn't reply to your comment right now. This may be because I'm having trouble processing the image in this post. Please try again later."
            }
            
            var shouldUseRawResponse = false
            
            // Try using the raw response content from the API
            if let lastAPIResponse = api.lastResponseContent, !lastAPIResponse.isEmpty {
                print("🔍 Checking last API response for usable content...")
                
                // Simple content extraction based on terminal output pattern
                // Log shows format like: "content": "\"Hi\"",
                if lastAPIResponse.contains("\"content\": ") {
                    print("🔎 Found content field in API response")
                    
                    // If the response contains a JSON structure we recognize, try to parse it
                    if lastAPIResponse.contains("\"choices\"") && lastAPIResponse.contains("\"message\"") {
                        do {
                            if let jsonData = lastAPIResponse.data(using: .utf8),
                               let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                               let choices = json["choices"] as? [[String: Any]],
                               let firstChoice = choices.first,
                               let message = firstChoice["message"] as? [String: Any],
                               let content = message["content"] as? String {
                                
                                var extractedContent = content
                                print("🎯 Extracted content from JSON: \"\(extractedContent)\"")
                                
                                // Remove quotes if they exist
                                if extractedContent.hasPrefix("\"") && extractedContent.hasSuffix("\"") {
                                    extractedContent = String(extractedContent.dropFirst().dropLast())
                                    print("🔄 Removed quotes: \"\(extractedContent)\"")
                                }
                                
                                replyContent = extractedContent
                                shouldUseRawResponse = true
            }
        } catch {
                            print("⚠️ JSON parsing failed: \(error.localizedDescription)")
                            
                            // Fallback to simple content extraction
                            if let contentRange = lastAPIResponse.range(of: "\"content\": \"([^\"]*)\"", options: .regularExpression) {
                                let extractedContent = String(lastAPIResponse[contentRange])
                                print("📝 Simple extraction found: \(extractedContent)")
                                if !extractedContent.isEmpty {
                                    let trimmedContent = extractedContent.replacingOccurrences(of: "\"content\": \"", with: "").dropLast()
                                    replyContent = String(trimmedContent)
                                    shouldUseRawResponse = true
                                }
                            }
                        }
                    }
                }
            }
            
            // Create and add the reply with either the error message or the actual content
            let aiReply = CommentReply(
                content: replyContent,
                isUserReply: false,
                status: shouldUseRawResponse ? .completed : .failed,
                character: character,
                replyToId: userReply.id // Link this reply to the user reply it's responding to
            )
            
            if shouldUseRawResponse {
                print("✅ Using extracted API content for reply: \"\(replyContent.prefix(30))...\"")
            } else {
                print("⚠️ Using fallback error message: \"\(replyContent)\"")
            }
            
            do {
                // Save the AI reply to Supabase - FIX: Wait for completion and handle errors properly
                try await saveReply(aiReply, for: responseId)
                print("💾 Saved AI error reply to Supabase: \(aiReply.id)")
                
                // Only update UI after successful save
                await MainActor.run {
                    // Add to the replies array
                    var currentReplies = commentReplies[responseId] ?? []
                    currentReplies.append(aiReply)
                    commentReplies[responseId] = currentReplies
                    
                    // Mark this response as not having a pending reply anymore
                    pendingReplies[responseId] = false
                    
                    // Notify observers
                    objectWillChange.send()
                }
            } catch {
                print("❌ ERROR: Failed to save AI reply to Supabase: \(error.localizedDescription)")
                // Still update the UI with the reply, even if we couldn't save it to Supabase
                await MainActor.run {
                    // Add to the replies array
                    var currentReplies = commentReplies[responseId] ?? []
                    currentReplies.append(aiReply)
                    commentReplies[responseId] = currentReplies
                    
                    // Mark this response as not having a pending reply anymore
                    pendingReplies[responseId] = false
                    
                    // Notify observers
                    objectWillChange.send()
                }
            }
        }
    }
    
    // MARK: - Prompt Generation
    
    // Generate a prompt for an AI character to respond to a post
    private func generatePrompt(character: AICharacter, post: Post) -> String {
        // Base system prompt for the character
        let systemPrompt = """
        You are an AI character with the following properties:
        Name: \(character.name)
        Avatar: \(character.avatar)
        Background Story: \(character.backgroundStory)
        Reply Format: \(character.replyFormat)
        
        You must STRICTLY follow the Reply Format. 
        Your response should be based on your background story and character traits.
        Respond directly without narration or explaining what you're doing.
        
        The post will be provided, and if there is an image, respond to both the text and image appropriately.
        """
        
        // User prompt containing the post content and metadata
        var userPrompt = "Here's a social media post"
        
        if let tag = post.tag {
            userPrompt += " tagged as \(tag)"
        }
        
        userPrompt += ":\n\n"
        userPrompt += post.content
        
        if post.image != nil || post.imageName != nil {
            userPrompt += "\n\n[This post contains an image]"
        }
        
        if let fitnessInfo = post.fitnessInfo {
            userPrompt += "\n\nFitness Info: \(fitnessInfo)"
        }
        
        // Combine prompts and return
        return "SYSTEM: \(systemPrompt)\n\nUSER: \(userPrompt)"
    }
    
    // Generate a prompt for an AI character to reply to a user comment
    private func generateReplyPrompt(character: AICharacter, originalResponse: AIResponse, userReply: CommentReply) -> String {
        // Base system prompt for the character
        let systemPrompt = """
        You are an AI character with the following properties:
        Name: \(character.name)
        Avatar: \(character.avatar)
        Background Story: \(character.backgroundStory)
        Reply Format: \(character.replyFormat)
        
        You must STRICTLY follow the Reply Format.
        Your response should be based on your background story and character traits.
        Respond directly as your character without narration, explanation, or quotes.
        Your response should be conversational, natural, and specifically address what the user said.
        
        IMPORTANT: 
        1. DO NOT use quotes around your response
        2. DO NOT prefix your response with your name
        3. DO NOT explain what you're doing
        4. Just respond as if you're having a natural conversation
        5. Keep your response brief and direct (under 100 words)
        """
        
        // User prompt containing the original response and user reply
        let userPrompt = """
        This is a conversation thread where you (as \(character.name)) previously commented:
        "\(originalResponse.content)"
        
        The user has replied to your comment:
        "\(userReply.content)"
        
        Please respond to the user's reply as \(character.name), continuing the conversation naturally.
        Remember to follow your character's Reply Format and personality.
        """
        
        // Combine prompts and return
        return "SYSTEM: \(systemPrompt)\n\nUSER: \(userPrompt)"
    }
    
    // Retry a failed AI response
    func retryResponse(for post: Post, from characterId: String) async {
        // Remove the failed response
        if var postResponses = responses[post.id] {
            postResponses.removeAll { $0.character?.id == characterId }
            responses[post.id] = postResponses
        }
        
        // Find the character from eligible characters and generate a new response
        let eligibleCharacters = AICharacter.charactersFor(post: post)
        if let character = eligibleCharacters.first(where: { $0.id == characterId }) {
            await generateResponses(for: post, with: [character])
        }
    }
    
    // Retry a failed reply
    func retryReply(for responseId: String, replyId: String) async {
        // Remove the failed reply
        if var replies = commentReplies[responseId] {
            if let failedReply = replies.first(where: { $0.id == replyId }),
               let response = responses.values.flatMap({ $0 }).first(where: { $0.id == responseId }) {
                replies.removeAll { $0.id == replyId }
                commentReplies[responseId] = replies
                
                // Generate a new reply
                await addUserReply(to: responseId, content: failedReply.content, aiResponse: response)
            }
        }
    }
    
    // Load all AI responses and their nested replies for a specific post
    func preloadAllResponsesAndReplies(for postId: String) async {
        // print("🔍 TREE PRELOAD: Starting preload for post: \(postId)")
        
        do {
            // First, load all AI responses for this post
            try await fetchResponses(for: postId)
            
            // Get the loaded responses
            let postResponses = responses[postId] ?? []
            if postResponses.isEmpty {
                //print("⚠️ TREE PRELOAD: No responses found for post \(postId)")
                return
            }
            
            //print("✅ TREE PRELOAD: Found \(postResponses.count) responses for post \(postId)")
            
            // For each response, load all its replies and build the tree
            for response in postResponses {
                //print("🔄 TREE PRELOAD: Building reply tree for response ID: \(response.id)")
                
                try await fetchReplies(for: response.id)
                
                let repliesCount = commentReplies[response.id]?.count ?? 0
                //print("✅ TREE PRELOAD: Loaded \(repliesCount) replies for response \(response.id)")
            }
            
            //print("🎉 TREE PRELOAD: Completed loading all responses and reply trees for post: \(postId)")
        } catch {
            print("❌ TREE PRELOAD ERROR: \(error.localizedDescription)")
        }
    }
    
    // Force reload of all replies for a response
    func forceReloadReplies(for responseId: String) async {
        //print("🔄 FORCE RELOAD: Forcing reload of all replies for response \(responseId)")
        
        // Clear any cached replies first
        await MainActor.run {
            self.commentReplies[responseId] = nil
        }
        
        // Fetch fresh data
        do {
            try await fetchReplies(for: responseId)
            //print("✅ FORCE RELOAD: Successfully reloaded replies for response \(responseId)")
        } catch {
            print("❌ FORCE RELOAD ERROR: \(error.localizedDescription)")
        }
    }
    
    // Check if the comment replies include nested conversations
    func hasNestedReplies(for responseId: String) -> Bool {
        let replies = commentReplies[responseId] ?? []
        
        // Check if any reply has a replyToId that is not nil
        return replies.contains { reply in
            return reply.replyToId != nil
        }
    }
    
    // Debug the entire reply tree structure for a post
    func debugReplyTreeForPost(postId: String) async {
        print("🔍 DEBUG TREE: Analyzing reply structure for post \(postId)")
        
        // Get all responses for the post
        let postResponses = responses[postId] ?? []
        print("📊 Found \(postResponses.count) responses for post")
        
        // For each response, analyze its reply tree
        for response in postResponses {
            let replies = commentReplies[response.id] ?? []
            
            //print("📝 Response \(response.id) has \(replies.count) total replies")
            
            // Count root vs nested replies
            let rootReplies = replies.filter { $0.replyToId == nil }.count
            let nestedReplies = replies.filter { $0.replyToId != nil }.count
            
            //print("  🌱 Root replies: \(rootReplies)")
            //print("  🌲 Nested replies: \(nestedReplies)")
            
            // Identify conversation chains
            var replyChains: [String: [String]] = [:]
            for reply in replies where reply.replyToId != nil {
                if replyChains[reply.replyToId!] == nil {
                    replyChains[reply.replyToId!] = []
                }
                replyChains[reply.replyToId!]!.append(reply.id)
            }
            
            // Print chains
            for (parentId, children) in replyChains {
                print("  🔗 Reply chain: \(parentId) -> \(children.joined(separator: ", "))")
            }
        }
    }
    
    // Method to ensure responses are loaded for a post when the comment button is clicked
    func ensureResponsesLoaded(for post: Post) async {
        print("🔍 Ensuring responses are loaded for post: \(post.id)")
        
        // First, check if responses are already loaded in memory
        let existingResponses = self.responses[post.id] ?? []
        if !existingResponses.isEmpty {
            print("✅ Post \(post.id) already has \(existingResponses.count) responses in memory")
            
            // If we have pending responses, wait a moment to see if they complete
            if existingResponses.contains(where: { $0.status == .pending }) {
                print("⏳ Post has pending responses, waiting briefly for completion")
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                } catch {
                    print("⚠️ Sleep interrupted: \(error.localizedDescription)")
                }
            }
            
            return
        }
        
        // If not in memory, try to fetch from database directly
        do {
            let query = SupabaseConfig.shared.database
                .from("ai_responses")
                .select("*")
                .eq("post_id", value: post.id)
            
            let response = try await query.execute()
            let data = response.data
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Try to decode the responses
            let existingResponses = try decoder.decode([AIResponseDTO].self, from: data)
            
            if !existingResponses.isEmpty {
                print("✅ Found \(existingResponses.count) existing responses in database for post \(post.id)")
                
                // Convert DTOs to domain models and update cache
                let domainResponses = existingResponses.map { $0.toAIResponse() }
                
                await MainActor.run {
                    // Update in-memory cache
                    self.responses[post.id] = domainResponses
                    
                    // Update the responded characters set
                    if self.respondedCharacters[post.id] == nil {
                        self.respondedCharacters[post.id] = []
                    }
                    
                    for response in domainResponses {
                        if let characterId = response.character?.id {
                            self.respondedCharacters[post.id]!.insert(characterId)
                        }
                    }
                    
                    print("📋 Updated responses dictionary: post ID \(post.id) now has \(domainResponses.count) responses")
                    self.objectWillChange.send()
                }
                
                // Also load all replies for these responses
                for response in domainResponses {
                    try? await fetchReplies(for: response.id)
                }
                
                return
            }
            
            print("🆕 No existing responses found in database, generating new ones for post \(post.id)")
        } catch {
            print("⚠️ Error checking for existing responses: \(error.localizedDescription)")
        }
        
        // If we get here, we need to generate new responses
        await generateResponses(for: post, with: AICharacter.charactersFor(post: post))
    }
} 
