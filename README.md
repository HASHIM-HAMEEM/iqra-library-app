# IQRA Library Registration App 📚

A modern, offline-first Flutter application designed for library administrators to efficiently manage student registrations, subscriptions, and library operations. Built with cutting-edge technology and user-friendly design.

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Supabase](https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white)
![Android](https://img.shields.io/badge/Android-3DDC84?style=for-the-badge&logo=android&logoColor=white)

## 🌟 Features

### 📱 Core Functionality
- **Student Management**: Complete CRUD operations for student records
- **Profile Pictures**: Image upload with automatic compression (1MB limit)
- **Subscription Tracking**: Manage student subscriptions and plans
- **Activity Logging**: Track all system activities and changes
- **Real-time Sync**: Automatic synchronization with Supabase backend

### 🎨 User Experience
- **Modern UI**: Clean, intuitive Material Design interface
- **Offline-First**: Works without internet connection
- **Responsive Design**: Optimized for various screen sizes
- **Dark/Light Theme**: Automatic theme switching
- **Loading States**: Visual feedback for all operations

### 🔧 Technical Features
- **Image Compression**: Automatic optimization to reduce storage costs
- **Error Handling**: Comprehensive error management with user-friendly messages
- **Caching**: Intelligent caching for improved performance
- **Connectivity**: Smart network state management
- **Security**: Row Level Security (RLS) with Supabase

## 🚀 Getting Started

### Prerequisites
- Flutter SDK (3.8.1 or higher)
- Dart SDK (3.0.0 or higher)
- Android Studio or VS Code
- Supabase account (for backend services)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/your-username/iqra-library-app.git
   cd iqra-library-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Supabase**
   - Create a new project on [Supabase](https://supabase.com)
   - Copy your project URL and anon key
   - Set up the database schema using the migrations in `supabase/migrations/`

4. **Run with environment variables**
   ```bash
   flutter run --dart-define=SUPABASE_URL=your_supabase_url --dart-define=SUPABASE_ANON_KEY=your_anon_key
   ```

### Database Setup

The app requires a Supabase database with the following tables:
- `students` - Student information and profiles
- `subscriptions` - Subscription management
- `activity_logs` - System activity tracking
- `sync_metadata` - Synchronization data
- `app_settings` - User preferences

Run the database migrations in order:
```sql
-- Execute files in supabase/migrations/ directory in numerical order
-- Starting with 001_create_initial_schema.sql
```

## 📱 Usage

### Student Management
1. **Add New Student**: Tap the "+" button to create a new student profile
2. **Upload Photos**: Select profile pictures with automatic compression
3. **Edit Information**: Update student details with real-time validation
4. **View Details**: Access comprehensive student information

### Subscription Management
1. **Create Subscriptions**: Set up student subscription plans
2. **Track Expiry**: Monitor subscription expiration dates
3. **Renewal Management**: Handle subscription renewals efficiently

### Image Upload Features
- **Automatic Compression**: Images are compressed to under 1MB
- **Quality Preservation**: Maintains image quality during compression
- **Size Validation**: Prevents upload of oversized images
- **Progress Feedback**: Visual indicators during compression

## 🏗️ Architecture

### Tech Stack
- **Frontend**: Flutter with Dart
- **Backend**: Supabase (PostgreSQL with real-time capabilities)
- **State Management**: Riverpod
- **UI Framework**: Material Design 3
- **Image Processing**: flutter_image_compress
- **Networking**: Dio HTTP client

### Project Structure
```
lib/
├── core/                 # Core functionality
│   ├── config/          # App configuration
│   ├── services/        # Business logic services
│   ├── theme/           # UI theming
│   ├── utils/           # Utility functions
│   └── routing/         # App navigation
├── data/                # Data layer
│   ├── models/          # Data models
│   ├── repositories/    # Data access layer
│   └── services/        # External service integrations
├── domain/              # Domain layer
│   ├── entities/        # Business entities
│   └── repositories/    # Abstract repositories
├── presentation/        # Presentation layer
│   ├── layouts/         # App layouts
│   ├── pages/           # Screen widgets
│   ├── providers/       # State management
│   └── widgets/         # Reusable UI components
└── main.dart           # App entry point
```

### Design Patterns
- **Clean Architecture**: Separation of concerns
- **Repository Pattern**: Data access abstraction
- **Provider Pattern**: State management
- **Dependency Injection**: Service locator pattern

## 🔧 Configuration

### Environment Variables
```bash
# Required for Supabase integration
SUPABASE_URL=your_supabase_project_url
SUPABASE_ANON_KEY=your_supabase_anon_key

# Optional for testing
TEST_EMAIL=test@example.com
TEST_PASSWORD=test_password
```

### Build Configuration
```bash
# Debug build
flutter build apk --debug

# Release build (recommended for production)
flutter build apk --release --target-platform android-arm64 --split-per-abi

# Build with custom configuration
flutter build apk --release --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY
```

## 🧪 Testing

### Run Tests
```bash
# Run all tests
flutter test

# Run with Supabase configuration
flutter test --dart-define=SUPABASE_URL=$SUPABASE_URL --dart-define=SUPABASE_ANON_KEY=$SUPABASE_ANON_KEY

# Run specific test file
flutter test test/simple_connection_test.dart
```

### Test Coverage
The app includes comprehensive testing:
- **Unit Tests**: Core business logic
- **Integration Tests**: Supabase connectivity
- **Widget Tests**: UI components
- **Connection Tests**: Network functionality

## 📦 Deployment

### APK Generation
```bash
# Generate ARM64 APK (recommended)
flutter build apk --release --target-platform android-arm64 --split-per-abi

# Generate for all platforms
flutter build apk --release --split-per-abi
```

### Installation
```bash
# Install on connected device
adb install build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# Or manually transfer and install the APK file
```

## 🔒 Security

### Row Level Security (RLS)
- All database tables use Supabase RLS
- Policies ensure users can only access their own data
- Authentication required for all operations

### Data Protection
- Images automatically compressed to reduce storage costs
- Sensitive data encrypted in transit and at rest
- Secure authentication with Supabase Auth

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Flutter best practices
- Write comprehensive tests for new features
- Update documentation for API changes
- Ensure all tests pass before submitting PR

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Authors

- **IQRA Library Team** - *Initial work and development*

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- Supabase team for the excellent backend-as-a-service
- Material Design team for the design system
- All contributors and users of this application

## 📞 Support

For support and questions:
- Create an issue on GitHub
- Check the documentation in the `docs/` folder
- Contact the development team

---

**Made with ❤️ by IQRA Library Team**

*Empowering libraries with modern technology for better student management.*
