


import SwiftUI

struct NotificationView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var aiResponseManager: AIResponseManager
    @EnvironmentObject var postsManager: PostsManager
    @State private var selectedPostId: String? = nil
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ZStack {
                Color(hex: "FFDD66")
                
                HStack {
                    Button(action: {
                        isPresented = false // Dismiss notification view and return to posts
                    }) {
                        ZStack {
                            Circle()
                                .stroke(Color.black, lineWidth: 1)
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.leading)
                    
                    Text("Notification")
                        .font(.system(size: 24, weight: .medium))
                        .padding(.leading, 8)
                    
                    Spacer()
                }
                .padding(.vertical, 12)
            }
            .frame(height: 56)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Get all notifications sorted by timestamp
                    let allNotifications = aiResponseManager.getNotifications()
                    
                    // Filter for today's notifications (last 24 hours)
                    let calendar = Calendar.current
                    let today = calendar.startOfDay(for: Date())
                    
                    let todayNotifications = allNotifications.filter { 
                        calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.timestamp), to: today).day == 0
                    }
                    
                    // Filter for this week's notifications (older than 24 hours)
                    let olderNotifications = allNotifications.filter {
                        calendar.dateComponents([.day], from: calendar.startOfDay(for: $0.timestamp), to: today).day ?? 0 > 0
                    }
                    
                    // Today's notifications
                    if !todayNotifications.isEmpty {
                        Text("new")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal)
                            .padding(.top, 16)
                        
                        ForEach(todayNotifications) { notification in
                            aiNotificationRow(notification)
                        }
                    } else if allNotifications.isEmpty {
                        // No notifications case
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "bell.slash")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            
                            Text("No notifications yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("When AI characters comment on your posts, you'll see their notifications here.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 80)
                    }
                    
                    // This week's notifications
                    if !olderNotifications.isEmpty {
                        Text("this week")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal)
                            .padding(.top, 8)
                        
                        ForEach(olderNotifications) { notification in
                            aiNotificationRow(notification)
                        }
                    }
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color(hex: "FFF8E1"))
            
            // Bottom indicator
            Rectangle()
                .fill(Color.black)
                .frame(width: 134, height: 5)
                .cornerRadius(2.5)
                .padding(.bottom, 8)
        }
        .background(Color(hex: "FFF8E1"))
        .edgesIgnoringSafeArea(.bottom)
        .onChange(of: selectedPostId) { newValue in
            // Navigate to the selected post if a post ID is provided
            if let postId = newValue {
                navigateToPost(postId: postId)
            }
        }
    }
    
    // MARK: - Helper Views
    private func aiNotificationRow(_ notification: AINotification) -> some View {
        // Get post from PostsManager to check if it has an image
        let post = postsManager.posts.first(where: { $0.id == notification.postId })
        let hasImage = post?.image != nil || post?.imageName != nil
        
        return Button(action: {
            // Set the selected post ID to trigger navigation
            selectedPostId = notification.postId
        }) {
            HStack(alignment: .center, spacing: 12) {
                // Character avatar
                ZStack {
                    Circle()
                        .fill(characterColor(for: notification.character.id))
                        .frame(width: 42, height: 42)
                    
                    Text(String((notification.character.name.first ?? "?").uppercased()))
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(notification.character.name)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("commented on your post")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                    }
                    
                    // Post content preview
                    Text(limitedPostContent(notification.postContent))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    // Comment preview (truncated)
                    Text(notification.content)
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.8))
                        .lineLimit(1)
                    
                    // Timestamp
                    Text(timeAgoString(from: notification.timestamp))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Show image indicator if post has an image
                if hasImage {
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "photo")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(notification.read ? Color.clear : Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Limit post content to display a reasonable preview
    private func limitedPostContent(_ content: String) -> String {
        let maxLength = 30
        if content.count <= maxLength {
            return content
        } else {
            let index = content.index(content.startIndex, offsetBy: maxLength)
            return content[..<index] + "..."
        }
    }
    
    // Navigate to the post
    private func navigateToPost(postId: String) {
        // Dismiss notification view
        isPresented = false
        
        // Use delayed execution to ensure the notification view closes properly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            // Post a notification to navigate to the specific post
            NotificationCenter.default.post(
                name: Notification.Name("NavigateToPost"),
                object: nil,
                userInfo: ["postId": postId]
            )
        }
    }
    
    // Time ago formatter
    private func timeAgoString(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day, .weekOfYear], from: date, to: now)
        
        if let minutes = components.minute, minutes < 60 {
            return "\(minutes) min"
        } else if let hours = components.hour, hours < 24 {
            return "\(hours)h"
        } else if let days = components.day, days < 7 {
            return "\(days)d"
        } else if let weeks = components.weekOfYear {
            return "\(weeks)w"
        } else {
            return "long ago"
        }
    }
    
    // Character color based on ID
    private func characterColor(for characterId: String) -> Color {
        switch characterId {
        case "buddy":
            return Color.orange
        case "whiskers":
            return Color.blue
        case "polly":
            return Color.red
        case "shakespeare":
            return Color.purple
        case "msLedger":
            return Color.gray
        case "posiBot":
            return Color.green
        case "professorSavory":
            return Color.brown
        case "ironMike":
            return Color.black
        case "lily":
            return Color.pink
        default:
            return Color.green
        }
    }
}

struct NotificationView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationView(isPresented: .constant(true))
            .environmentObject(AIResponseManager(postsManager: PostsManager()))
            .environmentObject(PostsManager())
    }
}
