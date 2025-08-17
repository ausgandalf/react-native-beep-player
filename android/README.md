# Android Setup for React Native Beep Player

This directory contains the Android-specific implementation of the React Native Beep Player module.

## Prerequisites

- Android Studio (latest version recommended)
- Android SDK (API level 21 or higher)
- Android NDK (version 23.1.7779620 or compatible)
- Java Development Kit (JDK) 11 or 17
- React Native development environment

## Setup Instructions

### 1. Configure Android SDK Path

Copy the `local.properties.template` file to `local.properties` and update the SDK path:

```bash
cp local.properties.template local.properties
```

Edit `local.properties` and set your Android SDK path:
- **Windows**: `sdk.dir=C\:\\Users\\YourUsername\\AppData\\Local\\Android\\Sdk`
- **macOS**: `sdk.dir=/Users/YourUsername/Library/Android/sdk`
- **Linux**: `sdk.dir=/home/YourUsername/Android/Sdk`

### 2. Build the Module

From the project root directory:

```bash
# Clean previous builds
cd android
./gradlew clean

# Build the module
./gradlew assembleDebug

# Or build release version
./gradlew assembleRelease
```

### 3. Integration with Main App

The module is automatically linked via `react-native.config.js`. Make sure your main app's `MainApplication.java` includes:

```java
import com.beepplayer.BeepPlayerPackage;

@Override
protected List<ReactPackage> getPackages() {
    List<ReactPackage> packages = new PackageList(this).getPackages();
    packages.add(new BeepPlayerPackage());
    return packages;
}
```

## Troubleshooting

### Common Build Errors

1. **SDK not found**: Update `local.properties` with correct SDK path
2. **Gradle sync failed**: Check internet connection and try `./gradlew --refresh-dependencies`
3. **Kotlin version mismatch**: Update `build.gradle` with compatible Kotlin version
4. **Permission denied**: Make sure `gradlew` is executable (`chmod +x gradlew` on Unix systems)

### Build Commands

```bash
# Clean build
./gradlew clean

# Build debug version
./gradlew assembleDebug

# Build release version
./gradlew assembleRelease

# Run tests
./gradlew test

# Check dependencies
./gradlew dependencies
```

### File Structure

```
android/
├── build.gradle              # Root build configuration
├── app/
│   ├── build.gradle         # Module build configuration
│   └── proguard-rules.pro   # ProGuard rules
├── gradle/
│   └── wrapper/
│       └── gradle-wrapper.properties
├── gradlew                  # Unix gradle wrapper
├── gradlew.bat             # Windows gradle wrapper
├── gradle.properties       # Gradle properties
├── settings.gradle         # Project settings
└── src/
    └── main/
        ├── AndroidManifest.xml
        └── java/
            └── com/
                └── beepplayer/
                    ├── BeepPlayerModule.kt
                    └── BeepPlayerPackage.kt
```

## Dependencies

The module depends on:
- React Native Android
- AndroidX libraries
- Kotlin standard library

All dependencies are automatically managed by the build configuration.
