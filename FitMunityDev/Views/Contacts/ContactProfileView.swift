import SwiftUI

struct ContactProfileView: View {
    let contact: Contact
    @Environment(\.presentationMode) var presentationMode
    @State private var expandedBio = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (stays fixed)
            HStack {
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 24))
                        .foregroundColor(.black)
                }
                
                ZStack {
                    Circle()
                        .fill(characterColor(for: contact.character?.id ?? "default"))
                        .frame(width: 40, height: 40)
                    
                    Text(String((contact.character?.name.first ?? "?").uppercased()))
                        .foregroundColor(.white)
                        .font(.system(size: 18, weight: .bold))
                }
                .padding(.leading, 8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.headline)
                    
                    Text(contact.character?.id ?? "")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.leading, 8)
                
                Spacer()
            }
            .padding()
            .background(Color(hex: "FFF8E1"))
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 0) {
                    // Character Image Area
                    ZStack {
                        // Background
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 300)
                        
                        // Character Image - Using SF Symbol
                        Image(systemName: characterSymbol(for: contact.character?.id ?? "default"))
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(characterColor(for: contact.character?.id ?? "default"))
                            .frame(height: 200)
                            .padding(50)
                    }
                    
                    // Profile Info Section
                    VStack(spacing: 16) {
                        // Profile Header with Full Name
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Color.purple.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.purple)
                            }
                            
                            Text(contact.name)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                        }
                        .padding(.top, 16)
                        
                        // Status Section (Placeholder for now)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Status")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.6))
                            
                            HStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 12, height: 12)
                                
                                Text("Online and Ready")
                                    .foregroundColor(.black)
                                
                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        
                        // Bio Section with Expand/Collapse
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bio")
                                .font(.subheadline)
                                .foregroundColor(.black.opacity(0.6))
                            
                            VStack(alignment: .leading) {
                                Text(characterBio(for: contact.character?.id ?? "default"))
                                    .lineLimit(expandedBio ? nil : 3)
                                    .padding([.leading, .trailing, .top])
                                
                                Button(action: {
                                    withAnimation {
                                        expandedBio.toggle()
                                    }
                                }) {
                                    Text(expandedBio ? "Read less" : "Read more")
                                        .font(.footnote)
                                        .foregroundColor(.blue)
                                        .padding([.leading, .bottom, .trailing])
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white)
                            .cornerRadius(8)
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                    .background(Color(hex: "FFDD66"))
                }
            }
        }
        .navigationBarHidden(true)
        .edgesIgnoringSafeArea(.bottom)
        .background(Color(hex: "FFDD66")) // Add background to prevent white flashes during scrolling
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
    
    // Return SF Symbol based on character ID
    private func characterSymbol(for characterId: String) -> String {
        switch characterId {
        case "buddy":
            return "dog"
        case "whiskers":
            return "cat"
        case "polly":
            return "bird"
        case "shakespeare":
            return "book.fill"
        case "msLedger":
            return "function"
        case "posiBot":
            return "atom"
        case "professorSavory":
            return "fork.knife"
        case "ironMike":
            return "dumbbell.fill"
        case "lily":
            return "leaf.fill"
        default:
            return "figure.run"
        }
    }
    
    // Return a bio based on character ID
    private func characterBio(for characterId: String) -> String {
        switch characterId {
        case "buddy":
            return "Buddy is an energetic dog who's always ready for a walk, run, or play session. Never judges you for taking breaks and celebrates every single achievement no matter how small. With boundless enthusiasm, Buddy will be by your side during every fitness journey, providing comfort after tough workouts and endless joy during your successes. He believes that the most important part of fitness is having fun and staying consistent, no matter how small the steps are."
        case "whiskers":
            return "Whiskers brings feline precision and grace to fitness advice. Slightly judgmental but always elegant, Whiskers delivers tough love with unmistakable class. As a sophisticated feline, Whiskers approaches fitness with the same calculating precision that cats bring to their movements. Expect polished, refined advice delivered with a hint of superiority and an expectation of excellence. Whiskers may occasionally seem aloof, but this cat truly cares about your fitness progress."
        case "polly":
            return "Polly repeats positive affirmations and keeps the energy high. This colorful parrot brings enthusiasm and creativity to workouts, making exercise feel like play. With a knack for memorizing and repeating motivational phrases, Polly ensures you'll never forget your fitness mantras. Though not the most original advisor, Polly's consistent encouragement creates a rhythm that keeps you moving forward on even the toughest days."
        case "shakespeare":
            return "With dramatic flair and poetic wisdom, Shakespeare transforms fitness advice into sonnets and soliloquies. 'To lift, or not to lift, that is the question.' The bard of fitness brings literary elegance to your workout routine, framing each challenge as an epic journey worthy of iambic pentameter. While his language may sometimes be flowery, Shakespeare's timeless wisdom cuts to the heart of motivation and perseverance in ways that transcend centuries."
        case "msLedger":
            return "A stickler for counting macros and tracking progress, Ms. Ledger ensures your fitness journey is precisely documented with impeccable attention to detail. With a mind for numbers and analytics, she transforms raw data into actionable insights. Ms. Ledger believes that what gets measured gets improved, and she'll help you track every calorie, rep, and step on your path to fitness. Her organized approach brings clarity to the sometimes chaotic world of fitness tracking."
        case "posiBot":
            return "Programmed for positivity, PosiBot finds the silver lining in every workout. This AI never has a bad day and meets challenges with unwavering optimism. When energy is low and motivation wanes, PosiBot's enthusiasm provides the spark needed to keep going. Though sometimes relentlessly cheerful, PosiBot's positivity is exactly what many need to push through plateaus and setbacks, reminding you that every attempt is progress."
        case "professorSavory":
            return "With academic rigor and culinary creativity, Professor Savory breaks down complex nutrition science into practical, delicious meal recommendations. Blending scholarly knowledge with a passion for flavor, the Professor turns nutritional science into culinary art. His extensive knowledge of food history and biochemistry allows him to explain not just what to eat, but why certain foods work together for optimal health, all while ensuring meals remain a joyful experience rather than a clinical obligation."
        case "ironMike":
            return "No excuses, just results. Iron Mike pushes you past your limits with military discipline and intensity. Not for the faint of heart, but guaranteed to transform your fitness. When you need someone to hold you accountable and push beyond comfortable boundaries, Iron Mike delivers tough love that builds mental and physical toughness. Behind his drill sergeant exterior lies a deep understanding of human potential and a genuine desire to help others achieve what they once thought impossible."
        case "lily":
            return "Lily approaches fitness from a mind-body perspective, emphasizing balance, mindfulness, and sustainable health practices that nurture both physical and mental wellbeing. With a gentle but effective approach, she encourages finding joy in movement rather than focusing solely on physical outcomes. Lily specializes in helping those who feel overwhelmed by traditional fitness culture, offering compassionate guidance that treats wellness as a holistic journey involving nutrition, movement, rest, and mental health in equal measure."
        default:
            return "A dedicated fitness professional committed to helping you achieve your health and wellness goals through personalized guidance and support. Drawing from extensive experience in multiple disciplines, this advisor tailors recommendations to your unique needs, preferences, and lifestyle factors, ensuring a sustainable and enjoyable approach to fitness that yields long-term results rather than quick fixes."
        }
    }
}

struct ContactProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleCharacter = AICharacter(
            id: "buddy",
            name: "Buddy",
            avatar: "A playful Golden Retriever with a shiny coat",
            backgroundStory: "A friendly, loyal Golden Retriever who loves interacting with everyone.",
            replyFormat: "Replies in a dog-like manner using 'wufwuf'",
            topicsToReplyTo: ["all"]
        )
        let sampleContact = Contact(id: "buddy", name: "Buddy", character: sampleCharacter)
        ContactProfileView(contact: sampleContact)
    }
} 