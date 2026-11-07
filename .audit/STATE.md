# دفتر وضعیت ممیزی درفش (audit/full-review)

> تنها حافظهٔ بین چرخه‌ها. هر چرخه در ابتدا این فایل را می‌خواند و در پایان به‌روز می‌کند.
> ⚠️ هیچ «رفع شد» بدون خروجی واقعی ابزار ثبت نکن.

- **چرخهٔ فعلی:** 5 (چرخهٔ بعدی که باید اجرا شود)
- **آخرین به‌روزرسانی:** 2026-11-08 — پایان چرخهٔ ۴ (ماژول‌های ۱۰/۱۱/۱۲؛ B9 و B10 رفع شد؛ ۴۱/۴۱ تست سبز)
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

### شرط توقف (کرون‌جاب حذف شود) — نسخهٔ نهایی به‌دستور کاربر (2026-11-07)
- **تنها شرط توقف:** کار همهٔ فایل‌ها تمام شده باشد — یعنی همهٔ ماژول‌های جدول ✅ شده باشند، همهٔ باگ‌های یافت‌شده رفع یا صریحاً بسته شده باشند، `flutter analyze` و `flutter test` سبز باشند و `FINAL_REPORT.md` نوشته شده باشد. آن‌وقت: با ابزار cron لیست کن و job «derafsh-audit-cycle» را delete کن، commit+push، LOCK حذف، تمام.
- **حذف شد:** شرط «دو چرخهٔ پیاپی بدون باگ» و سقف «۴۰ چرخه» و شرط «۳ چرخهٔ بی‌پیشرفت» — دیگر توقف‌زا نیستند. اگر چرخه‌ای پیشرفت نداشت، ادامه بده و در STATE ثبت کن (D7).

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
| 5 | `lib/data/link_parser.dart` | ✅ چ۲ | C1 (vmess grpc service_name از path جا مانده بود) + C2 (پلاگین obfs ss نادیده گرفته می‌شد) رفع شد؛ پورت عددی int پوشش تست شد |
| 6 | `lib/data/config_builder.dart` | ✅ چ۲ | بی‌باگ — تست ساختاری 1.14 موجود (address/sniff/dns جدید/no block-outbound) + plugin/passthrough بررسی شد |
| 7 | `lib/data/drf_source.dart` | ✅ چ۳ | B7 (effectiveSource روی کاتالوگ خالی StateError می‌داد) رفع شد؛ پارس/قفل/کلمپ پوشش تست شد |
| 8 | `lib/data/remote_config.dart` | ✅ چ۳ | B8 (نشت http.Client در refresh) رفع شد؛ اعتبارسنجی bot_url پوشش تست شد |
| 9 | `lib/core/*` (config/strings/persian/theme) | ✅ چ۳ | بی‌باگ — همه ثابت/تابع خالص؛ appVersion/buildNumber با pubspec (1.0.0+1) هماهنگ |
| 10 | `lib/ui/home_screen.dart` + `widgets/*` | ✅ چ۴ | بی‌باگ — listener در dispose جدا؛ notifyها خارج از build؛ UsageStrip گارد تقسیم بر صفر دارد (شواهد در «تأییدشده بی‌باگ») |
| 11 | `lib/ui/paywall_sheet.dart` | ✅ چ۴ | B9 (جواب بی‌صدای CTA وقتی launchUrl=false) رفع شد |
| 12 | `lib/ui/update_gate.dart` + `advanced_sheet.dart` + `licenses_screen.dart` | ✅ چ۴ | B10 (ردیف گیت در diagnostics فقط ثابت محلی را می‌دید نه serverMinBuild) رفع شد؛ assets/legal موجود و در pubspec اعلام‌شده |
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
| C1 | `link_parser.dart` | متوسط | vmess با `net=grpc` بدون service_name ساخته می‌شد → نودهای grpc به سرورهای با مسیر نامدار وصل نمی‌شدند | قرارداد v2rayNG: نام سرویس grpc در فیلد `path` JSON است اما پارسر serviceName را خالی می‌فرستاد | `serviceName: net=='grpc' ? json['path'] : ''` | `C1: vmess grpc takes service name from path` ✅ |
| C2 | `link_parser.dart` | متوسط | لینک‌های ss با پلاگین obfs-local/v2ray-plugin فیلدهای plugin/plugin_opts را از دست می‌دادند → نود بدون obfs می‌ساخت و وصل نمی‌شد | SIP002 plugin در query بود ولی خوانده نمی‌شد | نگاشت plugin (simple-obfs→obfs-local) + plugin_opts در `_buildSsNode`؛ پلاگین ناشناخته بی‌صدا drop می‌شود (node سالم می‌ماند) | `C2: ss SIP002 plugin...` و `C2: unknown ss plugin...` ✅ |
| B7 | `drf_source.dart` + `vpn_controller.dart` | متوسط (لتنات) | `effectiveSource` روی کاتالوگ خالی (`empty()` = مسیر طراحی‌شدهٔ asset ناخوانا) StateError می‌داد — `firstWhere` و `orElse: () => sources.first` هر دو روی لیست خالی پرتاب می‌کنند؛ API عمومی کنترلر | بدون گارد `sources.isEmpty` | امضای `effectiveSource` → `DrfSource?` (خالی → null) + گارد null در `connect()` با `EngineException('هیچ سورسی موجود نیست.')` | `B7: effectiveSource is null-safe...` ×۳ ✅ |
| B8 | `remote_config.dart` | کم | `http.Client()` inline هرگز close نمی‌شد — همان ریشهٔ B3؛ با timeout سوکت تا GC باز می‌ماند (نشت fd در هر استارتاپ) | client بدون lifecycle | متغیر محلی + `try/finally { client.close(); }` — بسته‌شدن در همهٔ مسیرها (موفق/خطا/non-2xx) | `B8: RuntimeConfig.refresh closes its http client` ×۴ ✅ |
| B9 | `paywall_sheet.dart` | کم | CTA پکیوال وقتی `launchUrl` مقدار false برمی‌گرداند (دستگاه بدون هندلر t.me) کاملاً بی‌صدا رد می‌شد — کاربر لمس می‌کند و هیچ‌چیز نمی‌بیند؛ فقط exception هندل شده بود | برگشت false هندل نشده بود | الگوی `update_gate._onDownload` کپی شد: `!launched → snackbar` + استخراج `_showCtaFallback` + چک `context.mounted` بعد await | `B9: CTA shows feedback...` ×۳ (false/throw/empty-bot-url) ✅ |
| B10 | `advanced_sheet.dart` + `update_gate.dart` | کم (لتنات) | ردیف «وضعیت گیت» در پنل پیشرفته فقط `buildNumber >= minRequiredBuild` محلی را حساب می‌کرد — اگر سرور `applyServerMinBuild` بزند، diagnostics «عبور» نشان می‌داد در حالی که گیت واقعی مسدود است؛ ردیف حداقل بیلد هم مقدار مؤثر را نشان نمی‌داد | recompute محلی به‌جای منبع حقیقت | `gatePass = !MandatoryUpdateGate.isBlocked` + getter عمومی `effectiveMinBuild` (=_serverMinBuild ?? local) و نمایش آن | `B10: advanced diagnostics reflect the real update gate` ✅ |

