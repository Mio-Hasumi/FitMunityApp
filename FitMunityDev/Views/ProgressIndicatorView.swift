


import SwiftUI

struct ProgressIndicatorView: View {
    let progress: Double
    let goalDate: String
    
    var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "FFDD66"))
                .frame(height: 56)
            
            HStack(spacing: 12) {
                // Progress circle
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .opacity(0.3)
                        .frame(width: 44, height: 44)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                }
                
                // Text
                VStack(alignment: .leading, spacing: 0) {
                    Text("You're going to reach your goal by")
                        .font(.system(size: 13))
                        .foregroundColor(.black)
                    
                    Text(goalDate)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 4)
    }
}

struct ProgressIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        ProgressIndicatorView(progress: 0.65, goalDate: "3 Aug 2022")
            .previewLayout(.sizeThatFits)
            .padding()
            .background(Color(hex: "FFF8E1"))
    }
}
