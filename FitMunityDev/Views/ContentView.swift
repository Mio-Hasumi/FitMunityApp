

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var postsManager = PostsManager()
    @StateObject private var aiManager: AIResponseManager
    @EnvironmentObject var authManager: AuthManager
    
    init() {
        // Initialize StateObject in init
        _aiManager = StateObject(wrappedValue: AIResponseManager(postsManager: PostsManager.shared))
    }
    
    var body: some View {
        TabView {
            // Posts Feed (main content)
            PostsFeedView()
                .environmentObject(postsManager)
                .environmentObject(aiManager)
                .tabItem {
                    Label("Feed", systemImage: "house.fill")
                }
            
            // Placeholder for other tabs
            Text("Profile")
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
            
            Text("Notifications")
                .tabItem {
                    Label("Notifications", systemImage: "bell.fill")
                }
            
            Text("Settings")
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .environment(\.managedObjectContext, viewContext)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let context = PersistenceController.preview.container.viewContext
        ContentView()
            .environment(\.managedObjectContext, context)
            .environmentObject(AuthManager())
            .environmentObject(PostsManager())
    }
}
