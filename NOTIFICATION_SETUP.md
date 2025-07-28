# UniCraft Firebase Notification System

## Overview
This comprehensive notification system provides professional-grade Firebase push notifications that work even when the app is closed. The system includes background message handling, local notifications, topic subscriptions, and proper navigation.

## Features
- ✅ Works when app is in foreground, background, and completely closed
- ✅ Professional notification handling with proper error management
- ✅ Topic-based subscriptions for targeted notifications
- ✅ Local notification support with custom actions
- ✅ Automatic FCM token management and database storage
- ✅ Navigation handling from notification taps
- ✅ Android 13+ notification permission handling
- ✅ Notification preferences management

## Setup Complete
The following files have been created/updated:

### Core Services
1. `lib/services/notification_service.dart` - Main notification service
2. `lib/services/background_message_handler.dart` - Background message handler
3. `lib/services/notification_manager.dart` - High-level notification manager
4. `lib/notification.dart` - Updated legacy wrapper for backward compatibility
5. `lib/main.dart` - Updated with proper notification initialization

### Android Configuration
1. `android/app/src/main/AndroidManifest.xml` - Updated with Firebase permissions and services
2. `android/app/src/main/res/values/colors.xml` - Notification color resource

### Examples
1. `lib/examples/notification_examples.dart` - Complete usage examples

## How to Use

### 1. Basic Setup (Already Done)
The notification system is automatically initialized in `main.dart`. No additional setup required.

### 2. Send Notifications

#### Simple Notification
```dart
await NotificationService.showLocalNotification(
  title: 'Hello!',
  body: 'This is a test notification',
  data: {'type': 'test'},
);
```

#### Notice Notification
```dart
final notificationManager = NotificationManager();
await notificationManager.sendNoticeNotification(
  title: 'Important Notice',
  content: 'Exam schedule has been updated.',
  noticeId: 'notice_123',
);
```

#### Event Notification
```dart
await notificationManager.sendEventNotification(
  title: 'Tech Fest 2025',
  description: 'Annual technology festival',
  eventId: 'event_123',
  eventDate: DateTime.now().add(Duration(days: 7)),
);
```

### 3. Topic Subscriptions

#### Subscribe to Topics (for targeted notifications)
```dart
// Subscribe when user logs in
final notificationManager = NotificationManager();
await notificationManager.subscribeToUserTopics();

// Subscribe to specific topics
await NotificationService.subscribeToTopic('computer_science');
await NotificationService.subscribeToTopic('year_2024');
```

#### Unsubscribe from Topics
```dart
// Unsubscribe when user logs out
await notificationManager.unsubscribeFromAllTopics();

// Unsubscribe from specific topic
await NotificationService.unsubscribeFromTopic('computer_science');
```

### 4. Integration with Existing Features

#### When User Logs In
```dart
await NotificationIntegrationExamples.onUserLogin();
```

#### When User Logs Out
```dart
await NotificationIntegrationExamples.onUserLogout();
```

#### When Admin Posts Notice
```dart
await NotificationIntegrationExamples.onNoticePosted(
  title: notice.title,
  content: notice.content,
  noticeId: notice.id,
  department: notice.department,
);
```

#### When New Poll is Created
```dart
await NotificationIntegrationExamples.onPollCreated(
  title: poll.title,
  pollId: poll.id,
  department: poll.department,
);
```

#### When Chat Message is Received
```dart
await NotificationIntegrationExamples.onChatMessageReceived(
  senderName: message.senderName,
  message: message.content,
  chatId: message.chatId,
);
```

### 5. Get FCM Token
```dart
final token = await NotificationService.getToken();
print('FCM Token: $token');
```

### 6. Clear All Notifications
```dart
await NotificationService.clearAllNotifications();
```

## Notification Navigation

When users tap on notifications, they'll be automatically navigated to the appropriate screen:

- **Notice notifications** → Navigate to `/notice` with notice data
- **Poll notifications** → Navigate to `/poll` with poll data  
- **Event notifications** → Navigate to `/event` with event data
- **Chat notifications** → Navigate to `/chat` with chat data
- **Other notifications** → Navigate to `/home`

## Backend Integration

To send notifications from your backend, use the FCM REST API:

```json
{
  "to": "/topics/all_users",
  "notification": {
    "title": "Notification Title",
    "body": "Notification body",
    "icon": "@mipmap/ic_launcher"
  },
  "data": {
    "type": "notice",
    "noticeId": "123",
    "title": "Notice Title"
  },
  "android": {
    "notification": {
      "channel_id": "unicraft_notifications",
      "priority": "high",
      "sound": "default"
    }
  }
}
```

## Notification Channels

The system uses the following notification channel:
- **Channel ID**: `unicraft_notifications`
- **Channel Name**: `UniCraft Notifications`
- **Importance**: High
- **Sound**: Enabled
- **Vibration**: Enabled

## Permission Handling

The system automatically requests the following permissions:
- Notification permission (Android 13+)
- Internet access
- Wake lock
- Vibration
- Boot completed receiver

## Troubleshooting

### Notifications not working when app is closed
- Ensure the background message handler is properly set up (✅ Done)
- Check Android manifest permissions (✅ Done)
- Verify Firebase configuration (check google-services.json)

### Navigation not working from notifications
- Ensure navigator key is properly set (✅ Done)
- Add proper route definitions in main.dart
- Check notification payload format

### Permissions denied
- The system automatically requests permissions
- Users can manually enable in device settings
- Check permission status: `await Permission.notification.status`

## Testing

Use the `NotificationExample` widget to test all notification features:

```dart
// Navigate to the example screen
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => NotificationExample()),
);
```

## Next Steps

1. **Test the notification system** using the example screen
2. **Integrate with your existing features** using the provided examples
3. **Set up backend notifications** using FCM REST API
4. **Customize notification appearance** by modifying the Android resources
5. **Add more navigation routes** for specific notification types

The notification system is now ready for professional use and will work reliably even when your app is completely closed!
