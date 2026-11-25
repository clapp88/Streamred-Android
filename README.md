# 88 Streams Android v1.23

## Fix
- Stronger duplicate prevention for chat
- Each message should now appear only once
- Uses message ID when available, otherwise a short time-window key

## Build
```bash
flutter pub get
flutter build apk --release
```
