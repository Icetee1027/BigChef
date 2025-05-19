import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = StepViewModel()
    @State private var stepText: String = ""

    var body: some View {
        ZStack {
            CookingARView(viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            VStack {
                Spacer()
                HStack {
                    TextField("輸入烹飪步驟", text: $stepText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    Button("送出") {
                        viewModel.currentDescription = stepText
                        stepText = ""
                    }
                }
                .padding()
            }
        }
    }
}
