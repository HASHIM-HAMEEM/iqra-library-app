# Iqra Library App - Complete Codebase Documentation

## Overview
The Iqra Library App is a comprehensive Flutter application for library membership management, built with modern architecture patterns and best practices. The application uses clean architecture with separation of concerns across multiple layers.

## Architecture

### Technology Stack
- **Frontend**: Flutter with Dart
- **State Management**: Riverpod
- **Backend Database**: Supabase (Postgres)
- **Backend Services**: Supabase
- **Navigation**: GoRouter
- **UI**: Material Design 3 with custom theming

### Project Structure

```
lib/
├── core/              # Core utilities and configuration
├── data/              # Data access layer (repositories, DAOs, services)
├── domain/            # Business logic layer (entities, repository interfaces)
├── presentation/      # UI layer (pages, widgets, providers)
└── main.dart         # Application entry point
```

## Core Layer (`lib/core/`)

### Configuration (`core/config/`)
- **app_config.dart**: Central configuration file containing:
  - Application metadata (name, version)
  - Database configuration
  - Security settings
  - UI parameters and limits
  - Feature flags
  - Supabase credentials
  - Performance configurations

### Routing (`core/routing/`)
- **app_router.dart**: GoRouter-based navigation system with:
  - Authentication-based route guards
  - Nested routes with MainLayout shell
  - Custom page transitions (modal sheets)
  - Routes for dashboard, students, subscriptions, activity, reports, settings, migration

### Theme (`core/theme/`)
- **app_theme.dart**: Comprehensive theming system with:
  - Light and dark theme variants
  - Material Design 3 color schemes
  - Custom color palette
  - Typography using Google Fonts (Inter)
  - Component themes (AppBar, Cards, Buttons, Input fields)
  - SafeGoogleFonts utility for font loading with fallbacks

- **app_colors.dart**: Custom color definitions

### Responsive Design (`core/responsive/`)
- **responsive.dart**: Responsive layout utilities

### Utils (`core/utils/`)
- **error_mapper.dart**: Error handling and mapping utilities
- **permission_service.dart**: Device permission management
- **responsive_utils.dart**: Responsive design helpers
- **telemetry_service.dart**: Application analytics and telemetry

## Data Layer (`lib/data/`)

### Database
- The app persists core data (students, subscriptions, activity logs) in Supabase.
- Local storage is used only for user/device settings (secure storage).

### Models (`data/models/`)
Data transfer objects for database entities:
- **student_model.dart**: Student data model
- **subscription_model.dart**: Subscription data model
- **activity_log_model.dart**: Activity log data model
- Generated files with JSON serialization support

### Services (`data/services/`)
- **supabase_service.dart**: Backend integration service with:
  - Authentication management
  - Data synchronization
  - Real-time subscriptions
  - Error handling

- **migration_service.dart**: Database migration utilities

### Repository Implementations (`data/repositories/`)
Concrete implementations of domain repository interfaces:
- **student_repository_impl.dart**: Student data management backed by Supabase

- **subscription_repository_impl.dart**: Subscription management implementation
- **activity_log_repository_impl.dart**: Activity logging implementation

## Domain Layer (`lib/domain/`)

### Entities (`domain/entities/`)
Business logic entities representing core data structures:

- **student.dart**: Student entity with:
  - Personal and contact information
  - Subscription details
  - Utility methods (fullName, age, initials)
  - JSON serialization
  - Immutable design with copyWith

- **subscription.dart**: Subscription entity
- **activity_log.dart**: Activity log entity

### Repository Interfaces (`domain/repositories/`)
Abstract repository contracts defining business operations:
- **student_repository.dart**: Student management interface
- **subscription_repository.dart**: Subscription management interface
- **activity_log_repository.dart**: Activity logging interface

## Presentation Layer (`lib/presentation/`)

### Layouts (`presentation/layouts/`)
- **main_layout.dart**: Main application layout with:
  - Responsive navigation (top, side, bottom bars)
  - Platform-adaptive design
  - User menu and logout functionality
  - Navigation state management

### State Management (`presentation/providers/`)

#### Database Providers (`providers/`)
- **database_provider.dart**: Riverpod providers for:
  - Database instance
  - Repository implementations
  - Service instances
  - DAO access

#### Authentication (`providers/auth/`)
- **auth_provider.dart**: Authentication state management with:
  - Session management and timeout
  - Biometric authentication support
  - Error handling
  - Supabase integration

- **setup_provider.dart**: Application setup state

#### UI State (`providers/ui/`)
- **ui_state_provider.dart**: Global UI state management:
  - Search queries
  - Loading states
  - Error/success messages
  - Theme mode
  - Pagination state
  - Filter configurations for students, subscriptions, activity logs

