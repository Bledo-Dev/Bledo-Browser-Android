# Bledo Browser

Bledo is a privacy-focused browser for Android built with Flutter. It features built-in security integrity checks and a clean, customizable user interface.

## Features

- **Privacy First**: Designed to keep your browsing experience private.
- **Security Guard**: Integrated checks for root access, debuggers, and environment integrity to protect your data.
- **Customizable Themes**: Multiple color themes including Blue, Light, and Green.
- **Modern Web Engine**: Powered by `flutter_inappwebview` for a robust browsing experience.
- **Anti-Tampering**: Built-in protection against unauthorized modifications.
- **Dynamic IP Rotator (Coming Soon)**: Built-in protection that automatically scrambles your IP address per session to stop websites from tracking you.

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (>= 3.0.0)
- [Android SDK](https://developer.android.com/studio)
- Java 17

### Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/Bledo-Dev/bledo.git
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
```

The APK will be located at `build/app/outputs/flutter-apk/app-release.apk`.

## Security Notice

This application includes integrity checks. If the application detects a compromised environment (root, debugger, signature mismatch), it may restrict access or wipe local data for security.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Credits

This browser was made by Woopskidds [Youtube](https://youtube.com/@Woopskidd).
