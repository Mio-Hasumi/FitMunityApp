import CoreData

struct PersistenceController {
    // Singleton instance
    static let shared = PersistenceController()

    // Storage for Core Data
    let container: NSPersistentContainer

    // Test configuration for SwiftUI previews
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        
        // Create example data for previews if needed
        let viewContext = controller.container.viewContext
        
        // Add any sample data here for previews
        // Example:
        // let newItem = Item(context: viewContext)
        // newItem.timestamp = Date()
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return controller
    }()

    // Initialization with optional in-memory storage
    init(inMemory: Bool = false) {
        // Use your app's model name here
        container = NSPersistentContainer(name: "FitMunityDev")

        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Error: \(error.localizedDescription)")
            }
        }
        
        // Enable automatic merging of changes from parent contexts
        container.viewContext.automaticallyMergesChangesFromParent = true
        
        // Optional: Enable constraint validation
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
} 