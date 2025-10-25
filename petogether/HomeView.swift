//
//  HomeView.swift
//  petogether
//
//  Created by Sun1 on 2025/10/24.
//

import SwiftUI
import SwiftData
import Combine
import Photos

struct HomeView: View {
    // Photo selection related state
    @State private var ownerImage: UIImage? = nil
    @State private var petImage: UIImage? = nil
    @State private var isImagePickerPresented = false
    @State private var imagePickerType: ImagePickerType = .owner
    @State private var showPermissionAlert = false
    @State private var permissionAlertMessage = ""
    
    // Scene category related state
    @State private var selectedCategory: String = ""
    
    // Navigation state
    @State private var showResult = false
    
    // Generated image state
    @State private var generatedImage: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Top Banner
                    BannerView()
                    
                    // Photo selection area
                    PhotoSelectionView(
                        ownerImage: $ownerImage,
                        petImage: $petImage,
                        isImagePickerPresented: $isImagePickerPresented,
                        imagePickerType: $imagePickerType,
                        showPermissionAlert: $showPermissionAlert,
                        permissionAlertMessage: $permissionAlertMessage
                    )
                    
                    // Scene category selection area
                    SceneCategorySelectionView(
                        selectedCategory: $selectedCategory
                    )
                    
                    // AI Generate button
                    AIActionButton(
                        ownerImage: ownerImage,
                        petImage: petImage,
                        selectedCategory: selectedCategory,
                        isLoading: isLoading,
                        generateImage: generateImage
                    )
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .background(
                NavigationLink(
                    destination: ResultView(
                        originalImage: generatedImage ?? ownerImage,
                        aiResult: "This is a photo taken in the \(selectedCategory) scene. AI analysis suggests that this photo has high emotional value and would make a wonderful album or keepsake.",
                        sceneCategory: selectedCategory,
                        sceneSubcategory: ""
                    ),
                    isActive: $showResult
                ) {
                    EmptyView()
                }
                .disabled(generatedImage == nil && ownerImage == nil)
            )
            .alert("Error", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $isImagePickerPresented) {
            ImagePicker(image: imagePickerType == .owner ? $ownerImage : $petImage, imagePickerType: imagePickerType)
        }
        .alert("相册访问权限", isPresented: $showPermissionAlert) {
            Button("前往设置") {
                openAppSettings()
            }
            Button("取消") { }
        } message: {
            Text(permissionAlertMessage)
        }
    }
    
    // Generate image using AI service
    private func generateImage() {
        // Validate inputs
        guard let ownerImage = ownerImage, let petImage = petImage, !selectedCategory.isEmpty else {
            errorMessage = "Please select both owner and pet photos and choose a scene category."
            showAlert = true
            return
        }
        
        // Start loading
        isLoading = true
        errorMessage = ""
        showResult = false // Reset navigation state
        
        // Call AI service to generate image
        AIService.shared.generateImage(
            ownerImage: ownerImage,
            petImage: petImage,
            sceneCategory: selectedCategory
        ) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let image):
                    self.generatedImage = image
                    self.showResult = true
                    print("Successfully generated image and navigating to result view")
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.showAlert = true
                    print("Failed to generate image: \(error)")
                }
            }
        }
    }
    
    
    
    // Open app settings
    private func openAppSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        
        if UIApplication.shared.canOpenURL(settingsUrl) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

// Image picker type
enum ImagePickerType {
    case owner
    case pet
}

// Top Banner View
struct BannerView: View {
    @State private var currentIndex = 0
    private let bannerImages = ["Banner-00", "Banner-01", "Banner-02"]
    private let timer = Timer.publish(every: 3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            TabView(selection: $currentIndex) {
                ForEach(0..<bannerImages.count, id: \.self) { index in
                    Image(bannerImages[index])
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width * 9/16) // 16:9 aspect ratio
                        .clipped()
                        .cornerRadius(10)
                        .overlay(
                            Group {
                                if index == 0 { // Only add text overlay to the first banner
                                    VStack {
                                        Text("Petogether")
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                            .shadow(color: .black, radius: 2, x: 2, y: 2) // Black shadow, 2px distance, bottom right
                                        Text("Fill pet moments with you")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.9))
                                            .shadow(color: .black, radius: 2, x: 2, y: 2) // Black shadow, 2px distance, bottom right
                                    }
                                }
                            }
                        )
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .frame(height: geometry.size.width * 9/16) // 16:9 aspect ratio
            .onReceive(timer) { _ in
                withAnimation {
                    currentIndex = (currentIndex + 1) % bannerImages.count
                }
            }
        }
        .frame(height: 200) // Set a fixed height for the banner area
    }
}

