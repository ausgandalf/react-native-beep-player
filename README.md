# react-native-beep-player

A React Native module for precise, sample-accurate beep sound playback on iOS and Android.

## Installation

### 1. Add Audio File

Place your `beep.wav` file in the appropriate location:

#### iOS:
- Add to Xcode → Build Phases → Copy Bundle Resources

#### Android:
- Place in `android/app/src/main/assets/` folder

#### Expo Integration

Two approaches are available for using this module with Expo:

##### Option 1 — Bare Workflow or Prebuild

If you're willing to run:

```bash
npx expo prebuild
```

and have the native code available, you can:

Place `beep.wav` in:

- iOS: ios/<ProjectName>/Resources/

- Android: android/app/src/main/assets/

Pass just "beep.wav" from JS.

Native module will load it from the bundle.

##### Option 2 — Use Expo Asset to resolve the path

If you want to keep assets in `assets/audio/clip_47.wav` and still call the native module from JS, you can:

```javascript
import { Asset } from 'expo-asset';
import BeepPlayer from 'react-native-beep-player';

async function startBeep() {
  const asset = Asset.fromModule(require('../assets/audio/clip_47.wav'));
  await asset.downloadAsync(); // ensure local file exists
  BeepPlayer.start(120, asset.localUri.replace('file://', ''));
}
```
`asset.localUri` will give you the absolute file path.

- On iOS, it’s in the app’s cache directory.

- On Android, same — native can read it directly.

### 2. Install Module

Install and link the module (manual linking required for React Native < 0.60):

```bash
npm install react-native-beep-player
cd ios && pod install && cd ..
```

## Usage

Import the module in your React Native app:

```javascript
import BeepPlayer from 'react-native-beep-player';
```

### Start Beep Loop

Start a beep loop at a specific BPM:

```javascript
// Start beep loop at 120 BPM
BeepPlayer.start(120, 'beep.wav');
```
### Mute/Unmute

Toggle mute state while keeping the beep loop running:

```javascript
// Stop beep loop
BeepPlayer.mute(true);
BeepPlayer.mute(false);
```

### Stop Beep Loop

Stop the currently playing beep loop:

```javascript
// Stop beep loop
BeepPlayer.stop();
```

## API Reference

### Methods

- `BeepPlayer.start(bpm, filename)` - Start beep loop at specified BPM with audio file
- `BeepPlayer.stop()` - Stop the currently playing beep loop

### Parameters

- `bpm` (number) - Beats per minute for the loop
- `filename` (string) - Name of the audio file (e.g., 'beep.wav')