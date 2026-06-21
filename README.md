# Standby Dock for Android 📱⏱️🎵

A premium, interactive, 60 FPS Android screensaver application inspired by iOS Standby. Designed for active desk chargers, it provides high-end clock faces, notification-synced media playback widgets, checklists, focus utilities, and smooth micro-drift screen saver animations (OLED burn-in prevention).

---

## Why Standby Dock? (Motivation) 💡

- **Less Distraction**: Modern phones constantly bombard you with notifications, ads, and feeds. Standby Dock turns your idle phone into an elegant, ambient dashboard—keeping you updated without dragging you into digital clutter.
- **No Good Free Alternatives**: While iOS has Standby mode built-in, the Android ecosystem lacks a high-quality, fluid, and free equivalent that isn't filled with intrusive ads, analytics trackers, or paid subscription walls.
- **Fully Open Source**: Standby Dock is completely open source. It respects your privacy, requires no user accounts, utilizes local Android MediaSession APIs for music management, and is open for anyone to contribute to, inspect, or build upon.

---

## Key Features 🚀

- **60 FPS Butter-Smooth Fluidity**: Native `AnimationController` loops lock to device hardware refresh rates (60Hz, 90Hz, 120Hz). Sweep seconds hands and ticker modules update at precise `16ms` intervals for maximum motion clarity.
- **Micro-Drift Burn-In Protection**: Subtle pixel offsets (micro-drifts) recalculate automatically every 60 seconds to protect high-end OLED screens during overnight desk placement.
- **Notification-Synced Media Panel**: Connects directly to the native Android MediaSession pipeline. Shows real-time song title, artist name, and album artwork crossfades (fully tested with Spotify, YouTube Music, and YouTube). Includes an adaptive soundwave visualizer and transport control touch indicators.
- **Premium Glassmorphic Layouts**: Semi-transparent backing elements with dynamic drop shadows tinted dynamically to match your active accent color.
- **Ambient Aura Glow**: Background visuals blend smoothly using real-time colors extracted directly from active media artwork.

---

## Interactive Widgets & Modes 🛠️

Customize the screensaver layout directly from the settings drawer:
1. **Clock Face Options**: Minimalist digital readout, Bold Tech display, Retro Flip Cards, or a clean Sweep Analog Face.
2. **Right Panel Utilities**:
   - **Media Player**: Notification-integrated transport controls with smooth artwork crossfades.
   - **Stopwatch**: Millisecond-precision lap tracker with responsive LayoutBuilder controls (automatically hides lap history on shorter screens).
   - **Timer**: Bounded scroll countdown with quick presets (+3m, +15m, +25m) and custom minute increments. Features full-screen breathing edge alarm glow triggers.
   - **Calendar**: Minimalist monthly grid view highlighting the current day in your custom accent color.
   - **To-Do List**: Checklist card saved locally via `SharedPreferences`.
   - **Pomodoro Focus**: 25-minute study / 5-minute break circular progress tracker.
   - **World Clock**: Current time readouts with dynamic offset calculations for major global capitals.
   - **Sticky Note**: Quick, text auto-saving dashboard scratchpad.
   - **Zen Breathing**: Visual, coach-directed inhale/hold/exhale pulsing guides.
3. **Screen Layout Configurations**: Split View, Swapped split, Clock-only, or Media-only.
4. **Accent Themes**: Instantly swappable accent color schemes.
5. **Backdrop Ambient Glow**: Toggle background artwork color aura glows on/off.
6. **Wakelock Controller**: Toggle screen awake persistence settings via WakelockPlus.

---

## How to Set Up & Run ⚙️

### Quick Download (No Coding Required) 📦
If you just want to run the application on your device without setting up a development environment, grab the pre-compiled, optimized production package directly from the **[Releases Page](https://github.com/Probal-Khanra/standbydock/releases)** and install the APK on your phone.

### Build From Source Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured on your system.
- Android Studio or command-line Android SDK tools.
- A physical Android device or emulator running API 26 (Android 8.0) or higher.

### Step 1: Clone and Get Dependencies
```bash
# Clone the repository
git clone [https://github.com/Probal-Khanra/standbydock.git](https://github.com/Probal-Khanra/standbydock.git)

# Navigate into the project folder
cd standbydock

# Fetch dependencies
flutter pub get