// Photo Selection View
struct PhotoSelectionView: View {
    @Binding var ownerImage: UIImage?
    @Binding var petImage: UIImage?
    @Binding var isImagePickerPresented: Bool
    @Binding var imagePickerType: ImagePickerType
    @Binding var showPermissionAlert: Bool
    @Binding var permissionAlertMessage: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Upload Photos")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Horizontally arranged owner and pet photo uploads
            HStack(spacing: 40) { // Increase spacing from 20 to 40
                // Owner photo
                VStack(spacing: 5) {
                    ZStack(alignment: .topTrailing) {
                        Button(action: {
                            checkPhotoPermission(for: .owner)
                        }) {
                            if let image = ownerImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "person.fill")
                                                .font(.title2)
                                            Text("Add owner photo")
                                                .font(.caption)
                                        }
                                    )
                            }
                        }
                        
                        if ownerImage != nil {
                            Button(action: {
                                ownerImage = nil
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold)) // 缩小30%
                                    .foregroundColor(.blue)
                                    .background(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                            .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                                    )
                            }
                            .offset(x: 8, y: -8) // 调整位置以适应新的大小
                        }
                    }
                }
                
                // Pet photo
                VStack(spacing: 5) {
                    ZStack(alignment: .topTrailing) {
                        Button(action: {
                            checkPhotoPermission(for: .pet)
                        }) {
                            if let image = petImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150, height: 150)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "pawprint.fill")
                                                .font(.title2)
                                            Text("Add pet photo")
                                                .font(.caption)
                                        }
                                    )
                            }
                        }
                        
                        if petImage != nil {
                            Button(action: {
                                petImage = nil
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 14, weight: .bold)) // 缩小30%
                                    .foregroundColor(.blue)
                                    .background(
                                        Circle()
                                            .stroke(Color.white, lineWidth: 2)
                                            .frame(width: 20, height: 20)
                                            .background(Circle().fill(Color.white).frame(width: 20, height: 20))
                                    )
                            }
                            .offset(x: 8, y: -8) // 调整位置以适应新的大小
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center) // Center the HStack
        }
    }
    
    // Check photo permission before presenting image picker
    private func checkPhotoPermission(for type: ImagePickerType) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized:
            // Permission granted, present image picker
            imagePickerType = type
            isImagePickerPresented = true
        case .notDetermined:
            // Request permission
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        self.imagePickerType = type
                        self.isImagePickerPresented = true
                    } else {
                        self.permissionAlertMessage = "需要访问相册来选择照片。请在设置中允许访问相册。"
                        self.showPermissionAlert = true
                    }
                }
            }
        default:
            // Permission denied or restricted
            permissionAlertMessage = "需要访问相册来选择照片。请在设置中允许访问相册。"
            showPermissionAlert = true
        }
    }
}

// Scene Category Selection View
struct SceneCategorySelectionView: View {
    @Binding var selectedCategory: String
    
    // Define four scene categories
    let categories = [
        ("Travel", LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing)),
        ("Diet", LinearGradient(gradient: Gradient(colors: [Color.green, Color.blue]), startPoint: .topLeading, endPoint: .bottomTrailing)),
        ("Sports", LinearGradient(gradient: Gradient(colors: [Color.orange, Color.red]), startPoint: .topLeading, endPoint: .bottomTrailing)),
        ("Shopping", LinearGradient(gradient: Gradient(colors: [Color.pink, Color.purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose a Scene")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Four square gradient background images
            HStack(spacing: 15) {
                ForEach(categories, id: \.0) { category, gradient in
                    SceneCategoryItem(
                        title: category,
                        gradient: gradient,
                        isSelected: selectedCategory == category
                    )
                    .onTapGesture {
                        selectedCategory = category
                    }
                }
            }
            .padding(.horizontal, 0)
            .onAppear {
                // Set default selected category to Travel
                if selectedCategory.isEmpty {
                    selectedCategory = "Travel"
                }
            }
        }
    }
}

// Scene Category Item View
struct SceneCategoryItem: View {
    let title: String
    let gradient: LinearGradient
    let isSelected: Bool
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(gradient)
            .frame(width: 70, height: 70)
            .overlay(
                VStack(spacing: 4) {
                    // Add corresponding emoji for each scene
                    switch title {
                    case "Travel":
                        Text("✈️")
                            .font(.caption)
                    case "Diet":
                        Text("🍽️")
                            .font(.caption)
                    case "Sports":
                        Text("⚽")
                            .font(.caption)
                    case "Shopping":
                        Text("🛍️")
                            .font(.caption)
                    default:
                        Text("")
                            .font(.caption)
                    }
                    
                    Text(title)
                        .foregroundColor(isSelected ? .white : Color.white.opacity(0.5)) // Make unselected text darker
                        .font(.caption)
                        .fontWeight(.bold)
                }
            )
            .scaleEffect(1.0) // Keep the shape unchanged when selected
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// AI Generate Button
struct AIActionButton: View {
    let ownerImage: UIImage?
    let petImage: UIImage?
    let selectedCategory: String
    let isLoading: Bool
    let generateImage: () -> Void
    
    var body: some View {
        Button(action: generateImage) {
            HStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(1.0)
                }
                Text(isLoading ? "Generating..." : "AI Generate")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.white)
            .background(
                (ownerImage != nil && petImage != nil && !selectedCategory.isEmpty && !isLoading) ?
                Color.blue : Color.gray
            )
            .cornerRadius(10)
        }
        .disabled(ownerImage == nil || petImage == nil || selectedCategory.isEmpty || isLoading)
    }
}

// Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.presentationMode) var presentationMode
    let imagePickerType: ImagePickerType
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary // 仅从相册选择
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    HomeView()
}