### باز
| ID | فایل | شرح | تلاش‌ها | دلیل بازماندن |
|---|---|---|---|---|
| (فعلاً هیچ) | — | — | — | — |

### تأییدشده بی‌باگ (شواهد)
- `usage_ledger`: پنجرهٔ رولینگ + merge بچ‌های زیرِ ۶۰ ثانیه درست است؛ تست B1/B2 مسیر persist را می‌پوشانند.
- `node_resolver.resolve`: ترتیب failover و بازپخش EngineException آخر درست (بازبینی کد + تست‌های موجود).
- `lib/core/*` (چ۳): config.dart فقط ثابت (هماهنگ با pubspec 1.0.0+1)؛ strings.dart فقط رشته؛ theme.dart رنگ/gradients + ThemeData؛ persian.dart سه تابع خالص با تست موجود (`faMmSs` کلمپ ۰..۵۹۹ عمدی است). خطای منطقی/نشت/ورودی نامعتبر ندارد.
- `drf_source.parse` (چ۳): fail-closed عمدی — خرابی asset در main.dart با try/catch به `empty()` می‌رود؛ free_source_id غایب → پیش‌فرض 1؛ locked از id≠freeId مشتق می‌شود (تست چ۳ پوشش کرد).
- `RuntimeConfig.refresh` (چ۳): مسیرهای non-2xx / ok!=true / map نبودن / بات خارج از t.me همه بی‌اثر و بی‌پرتاب؛ تست B8 چهار مسیر را پوشش داد.
- **یادداشت باز (بسته‌شده به‌عنوان deferred، نه باگ):** `MandatoryUpdateGate.applyServerMinBuild` هنوز از هیچ مسیر runtime صدا زده نمی‌شود و `RemoteConfig.latestVersionName` مصرف‌کننده ندارد — طبق docstring خود کد این تعمداً PART 3 (Worker) است؛ وصل‌کردنش ویژگی جدید محسوب می‌شود و در دامنهٔ ممیزی نیست. gate فعلاً با fallback محلی min=1 و build=1 باز است (رفتار صحیح v1.0.0).
- `home_screen.dart` (چ۴): `_onChanged` فقط تا dispose زنده است (listener جدا می‌شود)؛ همهٔ `_safeNotify`ها از onTap/Timer/async-continuation می‌آیند نه داخل build؛ `consumeTimeoutFlag` دیالوگ را یک‌بار نشان می‌دهد؛ `hasError` فیلد ساده است → notify مجدد ندارد؛ snackbar خطا فقط در گذر connecting→disconnected (رفتار عمدی).
- `usage_strip.dart` (چ۴): `total.inSeconds <= 0 → fraction=0` (تقسیم بر صفر گارد شده)؛ `clamp(0,1)`؛ `Color.lerp با f∈[0,1]`؛ `faMmSs` کلمپ داخلی دارد.
- `source_card.dart` (چ۴): presentational خالص؛ قفل از `source.locked` مشتق می‌شود؛ بدون state/منبع.
- `update_gate.dart` (چ۴): `_onDownload` هم `!launched` و هم exception را با snackbar هندل می‌کند (چ۴ فقط getter `effectiveMinBuild` اضافه شد — رفتار isBlocked تغییری نکرد).
- `licenses_screen.dart` (چ۴): `loadString` بعد از await با `context.mounted` گارد شده؛ assets/legal/LICENSE.md و OFL.txt موجود و در pubspec (بخش assets) اعلام‌شده‌اند → مسیر fail عملاً نمی‌رسد؛ `_FullTextScreen` presentational.
- `paywall_sheet.dart` (چ۴ پس از B9): هر سه مسیر CTA (خالی/false/exception) بازخورد کاربر دارند؛ `_ValueCell/_StepRow/_MathCard/_DelayedEntrance` presentational خالص.
- **مشاهدات (باگ طبقه‌بندی نمی‌شوند):** `lastErrorMessage` در ۵ نقطه نوشته می‌شود ولی هیچ خواننده‌ای در UI ندارد (نمایش آن تصمیم UX/ویژگی است)؛ snackbar خطای native-drop حین connected (prev==connecting نیست) بی‌صدا است ولی وضعیت UI به «قطع» تغییر می‌کند — هر دو برای PART 3/UX آینده ثبت شد، خارج ۷ دستهٔ باگ.

