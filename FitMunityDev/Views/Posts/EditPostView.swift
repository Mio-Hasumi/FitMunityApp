


import SwiftUI
import PhotosUI

// Helper extension for String trimming
private extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct EditPostView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var postsManager: PostsManager
    @EnvironmentObject private var authManager: AuthManager
    @State private var postText: String = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var showEmojiPicker = false
    @State private var selectedTag: String?
    @State private var tags = ["Food", "Fitness", "Progress"]
    @State private var showTagPicker = false
    @FocusState private var isEditorFocused: Bool
    @State private var isPosting = false
    @State private var postError: String? = nil
    
    // Move the emoji array into a property to simplify type inference
    private let emojiList = ["😊", "👍", "💪", "🏋️", "🥗", "🍎", "❤️", "🔥", "👏", "✅"]

    var body: some View {
        ZStack {
            backgroundView
            
            VStack(spacing: 0) {
                editorCard
                closeButton
            }
            .padding(.vertical)
        }
        // Sheet for the image picker
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
    }

    private func submitPost() async {
        // Check if we have valid content
        guard !postText.trim().isEmpty else { return }
        
        // Set posting state
        isPosting = true
        postError = nil
        
        // Get the current username
        let username = authManager.currentUser?.username ?? "FitMunity User"
        print("DEBUG: Creating post with username: \(username)")
        print("DEBUG: Current user: \(String(describing: authManager.currentUser))")
        
        Task {
            do {
                // Add post with image if available
                if let selectedImage = selectedImage {
                    try await postsManager.addPost(
                        content: postText,
                        image: selectedImage,
                        tag: selectedTag,
                        username: username
                    )
                } else {
                    try await postsManager.addPost(
                        content: postText,
                        tag: selectedTag,
                        username: username
                    )
                }
                
                // Successfully posted, dismiss the view
                await MainActor.run {
                    isPosting = false
                    isPresented = false
                }
            } catch {
                // Show error message
                await MainActor.run {
                    isPosting = false
                    postError = "Failed to post: \(error.localizedDescription)"
                    print("ERROR: \(error.localizedDescription)")
                }
            }
        }
    }
}

// MARK: - Subviews

