//
//  LoginView.swift
//  ChefHelper
//
//  Created by 陳泓齊 on 2025/4/10.
//

//import Firebase
import SwiftUI

struct LoginView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            // App Logo & Title
            Image("QuickFeatLogo")
            
            // Email Field
            CustomInputField(imageName: "envelope",
                             placeholderText: "Email",
                             textCase: .lowercase,
                             keyboardType: .emailAddress,
                             textContentType: .emailAddress,
                             text: $email)
            CustomInputField(imageName: "lock",
                             placeholderText: "Password",
                             textCase: .lowercase,
                             keyboardType: .default,
                             textContentType: .password,
                             isSecureField: true,
                             text: $password)
        }.padding(32)
        
        // TODO: Implement forgot password functionality
        // Button("Forgot your password?") { ... }
        
        Button {
            print("Sign in")
            viewModel.login(withEmail: email, password: password)
        } label: {
            Text("Sign in")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 340, height: 50)
                .background(Color.themeColor)
                .clipShape(Capsule())
                .padding()
        }
        .shadow(color: .gray.opacity(0.5), radius: 10, x: 0, y: 0)
        
        Spacer()
        
        // Sign UP
        NavigationLink  {
            RegistrationView()
                .environmentObject(viewModel) 
                .navigationBarHidden(true)
        } label: {
            HStack {
                Text("Don't have an account?")
                    .font(.footnote)
                Text("Sign Up")
                    .font(.footnote)
                    .fontWeight(.semibold)
            }
        }
        .padding(.bottom, 32)
        
        // TODO: Implement social login features
        // - Social media login buttons
        // - "OR" divider
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
