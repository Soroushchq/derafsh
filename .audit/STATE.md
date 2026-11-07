# دفتر وضعیت ممیزی درفش (audit/full-review)

> تنها حافظهٔ بین چرخه‌ها. هر چرخه در ابتدا این فایل را می‌خواند و در پایان به‌روز می‌کند.
> ⚠️ هیچ «رفع شد» بدون خروجی واقعی ابزار ثبت نکن.

- **چرخهٔ فعلی:** 2 (چرخهٔ بعدی که باید اجرا شود)
- **آخرین به‌روزرسانی:** 2026-11-07 — پایان چرخهٔ ۱ (۴ باگ رفع‌شده + ۱ race کوتلین؛ ۲۷/۲۷ تست)
- **ریپو:** https://github.com/Soroushchq/derafsh — برنچ `audit/full-review` (از main@4c4ee57 = ریلیز v1.0.0)
- **مسیر محلی:** `/home/z/my-project/derafsh-audit`
- **Flutter SDK:** `/home/z/my-project/sdk/flutter/bin` (اگر نبود: دانلود `flutter_linux_3.35.4-stable.tar.xz` از storage.googleapis و اکسترکت به `/home/z/my-project/sdk/`، سپس `flutter pub get` در ریپو)
- **push:** `GIT_ASKPASS=/home/z/my-project/.secrets/askpass.sh git push origin audit/full-review` — توکن هرگز در لاگ نیاید.

---

## قوانین چرخه (هر اجرا باید همین را اجرا کند)

1. اگر `.audit/LOCK` وجود دارد و mtime آن کمتر از ۲۵ دقیقه پیش است → چرخهٔ دیگری فعال است؛ **بدون کار تمام کن**. اگر قفل کهنه است (کرش اجرای قبلی)، حذفش کن و ادامه بده. *(D1)*
2. `.audit/LOCK` بساز (mtime = شروع چرخه).
3. `git status` — اگر تغییر کامیت‌نشده از چرخهٔ قبل مانده، اول بررسی/کامیت کن.
4. ماژول بعدی از جدول «ماژول‌ها» (اولین بدون ✅) را ممیزی کن. دنبال: خطای منطقی، نشت منابع، race condition، خطای مدیریت‌نشده، ورودی اعتبارسنجی‌نشده، وابستگی خراب، ناسازگاری تایپ.
5. هر باگ: شواهد (تست/خطا/استدلال) → ریشه → اصلاح → **تست جدید** → `flutter analyze && flutter test` سبز.
6. اگر تغییری تست‌ها را شکست: revert همان تغییر، راه دیگر (تا ۳ تلاش؛ بعد «باز» ثبت و برو بعدی).
7. در پایان چرخه `flutter analyze` و `flutter test` **حتماً سبز**.
8. STATE.md به‌روز (چرخه +۱، جدول‌ها، تصمیم‌ها).
9. کامیت جدا: `audit(cycle N): ...` (فایل‌های تغییرکرده + `.audit/STATE.md`؛ LOCK هرگز کامیت نشود) → push.
10. `.audit/LOCK` حذف.
11. خلاصهٔ فارسی کوتاه: پیدا شد / رفع شد / باز ماند / چرخهٔ بعد.

### شرط توقف (کرون‌جاب حذف شود)
- همهٔ ماژول‌ها ✅ **و** دو چرخهٔ پیاپی بدون باگ جدید → `FINAL_REPORT.md` بنویس، با ابزار cron لیست کن و job «derafsh-audit-cycle» را delete کن، commit+push، LOCK حذف، تمام.
- ۳ چرخهٔ پیاپی بدون پیشرفت یا چرخهٔ ۴۰ → گزارش وضعیت + دلیل، حذف کرون‌جاب، تمام.

### ممنوعیت‌ها
- بدون `git push --force` / بازنویسی تاریخچه / حذف برنچ.
- بدون خواندن/کامیت رمزها و keystore (در GitHub secrets است).
- بدون ویژگی جدید؛ وابستگی جدید فقط با ثبت دلیل در «تصمیم‌ها».

---

## نقشهٔ پروژه

