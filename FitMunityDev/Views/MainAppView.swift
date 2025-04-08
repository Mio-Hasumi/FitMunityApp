//
//  MainAppView.swift
//  FitMunityDev
//

import SwiftUI

struct MainAppView: View {
    @State private var selectedTab = 0 // Home tab selected by default
    @State private var showCreatePost = false
    @State private var showNotifications = false
    @EnvironmentObject var aiResponseManager: AIResponseManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var postsManager: PostsManager
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Content based on selected tab
            VStack(spacing: 0) {
                // Tab content
                tabContent
                
                Spacer(minLength: 70) // Space for the tab bar
            }
            
            // Custom tab bar at the bottom
            CustomTabBar(
                selectedTab: $selectedTab,
                onAddTapped: {
                    // Action for the add button
                    showCreatePost = true
                }
            )
        }
        .background(Color(hex: "FFF8DD"))
        .sheet(isPresented: $showCreatePost) {
            EditPostView(isPresented: $showCreatePost)
        }
        .onAppear {
            // Force UI refresh when the view appears
            aiResponseManager.objectWillChange.send()
        }
        .onChange(of: selectedTab) { value in
            // When switching to home tab, refresh post images
            if value == 0 {
                print("🔄 DEBUG: Switched to home tab, refreshing post images")
                Task {
                    await postsManager.refreshPostImages()
                }
            }
        }
    }
    
    // Tab content based on selected tab index
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case 0:
                // Home tab
                NavigationView {
                    ZStack(alignment: .top) {
                        // Main content
                        PostsFeedView()
                            .padding(.top, 60) // Add padding for the custom header
                        
                        // Custom header
                        VStack(spacing: 0) {
                            // Status bar color
                            Color(hex: "FFF8E1")
                                .frame(height: 0) // Takes up status bar space
                                .edgesIgnoringSafeArea(.top)
                            
                            // Custom header content
                            HStack(alignment: .center) {
                                Text("Posts")
                                    .font(.system(size: 34, weight: .bold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Button(action: {
                                    // Navigate to notification view
                                    print("🔔 DEBUG: Notification button tapped")
                                    let notificationCount = aiResponseManager.getNotifications().count
                                    print("📊 DEBUG: Current notifications count: \(notificationCount)")
                                    print("📊 DEBUG: Has unread notifications: \(aiResponseManager.hasUnreadNotifications)")
                                    
                                    showNotifications = true
                                    // Clear unread notifications when viewing
                                    aiResponseManager.clearUnreadNotifications()
                                    
                                    print("📊 DEBUG: After clearing - notifications count: \(aiResponseManager.getNotifications().count)")
                                    print("📊 DEBUG: After clearing - has unread: \(aiResponseManager.hasUnreadNotifications)")
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.black)
                                            .frame(width: 44, height: 44)
                                        
                                        // Notification badge
                                        if aiResponseManager.hasUnreadNotifications {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 12, height: 12)
                                                .offset(x: 2, y: -2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                            .background(Color(hex: "FFF8E1"))
                        }
                    }
                    .navigationBarHidden(true) // Hide the default navigation bar
                    .fullScreenCover(isPresented: $showNotifications) {
                        NotificationView(isPresented: $showNotifications)
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
                
            case 1:
                // Messages tab - now shows ContactView
                NavigationView {
                    ContactView()
                        .navigationBarHidden(true)
                }
                .navigationViewStyle(StackNavigationViewStyle())
                
            case 2:
                // Home/Feed tab (default)
                NavigationView {
                    ZStack(alignment: .top) {
                        // Main content
                        PostsFeedView()
                            .padding(.top, 60) // Add padding for the custom header
                        
                        // Custom header
                        VStack(spacing: 0) {
                            // Status bar color
                            Color(hex: "FFF8E1")
                                .frame(height: 0) // Takes up status bar space
                                .edgesIgnoringSafeArea(.top)
                            
                            // Custom header content
                            HStack(alignment: .center) {
                                Text("Posts")
                                    .font(.system(size: 34, weight:  .bold))
                                    .foregroundColor(.black)
                                
                                Spacer()    
                                
                                Button(action: {
                                    // Navigate to notification view
                                    print("🔔 DEBUG: Notification button tapped")
                                    let notificationCount = aiResponseManager.getNotifications().count
                                    print("📊 DEBUG: Current notifications count: \(notificationCount)")
                                    print("📊 DEBUG: Has unread notifications: \(aiResponseManager.hasUnreadNotifications)")
                                    
                                    showNotifications = true
                                    // Clear unread notifications when viewing
                                    aiResponseManager.clearUnreadNotifications()
                                    
                                    print("📊 DEBUG: After clearing - notifications count: \(aiResponseManager.getNotifications().count)")
                                    print("📊 DEBUG: After clearing - has unread: \(aiResponseManager.hasUnreadNotifications)")
                                }) {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: "bell.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.black)
                                            .frame(width: 44, height: 44)
                                        
                                        // Notification badge
                                        if aiResponseManager.hasUnreadNotifications {
                                            Circle()
                                                .fill(Color.red)
                                                .frame(width: 12, height: 12)
                                                .offset(x: 2, y: -2)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 10)
                            .padding(.bottom, 10)
                            .background(Color(hex: "FFF8E1"))
                        }
                    }
                    .navigationBarHidden(true) // Hide the default navigation bar
                    .fullScreenCover(isPresented: $showNotifications) {
                        NotificationView(isPresented: $showNotifications)
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
                
            case 3:
                StatisticsView()
                
            case 4:
                HomeView()
                
            default:
                PostsFeedView()
            }
        }
    }
}

// MARK: - Preview
struct MainAppView_Previews: PreviewProvider {
    static var previews: some View {
        let postsManager = PostsManager()
        let aiResponseManager = AIResponseManager(postsManager: postsManager)
        let authManager = AuthManager()
        
        MainAppView()
            .environmentObject(postsManager)
            .environmentObject(aiResponseManager)
            .environmentObject(authManager)
    }
}
