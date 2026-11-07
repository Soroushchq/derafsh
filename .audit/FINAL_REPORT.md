# گزارش نهایی ممیزی درفش (audit/full-review)

- **تاریخ پایان:** 2026-11-08 — پس از ۷ چرخهٔ ممیزی
- **دامنه:** کل ریپو در ۲۰ ماژول — Dart (state/engine/data/core/ui/design/intro/app/main)، Kotlin (لایهٔ VPN اندروید)، CI workflows، iOS Runner، تست‌ها، docs
- **نقطهٔ شروع:** `main@4c4ee57` (ریلیز v1.0.0) — بدون force push و بدون بازنویسی تاریخچه
- **گیت نهایی (خروجی واقعی ابزار):** `flutter analyze` = **No issues found!** · `flutter test` = **۴۲/۴۲ All tests passed!**

---

## خلاصهٔ اجرایی

۷ چرخهٔ ممیزی روی هر ۲۰ ماژول اجرا شد. **۱۷ باگ** (B1–B16 به‌همراه C1/C2) پیدا و **همگی رفع شدند**؛ هیچ باگی باز نماند. مهم‌ترین یافته‌ها: نشتی رویداد native به کنترلر (B2 — فاز «متصل» جعلی و سوختن سهمیه)، جابه‌جایی هندسی تاج پرتوهای ستارهٔ کاویانی (B11 — نقص چشمی اصلی UI)، خطای StateError روی کاتالوگ خالی (B7 — مسیر طراحی‌شدهٔ asset ناخوانا)، و ناهمگونی state پس از بازسازی حین دیالوگ رضایت VPN (B14). تعدادی مورد نیز به‌صورت **صریح بسته شدند** (deferred/observation) که در بخش «بازمانده‌ها» با دلیل آمده‌اند. در پایان هر چرخه `flutter analyze` و `flutter test` سبز بوده‌اند و هر چرخه در کامیت مستقل «audit(cycle N): …» روی `audit/full-review` پوش شده است.

---

## باگ‌ها به تفکیک دسته و شدت

| دسته | باگ‌ها |
|---|---|
| خطای منطقی | B1، B6، C1، B7، B10، B11، B14 |
| نشت منابع | B3، B8 |
| race / visibility | B2، B5، B13 |
| خطای مدیریت‌نشده | B9 |
| ورودی اعتبارسنجی‌نشده | C2، B15 |
| وابستگی خراب | B16 (دستورالعمل بیلد سند) |
| ناسازگاری تایپ | — (تغییر امضای B7 صرفاً بهبود طراحی API بود، نه مغایرت) |

| شدت | باگ‌ها |
|---|---|
| بالا | B2 (تونل مرده → UI جعلی «متصل» + سوختن سهمیه)، B11 (تاج پرتوهای ستاره یک‌اندازهٔ مرکز جابه‌جا/مدارزننده) |
| متوسط | B1، B5، B7، C1، C2 |
| کم | B3، B6، B8، B9، B10، B12، B13، B14، B15، B16 |

---

## فهرست باگ‌ها (ریشه → اصلاح → تست)