## تصمیم‌ها (با دلیل)
- **D4:** رفع B2 در خود engine انجام شد (نه UI) — هر مصرف‌کنندهٔ آیندهٔ engine همین رفتار را می‌گیرد؛ کنترلر فقط سیاست را اعمال می‌کند.
- **D5:** برای B6 از `_initLedger` غیرمسدودساز در constructor استفاده شد (نه await در main) — تا startup روی شبکه/دیسک کند متوقف نشود؛ UI با `_safeNotify` بعد از لود به‌روز می‌شود.
- **D6:** `debugTick()` با `@visibleForTesting` به‌جای ابزار mock — بدون وابستگی جدید.
- **D7 (دستور کاربر):** تنها شرط توقف = «تمام‌شدن کار همهٔ فایل‌ها»؛ شرط‌های قبلی (بی‌پیشرفت/سقف چرخه) حذف شدند.
- **D8:** پلاگین ناشناختهٔ ss (مثل shadowtls) drop می‌شود اما نود می‌ماند — sing-box v1.14 فقط obfs-local/v2ray-plugin دارد؛ ساختن نودِ قطعاً خراب بهتر از حذف کامل نیست ولی از شکست کل سورس بهتر است.
- **D1:** قفل کهنه (>۲۵ دقیقه) توسط چرخهٔ بعد شکسته می‌شود — وگرنه یک کرش کل ممیزی را می‌خواباند.
- **D2:** `.audit/STATE.md` و `FINAL_REPORT.md` داخل ریپو کامیت می‌شوند (ردیابی + بقا بین سندباکس‌ها)؛ LOCK فقط محلی و هرگز کامیت نمی‌شود.
- **D3:** تست‌های جدید فقط با `flutter test` — بدون وابستگی جدید مگر اجبار (با ثبت دلیل).
- **D9 (چ۳):** امضای `SourceCatalog.effectiveSource` به `DrfSource?` تغییر کرد (بجای StateError) — خالی یعنی «اتصال ممکن نیست»؛ تک‌مصرف‌کننده در `connect()` بعد از گارد isEmpty با EngineException مدیریت می‌شود؛ تغییر تایپ در کل ریپو فقط همین یک call-site داشت (grep شد).
- **D10 (چ۳):** سیم `RuntimeConfig.clientFactory` با `@visibleForTesting` برای تست‌پذیرکردن close() — الگوی D6؛ بدون وابستگی جدید.
- **D11 (چ۴):** `url_launcher_platform_interface` به‌عنوان **dev dependency** اعلام شد (flutter pub add --dev) — از قبل وابستگی transitive قفل‌شدهٔ url_launcher بود؛ هیچ پکیج جدیدی به درخت اضافه نشد و فقط lint `depend_on_referenced_packages` در تست B9 را برطرف می‌کند (سطح رسمی mock کردن url_launcher).
- **D12 (چ۴):** getter عمومی `MandatoryUpdateGate.effectiveMinBuild` اضافه شد (منبع حقیقت گیت) تا diagnostics بدون دسترسی به فیلد خصوصی `_serverMinBuild` مقدار واقعی را نشان دهد؛ رفتار `isBlocked` از نظر منطقی دست‌نخورده ماند.

