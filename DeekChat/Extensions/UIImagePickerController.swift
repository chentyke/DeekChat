import SwiftUI
import UIKit
import AVFoundation

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType
    @Environment(\.presentationMode) private var presentationMode

    // 检查相机是否可用
    static func isCameraAvailable() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    // 检查相机权限 - 使用更安全的实现
    static func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        // 确保在主线程上检查状态
        DispatchQueue.main.async {
            let status = AVCaptureDevice.authorizationStatus(for: .video)

            switch status {
            case .authorized:
                completion(true)
            case .notDetermined:
                // 请求权限在后台线程执行，结果在主线程返回
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    DispatchQueue.main.async {
                        completion(granted)
                    }
                }
            case .denied, .restricted:
                completion(false)
            @unknown default:
                completion(false)
            }
        }
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true

        // 安全设置源类型
        if sourceType == .camera && UIImagePickerController.isSourceTypeAvailable(.camera) {
            // 如果请求使用相机且相机可用
            let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if cameraStatus == .authorized {
                // 已有权限，直接使用相机
                picker.sourceType = .camera
            } else {
                // 没有权限，使用相册
                picker.sourceType = .photoLibrary
            }
        } else {
            // 如果请求使用相册或相机不可用，使用相册
            picker.sourceType = .photoLibrary
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }

            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}