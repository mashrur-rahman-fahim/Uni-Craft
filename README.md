# UniCraft - University Management System

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Enabled-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A comprehensive university management mobile application built with Flutter and Firebase, designed to streamline communication and collaboration within educational institutions.

## 📱 Features

### 🔐 Authentication & User Management
- **Multi-Authentication Support**: Email/Password and Google Sign-In
- **Role-Based Access Control**: Administrator, Co-Administrator, and General Member roles
- **Complete Account Management**: Profile creation, editing, and secure account deletion
- **Age Validation**: Proper age range validation (12-80) for university users

### 🎓 Academic Management
- **Notice Board System**: Create, view, edit, and manage notices with categories and priorities
- **Study Materials**: Upload, share, and organize educational resources
- **Event Calendar**: Schedule and manage academic events and deadlines
- **Attendance Tracking**: Monitor and record student attendance

### 💬 Communication Tools
- **Real-time Chat**: Group and individual messaging with Firebase backend
- **Group Management**: Create and manage university groups with join codes
- **Member Directory**: View and connect with fellow students and faculty

### 📊 Interactive Features
- **Polls & Surveys**: Create and participate in polls with real-time results
- **Dashboard Analytics**: View statistics and insights for administrators
- **Time Planning**: Integrated stopwatch and time management tools

### 🔧 System Features
- **Offline Support**: Continue using core features without internet
- **File Management**: Upload and share various file types
- **Search Functionality**: Find users, notices, and materials quickly
- **Responsive Design**: Optimized for different screen sizes

## 🏗️ Technical Architecture

### Frontend
- **Framework**: Flutter 3.0+
- **Language**: Dart
- **UI/UX**: Material Design with custom theming
- **State Management**: Provider pattern with StatefulWidgets

### Backend & Services
- **Authentication**: Firebase Authentication
- **Database**: Cloud Firestore (NoSQL)
- **Storage**: Firebase Storage for files and images
- **Real-time Updates**: Firestore snapshots for live data

### Key Dependencies
```yaml
dependencies:
  flutter: sdk: flutter
  firebase_core: ^2.24.2
  firebase_auth: ^4.15.3
  cloud_firestore: ^4.13.6
  firebase_storage: ^11.5.6
  google_sign_in: ^6.1.6
  image_picker: ^1.0.4
  file_picker: ^6.1.1
  connectivity_plus: ^5.0.1
```

## 🚀 Getting Started

### Prerequisites
- Flutter 3.0 or higher
- Dart 3.0 or higher
- Android Studio / VS Code
- Firebase project setup

### Installation

1. **Clone the Repository**
   ```bash
   git clone https://github.com/your-username/unicraft.git
   cd unicraft
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Setup**
   - Create a new Firebase project at [Firebase Console](https://console.firebase.google.com)
   - Enable Authentication (Email/Password and Google)
   - Create Firestore database
   - Enable Firebase Storage
   - Download `google-services.json` and place in `android/app/`

4. **Build and Run**
   ```bash
   # Debug build
   flutter run

   # Release build
   flutter build apk --release
   ```

## 📁 Project Structure

```
lib/
├── main.dart                 # App entry point
├── firebase_options.dart     # Firebase configuration
├── auth-page.dart           # Authentication screens
├── Homepage.dart            # Profile setup
├── dashboard.dart           # Main dashboard
├── notice.dart              # Notice management
├── chat.dart               # Chat functionality
├── calendar.dart           # Event calendar
├── study_Materials.dart    # Study materials
├── createPoll.dart         # Poll creation
├── services/               # Backend services
│   ├── auth_service.dart
│   ├── notice_service.dart
│   └── account_deletion_service.dart
├── widget/                 # Reusable widgets
├── utils/                  # Utility functions
└── models/                 # Data models
```

## 🔧 Configuration

### Firebase Collections Structure

#### Users Collection (`Profile`)
```json
{
  "uid": "string",
  "name": "string",
  "email": "string",
  "age": "string",
  "role": "Administrator|Co-Administrator|General member",
  "code": "string",
  "imageLink": "string",
  "isActive": "boolean",
  "createdAt": "timestamp"
}
```

#### Notices Collection
```json
{
  "title": "string",
  "content": "string",
  "groupCode": "string",
  "authorId": "string",
  "authorName": "string",
  "category": "string",
  "priority": "string",
  "isActive": "boolean",
  "createdAt": "timestamp"
}
```

### Security Rules
Ensure proper Firestore security rules are configured:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /Profile/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
    match /notices/{document} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
        resource.data.authorId == request.auth.uid;
    }
  }
}
```

## 👥 User Roles & Permissions

### Administrator
- Create and manage groups with join codes
- Full notice management (create, edit, delete)
- Access to all app features and analytics
- User management capabilities

### Co-Administrator
- Limited administrative privileges
- Notice management within assigned groups
- Event and material management

### General Member
- Join groups using codes
- View notices and materials
- Participate in chats and polls
- Basic profile management

## 🔒 Security Features

- **Age Validation**: Ensures users are between 16-80 years old
- **Input Validation**: Comprehensive form validation throughout the app
- **Secure Authentication**: Firebase Authentication with email verification
- **Data Protection**: Firestore security rules prevent unauthorized access
- **Complete Account Deletion**: GDPR-compliant user data removal

## 🐛 Known Issues & Limitations

- Firebase Storage requires proper permissions for image uploads
- Some features require internet connectivity
- Group join codes are numeric only

## 🚀 Deployment

### Android Release Build
```bash
# Generate release APK
flutter build apk --release

# Generate App Bundle (recommended for Play Store)
flutter build appbundle --release
```

### Build Optimization
- ProGuard enabled for release builds
- Image assets optimized
- Dependencies analyzed for unused imports

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Firebase for backend infrastructure
- Material Design for UI guidelines
- The open-source community for inspiration

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Contact: [your-email@example.com]

---

**UniCraft** - Connecting Universities, Empowering Education 🎓

*Built with ❤️ using Flutter and Firebase*