#### Feature Providers
- **students/**: Student-related state management
  - **students_provider.dart**: Student data streams and queries
  - **students_notifier.dart**: Student state mutations

- **subscriptions/**: Subscription state management
- **activity_logs/**: Activity log state management
- **migration_provider.dart**: Database migration state

### Pages (`presentation/pages/`)

#### Authentication
- **auth/auth_page.dart**: Login and authentication interface

#### Main Features
- **dashboard/dashboard_page.dart**: Main dashboard with statistics and quick actions
- **students/**: Student management pages
  - **students_page.dart**: Student listing with search and filters
  - **add_student_page.dart**: New student registration
  - **edit_student_page.dart**: Student information editing
  - **student_details_page.dart**: Detailed student view

- **subscriptions/**: Subscription management pages
  - **subscriptions_page.dart**: Subscription listing and management
  - **subscription_details_page.dart**: Detailed subscription view

#### Utilities
- **activity/activity_page.dart**: Activity log viewer
- **settings/settings_page.dart**: Application settings
- **migration/migration_page.dart**: Database migration interface
- **splash/splash_page.dart**: Application loading screen
- **setup_page.dart**: Initial application setup

### Widgets (`presentation/widgets/`)

#### Common Components (`widgets/common/`)
Reusable UI components:
- **app_card.dart**: Standardized card component
- **custom_app_bar.dart**: Custom application bar
- **custom_text_field.dart**: Enhanced text input fields
- **primary_button.dart**: Primary action button
- **loading_widget.dart**: Loading indicators
- **filter_chips.dart**: Filter selection chips
- **quick_action_card.dart**: Dashboard action cards
- **recent_activity_card.dart**: Activity display cards
- **section_header.dart**: Section title headers
- **typeahead_student_field.dart**: Student search field with autocomplete
- **compact_stat_tile.dart**: Statistics display tiles
- **app_bottom_sheet.dart**: Modal bottom sheets
- **diagnostics_overlay.dart**: Development diagnostics

#### Feature-Specific Components (`widgets/subscriptions/`)
- **subscription_card.dart**: Subscription display card
- **subscription_filters.dart**: Subscription filtering UI
- **subscription_timeline.dart**: Subscription timeline visualization

## Key Features

### Student Management
- Complete CRUD operations with soft delete
- Advanced search and filtering capabilities
- Age-based queries and statistics
- Email validation and duplicate prevention
- Profile image support
- Audit trail tracking

### Subscription Management
- Flexible subscription plans
- Status tracking (active, expired, cancelled, pending)
- Revenue calculations and reporting
- Automatic expiration handling
- Student relationship management

### Data Persistence
- Local SQLite database using Drift ORM
- Real-time data synchronization with Supabase
- Robust migration system
- Offline-first architecture with best-effort sync

### Authentication & Security
- Supabase-based authentication
- Session management with configurable timeouts
- Biometric authentication support (future)
- Secure credential storage

### User Interface
- Material Design 3 with custom theming
- Responsive design for multiple screen sizes
- Dark/light theme support with system integration
- Platform-adaptive navigation
- Rich filtering and search capabilities

### Developer Experience
- Clean architecture with clear separation of concerns
- Comprehensive state management with Riverpod
- Type-safe database operations
- Error handling and validation
- Development diagnostics and telemetry

## Configuration

The application is highly configurable through `app_config.dart`:
- Database settings and connection parameters
- UI limits and pagination sizes
- Security configurations
- Feature flags for development
- Performance tuning parameters

## Build and Generation

The project uses code generation for:
- Database operations (Drift)
- JSON serialization
- State management boilerplate

Generated files are denoted with `.g.dart` extensions and should not be manually edited.

## Development Guidelines

### Architecture Principles
1. **Clean Architecture**: Clear separation between layers
2. **Dependency Inversion**: Depend on abstractions, not concretions
3. **Single Responsibility**: Each class has a single, well-defined purpose
4. **Immutability**: Prefer immutable data structures
5. **Error Handling**: Comprehensive error handling at all layers

### State Management
- Use Riverpod providers for dependency injection
- Implement proper state mutations through notifiers
- Leverage stream providers for real-time data
- Handle loading and error states consistently

### Database Operations
- Use repository pattern for data access
- Implement soft deletes where appropriate
- Maintain audit trails for sensitive operations
- Handle database migrations properly

### UI Development
- Follow Material Design guidelines
- Implement responsive design patterns
- Use consistent theming throughout
- Provide proper accessibility support

This documentation provides a comprehensive overview of the Iqra Library App codebase, serving as a reference for developers working on the project and stakeholders understanding the system architecture.