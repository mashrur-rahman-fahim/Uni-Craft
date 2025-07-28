# Firebase FCM Server Key Update Instructions

## The Issue
Your app is getting 404 errors from FCM because the server key is invalid or expired.

## Solution: Update Your Firebase Server Key

### Step 1: Get Your New Server Key
1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `uni-craft-2c6b8`
3. Click the gear icon → Project Settings
4. Go to the "Cloud Messaging" tab
5. Scroll down to "Project credentials"
6. Copy the "Server key"

### Step 2: Update the Server Key in Your Code
Replace the server key in `lib/services/push_notification_service.dart`:

```dart
static const String _serverKey = 'YOUR_NEW_SERVER_KEY_HERE';
```

### Step 3: Alternative Approach (Recommended)
Instead of using server keys, use the new `fcm_service.dart` I created which:
- Uses Firebase SDK directly (more reliable)
- Handles tokens automatically
- Provides better error handling
- Stores notifications in Firestore as fallback

### Step 4: Initialize the New Service
In your `main.dart`, add:

```dart
import 'package:uni_craft/services/fcm_service.dart';

// In your main() function:
await FCMService.initialize();
```

### Step 5: Update Chat Notifications
Replace your current chat notification calls with:

```dart
await FCMService.sendChatNotification(
  receiverUid: receiverUid,
  message: messageText,
  senderName: senderName,
);
```

## Why This Fixes the 404 Error:
- Uses Firebase SDK instead of HTTP requests
- Automatically handles token refresh
- Provides fallback notification storage
- Better error handling and logging

## Additional Benefits:
- Works when app is in foreground/background
- Handles notification taps
- Automatically manages FCM tokens
- More reliable delivery