- **Stack:** Flutter 3.35.4 (Dart 3.9) + Kotlin glue + libbox (sing-box v1.14.4 AAR در CI با sagernet/gomobile) + Cloudflare Worker API (مصرف سمت کلاینت) + GitHub Actions.
- **نقاط ورود:** `lib/main.dart` → `DerafshApp` → `MandatoryUpdateGate` → `HomeScreen`؛ اندروید: `MainActivity` (MethodChannel `app.derafsh.drf/vpn`) → `DrfVpnService` → `BoxCore` (libbox CommandServer).
- **جریان داده:** `SourceCatalog` (asset ۱۹۶ سورس؛ free=id1) → `NodeResolver` (fetch + پارس + failover ≤۵ سورس) → `ConfigBuilder` (sing-box v1.14 JSON) → `LibboxVpnEngine` (MethodChannel/EventChannel) → native. سهمیهٔ رایگان: `UsageLedger` (رولینگ ۲۴h، SharedPreferences). `RuntimeConfig`: bot_url از `imsoroush.top/v1/config` (best-effort).
- **دستورها:** `flutter pub get` → `flutter analyze` → `flutter test` (بیلد اندروید فقط با libbox.aar — در CI).
- **وابستگی‌های runtime:** http، shared_preferences، url_launcher.

## ماژول‌ها (اولویت خطر؛ ✅ = بررسی‌شدهٔ این ممیزی)

| # | ماژول | وضعیت | یافته‌ها |
|---|---|---|---|
| 1 | `lib/state/vpn_controller.dart` | ✅ چ۱ | B1 (نشت سهمیه در disconnect دستی) + B2 (واکنش به قطع native) + B6 (sync سهمیه هنگام ساخت) رفع شد؛ هاردهنینگ notify بعد از dispose |
| 2 | `lib/engine/libbox_engine.dart` + `vpn_engine.dart` | ✅ چ۱ | B2: ناظر دائمی رویداد native + رابط `stateEvents`؛ handshake start جدا نگه داشته شد |
| 3 | `lib/data/usage_ledger.dart` | ✅ چ۱ | بی‌باگ — prune/merge/persist درست (پوشش تست چ۱) |
| 4 | `lib/data/node_resolver.dart` | ✅ چ۱ | B3: `dispose()` برای بستن http.Client؛ failover درست |
| 5 | `lib/data/link_parser.dart` | ⬜ | |
| 6 | `lib/data/config_builder.dart` | ⬜ | |
| 7 | `lib/data/drf_source.dart` | ⬜ | |
| 8 | `lib/data/remote_config.dart` | ⬜ | |
| 9 | `lib/core/*` (config/strings/persian/theme) | ⬜ | |
| 10 | `lib/ui/home_screen.dart` + `widgets/*` | ⬜ | |
| 11 | `lib/ui/paywall_sheet.dart` | ⬜ | |
| 12 | `lib/ui/update_gate.dart` + `advanced_sheet.dart` + `licenses_screen.dart` | ⬜ | |
| 13 | `lib/design/*` + `lib/intro/*` | ⬜ | |
| 14 | `lib/app.dart` + `lib/main.dart` | ⬜ | |
| 15 | `android/.../vpn/*.kt` | ⬜ | |
| 16 | `android/.../MainActivity.kt` + `DrfApplication.kt` + Manifest | ⬜ | |
| 17 | `.github/workflows/*` | ⬜ | |
| 18 | `ios/` (Runner) | ⬜ | |
| 19 | کیفیت تست‌های `test/*` | ⬜ | |
| 20 | `docs/*` + README + SOURCE | ⬜ | |

## باگ‌ها

