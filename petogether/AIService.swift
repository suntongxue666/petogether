//
//  AIService.swift
//  petogether
//
//  Created by Sun1 on 2025/10/24.
//

import Foundation
import UIKit

// Extension to support appending data (No longer needed for JSON body, but keep it for analyzeImage if it uses multipart)
extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - Data Structure Definition

struct AIRequest: Codable {
    let image: String  // Base64 encoded image data
    let sceneCategory: String
    let sceneSubcategory: String
}

struct AIResponse: Codable {
    let success: Bool
    let message: String?
    let result: AIResult?
    let error: AIError?
}

struct AIResult: Codable {
    let analysis: String  // AI analysis result
    let suggestions: [String]  // Suggestions
}

struct AIError: Codable {
    let code: Int
    let message: String
}

// MARK: - Nano Banana Image Generation Data Structures (Updated for JSON request body)

// Request structure for Nano Banana Image Generate API (for JSON body)
struct NanoBananaImageGenerateRequest: Codable {
    let prompt: String
    let type: String // <--- Added this required field!
    let parameters: NanoBananaGenerateParameters?
    let imageUrls: [String]? // <--- 改为imageUrls字段
    // Note: The API doc only shows a single 'image' string. If blend requires multiple images,
    // this is a common approach. If it fails, check with API provider how to send multiple images for blend mode.
    // Another option could be to send one image in 'image' and the other in 'parameters' or another top-level field.
    let mask: String? // Assuming not used for blend mode currently
}

struct NanoBananaGenerateParameters: Codable {
    let size: String?
    let seed: Int?
    let upscale: Bool?
    let controlnet: String? // Or more specific ControlNet parameters
    // Add other parameters as needed based on API documentation
    let mode: String? // Explicitly add mode here, if not a top-level field in API
}

// Response structure for the new API based on the error response we received
struct NanoBananaImageGenerateResponse: Codable {
    let code: Int
    let msg: String?
    let data: NanoBananaImageData?
}

struct NanoBananaImageData: Codable {
    let image: String?  // Base64 encoded generated image
    let seed: Int?
    let info: String?
    let taskId: String?  // Task ID for polling
}

// MARK: - API Service Class

class AIService {
    static let shared = AIService()
    
    // IMPORTANT: Check if the base URL should include /api/v1 or not.
    // Based on the docs, `/v1/image/generate` is the full path after the domain.
    // So, `baseURL` should be "https://api.nanobananaapi.ai"
    private let baseURL = "https://api.nanobananaapi.ai"
    private let apiKey = "0aa91cedfa0f1ccb694ac1ee7ae394bb"
    
    // Cloudinary configuration
    private let cloudName = "dygx9d3gi"
    private let uploadPreset = "unsigned-petogether"
    private let cloudinaryUploadURL: String
    
    // Travel场景的地点信息
    private let travelPlaces = [
        "日本 · 富士山，雪山与樱花林道",
        "法国 · 巴黎埃菲尔铁塔，塞纳河畔日落",
        "美国 · 纽约时代广场，霓虹灯与大屏广告",
        "中国 · 北京故宫，金瓦红墙宫殿",
        "英国 · 伦敦大本钟与泰晤士河",
        "意大利 · 罗马斗兽场，古石墙与雕刻",
        "阿联酋 · 迪拜哈利法塔，摩天大楼夜景",
        "冰岛 · 极光草原，天空绚丽极光拱顶",
        "韩国 · 首尔南山塔，粉色樱花坡道",
        "印度 · 泰姬陵，白色大理石宫殿与花园"
    ]
    
    private init() {
        self.cloudinaryUploadURL = "https://api.cloudinary.com/v1_1/\(cloudName)/image/upload"
    }
    
    // Get API Key
    func getAPIKey() -> String? {
        return apiKey
    }
    
    // Convert UIImage to Base64 string
    private func convertImageToBase64(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        return imageData.base64EncodedString()
    }
    
