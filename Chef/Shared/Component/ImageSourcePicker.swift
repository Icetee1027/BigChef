import SwiftUI
import PhotosUI

// MARK: - 修飾器：圖片來源選擇器（拍照／相簿）
struct ImageSourcePicker: ViewModifier {
    /// 是否顯示來源選擇對話框
    @Binding var isPresented: Bool
    
    /// 儲存選到的圖片
    @Binding var selectedImage: UIImage?
    
    /// 圖片選擇完成後要執行的動作
    let onImageSelected: (UIImage) -> Void

    func body(content: Content) -> some View {
        content
            // 顯示確認對話框讓使用者選擇來源
            .confirmationDialog("選擇圖片來源", isPresented: $isPresented) {
                Button("拍照") {
                    showImagePicker(sourceType: .camera)
                }
                Button("相簿") {
                    showImagePicker(sourceType: .photoLibrary)
                }
                Button("取消", role: .cancel) {}
            }
            // 顯示圖片挑選器 sheet
            .sheet(isPresented: $isShowingImagePicker) {
                if let sourceType = currentSourceType {
                    ImagePicker(
                        sourceType: sourceType,
                        selectedImage: $selectedImage,
                        onImageSelected: onImageSelected
                    )
                }
            }
    }

    // MARK: - 內部狀態
    @State private var isShowingImagePicker = false
    @State private var currentSourceType: UIImagePickerController.SourceType?

    /// 設定來源並顯示挑選器
    private func showImagePicker(sourceType: UIImagePickerController.SourceType) {
        currentSourceType = sourceType
        isShowingImagePicker = true
    }
}

// MARK: - UIKit 的 Image Picker 封裝為 SwiftUI 可用
struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    let onImageSelected: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    /// 建立 UIKit 控制器
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// 建立協調器（處理代理回傳）
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// 協調器：處理圖片選取和取消
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        // 選擇圖片完成
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.onImageSelected(image)
            }
            parent.dismiss()
        }

        // 使用者取消選擇
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - View 擴充：提供呼叫修飾器的語法糖
extension View {
    /// 加入圖片來源選擇功能
    func imageSourcePicker(
        isPresented: Binding<Bool>,
        selectedImage: Binding<UIImage?>,
        onImageSelected: @escaping (UIImage) -> Void
    ) -> some View {
        modifier(ImageSourcePicker(
            isPresented: isPresented,
            selectedImage: selectedImage,
            onImageSelected: onImageSelected
        ))
    }
}
