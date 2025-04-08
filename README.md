# FitMunity - Social Fitness Community App

FitMunity is an innovative social fitness community app built with SwiftUI that combines social networking, AI-powered interactions, and fitness tracking. The app creates an engaging environment where users can share their fitness journey while receiving personalized feedback and motivation from a diverse cast of AI characters.

## Core Features

### 1. Social Feed
- Create and share posts about your fitness journey
- Support for text and image posts
- Post categorization with tags (Food, Fitness, etc.)
- Interactive features including likes and comments
- Real-time feed updates
- Personalized user profiles

### 2. AI Companions
The app features a unique cast of AI characters that interact with users:

#### General Interaction Characters
- **Buddy** (Golden Retriever): A friendly, enthusiastic companion who responds to all posts with warmth and encouragement
- **Whiskers** (Siamese Cat): A sophisticated feline offering witty remarks with a hint of aristocratic charm
- **Polly** (African Grey Parrot): A mimicking companion that echoes and reinforces positive messages
- **PosiBot** (Motivational Robot): A purpose-built AI focused on spreading positivity and motivation

#### Specialized Characters
- **Shakespeare**: A poetic soul who responds to images with carefully crafted sonnets
- **Ms. Ledger**: A meticulous calorie tracking assistant
- **Professor Savory**: A culinary expert providing deep insights into food-related posts
- **Iron Mike**: A dedicated fitness expert offering professional training advice
- **Lily**: A nutrition student providing science-backed dietary guidance

Each character features:
- Unique personality and response style
- Specialized knowledge domains
- Custom avatar and visual identity
- Context-aware interactions

### 3. Fitness Tracking
- Automatic calorie tracking from food and fitness posts
- Visual statistics and progress graphs
- Daily and weekly progress views
- Timeline of calorie gains and burns
- Detailed activity logging

### 4. User Management
- Secure authentication system
- User registration and login
- Password reset functionality
- Profile customization
- Personal goal setting

## Technical Architecture

### Core Components

#### 1. Data Management
- **CoreData** for local storage
- **Supabase** backend integration
- Real-time synchronization
- Efficient caching system

#### 2. AI Integration
- OpenAI ChatGPT API integration
- Custom prompt engineering for each AI character
- Context-aware response generation
- Multi-character interaction management

#### 3. User Interface
- Modern SwiftUI implementation
- Custom navigation system
- Responsive animations
- Dark mode support
- Accessibility features

### Key Managers

- `AIResponseManager`: Handles AI character interactions and responses
- `PostsManager`: Manages post creation and social feed
- `AuthManager`: Handles user authentication
- `CalorieManager`: Tracks fitness and nutrition data

## Getting Started

### Prerequisites
- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- Active Supabase account
- OpenAI API key

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/FitMunity.git
```

2. Create and configure environment files:
```bash
cp .env.example .env
```
Edit `.env` with your API keys and configuration.

3. Install dependencies:
```bash
# If using CocoaPods
pod install

# If using Swift Package Manager
xcode-select --install
```

4. Open the project:
```bash
open FitMunityDev.xcodeproj
```

5. Build and run the project in Xcode

### Backend Setup

1. Create a Supabase project
2. Follow the instructions in `SUPABASE_SETUP.md` for database configuration
3. Configure authentication providers in Supabase dashboard
4. Set up storage buckets for image handling

## App Configuration

### Environment Variables
Required environment variables in `.env`:
- `OPENAI_API_KEY`: Your OpenAI API key
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anonymous key

### Supabase Tables
- `posts`: Store user posts
- `post_images`: Handle post images
- `ai_responses`: Store AI character responses
- `comment_replies`: Manage conversation threads
- `post_likes`: Track post interactions
- `calorie_entries`: Store fitness data
- `user_profiles`: Manage user information

## Development

### Code Structure
```
FitMunityDev/
├── Config/             # App configuration
├── Managers/           # Business logic
├── Models/            # Data models
├── Views/             # UI components
│   ├── Authentication/
│   ├── Feed/
│   ├── Profile/
│   └── Statistics/
├── Persistence/       # Data storage
└── Utilities/         # Helper functions
```

### Key Files
- `FitMunityDevApp.swift`: Main app entry point
- `AIResponseManager.swift`: AI interaction logic
- `PostsManager.swift`: Social feed management
- `AuthManager.swift`: Authentication handling

## Team

### Core Development Team

- **Yufan Chen** - Lead Developer & System Architect
  - Full-stack implementation
  - Database architecture and SQL optimization
  - System design and architecture
  - AI prompt engineering and optimization

- **Haoran Jisun** - Frontend Design

- **Ruitao Zou** - Authentication 

- **Aki Liu** - Swift package initialization

- **Chris Wu** - Initial AI character concept design

## License

This project is licensed under the MIT License - see the LICENSE file for details.

