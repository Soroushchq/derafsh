# Source Code (GPLv3 compliance notice)

Derafsh («درفش») is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version. See `LICENSE.md`.

## Corresponding source

The complete, corresponding source for every distributed binary of Derafsh
(APK / IPA) lives in this very repository:

    https://github.com/derafsh/derafsh

This includes the full build system (Gradle / Xcode project via `flutter create`
scaffolding) and all assets. There is no proprietary SDK or obfuscated component
in the client.

## Building from source

Requirements: Flutter (stable ≥ 3.35), JDK 17, Android SDK (for the APK) or
Xcode (for iOS).

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release          # Android
flutter build ios --release --no-codesign   # iOS (unsigned IPA)
```

## Third-party components

| Component | Role | License |
|---|---|---|
| Vazirmatn font | Persian typography | SIL OFL 1.1 (`assets/legal/OFL.txt`) |
| sing-box / libbox | VPN engine (planned, PART 2) | GPLv3 |

See the in-app screen «متن‌باز و لایسنس‌ها» for the bundled license texts.
