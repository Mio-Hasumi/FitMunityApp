import SwiftUI

struct AIResponseView: View {
    let post: Post
    @ObservedObject var aiManager: AIResponseManager
    @ObservedObject var postsManager: PostsManager = PostsManager.shared
    
    // State for inline reply input
    @State private var replyActiveForResponseId: String? = nil
    @State private var replyActiveForCommentId: String? = nil
    @State private var replyText: String = ""
    @State private var showingRepliesFor: String? = nil
    
    // Get all characters that would respond to this post
    private var characters: [AICharacter] {
        return AICharacter.charactersFor(post: post)
    }
    
    // Get whether there are any responses to show
    private var responses: [AIResponse] {
        return aiManager.getResponses(for: post.id)
    }
    
    // Check if we have any completed responses
    private var hasCompletedResponses: Bool {
        return responses.contains { $0.status == .completed }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Only show AI Response section if there are completed responses
            if hasCompletedResponses {
                // Show all completed responses
                ForEach(responses.filter { $0.status == .completed }) { response in
                    characterResponseView(for: response)
                        .id("response-view-\(response.id)")
                        .animation(.easeInOut(duration: 0.3), value: response.id)
                }
            } else if responses.contains(where: { $0.status == .pending }) {
                // Show loading indicator while responses are being generated
                HStack {
                    Spacer()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("AI is responding...")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .animation(.easeInOut, value: responses)
            } else {
                // Otherwise, show nothing but trigger response generation
                Color.clear.frame(height: 0)
                    .onAppear {
                        print("🔄 AIResponseView - No responses available yet for post: \(post.id)")
                        // Explicitly check if responses need to be generated
                        Task {
                            // Preload post image if needed
                            if post.image == nil {
                                print("🖼️ DEBUG: Preloading image for post in AIResponseView: \(post.id)")
                                await postsManager.updatePostImage(id: post.id)
                            }
                            // Generate responses
                            await aiManager.ensureResponsesLoaded(for: post)
                        }
                    }
            }
        }
        .padding()
        .background(Color(hex: "FFF8DD"))
        .cornerRadius(12)
        .opacity(hasCompletedResponses || responses.contains(where: { $0.status == .pending }) ? 1 : 0) // Show when responses are loading or completed
        .onAppear {
            print("🌳 TREE VIEW: AIResponseView appeared for post: \(post.id)")
            
            // Preload all replies when view appears
            Task {
                await aiManager.preloadAllResponsesAndReplies(for: post.id)
            }
        }
    }
    
    // Helper method to ensure all replies are reloaded
    private func reloadAllRepliesForPost() async {
        print("🔄 DEBUG: Reloading all replies for post: \(post.id)")
        
        // First ensure the post image is loaded
        if post.image == nil {
            print("🖼️ DEBUG: Preloading image during reply reload: \(post.id)")
            await postsManager.updatePostImage(id: post.id)
        }
        
        // Then reload all replies for each response
        for response in responses {
            await aiManager.forceReloadReplies(for: response.id)
        }
    }
    
    // Function to organize replies into a nested structure
    private func organizeReplies(for responseId: String) -> [String: Any] {
        let allReplies = aiManager.getReplies(for: responseId)
        print("🌳 VIEW TREE: Organizing \(allReplies.count) replies for response ID: \(responseId)")
        
        // Create a lookup dictionary to quickly access replies by ID
        var replyLookup: [String: CommentReply] = [:]
        for reply in allReplies {
            replyLookup[reply.id] = reply
            print("  📝 Reply \(reply.id) - isUser: \(reply.isUserReply), content: \"\(reply.content.prefix(20))...\"")
        }
        
        // Group replies by parent IDs to build the tree
        var replyTree: [String: Any] = [:]
        var repliesByParent: [String?: [CommentReply]] = [:]
        
        // First pass: group replies by their parent ID
        for reply in allReplies {
            if repliesByParent[reply.replyToId] == nil {
                repliesByParent[reply.replyToId] = []
            }
            repliesByParent[reply.replyToId]!.append(reply)
        }
        
        // Log root replies (those without a parent)
        let rootReplies = repliesByParent[nil] ?? []
        print("  🌱 Found \(rootReplies.count) root replies")
        
        // Group replies by their parent ID for fast lookup
        for (parentId, replies) in repliesByParent {
            if let parent = parentId {
                print("  👨‍👦 Parent \(parent) has \(replies.count) direct replies")
            }
        }
        
        // Store the result in the tree structure
        replyTree["lookup"] = replyLookup
        replyTree["byParent"] = repliesByParent
        replyTree["roots"] = rootReplies
        
        return replyTree
    }
    
