import Foundation

// Data Transfer Objects (DTOs) for Supabase

// Post DTO - maps to posts table in Supabase
struct PostDTO: Codable, Identifiable {
    let id: String
    let user_id: String
    let content: String
    let like_count: Int
    let comment_count: Int
    let time_created: Date
    let fitness_info: String?
    let tag: String?
    let username: String
    let is_deleted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, content, like_count, comment_count, time_created, fitness_info, tag, username, is_deleted
    }
}

// Post Image DTO - maps to post_images table in Supabase
struct PostImageDTO: Codable, Identifiable {
    let id: String
    let post_id: String
    let image_url: String
    let created_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id, post_id, image_url, created_at
    }
}

// AI Response DTO - maps to ai_responses table in Supabase
struct AIResponseDTO: Codable, Identifiable {
    let id: String
    let post_id: String
    let content: String
    let status: String
    let timestamp: Date
    let character_id: String
    let character_name: String
    let character_avatar: String
    let background_story: String?
    let reply_format: String?
    
    enum CodingKeys: String, CodingKey {
        case id, post_id, content, status, timestamp, character_id, character_name, character_avatar, background_story, reply_format
    }
    
    // Convert DTO to domain model
    func toAIResponse() -> AIResponse {
        let status: AIResponseStatus
        switch self.status {
        case "pending": status = .pending
        case "failed": status = .failed
        default: status = .completed
        }
        
        let character = AICharacter(
            id: character_id,
            name: character_name,
            avatar: character_avatar,
            backgroundStory: background_story ?? "",
            replyFormat: reply_format ?? "",
            topicsToReplyTo: ["all"]
        )
        
        return AIResponse(
            id: id,
            content: content,
            status: status,
            timestamp: timestamp,
            character: character
        )
    }
}

// Comment Reply DTO - maps to comment_replies table in Supabase
struct CommentReplyDTO: Codable, Identifiable {
    let id: String
    let response_id: String
    let content: String
    let is_user_reply: Bool
    let timestamp: Date
    let status: String
    let character_id: String?
    let character_name: String?
    let character_avatar: String?
    let reply_to_id: String?
    
    enum CodingKeys: String, CodingKey {
        case id, response_id, content, is_user_reply, timestamp, status, character_id, character_name, character_avatar, reply_to_id
    }
    
    // Convert DTO to domain model
    func toCommentReply() -> CommentReply {
        let status: AIResponseStatus
        switch self.status {
        case "pending": status = .pending
        case "failed": status = .failed
        default: status = .completed
        }
        
        var character: AICharacter? = nil
        if let characterId = character_id, 
           let characterName = character_name,
           let characterAvatar = character_avatar {
            character = AICharacter(
                id: characterId,
                name: characterName,
                avatar: characterAvatar,
                backgroundStory: "",
                replyFormat: "",
                topicsToReplyTo: ["all"]
            )
        }
        
        return CommentReply(
            id: id,
            content: content,
            isUserReply: is_user_reply,
            timestamp: timestamp,
            status: status,
            character: character,
            replyToId: reply_to_id
        )
    }
}

// Post Like DTO - maps to post_likes table in Supabase
struct PostLikeDTO: Codable, Identifiable {
    let id: String
    let post_id: String
    let user_id: String
    let created_at: Date
    
    enum CodingKeys: String, CodingKey {
        case id, post_id, user_id, created_at
    }
}

// Post with included data (for joined queries)
struct PostWithImagesDTO: Codable {
    let post: PostDTO
    let images: [PostImageDTO]?
    
    enum CodingKeys: String, CodingKey {
        case post = "posts"
        case images = "post_images"
    }
}

// Calorie Entry DTO - maps to calorie_entries table in Supabase
struct CalorieEntryDTO: Codable, Identifiable {
    let id: String
    let user_id: String
    let date: String // ISO8601 formatted date
    let calories: Int
    let is_gained: Bool
    let post_id: String
    let description: String
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, date, calories, is_gained, post_id, description
    }
    
    // Convert DTO to domain model
    func toCalorieEntry() -> CalorieEntry {
        let dateFormatter = ISO8601DateFormatter()
        let entryDate = dateFormatter.date(from: date) ?? Date()
        
        return CalorieEntry(
            calories: calories,
            isGained: is_gained,
            postId: post_id,
            description: description,
            date: entryDate,
            id: UUID(uuidString: id) ?? UUID()
        )
    }
}

