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

// MARK: - Nano Banana Image Generation Parameters (Based on API documentation)

// Parameters structure for Nano Banana Generate API (based on API docs)
struct NanoBananaGenerateParameters: Codable {
    // Common parameters based on API documentation
    let imageSize: String? // 添加imageSize参数
    let seed: Int?
    let upscale: Bool?
    let controlnet: String? // Or more specific ControlNet parameters
    // Add other parameters as needed based on API documentation
    let mode: String? // Explicitly add mode here, if not a top-level field in API
}

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
    let callbackUrl: String? // 添加回调URL参数
    let callbackSecret: String? // 添加回调密钥参数
    let imageSize: String? // 添加图片尺寸参数
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
    
    // Store completion handlers for pending tasks
    private var pendingTasks: [String: (Result<UIImage, Error>) -> Void] = [:]
    
    // IMPORTANT: Check if the base URL should include /api/v1 or not.
    // Based on the docs, `/v1/image/generate` is the full path after the domain.
    // So, `baseURL` should be "https://api.nanobananaapi.ai"
    private let baseURL = "https://api.nanobananaapi.ai"
    private let apiKey = "0aa91cedfa0f1ccb694ac1ee7ae394bb"
    
    // Print API key for debugging (REMOVE IN PRODUCTION)
    private func debugPrintAPIKey() {
        print("Using API Key: \(apiKey.prefix(5))...") // Only show first 5 characters for security
    }
    
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
        "印度 · 泰姬陵，白色大理石宫殿与花园",
        "美国 · 大峡谷国家公园，层岩叠嶂红色峡谷",
        "瑞士 · 少女峰，雪峰与绿色山谷",
        "澳大利亚 · 悉尼歌剧院与海港大桥",
        "泰国 · 曼谷大皇宫，金色尖顶寺庙",
        "中国 · 桂林阳朔山水，漓江竹筏山峰倒影",
        "希腊 · 圣托里尼蓝顶教堂与爱琴海",
        "加拿大 · 班夫国家公园，碧色湖泊与雪山",
        "日本 · 京都清水寺，枫叶古寺木廊道",
        "美国 · 旧金山金门大桥，海雾与日落剪影",
        "土耳其 · 卡帕多奇亚热气球峡谷",
        "日本 · 奈良东大寺，梅花鹿与古寺庭院",
        "法国 · 卢浮宫金字塔玻璃穹顶",
        "美国 · 拉斯维加斯大道，华丽夜景与霓虹霓彩",
        "中国 · 上海外滩，万国建筑群与黄浦江夜色",
        "西班牙 · 巴塞罗那圣家堂，哥特式尖塔",
        "俄罗斯 · 莫斯科红场与圣瓦西里大教堂",
        "越南 · 下龙湾石灰岩海岛与渔船",
        "摩洛哥 · 马拉喀什老城集市与红墙拱门",
        "新西兰 · 库克山，草甸与雪峰",
        "韩国 · 景福宫宫墙与传统韩式屋檐",
        "日本 · 北海道小樽运河，冬季银装雪景",
        "阿根廷 · 伊瓜苏大瀑布，壮丽水幕彩虹",
        "埃及 · 金字塔与沙漠驼队",
        "意大利 · 威尼斯贡多拉与水巷夕阳",
        "土耳其 · 蓝色清真寺圆顶群",
        "英国 · 剑桥学院河畔与石桥倒影",
        "瑞士 · 卢塞恩湖与木质廊桥",
        "马尔代夫 · 浅海栈道与碧绿泻湖",
        "印度尼西亚 · 巴厘岛海神庙礁石",
        "芬兰 · 玻璃小屋极光雪原",
        "日本 · 镰仓大佛与海风坡道",
        "法国 · 普罗旺斯薰衣草花田",
        "墨西哥 · 玛雅金字塔与热带植物",
        "美国 · 黄石公园彩色温泉台地",
        "澳大利亚 · 大堡礁湛蓝海域",
        "冰岛 · 黑沙滩与玄武岩海崖",
        "葡萄牙 · 佩纳宫彩色山顶城堡",
        "中国 · 西藏布达拉宫雪山背景",
        "马来西亚 · 双子塔摩天楼夜景",
        "希腊 · 米科诺斯风车海港",
        "比利时 · 布鲁日运河古城与石桥",
        "美国 · 优胜美地花岗岩峭壁与瀑布",
        "阿联酋 · 阿布扎比清真寺白色长廊",
        "德国 · 新天鹅堡雪山城堡",
        "日本 · 东京晴空塔夜景与街景霓虹",
        "意大利 · 佛罗伦萨大教堂与红顶屋海",
        "荷兰 · 郁金香田与风车农场",
        "南非 · 桌山与海岸线",
        "加拿大 · 尼亚加拉瀑布水雾",
        "瑞士 · 采尔马特马特洪峰雪岭"
    ]
    
    // Diet场景的地点信息
    private let dietPlaces = [
        "日本东京寿司吧台前，主厨现捏寿司，木质料理台",
        "法国巴黎街角户外咖啡座，法棍与牛角面包",
        "意大利那不勒斯披萨窑炉前，石砖餐厅与披萨师傅甩饼",
        "中国成都宽窄巷子火锅桌面，红汤翻滚热气升腾",
        "泰国曼谷夜市路边摊，椰子饮、芒果糯米饭",
        "韩国首尔烧烤店铁板烤肉，铜抽烟罩与滋滋油花",
        "香港茶餐厅卡座桌面，菠萝油与丝袜奶茶",
        "台湾夜市摊位前，超大鸡排与珍珠奶茶",
        "西班牙巴塞罗那海鲜饭铁锅料理",
        "越南河内街边粉摊，小凳低桌，热乎米粉",
        "土耳其旋转烤肉摊，铁架烤柱与烤肉片",
        "德国慕尼黑啤酒花园，烤肘子与扎啤",
        "美国纽约街头热狗摊与霓虹牌",
        "法国甜品店橱窗前，马卡龙与蛋糕塔",
        "日本京都怀石料理包间榻榻米",
        "新加坡海南鸡饭美食中心档口",
        "马来西亚娘惹菜馆复古瓷砖餐厅",
        "摩洛哥庭院风情薄荷茶与陶盘料理",
        "希腊海边餐厅蓝白桌椅，橄榄与烤鱼",
        "墨西哥街头玉米饼小摊",
        "印度黄焖咖喱店铜锅与香料墙",
        "中国广州早茶圆桌点心推车",
        "中国北京全聚德烤鸭台前片鸭场景",
        "中国西安城墙下肉夹馍与biangbiang面摊",
        "重庆磁器口麻辣小面巷口",
        "云南大理洱海畔露营风烧烤",
        "新疆夜市烤全羊与馕坑",
        "日本大阪章鱼烧摊烟火气街景",
        "韩国仁寺洞传统茶屋韩式木窗",
        "意大利罗马露天餐桌配红酒晚餐"
    ]
    
    // Sports场景的地点信息
    private let sportsPlaces = [
        "在海边沙滩上打沙滩排球，背景是金色落日与海风拂面的海岸线",
        "在城市公园里晨跑，背景是林荫大道与轻雾晨光",
        "在湖面划皮划艇，背景是平静湖面与被群山环绕的自然风光",
        "在户外草地打飞盘，背景是漫长绿坡与晴空",
        "在宽阔的海边冲浪，背景是卷起白浪的海面",
        "在山间徒步穿越木栈道，背景是高耸森林与云雾",
        "在室内攀岩墙上挑战路线，背景是专业彩色岩点",
        "在滑雪场的缓坡滑雪，背景是皑皑雪山和缆车",
        "在公园骑行自行车，背景是蜿蜒小道与湖面倒影",
        "在静谧庭院练习瑜伽，背景是竹子与禅意花园",
        "在赛道上轮滑或直排轮，背景是长直车道和城市天际线",
        "在人工草坪踢足球，背景是球门与运动看台",
        "在运动场跑道冲刺，背景是标准红色跑道和旗帜",
        "在网球场挥拍接球，背景是绿色球网和球馆看台",
        "在户外瑜伽垫上做普拉提，背景是清晨湖边",
        "在森林穿越路线进行越野跑，背景是高大松树林",
        "在健身房使用哑铃训练，背景是镜面与专业器材",
        "在河岸步道上公开骑行，背景是桥梁与流水",
        "在滑板公园做平衡练习，背景是坡道与涂鸦墙",
        "在沙地里和宠物一起慢跑，背景是海滩木栈道",
        "在户外玻璃球馆里打羽毛球，背景通透天幕",
        "在亲水公园练习桨板SUP，背景是开阔水面",
        "在郊野营地做伸展热身，背景是帐篷和篝火",
        "在露天篮球场投篮，背景是铁圈与街头场景",
        "在峡谷漂流出口合影，背景是激流飞瀑",
        "在健身跑道夜跑，背景是灯光和城市夜色",
        "在风景带骑马小道上慢行，背景是草甸和远山",
        "在儿童友好运动区玩平衡木或低空跳跃，背景是软垫乐园",
        "在山顶观景台太极晨练，背景是云海与日出",
        "在冬季湖面上的冰面滑行，背景是木屋与白雪森林"
    ]
    
    // Shopping场景的地点信息
    private let shoppingPlaces = [
        "在繁华城市中心的露天步行街购物，两侧林立时尚品牌店与咖啡座",
        "在大型商场的中庭休息区购物间隙合影，背景是挑高玻璃屋顶与时尚装饰",
        "在免税店挑选纪念品，背景是排列整齐的国际商品货架",
        "在欧洲风情古街的小店门口挑选手工饰品，背景是鹅卵石街道和老式路灯",
        "在高端商场香水柜台试香，背景是柔和灯光与玻璃陈列柜",
        "在日本商店街购买和风小物，背景是木质招牌与暖色灯笼",
        "在法国街头集市挑选鲜花，背景是推车摊位与浪漫街景",
        "在农夫市集选购新鲜蔬果，背景是彩色帐篷与木箱陈列",
        "在精致书店礼品区挑选文创商品，背景是摆设丰富的木质书架",
        "在复古老街买传统手工艺品，背景是怀旧木门与手作摊位",
        "在夜市小摊前挑选特色小吃伴手礼，背景是霓虹灯牌",
        "在艺术市集挑选原创绘画和陶艺作品，背景是艺术棚展与摊位",
        "在海岛免税店购买特色护肤品，背景是明亮落地窗与海景",
        "在古董跳蚤市场寻宝，背景是杂陈的小摆件与古旧家具",
        "在户外冬季圣诞市集买热红酒马克杯，背景是灯串与木屋摊位",
        "在商场宠物友好区购物，背景是宠物用品货架",
        "在精品服饰店试穿外套镜前合影，背景是落地镜与柔光灯",
        "在传统香料市场挑选香料和干果，背景是五彩香料堆叠",
        "在港口渔市场选购海产品，背景是摊位与蓝色渔船",
        "在南美手工艺市集选购织布制品，背景是鲜艳色彩与民族纹样",
        "在北欧生活方式店挑选家居摆件，背景是极简木质展台",
        "在亚洲寺庙集市买祈福挂饰，背景是经幡与木牌",
        "在露天花卉市场挑花束，背景是色彩丰富的花海摊位",
        "在设计师品牌概念店试戴配饰，背景是艺术装置与灯光造型墙",
        "在美式奥特莱斯户外街区逛街，背景是欧式拱廊与促销广告",
        "在手作皮具铺挑腰包，背景是原色皮革与工具台",
        "在充满民族风的沙漠集市挑选编织地毯，背景是帐篷与香料装饰",
        "在机场候机区免税廊桥购物区选购巧克力礼盒",
        "在文创艺术园区的市集摊位选取插画明信片",
        "在咖啡文化市集里挑选特色豆袋，背景是咖啡烘焙器具与木台"
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
            imageSize: "3:4", // 根据API文档使用正确的参数名imageSize
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
            mask: nil,
            callbackUrl: "https://petogether-callback-backend.onrender.com/api/nanobananaapi-callback", // 添加回调URL
            callbackSecret: "73bceb1e1e3fe217e0bf09aa76e1dfe6", // 添加回调密钥
            imageSize: "3:4" // 根据API文档使用正确的参数名imageSize
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
        
        // Debug API key
        debugPrintAPIKey()
        
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
                    // If we have a taskId, we need to wait for callback
                    if let taskId = data.taskId {
                        print("Received taskId, waiting for callback: \(taskId)")
                        print("Callback URL configured: https://petogether-callback-backend.onrender.com/api/nanobananaapi-callback")
                        print("Please check Render.com logs for callback reception")
                        // Store the completion handler and wait for callback
                        self.waitForCallback(taskId: taskId, completion: completion)
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
    
    // Wait for callback from Nano Banana API
    private func waitForCallback(taskId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("Waiting for callback for taskId: \(taskId)")
        print("Callback URL configured: https://petogether-callback-backend.onrender.com/api/nanobananaapi-callback")
        print("Timeout set to 60 seconds")
        
        // Store the taskId and completion handler for later use when callback arrives
        pendingTasks[taskId] = completion
        
        // Implement a timeout mechanism (optional)
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { // 60 seconds timeout
            if self.pendingTasks[taskId] != nil {
                // Timeout occurred - if callback didn't arrive, try polling as fallback
                print("Callback timeout for taskId: \(taskId), trying fallback polling")
                self.fallbackPollForTaskResult(taskId: taskId, completion: completion)
            }
        }
    }
    
    // Fallback polling mechanism in case callback doesn't work
    private func fallbackPollForTaskResult(taskId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("Starting fallback polling for taskId: \(taskId)")
        
        // Define polling interval and maximum attempts
        let pollingInterval: TimeInterval = 5.0
        var attempts = 0
        let maxAttempts = 12 // Total 60 seconds of polling
        
        // Use weak reference to avoid retain cycles
        weak var weakSelf = self
        
        // Create a timer to poll for the result
        let timer = Timer.scheduledTimer(withTimeInterval: pollingInterval, repeats: true) { timer in
            attempts += 1
            print("Fallback polling attempt #\(attempts) for taskId: \(taskId) at \(Date())")
            
            // Check if we've exceeded maximum attempts
            if attempts > maxAttempts {
                timer.invalidate()
                print("Fallback polling timeout after \(maxAttempts) attempts")
                DispatchQueue.main.async {
                    completion(.failure(AIServiceError.apiError(message: "Fallback polling timeout for taskId: \(taskId)")))
                }
                return
            }
            
            // Call getTaskResult to check the status
            weakSelf?.getTaskResult(taskId: taskId) { result in
                print("Fallback polling result for attempt #\(attempts)")
                switch result {
                case .success(let image):
                    print("Fallback polling successful, received image for taskId: \(taskId)")
                    timer.invalidate()
                    DispatchQueue.main.async {
                        completion(.success(image))
                    }
                case .failure(let error):
                    // If it's a temporary error, continue polling
                    if case AIServiceError.apiError(let message) = error, message?.contains("processing") == true {
                        print("Task still processing, continuing fallback polling...")
                    } else {
                        // For other errors, stop polling and return the error
                        print("Fallback polling failed with error: \(error)")
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
        print("Fallback polling timer added to run loop for taskId: \(taskId)")
    }
    
    // Method to be called when callback is received from backend
    func handleCallback(taskId: String, imageUrl: String) {
        print("Received callback for taskId: \(taskId)")
        print("Image URL: \(imageUrl)")
        // Retrieve the completion handler for this taskId
        guard let completion = pendingTasks.removeValue(forKey: taskId) else {
            print("No pending task found for taskId: \(taskId)")
            return
        }
        
        // Download the image from the provided URL
        guard let url = URL(string: imageUrl) else {
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        downloadImage(from: url) { result in
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
    
    // Method to be called when callback indicates failure
    func handleCallbackFailure(taskId: String, errorMessage: String) {
        print("Received failure callback for taskId: \(taskId), error: \(errorMessage)")
        // Retrieve the completion handler for this taskId
        guard let completion = pendingTasks.removeValue(forKey: taskId) else {
            print("No pending task found for taskId: \(taskId)")
            return
        }
        
        completion(.failure(AIServiceError.apiError(message: errorMessage)))
    }
    
    // Generate prompt based on scene category
    private func generatePromptForScene(_ sceneCategory: String) -> String {
        switch sceneCategory {
        case "Travel":
            // Randomly select a place
            let randomPlace = travelPlaces.randomElement() ?? "风景名胜地"
            // Prompt should be a description of the final blended image
            return "一个人和一只宠物在\(randomPlace)旅行，人物和宠物有自然的动作和合理的表情，并合理融入背景，高清，图片宽高比例3:4"
        case "Diet":
            // Randomly select a place
            let randomPlace = dietPlaces.randomElement() ?? "餐厅或家庭厨房"
            return "一个人和一只宠物正在一起享用美食，人物和宠物有自然的动作和合理的表情，背景是\(randomPlace)，高清，图片宽高比例3:4"
        case "Sports":
            // Randomly select a place
            let randomPlace = sportsPlaces.randomElement() ?? "运动场或户外"
            return "一个人和一只宠物正在一起进行体育运动，人物和宠物有自然的动作和合理的表情，背景是\(randomPlace)，高清，图片宽高比例3:4"
        case "Shopping":
            // Randomly select a place
            let randomPlace = shoppingPlaces.randomElement() ?? "商店或购物中心"
            return "一个人和一只宠物正在一起购物，人物和宠物有自然的动作和合理的表情，背景是\(randomPlace)，高清，图片宽高比例3:4"
        default:
            return "一个人和一只宠物在一起，有自然的动作和合理的表情，高清，图片宽高比例3:4"
        }
    }
    
    // Get task result using task ID (based on the correct API specification)
    func getTaskResult(taskId: String, completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("Calling getTaskResult for taskId: \(taskId)")
        
        // Build request URL for checking task status (based on the example)
        guard let url = URL(string: "\(baseURL)/api/v1/nanobanana/record-info?taskId=\(taskId)") else {
            completion(.failure(AIServiceError.invalidURL))
            return
        }
        
        // Configure URLRequest with GET method
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Log request for debugging
        print("Nano Banana API Request (Task Result):")
        print("URL: \(url)")
        print("Method: \(request.httpMethod ?? "Unknown")")
        print("Headers: \(request.allHTTPHeaderFields ?? [:])")
        
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
                // Parse the response according to the correct structure from the example
                if let json = try JSONSerialization.jsonObject(with: responseData, options: []) as? [String: Any] {
                    print("Task Result Response JSON: \(json)")
                    
                    // First check if this is the outer response structure with code/msg/data
                    if let code = json["code"] as? Int, code == 200,
                       let data = json["data"] as? [String: Any] {
                        // This is the outer structure, extract the inner data
                        self.handleTaskResultData(data: data, completion: completion)
                        return
                    } else {
                        // This might be the direct data structure
                        self.handleTaskResultData(data: json, completion: completion)
                        return
                    }
                }
                
                // If we can't parse the response
                let errorMessage = "Unable to parse task result response"
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
    
    // Handle task result data
    private func handleTaskResultData(data: [String: Any], completion: @escaping (Result<UIImage, Error>) -> Void) {
        print("Handling task result data: \(data)")
        
        // Check success flag
        if let successFlag = data["successFlag"] as? Int {
            switch successFlag {
            case 1: // Completed successfully
                if let response = data["response"] as? [String: Any],
                   let resultImageUrl = response["resultImageUrl"] as? String,
                   let imageUrl = URL(string: resultImageUrl) {
                    print("Task completed successfully, downloading image from: \(imageUrl)")
                    self.downloadImage(from: imageUrl) { result in
                        DispatchQueue.main.async {
                            completion(result)
                        }
                    }
                    return
                } else {
                    let errorMessage = "Task completed but no valid image URL found"
                    print("Task Result Error: \(errorMessage)")
                    let apiError = AIServiceError.apiError(message: errorMessage)
                    DispatchQueue.main.async {
                        completion(.failure(apiError))
                    }
                    return
                }
            case 0: // Still processing
                let processingError = AIServiceError.apiError(message: "Task still processing")
                print("Task is still processing")
                DispatchQueue.main.async {
                    completion(.failure(processingError))
                }
                return
            case 2, 3: // Failed
                let errorMessage = data["errorMessage"] as? String ?? "Generation failed"
                print("Task Failed: \(errorMessage)")
                let apiError = AIServiceError.apiError(message: "Task failed: \(errorMessage)")
                DispatchQueue.main.async {
                    completion(.failure(apiError))
                }
                return
            default:
                let errorMessage = "Unknown success flag value: \(successFlag)"
                print("Task Result Error: \(errorMessage)")
                let apiError = AIServiceError.apiError(message: errorMessage)
                DispatchQueue.main.async {
                    completion(.failure(apiError))
                }
                return
            }
        } else {
            let errorMessage = "Invalid response format: missing successFlag"
            print("Task Result Error: \(errorMessage)")
            let apiError = AIServiceError.apiError(message: errorMessage)
            DispatchQueue.main.async {
                completion(.failure(apiError))
            }
            return
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