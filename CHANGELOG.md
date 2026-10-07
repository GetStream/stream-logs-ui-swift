# StreamLogsUI iOS SDK CHANGELOG

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

# Upcoming

### 🔄 Changed

# [0.2.0](https://github.com/GetStream/stream-logs-ui-swift/releases/tag/0.2.0)
_October 07, 2026_

### ✅ Added
- Save the log settings and the viewer's level and subsystem filters across app launches [#7](https://github.com/GetStream/stream-logs-ui-swift/pull/7)

### 🐞 Fixed
- Fix building with Xcode 16 [#7](https://github.com/GetStream/stream-logs-ui-swift/pull/7)

# [0.1.0](https://github.com/GetStream/stream-logs-ui-swift/releases/tag/0.1.0)
_October 05, 2026_

### ✅ Added

First beta version of the iOS Logs UI SDK, with the following features:
- In-app log viewer, opened from a floating button you can drag or tuck away, or by shaking the device
- Keep using your app under the viewer's sheet
- HTTP requests with their method, status and bodies, and a copy as cURL action
- WebSocket events with their type and payload
- Search messages, bodies and payloads, and filter by level and subsystem
- JSON viewer with collapsible nodes and search
- Settings screen to change the level and subsystems of each log destination at runtime
- Custom log levels and appearance
- Export and import log sessions, to share them with your team, Stream support or your AI agent
- Works with any logging library, with no dependencies
- Integrates with the Stream Chat, Video and Feeds SDKs with a single line of code

For more details on the supported features, please check the [README](https://github.com/GetStream/stream-logs-ui-swift#readme).
