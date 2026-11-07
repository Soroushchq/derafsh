# Source Code (GPLv3 compliance notice)

Derafsh («درفش») is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version. See `LICENSE.md`.

## Corresponding source

The complete, corresponding source for every distributed binary of Derafsh
(APK / IPA) lives in this very repository:

    https://github.com/Soroushchq/derafsh

This includes the full Flutter/Dart application, the Kotlin VPN service glue,
the build system (Gradle / Xcode project via `flutter create` scaffolding) and
all assets. There is no proprietary SDK or obfuscated component in the client.

The Android VPN engine is built in CI from the official
[sing-box](https://github.com/SagerNet/sing-box) sources at tag `v1.14.4`
with `gomobile bind` (build tags: `with_gvisor,with_quic,with_utls`) — see
`.github/workflows/release.yml`. No prebuilt binary blob is committed to this
repository.

## Building from source

Requirements: Flutter (stable 3.35.4), JDK 17, Go ≥ 1.25 + gomobile + Android
SDK (for the APK) or Xcode (for iOS).

```bash
# 1) build the libbox engine (Android)
git clone --depth 1 --branch v1.14.4 https://github.com/SagerNet/sing-box
go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init
cd sing-box && gomobile bind -o ../libbox.aar -androidapi 24 -androidx \
  -ldflags='-s -w -buildid=' -tags 'with_gvisor,with_quic,with_utls' \
  ./experimental/libbox
mkdir -p ../android/app/libs && mv ../libbox.aar ../android/app/libs/

# 2) build the app
flutter pub get
flutter analyze
flutter test
flutter build apk --release          # Android
flutter build ios --release --no-codesign   # iOS (unsigned IPA)
```

## Third-party components

| Component | Role | License |
|---|---|---|
| Vazirmatn font | Persian typography | SIL OFL 1.1 (`assets/fonts/OFL.txt`) |
| sing-box / libbox | VPN engine (built from source at v1.14.4) | GPLv3 |
| gomobile (Go mobile) | JNI binding generator | BSD 3-clause |

See the in-app screen «متن‌باز و لایسنس‌ها» for the bundled license texts.
