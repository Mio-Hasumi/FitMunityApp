

import SwiftUI

// A shared component for the interaction bar at the bottom of posts
struct PostInteractionBar: View {
    let post: Post
    @ObservedObject var postsManager: PostsManager
    @State private var likeCount: Int
    @State private var isLiked: Bool = false
    @State private var showDeleteConfirmation = false
    
    var onLikeTapped: () -> Void = {}
    var onCommentTapped: () -> Void = {}
    var onDeleteTapped: () -> Void = {}
    
    // Initialize with a post
    init(post: Post, postsManager: PostsManager = PostsManager.shared, 
         onLikeTapped: @escaping () -> Void = {}, 
         onCommentTapped: @escaping () -> Void = {},
         onDeleteTapped: @escaping () -> Void = {}) {
        self.post = post
        self.postsManager = postsManager
        self._likeCount = State(initialValue: post.likeCount)
        self.onLikeTapped = onLikeTapped
        self.onCommentTapped = onCommentTapped
        self.onDeleteTapped = onDeleteTapped
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Spacer()
            
            // Like button with count
            Button(action: {
                // Toggle like state
                isLiked.toggle()
                
                // Update like count
                if isLiked {
                    likeCount += 1
                } else {
                    likeCount -= 1
                }
                
                // Call the provided action
                onLikeTapped()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 16))
                        .foregroundColor(isLiked ? .red : .black)
                    
                    Text("\(likeCount)")
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(hex: "FFDD66"))
                .cornerRadius(16)
            }
            .foregroundColor(.black)
            
            Spacer()
            
            // Comment button without count
            Button(action: onCommentTapped) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFDD66"))
                    .cornerRadius(16)
            }
            .foregroundColor(.black)
            
            Spacer()
            
            // Delete button
            Button(action: {
                showDeleteConfirmation = true
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color(hex: "FFDD66"))
                    .cornerRadius(16)
            }
            .foregroundColor(.black)
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Post"),
                    message: Text("Are you sure you want to delete this post?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDeleteTapped()
                    },
                    secondaryButton: .cancel()
                )
            }
            
            Spacer()
        }
        .padding(.vertical, 12)
        .background(Color(hex: "FFF8DD"))
        .cornerRadius(24)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 1)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
}

// MARK: - Previews
#Preview {
    VStack {
        PostInteractionBar(
            post: Post(
                id: "preview-id",
                content: "Sample post content",
                likeCount: 42,
                commentCount: 7,
                imageName: nil,
                image: nil,
                timeAgo: "3h ago",
                fitnessInfo: nil,
                aiResponse: nil,
                tag: nil
            )
        )
        .padding()
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