## baseline (چرخهٔ ۱ — ثبت‌شده)
- `flutter analyze` (قبل از تغییرات): `No issues found!`
- `flutter test` (قبل از تغییرات): **۲۲/۲۲ پاس**
- `flutter analyze` (پس از رفع‌ها): `No issues found!`
- `flutter test` (پس از رفع‌های چ۱): **۲۷/۲۷ پاس** (۵ تست جدید)
- `flutter analyze` (پس از چ۲): `No issues found!`
- `flutter test` (پس از چ۲): **۳۰/۳۰ پاس** (۳ تست جدید: C1، C2×۲)
- `flutter analyze` (پس از چ۳): `No issues found!` (۱.۲s)
- `flutter test` (پس از چ۳): **۳۷/۳۷ پاس** (۷ تست جدید: B7×۳، B8×۴ — `All tests passed!`)
- `flutter analyze` (پس از چ۴): `No issues found!` (۱.۳s)
- `flutter test` (پس از چ۴): **۴۱/۴۱ پاس** (۴ تست جدید: B9×۳، B10×۱ — `All tests passed!`)

## تلاش‌های ناموفق (bug → تعداد تلاش)
- B10-تست → ۳ تلاش (خودِ رفع B9/B10 از اول سبز بود؛ این‌ها نوسان نوشتن تست بود): ۱) `find.text('1')` دو match داشت (ردیف بیلد و ردیف حداقل‌بیلد) → `findsNWidgets(2)`؛ ۲) تغییر static بدون dirty کردن درخت rebuild نمی‌شود → به‌جای `pump()` از `pumpWidget` مجدد؛ ۳) سبز.