extension EditPostView {
    /// Background overlay
    private var backgroundView: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
    }
    
    /// The main editor card
    private var editorCard: some View {
        VStack(spacing: 0) {
            topToolbar
            textEditorArea
            formattingToolbar
            if showTagPicker { tagPicker }
            if showEmojiPicker { emojiPicker }
        }
        .background(Color(hex: "FFF8E1"))
        .cornerRadius(24)
        .padding(.horizontal)
    }
    
    /// Top toolbar with edit and send buttons
    private var topToolbar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.yellow.opacity(0.3))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "pencil")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                    }
                    Text("Edit")
                        .font(.system(size: 20, weight: .semibold))
                }
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                        .foregroundColor(.yellow)
                )
                
                Spacer()
                
                Button(action: {
                    Task {
                        await submitPost()
                    }
                }) {
                    if isPosting {
                        ProgressView()
                            .padding(.horizontal, 10)
                    } else {
                        Text("Post")
                            .padding(.horizontal, 10)
                    }
                }
                .disabled(postText.trim().isEmpty || isPosting)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(postText.trim().isEmpty || isPosting ? Color.gray.opacity(0.3) : Color.yellow)
                )
                .foregroundColor(postText.trim().isEmpty || isPosting ? .gray : .black)
            }
            
            if let error = postError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 10)
    }
    
    /// Text editor and image/tag preview area
    private var textEditorArea: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.black)
                .padding(.horizontal, 20)
            
            if postText.isEmpty {
                Text("Write your post here...")
                    .foregroundColor(.gray.opacity(0.8))
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    .allowsHitTesting(false)
            }
            
            VStack {
                TextEditor(text: $postText)
                    .scrollContentBackground(.hidden) // Makes the background transparent
                    .background(Color.clear)
                    .padding(.horizontal, 30)
                    .frame(height: 200)
                    .focused($isEditorFocused)
                
                if let image = selectedImage {
                    imagePreview(image: image)
                }
                
                if let tag = selectedTag {
                    tagDisplay(tag: tag)
                }
            }
        }
    }
    
    /// Formatting toolbar with various actions
    private var formattingToolbar: some View {
        HStack(spacing: 16) {
            Button(action: { applyBold() }) {
                Text("B")
                    .font(.system(size: 22, weight: .bold))
            }
            
            Button(action: {
                // Align action placeholder
            }) {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 20))
            }
            
            Button(action: { insertBulletPoint() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 20))
            }
            
            Text("|")
                .foregroundColor(.gray)
            
            Button(action: {
                showEmojiPicker.toggle()
                if showEmojiPicker {
                    showTagPicker = false
                    isEditorFocused = false
                }
            }) {
                Image(systemName: "face.smiling")
                    .font(.system(size: 20))
            }
            
            Button(action: {
                showImagePicker = true
            }) {
                Image(systemName: "photo")
                    .font(.system(size: 20))
            }
            
            Text("|")
                .foregroundColor(.gray)
            
            Button(action: {
                showTagPicker = true
            }) {
                HStack {
                    Image(systemName: "tag")
                        .font(.system(size: 20))
                    
                    if let selectedTag = selectedTag {
                        Text(selectedTag)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    } else {
                        Text("Add Tag")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(selectedTag != nil ? Color.yellow : Color.gray, lineWidth: 1)
                        .background(selectedTag != nil ? Color.yellow.opacity(0.1) : Color.clear)
                )
            }
        }
        .foregroundColor(.black)
        .padding(.vertical, 20)
    }
    
    /// Horizontal tag picker
    private var tagPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Button(action: {
                        selectedTag = tag
                        showTagPicker = false
                    }) {
                        Text("#\(tag)")
                            .font(.system(size: 16))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }
    
    /// Horizontal emoji picker
    private var emojiPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(emojiList, id: \.self) { emoji in
                    Button(action: {
                        insertEmoji(emoji)
                    }) {
                        Text(emoji)
                            .font(.system(size: 24))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }
    
    /// Close button for the editor
    private var closeButton: some View {
        Button(action: {
            isPresented = false
        }) {
            ZStack {
                Circle()
                    .fill(Color(hex: "FF9EB1"))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "xmark")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .offset(y: -30)
        .padding(.bottom, -30)
    }
    
    /// Image preview view with removal button
    private func imagePreview(image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(height: 120)
            .cornerRadius(12)
            .padding(.horizontal, 30)
            .padding(.top, 10)
            .overlay(
                Button(action: {
                    selectedImage = nil
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.black)
                        .background(Circle().fill(Color.white))
                }
                .offset(x: 8, y: -8),
                alignment: .topTrailing
            )
    }
    
    /// Tag display view with removal button
    private func tagDisplay(tag: String) -> some View {
        HStack {
            Text("#\(tag)")
                .font(.system(size: 16, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.3))
                .clipShape(Capsule())
            
            Button(action: {
                selectedTag = nil
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
        .padding(.top, 10)
    }
}

// MARK: - Helper Functions

extension EditPostView {
    private func applyBold() {
        // Example: simply appending placeholder bold text.
        postText += "**Bold Text**"
    }
    
    private func insertBulletPoint() {
        postText += "\n• "
    }
    
    private func insertEmoji(_ emoji: String) {
        postText += emoji
        showEmojiPicker = false
        isEditorFocused = true
    }
}

// MARK: - Image Picker

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.parent.selectedImage = image as? UIImage
                    }
                }
            }
        }
    }
}

// MARK: - Preview

struct EditPostView_Previews: PreviewProvider {
    static var previews: some View {
        EditPostView(isPresented: .constant(true))
            .environmentObject(PostsManager())
            .environmentObject(AuthManager())
    }
}
