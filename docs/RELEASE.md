# انتشار نسخه (Release Process)

## جریان خودکار

هر تگ `v*` روی ریپو، ورک‌فلوی **Release** را اجرا می‌کند:

1. **Build libbox AAR** — کلون sing-box v1.14.4 + `gomobile bind` (تگ‌های `with_gvisor,with_quic,with_utls`)
2. **Build Android APK** — تحلیل + تست + بیلد APK یونیورسال با امضای release (keystore از secrets)
3. **Build iOS IPA** — بیلد امضانشده (توزیع دستی؛ VPN در iOS نیازمند حساب اپل است)
4. **Create GitHub Release** — پیوست APK + IPA + متن `RELEASE_NOTES.md`

همچنین هر push به `main` ورک‌فلوی **CI** (تحلیل + تست) را اجرا می‌کند.

## چک‌لیست انتشار نسخهٔ جدید

1. شمارهٔ نسخه را در `pubspec.yaml` بالا ببرید — **هر دو بخش**:
   ```yaml
   version: 1.0.1+2   # +N = versionCode؛ باید یک واحد بزرگ‌تر از قبل باشد
   ```
2. `lib/core/config.dart` را همگام کنید:
   - `appVersion` ← نسخهٔ جدید
   - `buildNumber` ← همان +N
3. **گیت به‌روزرسانی اجباری:** در `lib/core/config.dart` مقدار `minRequiredBuild` را روی
   شمارهٔ بیلد *نسخهٔ جدید* بگذارید و این نسخه را منتشر کنید — همهٔ بیلدهای قدیمی‌تر
   پیام «به‌روزرسانی لازم است» می‌بینند و اجازهٔ اتصال ندارند.
   (وقتی Worker مستقر شود، همین مقدار از `/v1/config` سرور کنترل می‌شود.)
4. `RELEASE_NOTES.md` را برای نسخهٔ جدید به‌روز کنید (فارسی).
5. کامیت + تگ + پوش:
   ```bash
   git add -A && git commit -m "release: v1.0.1"
   git tag v1.0.1 && git push origin main --tags
   ```
6. از تب **Actions** پیشرفت را ببینید؛ ریلیز در تب **Releases** ساخته می‌شود.

## امضای اندروید

- Keystore فقط به‌صورت **Actions Secrets** نگهداری می‌شود:
  `KEYSTORE_BASE64` / `KEYSTORE_PASSWORD` / `KEY_ALIAS` / `KEY_PASSWORD`
- **هیچ‌وقت** فایل jks یا key.properties را کامیت نکنید (در `.gitignore` هم هست).
- اگر secrets پاک شود، بیلد با امضای debug ساخته می‌شود (فقط برای تست؛
  آپدیت روی نسخهٔ امضاشده نصب نخواهد شد).

## نکتهٔ به‌روزرسانی

چون APK امضاشده با کلید ثابت منتشر می‌شود، کاربران می‌توانند بدون حذف،
نسخهٔ جدید را نصب کنند (install-over). کافی است versionCode بزرگ‌تر باشد.