    // Upload image to Cloudinary
    private func uploadImageToCloudinary(_ image: UIImage, completion: @escaping (Result<String, Error>) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(AIServiceError.imageConversionFailed))
            return
        }
        
        guard let url = URL(string: cloudinaryUploadURL) else {
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        // Create upload request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add upload preset
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(uploadPreset)\r\n".data(using: .utf8)!)
        
        // Add image file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Send upload request
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.noData))
                }
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let secureURL = json["secure_url"] as? String {
                    DispatchQueue.main.async {
                        completion(.success(secureURL))
                    }
                } else {
                    let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                    DispatchQueue.main.async {
                        completion(.failure(AIServiceError.apiError(message: "Cloudinary upload failed: \(errorMessage)")))
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // Download image from URL
    private func downloadImage(from url: URL, completion: @escaping (Result<UIImage, Error>) -> Void) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data else {
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.noData))
                }
                return
            }
            
            guard let image = UIImage(data: data) else {
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.imageConversionFailed))
                }
                return
            }
            
            DispatchQueue.main.async {
                completion(.success(image))
            }
        }.resume()
    }
    
    // Send AI analysis request
    func analyzeImage(
        image: UIImage,
        sceneCategory: String,
        sceneSubcategory: String,
        completion: @escaping (Result<AIResponse, Error>) -> Void
    ) {
        // Convert image to Base64
        guard let base64Image = convertImageToBase64(image) else {
            completion(.failure(AIServiceError.imageConversionFailed))
            return
        }
        
        // Build request URL
        // If the full path is /api/v1/analyze, and baseURL is just the domain,
        // then append /api/v1/analyze.
        // However, if the docs imply `https://api.nanobananaapi.ai/v1/analyze`
        // then the correct path to append should be "/v1/analyze".
        // Let's assume consistent pattern with /image/generate.
        guard let url = URL(string: "\(baseURL)/v1/analyze") else { // <--- 修正点在这里！
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        // Build request body
        let requestModel = AIRequest(
            image: base64Image,
            sceneCategory: sceneCategory,
            sceneSubcategory: sceneSubcategory
        )
        
        // Encode request body
        guard let requestBody = try? JSONEncoder().encode(requestModel) else {
            completion(.failure(AIServiceError.encodingFailed))
            return
        }
        
        // Configure URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestBody
        
        // Log request for debugging
        print("AI Analysis API Request:")
        print("URL: \(url)")
        print("Method: \(request.httpMethod ?? "Unknown")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
        // Send network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                print("Network Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            // Check HTTP response status code
            if let httpResponse = response as? HTTPURLResponse {
                print("AI Analysis API Response:")
                print("Status Code: \(httpResponse.statusCode)")
                print("Headers: \(httpResponse.allHeaderFields)")
                
                if let responseData = data {
                    print("Response Data: \(String(data: responseData, encoding: .utf8) ?? "Unable to decode")")
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    let httpError = AIServiceError.httpError(statusCode: httpResponse.statusCode)
                    print("HTTP Error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(.failure(httpError))
                    }
                    return
                }
            }
            
            // Parse response data
            guard let responseData = data else {
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.noData))
                }
                return
            }
            
            do {
                let responseModel = try JSONDecoder().decode(AIResponse.self, from: responseData)
                print("Analysis API Response Model: success=\(responseModel.success), hasResult=\(responseModel.result != nil), hasError=\(responseModel.error != nil)")
                DispatchQueue.main.async {
                    completion(.success(responseModel))
                }
            } catch {
                print("JSON Decode Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // Generate image using Nano Banana API (MODIFIED TO USE JSON BODY)
    func generateImage(
        ownerImage: UIImage,
        petImage: UIImage,
        sceneCategory: String,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        // First, upload images to Cloudinary
        uploadImageToCloudinary(ownerImage) { [weak self] ownerResult in
            guard let self = self else { return }
            
            switch ownerResult {
            case .success(let ownerURL):
                self.uploadImageToCloudinary(petImage) { petResult in
                    switch petResult {
                    case .success(let petURL):
                        // Both images uploaded successfully, now call Nano Banana API
                        self.callNanoBananaAPI(ownerImageURL: ownerURL, petImageURL: petURL, sceneCategory: sceneCategory, completion: completion)
                    case .failure(let error):
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // Call Nano Banana API with Cloudinary URLs
    private func callNanoBananaAPI(
        ownerImageURL: String,
        petImageURL: String,
        sceneCategory: String,
        completion: @escaping (Result<UIImage, Error>) -> Void
    ) {
        // Generate prompt based on scene category
        let prompt = generatePromptForScene(sceneCategory)
        
        // Build request URL (REVERTING to the path that did not give 404)
        // It seems `/api/v1/nanobanana/generate` might be the correct endpoint for Nano Banana's image generation.
        guard let url = URL(string: "\(baseURL)/api/v1/nanobanana/generate") else { // <--- 修正点在这里！
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        // Build JSON request body
        let parameters = NanoBananaGenerateParameters(
            size: "512x512", // Example size, adjust as needed or make dynamic
            seed: nil, // Optional
            upscale: nil, // Optional
            controlnet: nil, // Optional
            mode: "blend" // Specify blend mode in parameters
        )
        
        // Use Cloudinary URLs instead of Base64 encoded images
        let requestModel = NanoBananaImageGenerateRequest(
            prompt: prompt,
            type: "IMAGETOIAMGE", // <--- 使用正确的值 "IMAGETOIAMGE"
            parameters: parameters,
            imageUrls: [ownerImageURL, petImageURL], // <--- 改为imageUrls字段
            mask: nil
        )
        
        guard let requestBody = try? JSONEncoder().encode(requestModel) else {
            completion(.failure(AIServiceError.encodingFailed))
            return
        }
        
        // Configure URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Changed to application/json
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = requestBody
        
        // Log request for debugging
        print("Nano Banana API Request (Image Generate):")
        print("URL: \(url)")
        print("Method: \(request.httpMethod ?? "Unknown")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let bodyString = String(data: requestBody, encoding: .utf8) {
            print("Request Body: \(bodyString)")
        }
        
        // Send network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle network errors
            if let error = error {
                print("Network Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                    print("Nano Banana API Response (Image Generate):")
                    print("Status Code: \(httpResponse.statusCode)")
                    print("Headers: \(httpResponse.allHeaderFields)")
                    
                    if let responseData = data {
                        print("Response Data: \(String(data: responseData, encoding: .utf8) ?? "Unable to decode")")
                    }
                    
                    guard 200...299 ~= httpResponse.statusCode else {
                        let httpError = AIServiceError.httpError(statusCode: httpResponse.statusCode)
                        print("HTTP Error: \(httpResponse.statusCode)")
                        DispatchQueue.main.async {
                            completion(.failure(httpError))
                        }
                        return
                    }
                }
            
            // Parse response data
            guard let responseData = data else {
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.noData))
                }
                return
            }
            
            do {
                let responseModel = try JSONDecoder().decode(NanoBananaImageGenerateResponse.self, from: responseData)
                print("API Response Model: code=\(responseModel.code), msg=\(responseModel.msg ?? "nil"), hasData=\(responseModel.data != nil)")
                
                // Check if the request was successful (code 200 means success)
                if responseModel.code == 200, let data = responseModel.data {
                    print("API Data: taskId=\(data.taskId ?? "nil")")
                    // If we have a taskId, we need to poll for the result
                    if let taskId = data.taskId {
                        print("Received taskId, starting to poll for result")
                        self.pollForTaskResult(taskId: taskId, completion: completion)
                    } else if let base64Image = data.image {
                        // Convert Base64 string to UIImage
                        guard let imageData = Data(base64Encoded: base64Image),
                              let generatedImage = UIImage(data: imageData) else {
                            print("Image conversion failed: unable to decode base64 image data")
                            DispatchQueue.main.async {
                                completion(.failure(AIServiceError.imageConversionFailed))
                            }
                            return
                        }
                        
                        DispatchQueue.main.async {
                            completion(.success(generatedImage))
                        }
                    } else {
                        let errorMessage = "No taskId or image in response"
                        print("API Error: \(errorMessage)")
                        let apiError = AIServiceError.apiError(message: errorMessage)
                        DispatchQueue.main.async {
                            completion(.failure(apiError))
                        }
                    }
                } else {
                    // Handle error response, including 500 from the server,
                    // as the provided error structure also has code and msg
                    let errorMessage = responseModel.msg ?? "Unknown API error"
                    print("API Error: code=\(responseModel.code), message=\(errorMessage)")
                    let apiError = AIServiceError.apiError(message: "Nano Banana API Error \(responseModel.code): \(errorMessage)")
                    DispatchQueue.main.async {
                        completion(.failure(apiError))
                    }
                }
            } catch {
                print("JSON Decode Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // Poll for task result
    private func pollForTaskResult(taskId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("Starting to poll for task result with taskId: \(taskId)")
        
        // Define polling interval and maximum attempts
        let pollingInterval: TimeInterval = 3.0
        var attempts = 0
        let maxAttempts = 20
        
        // Use weak reference to avoid retain cycles
        weak var weakSelf = self
        
        // Create a timer to poll for the result
        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { timer in
            attempts += 1
            print("Polling attempt #\(attempts) for taskId: \(taskId) at \(Date())")
            
            // Check if we've exceeded maximum attempts
            if attempts > maxAttempts {
                timer.invalidate()
                print("Task polling timeout after \(maxAttempts) attempts")
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.apiError(message: "Task polling timeout")))
                }
                return
            }
            
            // Call getTaskResult to check the status
            print("Calling getTaskResult for polling attempt #\(attempts)")
            weakSelf?.getTaskResult(taskId: taskId) { result in
                print("Received result for polling attempt #\(attempts)")
                switch result {
                case .success(let image):
                    print("Task completed successfully, received image")
                    timer.invalidate()
                    DispatchQueue.main.async {
                        completion(.success(image))
                    }
                case .failure(let error):
                    // If it's a temporary error, continue polling
                    if case AIServiceError.apiError(let message) = error, message?.contains("still") == true {
                        print("Task still processing, continuing to poll...")
                    } else {
                        // For other errors, stop polling and return the error
                        print("Task polling failed with error: \(error)")
                        timer.invalidate()
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                }
            }
        }
        
        // Add timer to run loop to ensure it fires
        RunLoop.main.add(timer, forMode: .common)
        print("Timer added to run loop for taskId: \(taskId)")
    }
    
    // Get task result using task ID
    func getTaskResult(taskId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("Calling getTaskResult for taskId: \(taskId)")
        
        // Build request URL for checking task status
        guard let url = URL(string: "\(baseURL)/v1/get-task-details") else {
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        // Build request body with task_id
        let requestBody = ["task_id": taskId]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(AIServiceError.encodingFailed))
            return
        }
        
        // Configure URLRequest
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = httpBody
        
        // Log request for debugging
        print("Nano Banana API Request (Task Result):")
        print("URL: \(url)")
        print("Method: \(request.httpMethod ?? "Unknown")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let bodyString = String(data: httpBody, encoding: .utf8) {
            print("Request Body: \(bodyString)")
        }
        
        // Send network request
        URLSession.shared.dataTask(with: request) { data, response, error in
            print("Received response for getTaskResult taskId: \(taskId)")
            
            // Handle network errors
            if let error = error {
                print("Network Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Nano Banana API Response (Task Result):")
                print("Status Code: \(httpResponse.statusCode)")
                print("Headers: \(httpResponse.allHeaderFields)")
                
                if let responseData = data {
                    print("Response Data: \(String(data: responseData, encoding: .utf8) ?? "Unable to decode")")
                }
                
                guard 200...299 ~= httpResponse.statusCode else {
                    let httpError = AIServiceError.httpError(statusCode: httpResponse.statusCode)
                    print("HTTP Error: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        completion(.failure(httpError))
                    }
                    return
                }
            }
            
            // Parse response data
            guard let responseData = data else {
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.noData))
                }
                return
            }
            
            do {
                // Parse the response according to the official structure
                if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any],
                   let success = json["success"] as? Bool,
                   success == true,
                   let data = json["data"] as? [String: Any],
                   let status = data["status"] as? String {
                    
                    print("Task Status: \(status)")
                    
                    // Check if the task is completed
                    if status == "completed",
                       let result = data["result"] as? [String: Any],
                       let images = result["images"] as? [[String: Any]],
                       let firstImage = images.first {
                        
                        // Try to get image URL first
                        if let imageUrlString = firstImage["url"] as? String,
                           let imageUrl = URL(string: imageUrlString) {
                            print("Downloading image from URL: \(imageUrl)")
                            // Download the image from URL
                            self.downloadImage(from: imageUrl) { result in
                                DispatchQueue.main.async {
                                    completion(result)
                                }
                            }
                            return
                        }
                        // If no URL, try base64
                        else if let base64String = firstImage["base64"] as? String {
                            print("Converting base64 image data")
                            // Convert Base64 string to UIImage
                            guard let imageData = Data(base64Encoded: base64String),
                                  let generatedImage = UIImage(data: imageData) else {
                                print("Image conversion failed: unable to decode base64 image data")
                                DispatchQueue.main.async {
                                    completion(.failure(AIServiceError.imageConversionFailed))
                                }
                                return
                            }
                            
                            DispatchQueue.main.async {
                                completion(.success(generatedImage))
                            }
                            return
                        }
                    }
                    // If task is still processing or queued
                    else if status == "processing" || status == "queued" {
                        let processingError = AIServiceError.apiError(message: "Task still \(status)")
                        print("Task is still \(status), returning error to continue polling")
                        DispatchQueue.main.async {
                            completion(.failure(processingError))
                        }
                        return
                    }
                    // If task failed
                    else if status == "failed",
                            let errorMessage = data["error_message"] as? String {
                        print("Task Failed: \(errorMessage)")
                        let apiError = AIServiceError.apiError(message: "Task failed: \(errorMessage)")
                        DispatchQueue.main.async {
                            completion(.failure(apiError))
                        }
                        return
                    }
                }
                
                // If we can't parse the response or task is not completed
                let errorMessage = "Task not completed yet or invalid response format"
                print("Task Result API Error: \(errorMessage)")
                let apiError = AIServiceError.apiError(message: errorMessage)
                DispatchQueue.main.async {
                    completion(.failure(apiError))
                }
            } catch {
                print("JSON Decode Error: \(error)")
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }.resume()
    }
    
    // Generate prompt based on scene category
    private func generatePromptForScene(_ sceneCategory: String) -> String {
        switch sceneCategory {
        case "Travel":
            // Randomly select a place
            let randomPlace = travelPlaces.randomElement() ?? "风景名胜地"
            // Prompt should be a description of the final blended image
            return "一个人和一只宠物在\(randomPlace)旅行，人物和宠物有自然的动作和合理的表情，并合理融入背景，高清，图片宽高比例9:16"
        case "Diet":
            return "一个人和一只宠物正在一起享用美食，人物和宠物有自然的动作和合理的表情，背景是餐厅或家庭厨房，高清，图片宽高比例9:16"
        case "Sports":
            return "一个人和一只宠物正在一起进行体育运动，人物和宠物有自然的动作和合理的表情，背景是运动场或户外，高清，图片宽高比例9:16"
        case "Shopping":
            return "一个人和一只宠物正在一起购物，人物和宠物有自然的动作和合理的表情，背景是商店或购物中心，高清，图片宽高比例9:16"
        default:
            return "一个人和一只宠物在一起，有自然的动作和合理的表情，高清，图片宽高比例9:16"
        }
    }
}

// MARK: - Error Type Definition

enum AIServiceError: Error, LocalizedError {
    case missingAPIKey
    case imageConversionFailed
    case invalidURL
    case encodingFailed
    case httpError(statusCode: Int)
    case noData
    case apiError(message: String?)
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing API key, please configure the API key in settings first"
        case .imageConversionFailed:
            return "Image conversion failed"
        case .invalidURL:
            return "Invalid URL"
        case .encodingFailed:
            return "Request encoding failed"
        case .httpError(let statusCode):
            return "HTTP error, status code: \(statusCode)"
        case .noData:
            return "No response data"
        case .apiError(let message):
            return message ?? "API error occurred"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
}