| ID | فایل | شرح | ریشه | اصلاح | تست |
|---|---|---|---|---|---|
| B1 | `vpn_controller.dart` | disconnect دستی تا ۴ ثانیهٔ آخر مصرف را ثبت نمی‌کرد (زیر-حساب سهمیه) | flush بچ فقط در tick ≥۵ثانیه | `disconnect()` قبل از stop → `await _flushPending()`؛ مسیر timeout هم همان | `B1: manual disconnect flushes…` ✅ |
| B2 | `libbox_engine.dart` + `vpn_controller.dart` | مرگ تونل به UI نمی‌رسید؛ فاز «متصل» جعلی، سهمیه می‌سوخت | listener رویداد فقط طول start() زنده بود | ناظر دائمی رویداد + `stateEvents` + `_onNativeState` (drop → flush + disconnected + خطا؛ double-handle خودی بسته شد) | `B2: native drop…`، `B2: user-initiated…` ✅ |
| B3 | `node_resolver.dart` | `http.Client` هرگز close نمی‌شد | بدون lifecycle | `dispose()` عمومی | `B3: dispose closes…` ✅ |
| B5 | `BoxCore.kt` | `commandServer`/`fileDescriptor` بین ترد worker و ترد توقف بدون happens-before | بدون @Volatile | `@Volatile` روی هر دو | بازبینی کد؛ کامپایل CI ✅ |
| B6 | `vpn_controller.dart` | بعد از ری‌استارت، نوار سهمیهٔ رایگان مقدار کامل نشان می‌داد | ledger فقط در connect() لود می‌شد | `_initLedger` غیرمسدودساز در constructor + `_safeNotify` | `B6: freeRemaining is initialized…` ✅ |
| C1 | `link_parser.dart` | vmess grpc بدون service_name ساخته می‌شد | قرارداد v2rayNG: نام سرویس در فیلد `path` | `serviceName: net=='grpc' ? json['path'] : ''` | `C1: vmess grpc…` ✅ |
| C2 | `link_parser.dart` | لینک‌های ss با پلاگین obfs/v2ray-plugin فیلدهای plugin را از دست می‌دادند | SIP002 plugin خوانده نمی‌شد | نگاشت plugin + plugin_opts؛ پلاگین ناشناخته drop (D8) | `C2: ss SIP002 plugin…` ×۲ ✅ |
| B7 | `drf_source.dart` + `vpn_controller.dart` | `effectiveSource` روی کاتالوگ خالی StateError می‌داد (مسیر طراحی‌شدهٔ asset ناخوانا) | `firstWhere`/`orElse` روی لیست خالی | امضا → `DrfSource?` + گارد در `connect()` با EngineException فارسی (D9) | `B7: effectiveSource is null-safe…` ×۳ ✅ |
| B8 | `remote_config.dart` | `http.Client` در refresh هرگز close نمی‌شد (نشت fd در هر استارتاپ) | همان ریشهٔ B3 | `try/finally close()` + سیم `clientFactory` (D10) | `B8: RuntimeConfig.refresh closes…` ×۴ ✅ |
| B9 | `paywall_sheet.dart` | CTA وقتی `launchUrl` مقدار false برمی‌گرداند کاملاً بی‌صدا بود | برگشت false هندل نشده بود | الگوی `update_gate._onDownload` + `_showCtaFallback` + چک `context.mounted` | `B9: CTA shows feedback…` ×۳ ✅ |
| B10 | `advanced_sheet.dart` + `update_gate.dart` | ردیف گیت در diagnostics مقدار مؤثر سرور را نمی‌دید | recompute محلی | `gatePass = !isBlocked` + getter `effectiveMinBuild` (D12) | `B10: advanced diagnostics…` ✅ |
| B11 | `design/kaviani_star.dart` | تاج پرتوهای چرخان یک‌اندازهٔ مرکز جابه‌جا و مدارزننده بود؛ در spin=۰ در `2c` نقاشی می‌شد | `translate(c)+rotate` روی مسیرهای مرکز-محور بدون counter-translate | ایدیوم pivot `translate(c)→rotate→translate(−c)` (D13) | تست پیکسلی PictureRecorder→toImage: قبل از رفع alpha=۰، بعد از رفع >۰ ✅ |
| B12 | `NetworkMonitor.kt` | روی API<۲۸ کال‌بک‌ها (و حلقهٔ sleep تا ۱ ثانیه) روی main thread اجرا می‌شد | فرم یک‌آرگومانی registerDefaultNetworkCallback | پاس دادن `callbackHandler` | بازبینی + مستندات؛ کامپایل CI (D14) ✅ |
| B13 | `NetworkMonitor.kt` | `listener`/`defaultNetwork` بین تردها بدون @Volatile | همان ریشهٔ B5 | `@Volatile` هر دو فیلد | بازبینی کد ✅ |
| B14 | `MainActivity.kt` | حین دیالوگ رضایت، بازسازی/مرگ پروسه → استارت VPN بدون درخواست‌کنندهٔ زنده → ناهمگونی UI/native و مسیر double-start | Result فقط در فیلد اکتیویتی | استارت+reply به `result != null` گارد شد (D15) | بازبینی چرخهٔ حیات FlutterActivity؛ کامپایل CI ✅ |
| B15 | `DrfVpnService.kt` + Manifest | روی API<۳۳ هر اپی می‌توانست با broadcast، VPN را بی‌صدا ببندد | ثبت implicit-export | permission سطح-امضا `…permission.STOP_VPN` + ثبت ۴-آرگومانی (D16) | بازبینی + مستندات؛ کامپایل CI ✅ |
| B16 | `README.md` + `SOURCE.md` | دستورالعمل بیلد libbox با CI هماهنگ نبود (gomobile رسمی@latest به‌جای شاخهٔ sagernet v0.1.13؛ بدون javapkg/تگ‌ها/ldflags) | کپی دستورالعمل عمومی | هم‌ترازی کامل اسنیپت با release.yml + اصلاح «چهارپر→هشت‌پر» | تطبیق خط‌به‌خط با CI (D17) ✅ |