    // Helper to find the ID of the deepest/most recent reply in a thread
    private func findDeepestReplyId(for responseId: String) -> String? {
        let replyTree = organizeReplies(for: responseId)
        let byParent = replyTree["byParent"] as? [String?: [CommentReply]] ?? [:]
        
        // If there are no replies yet, return nil (will default to the main response)
        let allReplies = aiManager.getReplies(for: responseId)
        if allReplies.isEmpty {
            return nil
        }
        
        // Find the most recent reply (sorted by timestamp)
        let sortedReplies = allReplies.sorted { $0.timestamp > $1.timestamp }
        return sortedReplies.first?.id
    }
    
    // View for a character's response
    private func characterResponseView(for response: AIResponse) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Character information
            HStack(alignment: .top) {
                // Character avatar
                Circle()
                    .fill(characterColor(for: response.character?.id ?? "default"))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String((response.character?.name.first ?? "?").uppercased()))
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .bold))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    // Character name
                    Text(response.character?.name ?? "AI Character")
                        .font(.headline)
                        .foregroundColor(.black)
                    
                    // Response content
                    Text(response.content)
                        .foregroundColor(.black)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            // Replies section
            if aiManager.hasReplies(for: response.id) {
                Divider()
                    .padding(.vertical, 8)
                
                // If showing replies for this response, add them
                if showingRepliesFor == response.id {
                    // Show all replies using the enhanced tree structure
                    let replyTree = organizeReplies(for: response.id)
                    replyThread(responseId: response.id, tree: replyTree)
                    
                    // Hide button
                    Button(action: {
                        showingRepliesFor = nil
                    }) {
                        Text("Hide replies")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                } else {
                    // Show replies button
                    Button(action: {
                        showingRepliesFor = response.id
                        Task {
                            await aiManager.forceReloadReplies(for: response.id)
                            
                            // Also ensure post image is loaded
                            if post.image == nil {
                                let _ = await postsManager.updatePostImage(id: post.id)
                            }
                        }
                    }) {
                        Text("Show \(aiManager.getReplies(for: response.id).count) replies")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Main reply section at the bottom - always shown
            let deepestReplyId = findDeepestReplyId(for: response.id)
            
            // Show reply input field if active
            if replyActiveForResponseId == response.id {
                // Show reply input for either the main response or the deepest reply
                if let replyId = deepestReplyId {
                    // Reply to the deepest reply in the thread
                    replyInputField(for: response.id, replyToId: replyId)
                } else {
                    // Default to replying to the main response if no deeper replies exist
                    replyInputField(for: response.id)
                }
            } else {
                // Show the yellow reply button
                HStack {
                    Spacer()
                    Button(action: {
                        replyActiveForResponseId = response.id
                        // If there are replies, target the most recent one
                        if let deepestId = deepestReplyId {
                            replyActiveForCommentId = deepestId
                        } else {
                            replyActiveForCommentId = nil
                        }
                        replyText = ""
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.caption)
                            Text("Reply")
                                .font(.caption)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(hex: "FFDD66"))
                        .foregroundColor(.black)
                        .cornerRadius(16)
                    }
                }
                .padding(.top, 8)
            }
            
            // Show reply loading indicator
            if aiManager.isGeneratingReply(for: response.id) {
                HStack {
                    Spacer()
                    Text("Replying...")
                        .font(.caption)
                        .foregroundColor(.gray)
                    ProgressView()
                        .scaleEffect(0.7)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(hex: "FFF8DD"))
        .cornerRadius(12)
        .id("response-\(response.id)") // Add a stable ID for this response view
    }
    
    // View for a thread of replies with the robust tree structure
    private func replyThread(responseId: String, tree: [String: Any]) -> some View {
        // Debugging info
        let roots = tree["roots"] as? [CommentReply] ?? []
        let byParent = tree["byParent"] as? [String?: [CommentReply]] ?? [:]
        let lookup = tree["lookup"] as? [String: CommentReply] ?? [:]
        
        print("📁 REPLY THREAD: Showing \(roots.count) root replies for response \(responseId)")
        
        return VStack(alignment: .leading, spacing: 12) { // Increased spacing between reply groups
            // Ensure the post image is loaded when thread is shown
            Color.clear.frame(height: 0)
                .onAppear {
                    print("🖼️ DEBUG: Reply thread shown, checking post image: \(post.id)")
                    Task {
                        if post.image == nil {
                            print("🖼️ DEBUG: Preloading image for reply thread: \(post.id)")
                            await postsManager.updatePostImage(id: post.id)
                        }
                    }
                }
            
            // Show all root replies
            ForEach(roots) { rootReply in
                VStack(alignment: .leading, spacing: 8) { // Added VStack with spacing for each reply group
                    // Root comment
                    replyView(for: rootReply, responseId: responseId, indentLevel: 0)
                    
                    // Show any replies to this comment with indentation
                    recursiveReplies(for: rootReply.id, byParent: byParent, lookup: lookup, responseId: responseId, indentLevel: 1)
                }
            }
        }
        .padding(.vertical, 8) // Added padding around the entire thread
    }
    
    // Helper to create a consistent reply input field
    private func replyInputField(for responseId: String, replyToId: String? = nil, indentLevel: Int = 0) -> some View {
        VStack(spacing: 4) {
            // If replying to a specific comment, show an indicator
            if let replyTo = replyToId, let name = getReplyTargetName(replyId: replyTo, responseId: responseId) {
                HStack {
                    if indentLevel > 0 {
                        Spacer()
                            .frame(width: CGFloat(indentLevel) * 20)
                    }
                    Text("Replying to \(name)")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.bottom, 2)
                    Spacer()
                }
            }
            
            HStack(spacing: 8) {
                if indentLevel > 0 {
                    Spacer()
                        .frame(width: CGFloat(indentLevel) * 20) // Indent based on depth
                }
                
                TextField(replyToId == nil ? "Type your reply..." : "Reply...", text: $replyText)
                    .padding(8)
                    .background(Color(hex: "FFDD66"))
                    .foregroundColor(.black)
                    .cornerRadius(16)
                
                Button(action: {
                    if let replyTo = replyToId {
                        submitNestedReply(for: responseId, replyToId: replyTo)
                    } else {
                        if let response = responses.first(where: { $0.id == responseId }) {
                            submitReply(for: response)
                        }
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundColor(replyText.isEmpty ? .gray : .white)
                        .background(Circle().fill(replyText.isEmpty ? Color.clear : Color(hex: "FFDD66")))
                }
                .disabled(replyText.isEmpty)
            }
        }
        .padding(.top, 4)
    }
    
    // Helper to get the name of the user/character we're replying to
    private func getReplyTargetName(replyId: String, responseId: String) -> String? {
        let allReplies = aiManager.getReplies(for: responseId)
        if let reply = allReplies.first(where: { $0.id == replyId }) {
            return reply.isUserReply ? "You" : (reply.character?.name ?? "AI")
        }
        return nil
    }
    
    // View for a reply
    private func replyView(for reply: CommentReply, responseId: String, indentLevel: Int = 0) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Indentation based on depth level
            if indentLevel > 0 {
                Spacer()
                    .frame(width: CGFloat(indentLevel) * 20)
            }
            
            // Avatar
            if reply.isUserReply {
                // User avatar
                Circle()
                    .fill(Color.gray)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text("U")
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                    )
            } else {
                // Character avatar
                Circle()
                    .fill(characterColor(for: reply.character?.id ?? "default"))
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(String((reply.character?.name.first ?? "?").uppercased()))
                            .foregroundColor(.white)
                            .font(.system(size: 12, weight: .bold))
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                // Display username or character name
                Text(reply.isUserReply ? "You" : (reply.character?.name ?? "AI"))
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                // Reply content
                Text(reply.content)
                    .font(.body)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 2)
    }
    
    // Submit a reply to an AI response or to a comment
    private func submitReply(for response: AIResponse) {
        guard !replyText.isEmpty else { return }
        
        Task {
            // Ensure post image is loaded before making the reply
            if post.image == nil {
                print("🖼️ DEBUG: Preloading image for reply to response, post ID: \(post.id)")
                await postsManager.updatePostImage(id: post.id)
            }
            
            // If replyActiveForCommentId is set, we're replying to a specific comment,
            // otherwise we're replying to the main response
            if let commentId = replyActiveForCommentId {
                // Reply to a specific comment
                await aiManager.addUserReply(to: response.id, content: replyText, aiResponse: response, replyToId: commentId)
            } else {
                // Reply to the main response
                await aiManager.addUserReply(to: response.id, content: replyText, aiResponse: response)
            }
            
            // Clear input and reset state
            DispatchQueue.main.async {
                replyText = ""
                replyActiveForResponseId = nil
                replyActiveForCommentId = nil
            }
        }
    }
    
    // Submit a nested reply to another comment
    private func submitNestedReply(for responseId: String, replyToId: String) {
        guard !replyText.isEmpty else { return }
        
        // Get the original response
        if let response = responses.first(where: { $0.id == responseId }) {
            // Make sure the post image is loaded before submitting the reply
            Task {
                // Ensure post image is loaded before making the reply
                if post.image == nil {
                    print("🖼️ DEBUG: Preloading image for nested reply to comment, post ID: \(post.id)")
                    await postsManager.updatePostImage(id: post.id)
                }
                
                // Submit the reply to the specified comment
                await aiManager.addUserReply(to: responseId, content: replyText, aiResponse: response, replyToId: replyToId)
                
                // Clear input and reset state
                DispatchQueue.main.async {
                    replyText = ""
                    replyActiveForCommentId = nil
                    replyActiveForResponseId = nil
                    
                    // Show replies if they're not already shown
                    if showingRepliesFor != responseId {
                        showingRepliesFor = responseId
                    }
                }
            }
        }
    }
    
    // Get a color for a character
    private func characterColor(for characterId: String) -> Color {
        let colors: [Color] = [
            Color(hex: "FF6B6B"),  // Red
            Color(hex: "4ECDC4"),  // Teal
            Color(hex: "FFE66D"),  // Yellow
            Color(hex: "1A535C"),  // Dark blue
            Color(hex: "FF9F1C"),  // Orange
            Color(hex: "7B68EE")   // Purple
        ]
        
        // Generate a consistent index based on the character ID
        if let firstChar = characterId.first, let ascii = firstChar.asciiValue {
            return colors[Int(ascii) % colors.count]
        }
        
        return colors[0]
    }
    
    // Recursively show replies to a comment
    private func recursiveReplies(for replyId: String, byParent: [String?: [CommentReply]], lookup: [String: CommentReply], responseId: String, indentLevel: Int) -> VStack<ForEach<[CommentReply], String, VStack<TupleView<(AnyView, AnyView)>>>> {
        // Get all replies to this comment
        let children = byParent[replyId] ?? []
        
        return VStack(alignment: .leading, spacing: 8) { // Added consistent spacing between replies
            ForEach(children) { childReply in
                VStack(alignment: .leading, spacing: 8) { // Added VStack with spacing for each nested reply
                    // Show the child comment with indentation
                    AnyView(replyView(for: childReply, responseId: responseId, indentLevel: indentLevel))
                    
                    // Recursive call for this child's replies
                    AnyView(recursiveReplies(for: childReply.id, byParent: byParent, lookup: lookup, responseId: responseId, indentLevel: indentLevel + 1))
                }
            }
        }
    }
}

// MARK: - Previews
struct AIResponseView_Previews: PreviewProvider {
    static var previews: some View {
        let post = Post(
            id: "preview-id",
            content: "This is a sample post for preview",
            likeCount: 10,
            commentCount: 2,
            imageName: nil,
            image: nil,
            timeAgo: "5m ago",
            fitnessInfo: nil,
            aiResponse: nil,
            tag: "fitness"
        )
        let aiManager = AIResponseManager()
        let postsManager = PostsManager()
        
        return AIResponseView(post: post, aiManager: aiManager, postsManager: postsManager)
            .padding()
            .previewLayout(.sizeThatFits)
    }
} 
