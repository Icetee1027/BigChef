//
//  AuthViewModel.swift
//  ChefHelper
//
//  Created by 羅辰澔 on 2025/5/6.
//

// AuthViewModel.swift
import SwiftUI
import FirebaseAuth
import FirebaseFirestore // 確保導入 FirebaseFirestore

class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var didAuthenticateUser = false // 可以用來觸發 UI 更新或流程轉換
    @Published var currentUser: User? // 您的 User model
    // private var tempUserSession: FirebaseAuth.User? // 在註冊流程中暫存用戶 session

    private let service = UserService()

    // MARK: - Coordinator Callbacks
    // 由 AuthCoordinator 設定這些回調
    var onLoginSuccess: (() -> Void)?
    var onRegistrationSuccess: (() -> Void)? // 註冊成功 (通常也意味著登入成功)
    var onAuthFailure: ((Error) -> Void)?
    var onNavigateToRegistration: (() -> Void)? // 從登入頁導航到註冊頁
    var onNavigateBackToLogin: (() -> Void)?    // 從註冊頁導航回登入頁
    var onUserWantsToCancelAuth: (() -> Void)?  // 用戶明確取消驗證流程

    init() {
        // 檢查當前 Firebase Auth 狀態
        self.userSession = Auth.auth().currentUser
        if self.userSession != nil {
            fetchUser() // 如果已有 session，獲取用戶資料
        }
        print("AuthViewModel: 初始化完成。User session: \(String(describing: userSession?.uid))")
    }
    
    // MARK: - Login
    func login(withEmail email: String, password: String) {
        print("AuthViewModel: 嘗試登入，Email: \(email)")
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                print("AuthViewModel DEBUG: 登入失敗，錯誤: \(error.localizedDescription)")
                self.onAuthFailure?(error) // 通知 Coordinator 登入失敗
                return
            }
          
            guard let user = result?.user else {
                let unknownError = NSError(domain: "AuthViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "登入後無法獲取用戶物件"])
                print("AuthViewModel DEBUG: 登入後無法獲取用戶物件")
                self.onAuthFailure?(unknownError)
                return
            }
            self.userSession = user
            self.fetchUser { success in // fetchUser 現在有一個完成回調
                if success {
                    print("AuthViewModel DEBUG: 用戶已登入並獲取資料: \(String(describing: self.userSession?.email))")
                    self.didAuthenticateUser = true // 更新狀態
                    self.onLoginSuccess?()      // 通知 Coordinator 登入成功
                } else {
                    // 即使 Firebase 登入成功，但如果 fetchUser 失敗，也視為一種驗證問題
                    let fetchError = NSError(domain: "AuthViewModel", code: -2, userInfo: [NSLocalizedDescriptionKey: "登入成功但獲取用戶詳細資料失敗"])
                    self.onAuthFailure?(fetchError)
                }
            }
        }
    }
    
    // MARK: - Register
    func register(withEmail email: String, password: String, fullname: String, username: String, profileImage: UIImage? = nil) {
        print("AuthViewModel: 嘗試註冊，Email: \(email), Username: \(username)")
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            if let error = error {
                print("AuthViewModel DEBUG: 註冊 Firebase Auth 失敗，錯誤: \(error.localizedDescription)")
                self.onAuthFailure?(error) // 通知 Coordinator 註冊失敗
                return
            }
        
            guard let firebaseUser = result?.user else {
                let unknownError = NSError(domain: "AuthViewModel", code: -3, userInfo: [NSLocalizedDescriptionKey: "註冊後無法獲取 Firebase 用戶物件"])
                print("AuthViewModel DEBUG: 註冊後無法獲取 Firebase 用戶物件")
                self.onAuthFailure?(unknownError)
                return
            }
              
            let userData: [String: Any] = [
                "email": email,
                "username": username.lowercased(),
                "fullname": fullname,
                "uid": firebaseUser.uid,
                // "profileImageUrl": "" // 初始可以為空或預設值
            ]
            
            Firestore.firestore().collection("users")
                .document(firebaseUser.uid)
                .setData(userData) { [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        print("AuthViewModel DEBUG: 上傳用戶資料到 Firestore 失敗，錯誤: \(error.localizedDescription)")
                        // 這裡可以選擇是否也觸發 onAuthFailure，或者認為 Auth 成功但資料儲存失敗
                        // 為了流程一致性，也視為一種驗證流程的失敗
                        self.onAuthFailure?(error)
                        return
                    }
                    
                    print("AuthViewModel DEBUG: 用戶資料已上傳到 Firestore。")
                    // 註冊成功後，用戶已登入，設定 userSession
                    self.userSession = firebaseUser

                    if let imageToUpload = profileImage {
                        self.uploadProfileImage(imageToUpload, for: firebaseUser) { success in
                            if success {
                                self.completeRegistration()
                            } else {
                                // 圖片上傳失敗，但用戶資料已創建。可以選擇是否視為整體失敗。
                                // 為了簡化，我們先假設即使圖片失敗，註冊（用戶創建）也算成功。
                                print("AuthViewModel WARNING: 個人圖片上傳失敗，但註冊流程繼續。")
                                self.completeRegistration()
                            }
                        }
                    } else {
                        self.completeRegistration()
                    }
                }
        }
    }

    private func completeRegistration() {
        self.fetchUser { success in // 獲取剛註冊的用戶的完整資料
            if success {
                print("AuthViewModel DEBUG: 註冊流程完成，用戶資料已獲取。")
                self.didAuthenticateUser = true
                self.onRegistrationSuccess?() // 通知 Coordinator 註冊成功
            } else {
                let fetchError = NSError(domain: "AuthViewModel", code: -4, userInfo: [NSLocalizedDescriptionKey: "註冊成功但獲取用戶詳細資料失敗"])
                self.onAuthFailure?(fetchError)
            }
        }
    }
    
    // MARK: - Logout
    func logout() {
        print("AuthViewModel: 嘗試登出")
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            self.currentUser = nil
            self.didAuthenticateUser = false
            print("AuthViewModel DEBUG: 用戶已登出")
            // 登出通常由 AppCoordinator 或 ProfileCoordinator 觸發，
            // 這裡 ViewModel 執行登出操作，然後 AppCoordinator 會轉換到 AuthCoordinator 流程。
            // 所以 ViewModel 本身不需要 onLogoutSuccess 回調給 AuthCoordinator。
        } catch let error {
            print("AuthViewModel DEBUG: 登出失敗，錯誤: \(error.localizedDescription)")
            // 登出失敗通常是個問題，但一般不會阻止 UI 轉換到登入頁
        }
    }
    
    // MARK: - Profile Image Upload (for registration or profile update)
    private func uploadProfileImage(_ image: UIImage, for firebaseUser: FirebaseAuth.User, completion: @escaping (Bool) -> Void) {
        print("AuthViewModel: 上傳個人圖片中...")
        ImageUploader.uploadImage(image: image) { [weak self] profileImageUrl in
            guard let self = self else { completion(false); return }
            Firestore.firestore().collection("users")
                .document(firebaseUser.uid)
                .updateData(["profileImageUrl": profileImageUrl]) { error in
                    if let error = error {
                        print("AuthViewModel DEBUG: 更新個人圖片 URL 到 Firestore 失敗: \(error.localizedDescription)")
                        completion(false)
                        return
                    }
                    print("AuthViewModel DEBUG: 個人圖片 URL 已更新到 Firestore。")
                    // 更新本地 currentUser 的圖片 URL (如果需要立即反映)
                    self.currentUser?.profileImageUrl = profileImageUrl
                    completion(true)
                }
        }
    }
    
    // MARK: - Fetch User Data
    // 加入一個完成回調，以便在操作完成後執行特定邏輯
    func fetchUser(completion: ((Bool) -> Void)? = nil) {
        guard let uid = self.userSession?.uid else {
            print("AuthViewModel: fetchUser 失敗，因為 userSession?.uid 為 nil")
            completion?(false)
            return
        }
        print("AuthViewModel: 獲取用戶資料中，UID: \(uid)")
        service.fetchUser(withUid: uid) { [weak self] user in
            guard let self = self else { completion?(false); return }
            self.currentUser = user
            if user != nil {
                print("AuthViewModel DEBUG: 用戶資料已獲取: \(String(describing: user?.username))")
                completion?(true)
            } else {
                print("AuthViewModel DEBUG: 未能獲取用戶資料 (service.fetchUser 回傳 nil)")
                completion?(false)
            }
        }
    }

    // MARK: - Navigation Triggers (called by View, handled by Coordinator)
    func requestNavigateToRegistration() {
        print("AuthViewModel: 請求導航到註冊頁面")
        onNavigateToRegistration?()
    }

    func requestNavigateBackToLogin() {
        print("AuthViewModel: 請求導航回登入頁面")
        onNavigateBackToLogin?()
    }

    func requestCancelAuthentication() {
        print("AuthViewModel: 請求取消驗證流程")
        onUserWantsToCancelAuth?()
    }
}
