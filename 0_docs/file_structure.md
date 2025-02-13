# OHFtok Application File Structure

## Current Structure
```
lib/
├── main.dart
├── config/
│   ├── constants.dart
│   ├── routes.dart
│   └── theme/
│       ├── app_theme.dart
│       └── theme_constants.dart
│
├── models/
│   ├── user.dart
│   ├── achievement.dart
│   ├── video.dart
│   └── notification.dart
│
├── screens/
│   ├── auth/
│   │   ├── auth_wrapper.dart
│   │   ├── login_screen.dart
│   │   ├── register_screen.dart
│   │   └── forgot_password_screen.dart
│   │
│   ├── onboarding/
│   │   ├── onboarding_screen.dart
│   │   └── components/
│   │       ├── interest_selection.dart
│   │       └── onboarding_page.dart
│   │
│   ├── home/
│   │   ├── home_page.dart
│   │   └── components/
│   │       ├── video_feed_item.dart
│   │       └── bottom_nav_bar.dart
│   │
│   └── profile/
│       ├── profile_screen.dart
│       └── components/
│           ├── profile_header.dart
│           └── achievement_list.dart
│
├── services/
│   ├── auth_service.dart
│   ├── theme_service.dart
│   ├── achievement_service.dart
│   ├── notification_service.dart
│   └── storage_service.dart
│
└── widgets/
    ├── common/
    │   ├── custom_button.dart
    │   ├── loading_indicator.dart
    │   └── error_dialog.dart
    │
    ├── tutorial/
    │   ├── tutorial_overlay.dart
    │   └── feature_highlight.dart
    │
    └── profile/
        ├── profile_completion_card.dart
        └── interest_chips.dart
```

## Planned Structure (New Features)
```
lib/
├── screens/
│   ├── video/
│   │   ├── video_feed_screen.dart
│   │   ├── video_creation_screen.dart
│   │   ├── video_edit_screen.dart
│   │   └── components/
│   │       ├── video_player.dart
│   │       ├── video_controls.dart
│   │       ├── video_filters.dart
│   │       └── video_editor.dart
│   │
│   ├── social/
│   │   ├── followers_screen.dart
│   │   ├── following_screen.dart
│   │   ├── notifications_screen.dart
│   │   └── components/
│   │       ├── user_list_item.dart
│   │       └── notification_item.dart
│   │
│   └── analytics/
│       ├── analytics_dashboard.dart
│       └── components/
│           ├── engagement_chart.dart
│           └── metrics_card.dart
│
├── services/
│   ├── video/
│   │   ├── video_service.dart
│   │   ├── video_processing_service.dart
│   │   └── video_cache_service.dart
│   │
│   ├── social/
│   │   ├── social_service.dart
│   │   └── interaction_service.dart
│   │
│   └── analytics/
│       ├── analytics_service.dart
│       └── metrics_service.dart
│
├── models/
│   ├── video/
│   │   ├── video_model.dart
│   │   └── video_metadata.dart
│   │
│   ├── social/
│   │   ├── follower.dart
│   │   └── interaction.dart
│   │
│   └── analytics/
│       ├── engagement_metrics.dart
│       └── user_analytics.dart
│
└── widgets/
    ├── video/
    │   ├── video_player_controls.dart
    │   ├── video_progress_bar.dart
    │   └── video_thumbnail.dart
    │
    ├── social/
    │   ├── follow_button.dart
    │   ├── share_sheet.dart
    │   └── interaction_buttons.dart
    │
    └── analytics/
        ├── metrics_display.dart
        └── chart_widgets.dart
```

## Directory Purposes

### Config
- **constants.dart**: Application-wide constants
- **routes.dart**: Route definitions and navigation configuration
- **theme/**: Theme-related configurations and constants

### Models
- Data models and their related logic
- Each model has its own file for better organization
- Complex models may have their own subdirectory

### Screens
- Main UI screens of the application
- Organized by feature/functionality
- Components subdirectories for screen-specific widgets

### Services
- Business logic and data management
- Firebase and external service integrations
- Feature-specific services in subdirectories

### Widgets
- Reusable UI components
- Organized by feature and common components
- Each widget should be focused and maintainable

## Best Practices

1. **File Naming**
   - Use snake_case for file names
   - Be descriptive but concise
   - Add _screen, _page, or _widget suffix as appropriate

2. **Directory Organization**
   - Group related files in feature-specific directories
   - Keep directory depth reasonable (max 3-4 levels)
   - Use index.dart files for convenient exports

3. **Code Organization**
   - One widget/class per file
   - Keep files focused and manageable
   - Use subdirectories for complex features

4. **Import Organization**
   - Group imports by type (dart, package, relative)
   - Use relative imports for project files
   - Export commonly used widgets through index files

## Next Steps

1. **Create Base Structure**
   ```bash
   mkdir -p lib/{config,models,screens,services,widgets}/{auth,video,social,analytics}
   ```

2. **Implement Core Files**
   - Start with config and models
   - Add services as needed
   - Create placeholder widgets

3. **Feature Implementation**
   - Follow the planned structure
   - Implement one feature at a time
   - Keep code modular and testable

4. **Documentation**
   - Update this document as structure evolves
   - Document major architectural decisions
   - Keep README.md updated 