# درفش (Derafsh)

> یک اتصال. یک دکمه. درفش برافراشته.

درفش یک کلاینت VPN فارسی‌اول برای اندروید و iOS است — تجربه‌ی «یک دکمه اتصال» بدون تنظیمات و بدون import اشتراک. نام و هویت بصری آن از **درفش کاویانی**، درفش شاهی ایران باستان، گرفته شده است (پژوهش و توکن‌های طراحی: [`docs/DESIGN.md`](docs/DESIGN.md)).

## وضعیت — v1.0.0 (اولین ریلیز عمومی)

- ✅ هویت بصری کاویانی (رنگ، فرم، تایپوگرافی وزیرمتن) + انیمیشن‌های ستارهٔ چهارپر و جرقه‌های سندان
- ✅ **موتور واقعی sing-box v1.14.4 (libbox)** روی اندروید — TUN، auto-route، DoH از مسیر تونل
- ✅ **۱۹۶ سورس** (درافش ۱ تا درافش ۱۹۶) با انتخاب خودکار بهترین کانفیگ (اولویت Reality/Vision)
- ✅ پشتیبانی از vmess / vless / trojan / shadowsocks / hysteria2 / tuic + ترنسپورت‌های ws/grpc/h2/httpupgrade
- ✅ طرح رایگان: درافش ۱ + ۳۰ دقیقه در پنجرهٔ ۲۴ ساعتهٔ رولینگ (ذخیرهٔ محلی)
- ✅ لیست سورس‌ها با قفل پرمیوم + پی‌وال متقاعدکننده
- ✅ گیت به‌روزرسانی اجباری (`MandatoryUpdateGate` — با اتصال Worker از سرور کنترل می‌شود)
- ✅ بخش پیشرفتهٔ مخفی (۵ بار لمس شمارهٔ نسخه) + صفحهٔ «متن‌باز و لایسنس‌ها»
- ⬜ PART 3: Worker (Cloudflare) + فعال‌سازی کد تک‌دستگاهی
- ⬜ PART 4: بات تلگرام + پرداخت

## معماری

```
Flutter (Dart, RTL, Vazirmatn)
  └── MethodChannel / EventChannel  app.derafsh.drf(/vpn|/vpn/events)
        └── Kotlin: DrfVpnService (VpnService + specialUse FGS)
              └── BoxCore → libbox CommandServer (sing-box v1.14.4, gomobile AAR)
```

- کاتالوگ سورس‌ها: `assets/data/sources.json` (۱۹۶ سورس؛ `free_source_id: 1`)
- پارسر لینک‌ها و سازندهٔ کانفیگ sing-box: `lib/data/`
- موتور: `lib/engine/` (اندروید واقعی؛ iOS فعلاً فقط UI — نیازمند امضا)
- گلو کد بومی: `android/app/src/main/kotlin/app/derafsh/drf/`

## بیلد محلی

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release                 # اندروید (به libbox.aar نیاز دارد)
flutter build ios --release --no-codesign   # iOS (IPA امضانشده — توزیع دستی)
```

برای بیلد اندروید باید `libbox.aar` را در `android/app/libs/` بگذارید:

```bash
git clone --depth 1 --branch v1.14.4 https://github.com/SagerNet/sing-box
go install golang.org/x/mobile/cmd/gomobile@latest && gomobile init
cd sing-box && gomobile bind -o ../libbox.aar -androidapi 24 -androidx \
  -ldflags='-s -w -buildid=' -tags 'with_gvisor,with_quic,with_utls' \
  ./experimental/libbox
```

**بیلدهای رسمی با GitHub Actions** ساخته می‌شوند (تگ `v*` → ریلیز با APK + IPA؛ امضای release با secrets ریپو).

## لایسنس

GPLv3 — متن کامل در [`LICENSE.md`](LICENSE.md) (+ بند اضافی §7 برای حفاظت برند). افشای سورس: [`SOURCE.md`](SOURCE.md). قلم وزیرمتن: SIL OFL 1.1. موتور sing-box: GPLv3.
