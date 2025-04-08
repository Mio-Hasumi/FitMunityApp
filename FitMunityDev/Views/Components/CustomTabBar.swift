


import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    var onAddTapped: () -> Void = {}
    
    var body: some View {
        ZStack {
            // Tab bar background
            RoundedRectangle(cornerRadius: 32)
                .fill(Color.black)
                .frame(height: 64)
            
            // Tab items
            HStack {
                TabBarButton(icon: "house.fill", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabBarButton(icon: "person.2.fill", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                // Center button
                Button(action: {
                    onAddTapped()
                }) {
                    Circle()
                        .fill(Color(hex: "FF9EB1"))
                        .frame(width: 56, height: 56)
                        .shadow(radius: 2)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        )
                }
                .offset(y: -10)
                
                TabBarButton(icon: "heart.fill", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
                
                TabBarButton(icon: "person.fill", isSelected: selectedTab == 4) {
                    selectedTab = 4
                }
            }
        }
        .frame(height: 64)
    }
}

struct TabBarButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(isSelected ? .white : .white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            Spacer()
            CustomTabBar(selectedTab: .constant(0))
        }
        .previewLayout(.sizeThatFits)
        .padding(.vertical)
        .background(Color(hex: "FFF8DD"))
    }
}
