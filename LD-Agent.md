# LD-Agent: Core Functionality of FitMunity

## What is an LD-Agent?

An LD-Agent (Long-term Dialogue Agent) is a model-agnostic framework designed to maintain coherent and personalized long-term conversations with users across multiple sessions and extended time periods. Based on research by Li et al. (2024), LD-Agents incorporate three key independently tunable modules:

1. **Event Perception Module**: Stores and retrieves relevant memories from past conversations
2. **Persona Extraction Module**: Dynamically models both user and agent personas
3. **Response Generation Module**: Integrates memories and personas to generate appropriate responses

Unlike most existing dialogue systems that focus on brief, single-session interactions spanning only 2-15 turns, LD-Agents are specifically designed for real-world scenarios requiring long-term companionship and familiarity with users over time.

In the context of FitMunity, the LD-Agent is the heart of the app, responsible for managing the core functionalities that make the app a unique social fitness platform. It processes user-generated content, analyzes fitness-related data, and facilitates personalized AI character interactions based on sophisticated language understanding.

## LD-Agent Technical Architecture

### Event Memory System
The LD-Agent employs a dual-memory system:

1. **Long-term Memory**: 
   - Stores vector representations of high-level event summaries from previous sessions
   - Uses a time-aware and topic-based retrieval mechanism that considers semantic relevance, topic overlap, and time decay
   - Employs a tunable event summary module to create concise and relevant memories

2. **Short-term Memory**:
   - Maintains a dynamic dialogue cache for the current session
   - Automatically determines when to transfer short-term memory to long-term storage
   - Ensures detailed context is preserved for ongoing conversations

### Persona Management
The persona module utilizes a bidirectional user-agent modeling approach:

- **Dynamic Extraction**: Continuously updates persona information from ongoing dialogue
- **Separate Persona Banks**: Maintains distinct persona repositories for both users and AI characters
- **Chain-of-Thought Reasoning**: Employs sophisticated reasoning to infer implicit personality traits

### Decision-Making Framework
The agent utilizes a multi-step decision process:
1. **Content Analysis**: Evaluates user-generated content
2. **Context Evaluation**: Considers user history and preferences
3. **Response Selection**: Chooses appropriate AI character and response type
4. **Feedback Integration**: Incorporates user interactions to improve future responses

## Profile Management System

### User Profile Structure

The user profile in FitMunity is structured in three distinct layers:

1. **Static Profile (Pinned Information)**
   - Permanent or slowly changing attributes
   - Examples:
     - Age and birthday
     - Height
     - Known allergies or medical conditions
     - Dietary restrictions
     - Fitness goals
     - Base metabolic rate
   - These attributes are pinned at the top of the profile and require explicit user action or periodic review to update

2. **Short-term Activity Profile (7-Day Rolling Window)**
   - Maintains detailed daily summaries for the past week
   - Includes:
     - Daily workout summaries
     - Calorie intake and burn records
     - Types of exercises performed
     - Achievement milestones
     - Social interactions and comments
     - Mood and energy levels
   - This information is used for immediate context in AI interactions
   - Updates in real-time as users post new content or interact with the app

3. **Long-term Abstract Memory (2-Year Historical Record)**
   - Compressed weekly summaries stored in a rolling list
   - Each weekly summary is condensed into 1-2 concise sentences
   - Examples of weekly summaries:
     - "Focused on strength training, achieved new PR in deadlifts (180lbs)"
     - "Recovered from minor knee injury, gradually returned to running"
   - Maintains up to 104 weeks (2 years) of compressed summaries
   - Older summaries are gradually phased out using a first-in-first-out approach
   - Used to track long-term progress and identify patterns

### Profile Compression Process

1. **Daily to Weekly Compression**
   - Every 7 days, the detailed daily activities are analyzed
   - Key patterns and significant events are identified
   - A natural language processing algorithm generates a concise summary
   - The summary focuses on:
     - Major achievements
     - Significant changes in routine
     - Notable challenges or setbacks
     - Overall progress toward goals

2. **Weekly to Long-term Storage**
   - The compressed weekly summary is added to the long-term list
   - If the list exceeds 104 entries, the oldest entry is removed
   - Each entry includes:
     - Timestamp
     - Compressed summary text
     - Key metrics or milestones
     - References to any significant events

### AI Character Profiles

The AI character profiles will be implemented in a future update, focusing on:
- Personality traits and response patterns
- Knowledge base and expertise areas
- Interaction history with users
- Behavioral consistency across sessions

This profile system ensures that the LD-Agent has access to both immediate and historical context while maintaining a manageable data footprint. The multi-layered approach allows for efficient retrieval of relevant information based on the conversation context and time frame.

## Implementation Structure for FitMunity

### 1. Core Data Models

```swift
// Memory representation
struct Memory {
    let timestamp: Date
    let summary: String
    let vectorRepresentation: [Float]
    let topics: Set<String>
}

// Persona representation
struct Persona {
    let traits: [String]
    let lastUpdated: Date
    let confidence: Float
}

// User-Agent interaction context
struct DialogueContext {
    let currentSession: [Message]
    let relevantMemories: [Memory]
    let userPersona: Persona
    let agentPersona: Persona
}
```

### 2. Event Memory Implementation

