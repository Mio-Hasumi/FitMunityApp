import Foundation
import UIKit

// Error types for the ChatGPT API
enum ChatGPTError: Error, LocalizedError {
    case invalidAPIKey
    case invalidResponse
    case networkError
    case serverError
    
    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "API key is not set or invalid"
        case .invalidResponse:
            return "Received an invalid response from the server"
        case .networkError:
            return "Network error, please check your connection"
        case .serverError:
            return "Server error, please try again later"
        }
    }
}

class ChatGPTAPI {
    private let apiKey: String
    private let baseURL: String
    
    // Add property to store last raw response content
    public private(set) var lastResponseContent: String?
    
    init(apiKey: String, baseURL: String = "https://api.openai.com/v1/chat/completions") {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }
    
    func generateResponse(for prompt: String, image: UIImage? = nil) async throws -> String {
        // Check if API key is set
        guard !apiKey.isEmpty && apiKey != "OPENAI_API_KEY_NOT_SET" else {
            throw ChatGPTError.invalidAPIKey
        }
        
        // Create URL from the base URL
        guard let url = URL(string: baseURL) else {
            throw ChatGPTError.invalidResponse
        }
        
        // Create the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Create the message content
        var messageContent: [[String: Any]] = [
            ["role": "system" as String, "content": "You are a helpful assistant." as String]
        ]
        
        // Add image content if available
        var hasImage = false
        if let image = image {
            print("🖼️ DEBUG: Preparing to encode image of size: \(image.size)")
            if let base64Image = encodeImage(image) {
                hasImage = true
                print("✅ DEBUG: Successfully encoded image to base64")
                
                // For GPT-4o multimodal capabilities - correct format
                let userContent: [[String: Any]] = [
                    ["type": "text", "text": prompt],
                    ["type": "image_url", "image_url": ["url": base64Image]]
                ]
                messageContent.append(["role": "user", "content": userContent])
            } else {
                print("⚠️ DEBUG: Failed to encode image, falling back to text-only message")
                // Fall back to text-only if image encoding fails
                messageContent.append(["role": "user", "content": prompt + "\n\n[Note: There was an image attached but it could not be processed]"])
            }
        } else {
            // Plain text message
            messageContent.append(["role": "user", "content": prompt])
        }
        
        // Create the request body
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": messageContent,
            "max_tokens": 500,
            "temperature": 0.7
        ]
        
