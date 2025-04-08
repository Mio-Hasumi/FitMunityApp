import SwiftUI

struct ContactView: View {
    @State private var searchText = ""
    @StateObject private var viewModel = ContactViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Contact List")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.top)
            
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("search", text: $searchText)
                    .font(.system(size: 16))
            }
            .padding(10)
            .background(Color.white.opacity(0.3))
            .cornerRadius(20)
            .padding(.horizontal)
            .padding(.vertical, 10)
            
            // Contact list
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.filteredContacts(searchText: searchText)) { contact in
                        ContactRow(contact: contact)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
        .background(Color(hex: "FFF8E1"))
    }
}

struct ContactRow: View {
    let contact: Contact
    @State private var showProfile = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Character avatar
            Circle()
                .fill(characterColor(for: contact.character?.id ?? "default"))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String((contact.character?.name.first ?? "?").uppercased()))
                        .foregroundColor(.white)
                        .font(.system(size: 20, weight: .bold))
                )
            
            // Contact name
            Text(contact.name)
                .font(.headline)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(hex: "FFDD66").opacity(0.2))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            showProfile = true
        }
        .fullScreenCover(isPresented: $showProfile) {
            ContactProfileView(contact: contact)
        }
    }
    
    // Return a color based on character ID
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

// MARK: - Preview
struct ContactView_Previews: PreviewProvider {
    static var previews: some View {
        ContactView()
    }
}
