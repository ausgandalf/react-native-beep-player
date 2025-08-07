# react-native-beep-player

A React Native module for precise, sample-accurate beep sound playback on iOS and Android.

## Installation

### 1. Add Audio File

Place your `beep.wav` file in the appropriate location:

**iOS:**
- Add to Xcode → Build Phases → Copy Bundle Resources

**Android:**
- Place in `android/app/src/main/assets/` folder

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