        // Serialize the request body to JSON
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody)
            request.httpBody = jsonData
            
            // Debug: Print the request JSON
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔍 DEBUG: API Request body size: \(jsonData.count) bytes, hasImage: \(hasImage)")
            }
        } catch {
            print("❌ ERROR: Failed to create request JSON: \(error.localizedDescription)")
            throw ChatGPTError.invalidResponse
        }
        
        // Send the request
        do {
            // Add timeout to prevent hanging requests
            request.timeoutInterval = 30.0
            
            print("🌐 DEBUG: Sending API request to \(baseURL)")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            // Debug: Print the response status code
            if let httpResponse = response as? HTTPURLResponse {
                print("🌐 DEBUG: API Response status code: \(httpResponse.statusCode)")
                
                // Log headers for debugging
                if httpResponse.statusCode != 200 {
                    print("⚠️ API Error Response Headers:")
                    httpResponse.allHeaderFields.forEach { key, value in
                        print("   \(key): \(value)")
                    }
                }
            }
            
            // Debug: Print the raw response
            if let responseString = String(data: data, encoding: .utf8) {
                // Store raw response regardless of parsing outcome
                self.lastResponseContent = responseString
                
                // Try direct access to the content via structure we saw in logs
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let message = firstChoice["message"] as? [String: Any],
                       let content = message["content"] as? String {
                        
                        print("✅ Successfully extracted content directly: \(content.prefix(30))...")
                        
                        // Process the content - remove quotes if present
                        var processedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // If the response is just a quoted string (like "Hi"), remove the quotes
                        if processedContent.hasPrefix("\"") && processedContent.hasSuffix("\"") {
                            processedContent = String(processedContent.dropFirst().dropLast())
                            print("🔄 Removed surrounding quotes: \(processedContent.prefix(30))...")
                        }
                        
                        return processedContent
                    }
                } catch {
                    print("⚠️ Error parsing JSON directly: \(error.localizedDescription)")
                }
            }
            
            // Check the response
            guard let httpResponse = response as? HTTPURLResponse else {
                throw ChatGPTError.networkError
            }
            
            // Handle HTTP error codes
            if httpResponse.statusCode >= 400 {
                print("❌ API Error: Status code \(httpResponse.statusCode)")
                if let errorData = String(data: data, encoding: .utf8) {
                    print("❌ API Error details: \(errorData)")
                }
                
                switch httpResponse.statusCode {
                case 401:
                    throw ChatGPTError.invalidAPIKey
                case 413:
                    print("❌ Error: Payload too large - the image is likely too big")
                    throw ChatGPTError.invalidResponse
                case 500...599:
                    throw ChatGPTError.serverError
                default:
                    throw ChatGPTError.invalidResponse
                }
            }
            
            // If we made it here, try once more with the full JSONSerialization
            if let data = self.lastResponseContent?.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let content = message["content"] as? String {
                
                print("✅ Extracted content from stored JSON: \(content)")
                var processedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if processedContent.hasPrefix("\"") && processedContent.hasSuffix("\"") {
                    processedContent = String(processedContent.dropFirst().dropLast())
                    print("🔄 Removed surrounding quotes: \(processedContent)")
                }
                
                return processedContent
            }
            
            throw ChatGPTError.invalidResponse
        } catch let error as ChatGPTError {
            // When throwing a ChatGPTError, try to extract content from last stored response
            if let responseContent = lastResponseContent,
               responseContent.contains("\"content\": \"") {
                print("🔍 Attempting to extract content from error response...")
                
                // Try to extract just the string following "content":
                if let contentStart = responseContent.range(of: "\"content\": ")?.upperBound {
                    let afterContent = responseContent[contentStart...]
                    
                    // If content starts with a quote
                    if afterContent.hasPrefix("\"") {
                        // Find the matching end quote (not escaped)
                        var inEscape = false
                        var quotePos = afterContent.index(after: afterContent.startIndex)
                        
                        while quotePos < afterContent.endIndex {
                            if afterContent[quotePos] == "\\" && !inEscape {
                                inEscape = true
                            } else if afterContent[quotePos] == "\"" && !inEscape {
                                break
                            } else {
                                inEscape = false
                            }
                            quotePos = afterContent.index(after: quotePos)
                        }
                        
                        if quotePos < afterContent.endIndex {
                            let content = String(afterContent[afterContent.index(after: afterContent.startIndex)..<quotePos])
                            print("✅ Found content in error response: \(content)")
                            return content
                        }
                    }
                }
            }
            
            throw error
        } catch {
            throw ChatGPTError.networkError
        }
    }
    
    // Backward compatibility for existing code
    func generateResponse(for post: Post) async throws -> String {
        let character = AICharacter.characterFor(post: post)
        
        // Determine which image to use
        var imageToSend: UIImage? = post.image
        
        // If post has an asset catalog image, load it
        if imageToSend == nil, let imageName = post.imageName {
            imageToSend = UIImage(named: imageName)
        }
        
        // Pass the image to the API if it exists
        return try await generateResponse(for: post.content, image: imageToSend)
    }
    
    // Encode image to base64 for API request
    public func encodeImage(_ image: UIImage) -> String? {
        // Scale down image if it's too large
        let maxDimension: CGFloat = 768  // Reduced from 1024 for more reliable processing
        let scaledImage: UIImage
        
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = maxDimension / max(image.size.width, image.size.height)
            let newWidth = image.size.width * scale
            let newHeight = image.size.height * scale
            let newSize = CGSize(width: newWidth, height: newHeight)
            
            print("🔍 DEBUG: Resizing image from \(image.size) to \(newSize)")
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            scaledImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        } else {
            scaledImage = image
        }
        
        // Convert to JPEG data with lower compression for more reliable processing
        guard let imageData = scaledImage.jpegData(compressionQuality: 0.5) else {
            print("⚠️ ERROR: Failed to create JPEG data from image")
            return nil
        }
        
        print("📊 DEBUG: Image data size: \(Double(imageData.count) / 1024.0 / 1024.0) MB")
        
        // Check if the image data is too large (OpenAI has a 20MB limit)
        if imageData.count > 15 * 1024 * 1024 {  // 15MB safety threshold
            print("⚠️ ERROR: Image data exceeds safe limit (15MB)")
            return nil
        }
        
        // Convert to base64 and return as data URL
        let base64String = imageData.base64EncodedString()
        return "data:image/jpeg;base64,\(base64String)"
    }
} 
