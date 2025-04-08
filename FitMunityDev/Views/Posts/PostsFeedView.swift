

import SwiftUI

struct PostsFeedView: View {
    @EnvironmentObject private var postsManager: PostsManager
    @EnvironmentObject private var aiManager: AIResponseManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var showCreatePost = false
    @State private var scrollToPostId: String? = nil
    @State private var highlightedPostId: String? = nil
    
    var body: some View {
        ScrollViewReader { scrollReader in
            ZStack {
                // Background
                Color(hex: "FFF8DD").edgesIgnoringSafeArea(.all)
                
                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 16) {
                            // Add post and progress indicator row
                            HStack(spacing: 12) {
                                // Add post button
                                AddPostButton {
                                    showCreatePost = true
                                }
                                
                                // Progress indicator
                                ProgressIndicatorView(progress: 0.65, goalDate: "3 Aug 2022")
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            
                            // Error message
                            if let error = postsManager.error {
                                VStack(spacing: 20) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.orange)
                                    
                                    Text("Error loading posts")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text(error)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        Task {
                                            try? await postsManager.fetchPosts()
                                        }
                                    }) {
                                        Text("Try Again")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(Color.yellow)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(.top, 40)
                                .padding(.bottom, 40)
                                .frame(maxWidth: .infinity)
                            }
                            // Show message if no posts
                            else if postsManager.posts.isEmpty {
                                VStack(spacing: 20) {
                                    Image(systemName: "square.and.pencil")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    
                                    Text("No posts yet")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text("Create your first post by tapping the + button above")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        showCreatePost = true
                                    }) {
                                        Text("Create Post")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 10)
                                            .background(Color.yellow)
                                            .cornerRadius(8)
                                    }
                                }
                                .padding(.top, 40)
                                .padding(.bottom, 40)
                                .frame(maxWidth: .infinity)
                            }
                            
                            // Post content
                            ForEach(postsManager.posts, id: \.id) { post in
                                VStack(spacing: 0) {
                                    postCardFor(post: post)
                                        .id(post.id) // Set an ID for scrolling to specific post
                                        .onTapGesture {
                                            // Handle post tap if needed
                                        }
                                        .overlay(
                                            // Highlight the post if it's the one from the notification
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.yellow, lineWidth: post.id == highlightedPostId ? 3 : 0)
                                                .animation(.easeInOut(duration: 0.3), value: highlightedPostId)
                                        )
                                }
                                .padding(.bottom, 16)
                            }
                        }
                        .padding(16)
                    }
                }
                .background(Color(hex: "FFF8DD"))
                .edgesIgnoringSafeArea(.bottom) // Only ignore bottom safe area
            }
            .sheet(isPresented: $showCreatePost) {
                EditPostView(isPresented: $showCreatePost)
            }
            .onAppear {
                // Set up notification observer
                setupNotificationObserver()
                
                // Fetch posts on appear if we're signed in
                if authManager.authState == .signedIn {
                    Task {
                        try? await postsManager.fetchPosts()
                        
                        // Also refresh post images
                        await postsManager.refreshPostImages()
                        
                        // Preload all images to ensure they're ready in the memory cache
                        await postsManager.preloadAllImages()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Refresh images when app returns to foreground
                if authManager.authState == .signedIn {
                    Task {
                        print("🔄 App returning to foreground, refreshing post images")
                        await postsManager.refreshPostImages()
                    }
                }
            }
            .onChange(of: scrollToPostId) { newValue in
                if let postId = newValue {
                    // Small delay to ensure UI is ready
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollReader.scrollTo(postId, anchor: .center)
                        
                        // Highlight the post
                        withAnimation(.easeInOut(duration: 0.5)) {
                            highlightedPostId = postId
                        }
                        
                        // Provide haptic feedback
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                        
                        // Clear scroll target
                        scrollToPostId = nil
                        
                        // Clear highlight after a delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            withAnimation {
                                highlightedPostId = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    // Set up notification observer for navigating to posts
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("NavigateToPost"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let postId = userInfo["postId"] as? String {
                // Set the post ID to scroll to
                scrollToPostId = postId
            }
        }
    }
    
    // Helper function to determine which post card to use
    private func postCardFor(post: Post) -> some View {
        // Debug post ID to make sure it's unique
        // print("🔍 Displaying post card with ID: \(post.id)")
        
        return Group {
            if post.fitnessInfo != nil {
                // Use expanded post card for posts with fitness info
                ExpandedPostCardView(
                    post: post,
                    aiManager: aiManager,
                    onLikeTapped: { likePost(post) },
                    onCommentTapped: { openComments(post) },
                    onViewCommentsTapped: { openComments(post) },
                    onDeleteTapped: { deletePost(post) }
                )
                .onAppear {
                    // We'll let the AIResponseManager handle checking if responses already exist
                    print("🆔 Post appear with ID: \(post.id)")
                }
            } else if post.image != nil || post.imageName != nil {
                // Use image post card for posts with images (either UIImage or asset name)
                ImagePostCard(
                    post: post,
                    aiManager: aiManager,
                    onLikeTapped: { likePost(post) },
                    onCommentTapped: { openComments(post) },
                    onDeleteTapped: { deletePost(post) }
                )
                .onAppear {
                    print("🆔 Post appear with ID: \(post.id)")
                }
            } else {
                // Use standard post card for text-only posts
                PostCard(
                    post: post,
                    aiManager: aiManager,
                    onLikeTapped: { likePost(post) },
                    onCommentTapped: { openComments(post) },
                    onDeleteTapped: { deletePost(post) }
                )
                .onAppear {
                    print("🆔 Post appear with ID: \(post.id)")
                }
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 2)
    }
    
    // Action handlers
    private func likePost(_ post: Post) {
        Task {
            await postsManager.likePost(id: post.id)
        }
    }
    
    private func openComments(_ post: Post) {
        // DON'T increment the comment count manually - it should only increase when AI characters respond
        // postsManager.addComment(to: post.id)
        
        // In a real app, this would navigate to a comments view
        print("Opening comments for post: \(post.id)")
    }
    
    private func deletePost(_ post: Post) {
        Task {
            await postsManager.deletePost(id: post.id)
        }
    }
}

// MARK: - Previews
struct PostsFeedView_Previews: PreviewProvider {
    static var previews: some View {
        PostsFeedView()
            .environmentObject(PostsManager.shared)
            .environmentObject(AIResponseManager())
            .environmentObject(AuthManager())
    }
}
