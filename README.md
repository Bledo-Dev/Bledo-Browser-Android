# Bledo Browser

Bledo is a privacy-focused browser for Android built with Flutter. It features built-in security integrity checks and a clean, customizable user interface.

## Features

- **Privacy First**: Designed to keep your browsing experience private.
- **Security Guard**: Integrated checks for root access, debuggers, and environment integrity to protect your data.
- **Customizable Themes**: Multiple color themes including Blue, Light, and Green.
- **Modern Web Engine**: Powered by `flutter_inappwebview` for a robust browsing experience.
- **Anti-Tampering**: Built-in protection against unauthorized modifications.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
- [Android SDK](https://developer.android.com/studio)
- Java 17

### Installation

1.  Clone the repository:
```bash
    git clone [https://github.com/yourusername/bledo.git](https://github.com/yourusername/bledo.git)
    cd bledo
    ```
2.  Install dependencies:
```bash
    flutter pub get
    ```
3.  Run the app:
```bash
    flutter run
    ```

### Building for Release

To generate a release APK:

```bash
flutter build apk --release --no-tree-shake-icons
