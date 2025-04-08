


import SwiftUI

struct ExpandedPostCardView: View {
    let post: Post
    @ObservedObject var aiManager: AIResponseManager
    @ObservedObject var postsManager: PostsManager
    @State private var showAIResponses = false
    @State private var isButtonDisabled = false
    
    var onLikeTapped: () -> Void
    var onCommentTapped: () -> Void
    var onViewCommentsTapped: () -> Void
    var onDeleteTapped: (() -> Void)?
    
    // Initialize with dependencies
    init(
        post: Post,
        aiManager: AIResponseManager,
        postsManager: PostsManager = PostsManager.shared,
        onLikeTapped: @escaping () -> Void = {},
        onCommentTapped: @escaping () -> Void = {},
        onViewCommentsTapped: @escaping () -> Void = {},
        onDeleteTapped: (() -> Void)? = nil
    ) {
        self.post = post
        self.aiManager = aiManager
        self.postsManager = postsManager
        self.onLikeTapped = onLikeTapped
        self.onCommentTapped = onCommentTapped
        self.onViewCommentsTapped = onViewCommentsTapped
        self.onDeleteTapped = onDeleteTapped
    }
    
    // Get whether there are any responses to show
    private var hasResponses: Bool {
        return !aiManager.getResponses(for: post.id).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Post header with profile info
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading) {
                    Text(post.username)
                        .font(.headline)
                    Text(post.timeAgo)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if let tag = post.tag {
                    Text("#\(tag)")
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding()
            
            // Divider between header and content
            Divider()
                .padding(.horizontal)
            
            // Post content
            Text(post.content)
                .font(.body)
                .padding(.horizontal)
                .padding(.top)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Fitness info section
            if let fitnessInfo = post.fitnessInfo {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Today's Workout")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text(fitnessInfo)
                        .font(.body)
                        .foregroundColor(.primary)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(8)
                .padding()
            }
            
            // Image if available
            if let uiImage = post.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipped()
                    .padding(.vertical)
                    .onAppear {
                        print("📱 DEBUG: Displaying image for post ID: \(post.id)")
                    }
            } else if let imageName = post.imageName {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 250)
                    .clipped()
                    .padding(.vertical)
                    .onAppear {
                        print("📱 DEBUG: Displaying named image: \(imageName) for post ID: \(post.id)")
                    }
            } else {
                Color.clear
                    .frame(height: 0)
                    .onAppear {
                        print("⚠️ DEBUG: No image available for post ID: \(post.id)")
                    }
            }
            
            // Interaction bar (like, comment buttons)
            PostInteractionBar(
                post: post,
                postsManager: postsManager,
                onLikeTapped: onLikeTapped,
                onCommentTapped: {
                    // Prevent rapid multiple taps with debounce
                    guard !isButtonDisabled else { return }
                    
                    // Disable button temporarily
                    isButtonDisabled = true
                    
                    // Only toggle the visibility, don't increment count
                    let newState = !showAIResponses
                    
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showAIResponses = newState
                    }
                    
                    // Ensure responses are loaded when opened
                    if newState {
                        Task {
                            // Ensure post image is loaded if it has one
                            if post.image == nil && (post.imageName != nil || post.fitnessInfo != nil) {
                                _ = await postsManager.updatePostImage(id: post.id)
                            }
                            
                            // Use the dedicated method to ensure responses are loaded
                            await aiManager.ensureResponsesLoaded(for: post)
                            
                            // Re-enable button after a short delay to prevent accidental double-taps
                            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                            await MainActor.run {
                                isButtonDisabled = false
                            }
                        }
                    } else {
                        // Re-enable button sooner when closing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            isButtonDisabled = false
                        }
                    }
                    // DON'T call onCommentTapped here as it might be triggering count increments
                },
                onDeleteTapped: {
                    // Call provided delete handler or default to using PostsManager
                    if let customDeleteAction = onDeleteTapped {
                        customDeleteAction()
                    } else {
                        Task {
                            await postsManager.deletePost(id: post.id)
                        }
                    }
                }
            )
            .padding(.horizontal)
            
            // View comments button
            Button(action: onViewCommentsTapped) {
                HStack {
                    Text("View all \(post.commentCount) comments")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            
            // Conditional AI response section
            if showAIResponses {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal)
                    
                    HStack {
                        Text("AI Response")
                            .font(.headline)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        Spacer()
                    }
                    
                    AIResponseView(post: post, aiManager: aiManager)
                        .padding(.horizontal)
                        .padding(.bottom)
                        .transition(.opacity)
                        .onAppear {
                            print("📱 AIResponseView appeared for post: \(post.id)")
                        }
                }
                .transition(.opacity)
            }
        }
        .background(Color(hex: "FFF8DD"))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .id("post-\(post.id)-\(showAIResponses ? "open" : "closed")")  // Simplified ID pattern
        .onAppear {
            // When card appears, ensure image is loaded if it's missing
            if post.image == nil && post.imageName == nil {
                print("🔄 DEBUG: Expanded post card appeared without image, attempting to load it for post ID: \(post.id)")
                Task {
                    if await postsManager.updatePostImage(id: post.id) {
                        print("✅ DEBUG: Successfully loaded and attached image for post ID: \(post.id)")
                    }
                }
            }
            
            // Prefetch responses in the background without showing them
            Task {
                await aiManager.autoGenerateResponses(for: post)
            }
        }
    }
}

#Preview {
    ExpandedPostCardView(
        post: Post(
            id: "preview-id",
            content: "This is a sample expanded post for preview with fitness information",
            likeCount: 25,
            commentCount: 5,
            imageName: nil,
            image: nil,
            timeAgo: "15m ago",
            fitnessInfo: "Ran 5km in 25 minutes. Feeling great!",
            aiResponse: nil,
            tag: "running"
        ),
        aiManager: AIResponseManager(),
        postsManager: PostsManager.shared,
        onLikeTapped: {},
        onCommentTapped: {},
        onViewCommentsTapped: {},
        onDeleteTapped: nil
    )
}