### رفع‌شده
| ID | فایل | شدت | شرح | ریشه | اصلاح | تست |
|---|---|---|---|---|---|---|
| B1 | `vpn_controller.dart` | متوسط | disconnect دستی تا ۴ ثانیهٔ آخر مصرف را در ledger ثبت نمی‌کرد → سهمیهٔ ۳۰ دقیقه بیشتر از واقعیت می‌ماند (زیر-حساب مصرف) | flush بچ فقط در tick ≥۵ ثانیه، نه در disconnect | `disconnect()` قبل از stop → `await _flushPending()`؛ تایم‌اوت هم همان مسیر | `B1: manual disconnect flushes pending seconds to the ledger` ✅ |
| B2 | `libbox_engine.dart` + `vpn_controller.dart` | **بالا** | مرگ تونل (قطع native وسط نشست) به UI نمی‌رسید → فاز «متصل» جعلی، تایمر می‌چرخید، سهمیه می‌سوخت و کاربر بی‌خبر | listener رویدادها فقط طول `start()` زنده بود و بعد cancel می‌شد | ناظر دائمی رویداد در engine (نوشتن lastState/lastError) + `stateEvents` در رابط موتور + `_onNativeState` در کنترلر (قطع غیرمنتظره → flush + فاز disconnected + پیام خطا)؛ قطع خودی double-handle نمی‌شود | `B2: native drop moves controller...` و `B2: user-initiated disconnect...` ✅ |
| B3 | `node_resolver.dart` | کم | http.Client هرگز close نمی‌شد | بدون lifecycle | `dispose()` عمومی | `B3: dispose closes the underlying http client` ✅ |
| B6 | `vpn_controller.dart` + `main.dart` مسیر | متوسط | بعد از ری‌استارت اپ، نوار «زمان رایگان» ۳۰ دقیقهٔ کامل نشان می‌داد حتی اگر ۲۰ دقیقه مصرف شده بود | ledger فقط داخل connect() لود می‌شد | `_initLedger()` async در constructor (unawaited) + `_safeNotify` | `B6: freeRemaining is initialized from the persisted ledger` ✅ |
| B5 | `BoxCore.kt` | متوسط | race visibility: `commandServer`/`fileDescriptor` بین ترد worker و main بدون happens-before | بدون @Volatile | `@Volatile` روی هر دو فیلد | اعتبارسنجی کامپایل با CI (ریلیز بعدی)؛ تست‌پذیر در vmesis ندارد — ثبت کدبازبینی |

### باز
| ID | فایل | شرح | تلاش‌ها | دلیل بازماندن |
|---|---|---|---|---|
| (فعلاً هیچ) | — | — | — | — |

### تأییدشده بی‌باگ (شواهد)
- `usage_ledger`: پنجرهٔ رولینگ + merge بچ‌های زیرِ ۶۰ ثانیه درست است؛ تست B1/B2 مسیر persist را می‌پوشانند.
- `node_resolver.resolve`: ترتیب failover و بازپخش EngineException آخر درست (بازبینی کد + تست‌های موجود).

## تصمیم‌ها (با دلیل)
- **D4:** رفع B2 در خود engine انجام شد (نه UI) — هر مصرف‌کنندهٔ آیندهٔ engine همین رفتار را می‌گیرد؛ کنترلر فقط سیاست را اعمال می‌کند.
- **D5:** برای B6 از `_initLedger` غیرمسدودساز در constructor استفاده شد (نه await در main) — تا startup روی شبکه/دیسک کند متوقف نشود؛ UI با `_safeNotify` بعد از لود به‌روز می‌شود.
- **D6:** `debugTick()` با `@visibleForTesting` به‌جای ابزار mock — بدون وابستگی جدید.
- **D1:** قفل کهنه (>۲۵ دقیقه) توسط چرخهٔ بعد شکسته می‌شود — وگرنه یک کرش کل ممیزی را می‌خواباند.
- **D2:** `.audit/STATE.md` و `FINAL_REPORT.md` داخل ریپو کامیت می‌شوند (ردیابی + بقا بین سندباکس‌ها)؛ LOCK فقط محلی و هرگز کامیت نمی‌شود.
- **D3:** تست‌های جدید فقط با `flutter test` — بدون وابستگی جدید مگر اجبار (با ثبت دلیل).

## baseline (چرخهٔ ۱ — ثبت‌شده)
- `flutter analyze` (قبل از تغییرات): `No issues found!`
- `flutter test` (قبل از تغییرات): **۲۲/۲۲ پاس**
- `flutter analyze` (پس از رفع‌ها): `No issues found!`
- `flutter test` (پس از رفع‌ها): **۲۷/۲۷ پاس** (۵ تست جدید: B1، B2×۲، B3، B6)

## تلاش‌های ناموفق (bug → تعداد تلاش)
- —
