import SwiftUI

// MARK: - Models
struct Contact: Identifiable {
    let id: String
    let name: String
    let character: AICharacter?
    
    init(id: String, name: String, character: AICharacter? = nil) {
        self.id = id
        self.name = name
        self.character = character
    }
}

enum TabItem: CaseIterable {
    case home
    case messages
    case favorites
    case profile
    
    var iconName: String {
        switch self {
        case .home: return "house.fill"
        case .messages: return "person.2.fill"
        case .favorites: return "heart"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - View Model
class ContactViewModel: ObservableObject {
    @Published var contacts: [Contact] = []
    @Published var selectedTab: TabItem = .home
    
    init() {
        self.loadContacts()
    }
    
    private func loadContacts() {
        // Use our AI characters as contacts
        let aiCharacters = AICharacter.allCharacters
        
        self.contacts = aiCharacters.map { character in
            return Contact(
                id: character.id,
                name: character.name,
                character: character
            )
        }
    }
    
    func filteredContacts(searchText: String) -> [Contact] {
        if searchText.isEmpty {
            return contacts
        } else {
            return contacts.filter { $0.name.lowercased().contains(searchText.lowercased()) }
        }
    }
} 