#### Long-term Memory Manager
```swift
class LongTermMemoryManager {
    // Vector store for efficient memory retrieval
    private var memoryBank: [Memory]
    private let encoder: TextEncoder // e.g., MiniLM
    private let summarizer: EventSummarizer
    
    // Configuration parameters
    private let timeDecayFactor: Float = 1e+7
    private let semanticThreshold: Float = 0.5
    
    func storeMemory(context: [Message]) {
        let summary = summarizer.summarize(context)
        let vector = encoder.encode(summary)
        let topics = extractTopics(context)
        let memory = Memory(timestamp: Date(), 
                          summary: summary,
                          vectorRepresentation: vector,
                          topics: topics)
        memoryBank.append(memory)
    }
    
    func retrieveRelevantMemories(query: String) -> [Memory] {
        let queryVector = encoder.encode(query)
        let queryTopics = extractTopics(query)
        
        return memoryBank
            .map { memory in
                let semanticScore = cosineSimilarity(queryVector, memory.vectorRepresentation)
                let topicScore = calculateTopicOverlap(queryTopics, memory.topics)
                let timeDecay = exp(-timeDifference(memory.timestamp) / timeDecayFactor)
                let totalScore = timeDecay * (semanticScore + topicScore)
                return (memory, totalScore)
            }
            .filter { $0.1 > semanticThreshold }
            .sorted { $0.1 > $1.1 }
            .map { $0.0 }
    }
}
```

#### Short-term Memory Manager
```swift
class ShortTermMemoryManager {
    private var currentSession: [Message]
    private let sessionTimeoutInterval: TimeInterval = 600 // 10 minutes
    private let longTermMemory: LongTermMemoryManager
    
    func addMessage(_ message: Message) {
        if isSessionExpired() {
            // Transfer to long-term memory
            longTermMemory.storeMemory(context: currentSession)
            currentSession.removeAll()
        }
        currentSession.append(message)
    }
}
```

### 3. Persona Management Implementation

```swift
class PersonaManager {
    private var userPersonaBank: [String: Persona]
    private var agentPersonaBank: [String: Persona]
    private let personaExtractor: PersonaExtractor
    
    func updateUserPersona(userId: String, message: String) {
        if let traits = personaExtractor.extractTraits(from: message) {
            let updatedPersona = Persona(
                traits: traits,
                lastUpdated: Date(),
                confidence: calculateConfidence(traits)
            )
            userPersonaBank[userId] = updatedPersona
        }
    }
    
    func getPersonaContext(userId: String) -> (userPersona: Persona?, agentPersona: Persona?) {
        return (userPersonaBank[userId], agentPersonaBank[userId])
    }
}
```

### 4. Response Generation Implementation

```swift
class ResponseGenerator {
    private let llmClient: LLMClient // e.g., ChatGPT client
    private let memoryManager: LongTermMemoryManager
    private let personaManager: PersonaManager
    
    func generateResponse(context: DialogueContext) async throws -> String {
        // Construct prompt with context, memories, and personas
        let prompt = constructPrompt(
            context: context.currentSession,
            memories: context.relevantMemories,
            userPersona: context.userPersona,
            agentPersona: context.agentPersona
        )
        
        // Generate response using LLM
        return try await llmClient.complete(prompt)
    }
    
    private func constructPrompt(context: [Message], 
                               memories: [Memory],
                               userPersona: Persona,
                               agentPersona: Persona) -> String {
        // Construct structured prompt following the format in Appendix D.3
        // of the LD-Agent paper
        return """
        <CONTEXT>
        \(formatContext(context))
        
        <MEMORY>
        \(formatMemories(memories))
        
        <USER TRAITS>
        \(formatPersona(userPersona))
        
        <AGENT TRAITS>
        \(formatPersona(agentPersona))
        
        Please respond as the agent...
        """
    }
}
```

### 5. Integration with FitMunity

```swift
class LDAgentManager {
    private let memoryManager: LongTermMemoryManager
    private let shortTermMemory: ShortTermMemoryManager
    private let personaManager: PersonaManager
    private let responseGenerator: ResponseGenerator
    
    func handleUserMessage(_ message: Message, userId: String) async throws -> String {
        // 1. Update short-term memory
        shortTermMemory.addMessage(message)
        
        // 2. Update user persona
        personaManager.updateUserPersona(userId: userId, message: message.content)
        
        // 3. Retrieve relevant memories
        let memories = memoryManager.retrieveRelevantMemories(query: message.content)
        
        // 4. Get persona context
        let (userPersona, agentPersona) = personaManager.getPersonaContext(userId: userId)
        
        // 5. Construct dialogue context
        let context = DialogueContext(
            currentSession: shortTermMemory.getCurrentSession(),
            relevantMemories: memories,
            userPersona: userPersona,
            agentPersona: agentPersona
        )
        
        // 6. Generate and return response
        return try await responseGenerator.generateResponse(context: context)
    }
}
```

### 6. Configuration and Setup

```swift
// In your app's setup code
func configureLDAgent() {
    // Initialize components
    let encoder = MiniLMTextEncoder()
    let summarizer = EventSummarizer()
    let memoryManager = LongTermMemoryManager(encoder: encoder, 
                                            summarizer: summarizer)
    let shortTermMemory = ShortTermMemoryManager(longTermMemory: memoryManager)
    let personaManager = PersonaManager()
    let responseGenerator = ResponseGenerator()
    
    // Create main LD-Agent manager
    let ldAgent = LDAgentManager(
        memoryManager: memoryManager,
        shortTermMemory: shortTermMemory,
        personaManager: personaManager,
        responseGenerator: responseGenerator
    )
    
    // Register with dependency container
    DependencyContainer.register(ldAgent)
}
```

This implementation structure provides a modular, maintainable architecture that follows the LD-Agent framework's principles. Each component is independently tunable and can be improved or replaced without affecting the others. The implementation uses Swift's strong type system and modern async/await concurrency model for efficient operation.

Key features of this implementation:
- Modular architecture with clear separation of concerns
- Type-safe data models
- Efficient memory management with dual storage system
- Sophisticated persona tracking
- Flexible response generation system
- Easy integration with existing FitMunity codebase

The actual implementation should include additional error handling, logging, and performance optimizations based on specific requirements and constraints.