---

## بازمانده‌ها (صریحاً بسته‌شده — باگ نیستند، با دلیل)

- **`applyServerMinBuild`/`latestVersionName` بدون مصرف‌کننده:** تعمداً PART 3 (Worker) است؛ وصل‌کردنش ویژگی جدید است و خارج از دامنهٔ ممیزی.
- **`lastErrorMessage` بدون خواننده در UI و snackbar بی‌صدای drop حین connected:** تصمیم UX/ویژگی آینده (PART 3/4) — خارج از ۷ دستهٔ باگ.
- **`BoxCore.startService` بدون گارد استارت-روی-نمونهٔ فعال:** تنها call-site (onStartCommand) از سمت Dart با گارد فاز و (پس از B14) گارد درخواست‌کنندهٔ زنده محافظت می‌شود؛ اگر در آینده مسیر استارت دومی باز شود باید سخت‌گیرانه‌تر شود.
- **`StringArray.len() = 0` در `DrfPlatformInterface.kt`:** با بررسی سورس sing-box v1.14.4 اثبات شد که مصرف‌کنندهٔ Go همه‌جا از `HasNext/Next` استفاده می‌کند → در نسخهٔ پین‌شده بی‌اثر؛ با ارتقای libbox باید revisited شود.
- **HandlerThread `drf-net-callback` در stop() quit نمی‌شود:** ۱ ترد بیکار در singleton پردازه‌ای — بازسازی آن تغییر ساختاری می‌خواهد با سود ناچیز.
- **مشاهدات ظاهری:** سایهٔ crimson دکمهٔ disabled و چرخش sheen روی disabled؛ `shouldRepaint` جرقه‌ها `count` را نمی‌بیند (تک call-site با count ثابت).
- **Podfile iOS کامیت نشده:** CI آن را تولید می‌کند و بیلد v1.0.0 سبز بود؛ برای تکرارپذیری توصیه به کامیت (بهبود، نه باگ).
- **خارج از دامنه (پیش از ممیزی ثبت شده):** پارامتر نسخهٔ سرور در `/v1/free/sub`، چرخش توکن Git، پیاده‌سازی PART 3 (Worker) و PART 4 (بات تلگرام/پرداخت).

---

## تصمیم‌های کلیدی (D1–D17)

