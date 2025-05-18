import SwiftUI

struct ActionButtonsView: View {
    var onScan: () -> Void
    var onGenerate: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onScan) {
                HStack {
                    Image(systemName: "viewfinder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 30, height: 30)
                    Text("Scan")
                        .font(.headline)
                        .foregroundColor(.brandOrange)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandOrange.opacity(0.15))
                .cornerRadius(12)
            }

            Button(action: onGenerate) {
                Text("Generate Recipe")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandOrange)
                    .cornerRadius(12)
            }
        }
    }
}