// User Profile DTO - maps to user_profiles table in Supabase
struct UserProfileDTO: Codable {
    let id: String
    let user_id: String
    let name: String?
    let age: Int?
    let gender: String?
    let height: Double?
    let height_unit: String?
    let current_weight: Double?
    let target_weight: Double?
    let weight_unit: String?
    let goal: String?
    let avatar: String?
    let has_completed_onboarding: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, user_id, name, age, gender, height, height_unit, current_weight, target_weight, weight_unit, goal, avatar, has_completed_onboarding
    }
    
    // Convert UserProfileDTO to update UserData model
    func updateUserData(_ userData: UserData) {
        if let name = name {
            userData.name = name
        }
        
        if let age = age {
            userData.age = age
        }
        
        if let gender = gender, let genderEnum = Gender(rawValue: gender) {
            userData.gender = genderEnum
        }
        
        if let height = height {
            userData.height = height
        }
        
        if let heightUnit = height_unit, let unit = MeasurementUnit.HeightUnit(rawValue: heightUnit) {
            userData.heightUnit = unit
        }
        
        if let currentWeight = current_weight {
            userData.currentWeight = currentWeight
        }
        
        if let targetWeight = target_weight {
            userData.targetWeight = targetWeight
        }
        
        if let weightUnit = weight_unit, let unit = MeasurementUnit.WeightUnit(rawValue: weightUnit) {
            userData.weightUnit = unit
        }
        
        if let goal = goal, let goalEnum = Goal(rawValue: goal) {
            userData.goal = goalEnum
        }
        
        if let avatar = avatar {
            userData.avatar = avatar
        }
        
        userData.hasCompletedOnboarding = has_completed_onboarding
    }
}

// Extensions to convert domain models to DTOs
extension AIResponse {
    func toDTO(postId: String) -> AIResponseDTO {
        AIResponseDTO(
            id: id,
            post_id: postId,
            content: content,
            status: status.rawValue,
            timestamp: timestamp,
            character_id: character?.id ?? "unknown",
            character_name: character?.name ?? "Unknown",
            character_avatar: character?.avatar ?? "",
            background_story: character?.backgroundStory,
            reply_format: character?.replyFormat
        )
    }
}

extension CommentReply {
    func toDTO(responseId: String) -> CommentReplyDTO {
        CommentReplyDTO(
            id: id,
            response_id: responseId,
            content: content,
            is_user_reply: isUserReply,
            timestamp: timestamp,
            status: status.rawValue,
            character_id: character?.id,
            character_name: character?.name,
            character_avatar: character?.avatar,
            reply_to_id: replyToId
        )
    }
}

// Extension to convert domain model to DTO
extension CalorieEntry {
    func toDTO(userId: String) -> CalorieEntryDTO {
        let dateFormatter = ISO8601DateFormatter()
        
        return CalorieEntryDTO(
            id: id.uuidString,
            user_id: userId,
            date: dateFormatter.string(from: date),
            calories: calories,
            is_gained: isGained,
            post_id: postId,
            description: description
        )
    }
}

// Extension to convert UserData to UserProfileDTO
extension UserData {
    func toProfileDTO(userId: String) -> UserProfileDTO {
        UserProfileDTO(
            id: UUID().uuidString,
            user_id: userId,
            name: name,
            age: age,
            gender: gender?.rawValue,
            height: height,
            height_unit: heightUnit.rawValue,
            current_weight: currentWeight,
            target_weight: targetWeight,
            weight_unit: weightUnit.rawValue,
            goal: goal?.rawValue,
            avatar: avatar,
            has_completed_onboarding: hasCompletedOnboarding
        )
    }
} 