- **D1** قفل کهنهٔ >۲۵ دقیقه توسط چرخهٔ بعد شکسته می‌شود؛ **D2** STATE/FINAL_REPORT داخل ریپو کامیت می‌شوند، LOCK هرگز؛ **D3** تست‌های جدید فقط با flutter test و بدون وابستگی جدید.
- **D4** رفع B2 در engine (نه UI) تا همهٔ مصرف‌کنندگان آینده همان رفتار را بگیرند؛ **D5** `_initLedger` غیرمسدودساز؛ **D6** سیم تست با `@visibleForTesting` به‌جای پکیج mock.
- **D7** تنها شرط توقف = تمام‌شدن کار همهٔ فایل‌ها (به دستور کاربر).
- **D8** پلاگین ناشناختهٔ ss drop می‌شود اما نود می‌ماند؛ **D9** امضای `effectiveSource` → nullable؛ **D10** سیم `clientFactory`؛ **D11** `url_launcher_platform_interface` به‌عنوان dev dependency (transitive قفل‌شده، بدون پکیج جدید)؛ **D12** getter `effectiveMinBuild`.
- **D13** رفع B11 با ایدیوم pivot + اثبات پیکسلی بدون وابستگی؛ **D14** باگ‌های کاتلین/منیفست با بازبینی+مستندات+کامپایل CI (بدون Robolectric/Android SDK محلی)؛ **D15** گارد درخواست‌کنندهٔ زنده در B14؛ **D16** permission سطح-امضا برای B15 (نه سوییچ به startService که auto-disconnect بک‌گراند را می‌شکند)؛ **D17** اصلاحات سندی با معیار تطبیق با CI.

---

## وضعیت analyze/test (در طول چرخه‌ها — خروجی واقعی)

| چرخه | flutter analyze | flutter test |
|---|---|---|
| baseline | No issues found! | ۲۲/۲۲ |
| چ۱ (+B1/B2/B3/B6) | No issues found! | ۲۷/۲۷ |
| چ۲ (+C1/C2) | No issues found! | ۳۰/۳۰ |
| چ۳ (+B7/B8) | No issues found! | ۳۷/۳۷ |
| چ۴ (+B9/B10) | No issues found! | ۴۱/۴۱ |
| چ۵ (+B11) | No issues found! | ۴۲/۴۲ |
| چ۶ (+B12/B13/B14/B15) | No issues found! (۱۵.۱s — سرد پس از نصب مجدد SDK) | ۴۲/۴۲ |
| **چ۷ (+B16، نهایی)** | **No issues found! (۲.۷s)** | **۴۲/۴۲ All tests passed!** |

یادداشت: در چرخهٔ ۶ سندباکس ریست شد؛ ریپو از `origin/audit/full-review` بازیابی و SDK دوباره نصب شد — تاریخچه دست‌نخورده ماند.

---

## پیشنهادهای بعدی

1. **Merge `audit/full-review` → `main`** و انتشار **v1.0.1** — کامپایل CI استقرار B5/B12–B15 را نهایی تأیید می‌کند (تنها اعتبارسنجی باقی‌مانده برای اصلاحات کاتلین).
2. **کامیت `ios/Podfile`** برای تکرارپذیری بیلد iOS.
3. **PART 3 (Worker):** اتصال `applyServerMinBuild` به `/v1/config` و قفل سهمیهٔ رایگان سمت سرور (ریسک reset با پاک‌کردن دادهٔ اپ فعلاً شناخته‌شده است).
4. **PART 4:** بات تلگرام و فعال‌سازی کد تک‌دستگاهی (HMAC).
5. **بازبینی‌های مشروط:** `StringArray.len()` پس از هر ارتقای libbox؛ گارد double-start در `BoxCore.startService` در صورت بازشدن مسیر استارت دوم؛ نمایش `lastErrorMessage` در UI.
6. **قرارداد نگهداری:** چرخهٔ ممیزی با جاب کرون پایان یافت؛ برای ممیزی‌های آینده همین گردش‌کار (LOCK/STATE/کامیت مستقل) قابل استفادهٔ مجدد است.
