
import SwiftUI

struct AddPostButton: View {
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    .foregroundColor(.black)
                    .frame(width: 50, height: 50)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
            }
        }
    }
}

struct AddPostButton_Previews: PreviewProvider {
    static var previews: some View {
        AddPostButton(action: {})
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
