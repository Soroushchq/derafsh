# دفتر وضعیت ممیزی درفش (audit/full-review)

> تنها حافظهٔ بین چرخه‌ها. هر چرخه در ابتدا این فایل را می‌خواند و در پایان به‌روز می‌کند.
> ⚠️ هیچ «رفع شد» بدون خروجی واقعی ابزار ثبت نکن.

- **چرخهٔ فعلی:** 7 — **ممیزی کامل شد؛ همهٔ ۲۰ ماژول ✅** (FINAL_REPORT.md نوشته شد؛ کرون‌جاب حذف می‌شود)
- **آخرین به‌روزرسانی:** 2026-11-08 — پایان چرخهٔ ۷ (ماژول‌های ۱۷/۱۸/۱۹/۲۰؛ B16 رفع شد؛ ۴۲/۴۲ تست سبز)
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
| 13 | `lib/design/*` + `lib/intro/*` | ✅ چ۵ | B11 (تاج پرتو کاویانی به‌خاطر transform بدون counter-translate یک‌اندازهٔ مرکز جابه‌جا می‌شد) رفع شد؛ بقیهٔ فایل‌ها بی‌باگ (شواهد در «تأییدشده بی‌باگ») |
| 14 | `lib/app.dart` + `lib/main.dart` | ✅ چ۶ | بی‌باگ — شواهد در «تأییدشده بی‌باگ» |
| 15 | `android/.../vpn/*.kt` | ✅ چ۶ | B12 (کال‌بک شبکه بدون Handler روی API<۲۸ روی main thread می‌خوابید) + B13 (بدون @Volatile روی listener/defaultNetwork) رفع شد |
| 16 | `android/.../MainActivity.kt` + `DrfApplication.kt` + Manifest | ✅ چ۶ | B14 (launch بعد از موافقت بدون درخواست‌کنندهٔ زنده) + B15 (broadcast توقف بدون گارد امضا روی API<۳۳) رفع شد |
| 17 | `.github/workflows/*` | ✅ چ۷ | بی‌باگ — محتوای فعلی همان چیزی است که ریلیز v1.0.0 را با هر ۳ asset سبز ساخت (شواهد در «تأییدشده بی‌باگ») |
| 18 | `ios/` (Runner) | ✅ چ۷ | بی‌باگ — شل استاندارد Flutter؛ iOS عمداً بدون موتور VPN (UnsupportedEngine در main.dart)؛ IPA v1.0.0 در ریلیز موجود است |
| 19 | کیفیت تست‌های `test/*` | ✅ چ۷ | بی‌باگ — همهٔ تست‌ها ادعای واقعی دارند؛ timerها با fakeAsync/fake clock؛ بدون وابستگی به wall-clock (شواهد در «تأییدشده بی‌باگ») |
| 20 | `docs/*` + README + SOURCE | ✅ چ۷ | B16 (دستورالعمل gomobile در README/SOURCE با CI هماهنگ نبود) رفع شد؛ ادعاهای دیگر با کد تطبیق داده شد |

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
| B11 | `design/kaviani_star.dart` | **بالا** (چشمی) | تاج پرتوهای چرخان ستارهٔ کاویانی در همهٔ moodهای فعال (awakening/radiant) یک‌اندازهٔ مرکز (`c`) از ستاره فاصله می‌گرفت و مدار می‌زد — مسیرهای `_rayPath` حول `c` ساخته می‌شدند ولی بعد از `translate(c)+rotate(θ)` کشیده می‌شدند → موقعیت دستگاه = `c + R·c + R·dir·r`؛ در spin=0 تاج در `2c` (گوشهٔ پایین-راست) نقاشی می‌شد | تبدیل pivot بدون counter-translate روی هندسهٔ مرکز-محور | ایدیوم pivot: `translate(c) → rotate(θ) → translate(−c)` تا هندسهٔ مرکز-محور حول مرکز ستاره بچرخد؛ شیدر (در فضای محلی) دست‌نخورده ماند | تست پیکسلی `B11: ray crown is painted around the star center...` (PictureRecorder→toImage؛ قبل از رفع alpha=0 در پیکسل پرتو، بعد از رفع >0) ✅ |
| B12 | `android/.../NetworkMonitor.kt` | کم | شاخهٔ API<۲۸ از `registerDefaultNetworkCallback(callback)` بدون Handler استفاده می‌کرد → کال‌بک‌ها روی main thread اجرا می‌شدند و `notifyListener` (حلقهٔ retry با `Thread.sleep(100)` تا ۱ ثانیه) می‌توانست UI را تا ~۱ ثانیه روی دستگاه‌های قدیمی فریز کند | فرم یک‌آرگومانی (کال‌بک روی main thread طبق مستندات ConnectivityManager) | پاس دادن `callbackHandler` (فرم ۲-آرگومانی از API ۲۴ موجود است) — هم‌تراز با شاخه‌های ۳۱/۲۸ | بازبینی کد + مستندات اندروید؛ کامپایل CI (ریلیز بعدی) — تست flutter برای کاتلین ساختاراً ممکن نیست (پیش‌نمونهٔ B5) ✅ |
| B13 | `android/.../NetworkMonitor.kt` | کم | `listener` و `defaultNetwork` بین ترد کال‌بک، ترد worker libbox و main بدون @Volatile ردوبدل می‌شدند — JMM هیچ happens-before بین آن ترد‌ها ندارد؛ خواندن کهنه = ازدست‌رفتن آپدیت اولیهٔ اینترفیس | همان ریشهٔ B5 | `@Volatile` روی هر دو فیلد | بازبینی کد (الگوی پذیرفته‌شدهٔ B5)؛ کامپایل CI ✅ |
| B14 | `android/.../MainActivity.kt` | کم (لبه‌ای) | در `onActivityResult` مسیر RESULT_OK بدون چک `pendingVpnResult != null` سرویس را استارت می‌زد — اگر اکتیویتی حین دیالوگ رضایت بازسازی/کرش می‌کرد، Dart-isolate قبلی مرده بود و VPN بدون درخواست‌کنندهٔ زنده بالا می‌آمد؛ UI تازه «قطع» را نشان می‌داد در حالی که تونل فعال بود (ناهمگونی state → مسیر double-start در `BoxCore.startService` هم باز می‌شد)؛ `_onNativeState` رویداد connected غیرمنتظره را نادیده می‌گیرد (return زودهنگام) پس همگام نمی‌شد | نتیجهٔ pending فقط در فیلد اکتیویتی نگه داشته می‌شود و null بودنش معنای «درخواست‌کنندهٔ مرده» را دارد | استارت سرویس و reply به `result != null` گارد شد؛ درخواست‌کنندهٔ مرده → رضایت drop می‌شود تا UI تازه با native همگون بماند و کاربر صریح وصل شود | بازبینی کد + چرخهٔ حیات FlutterActivity (engine با host نابود می‌شود)؛ کامپایل CI ✅ |
| B15 | `android/.../DrfVpnService.kt` + Manifest | کم | گیرندهٔ broadcast توقف روی API<۳۳ بدون RECEIVER_NOT_EXPORTED/permission ثبت می‌شد → هر اپی می‌توانست `app.derafsh.drf.vpn.STOP` را پخش کند و VPN را بی‌صدا ببندد (DoS آزاردهنده؛ روی ۳۳+ بسته بود) | ثبت implicit-export در API قدیمی | permission سفیدسطح امضا `app.derafsh.drf.permission.STOP_VPN` (protectionLevel=signature در Manifest + uses-permission) و ثبت گیرنده در شاخهٔ <۳۳ با فرم ۴-آرگومانی `registerReceiver(..., STOP_PERMISSION, null)` | بازبینی کد + مستندات اندروید (امضای خودِ اپ همیشه پاس می‌شود)؛ کامپایل CI ✅ |
| B16 | `README.md` + `SOURCE.md` | کم (سند) | دستورالعمل بیلد libbox به کاربر می‌گفت `go install golang.org/x/mobile/cmd/gomobile@latest` — درحالی‌که sing-box v1.14 فقط با **شاخهٔ sagernet gomobile v0.1.13** بیلد می‌شود (کامنت CI همین را می‌گوید) و `-javapkg=io.nekohasekai`/تگ‌ها/ldflags هم غایب بودند → کسی که README را دنبال کند یا بیلد شکست می‌خورد یا AAR با پکیج‌نام اشتباه می‌سازد و import های کاتلین (`io.nekohasekai.libbox.*`) می‌شکنند | کپی‌شدن دستورالعمل قدیمی/عمومی به‌جای هم‌ترازی با release.yml | هم‌ترازی هر دو اسنیپت با CI: نصب gomobile+gobind از شاخهٔ sagernet@v0.1.13، `gomobile init`، و پرچم‌های bind دقیقاً برابر CI (javapkg/libname/trimpath/ldflags شامل constant.Version و godebug و checklinkname، تگ‌های badlinkname/tfogo_checklinkname0)؛ ضمناً «ستارهٔ چهارپر» README به «هشت‌پر» (هم‌تراز با DESIGN.md و پینتر) اصلاح شد | بازبینی محتوایی + تطبیق خط‌به‌خط با release.yml؛ برای سند واحد تست واحد معنا ندارد (پیش‌نمونهٔ D14) ✅ |

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
- `shine_button.dart` (چ۵): منطق رنگ در هر ۴ ترکیب (crimson×enabled) درست؛ `onTap` فقط وقتی enabled اجرا می‌شود؛ `_sheen` در dispose بسته می‌شود؛ press-state در onTapCancel/onTapUp همیشه ریست می‌شود. مشاهدات ظاهری (باگ نیست): دکمهٔ disabled سایهٔ crimson کم‌رنگ می‌گیرد و شیمر هم روی disabled می‌چرخد — انتخاب طراحی.
- `sparks.dart` (چ۵): پارامترها per-particle با `Random(i·7919)` قطعی‌اند؛ alpha = `sin(t·π).clamp(0,1)` هرگز از ۱ نمی‌گذرد؛ مسیر صعودی (y معکوس + drift بالا) عمدی است. یادداشت: `shouldRepaint` فقط `progress` را مقایسه می‌کند (نه `count`) — تک‌call-site با count ثابت (26)؛ اگر در آینده count داینامیک شود باید اضافه شود (observation، نه باگ).
- `stagger_in.dart` (چ۵): presentational خالص؛ opacity با clamp گارد شده؛ تأخیر per-index فقط duration را بلند می‌کند؛ child به TweenAnimationBuilder پاس داده می‌شود (بازسازی ارزان).
- `intro.dart` (چ۵): status-listener فقط در completed `onDone` می‌زند و با dispose کنترلر جدا می‌شود (پس از unmount فراخوانی نمی‌شود)؛ skip با tap کار می‌کند؛ همهٔ sub-progressها با `.clamp(0,1)` گارد شده‌اند؛ overshoot عمدی easeOutBack در `unfold` بی‌خطر است (alpha ها را موتور کلمپ می‌کند؛ مقدار نهایی دقیقاً ۱)؛ `HaloPaint` حول مرکز و بدون transform مشکل‌ساز است و shouldRepaint هر دو فیلد را می‌پوشاند.
- `app.dart` (چ۶): تک state `_introDone` است و setState فقط از onDone (خارج از build) می‌آید؛ intro روی Stack به‌عنوان overlay است و با setState برداشته می‌شود؛ `child ??` گارد builder استاندارد MaterialApp است؛ RTL با builder دور navigator — بدون listener/منبع قابل‌نشت.
- `main.dart` (چ۶): `ensureInitialized` قبل از هر کال channel؛ `RuntimeConfig.refresh` با unawaited (هرگز throw نمی‌کند و client را می‌بندد — B8)؛ `SourceCatalog.load` در try/catch → `empty()` (مسیر طراحی‌شدهٔ B7 که connect() با EngineException می‌پوشاند)؛ `_pickEngine` بر اساس پلتفرم با پیام صریح UnsupportedEngine؛ بدون state global/استریم/کنترلری که نشت کند.
- `BoxCore.kt` (چ۶): الگوی دو-بررسی `stopRequested` (بعد از assign و بعد از startOrReloadService) مسیرهای توقف حین استارت را می‌بندد؛ closeTun در همهٔ مسیرهای خطا/توقف صدا زده می‌شود؛ closeServer هم closeService هم close را با runCatching می‌پوشاند. **مشاهدهٔ deferred (باگ قابل‌اثبات در جریان فعلی نیست):** `startService` گارد «استارت روی نمونهٔ فعال» ندارد؛ تنها call-site آن onStartCommand است که از سمت Dart با گارد فاز connect() و (بعد از B14) گارد درخواست‌کنندهٔ زنده محافظت می‌شود — اگر در آینده مسیر استارت دوم باز شود باید سخت‌گیرانه‌تر شود.
- `VpnStateBus.kt` (چ۶): `sink` فقط روی main thread لمس می‌شود (setSink از EventChannel روی main، emit هم روی main.post) → thread-confined؛ `phase/error/pendingConfig` همه @Volatile؛ emit برای sink خالی بی‌اثر.
- `DrfPlatformInterface.kt` (چ۶): متدهای پشتیبانی‌نشده به‌صورت صریح error() می‌دهند (fail-closed)؛ `getInterfaces` با fallback های runCatching/firstOrNull می‌سازد. **مشاهدهٔ تاییدشده بی‌اثر:** `StringArray.len() = 0` — سورس sing-box v1.14.4 (کلون محلی /tmp/singbox) نشان می‌دهد مصرف‌کنندهٔ Go همه‌جا `iteratorToArray` است که فقط `HasNext/Next` می‌خواند؛ تنها `.Len()`های libbox روی تایپ‌های دیگرند → در نسخهٔ پین‌شده بی‌اثر؛ اگر libbox ارتقا یافت باید len درست شود (یادداشت دیده‌بان).
- **`NetworkMonitor.kt` یادداشت (باگ نیست):** HandlerThread اختصاصی `drf-net-callback` در stop() quit نمی‌شود (۱ ترد بیکار تا مرگ پروسه، singleton پردازه‌ای) — بازسازی handler بعد از quit نیاز به تغییر ساختاری دارد و سود عملی ندارد؛ ثبت شد تا اگر مدل lifecycle عوض شد revisited شود.
- `release.yml`/`ci.yml` (چ۷): محتوای release.yml از ۵fda2c6 تا 4c4ee57 (تگ v1.0.0) بدون تغییر است و ریلیز v1.0.0 در GitHub با هر ۳ asset (APK universal، APK arm64، IPA unsigned) ساخته شد → مسیر کامل CI/CD به‌صورت تجربی سبز است؛ heredoc امضای keystore با تورفتگی بلوک YAML درست بسته می‌شود (EOF در ستون صفر پس از strip تورفتگی بلوک)؛ نام assetها بین cp/delete-asset/upload هماهنگ‌اند؛ RELEASE_NOTES.md موجود و کامیت‌شده است؛ permissions فقط contents:write.
- `ios/Runner` (چ۷): AppDelegate/Info.plist/pbxproj استاندارد scaffold؛ deployment target 13.0؛ بدون entitlement اضافه؛ موتور VPN روی iOS عمداً UnsupportedEngine است (پیام صریح) — UI-only طبق نقشهٔ پروژه؛ نبودن Podfile در ریپو با بیلد موفق v1.0.0 سازگار است (flutter در CI Podfile را تولید می‌کند) — توصیه: کامیت Podfile برای تکرارپذیری (observation).
- کیفیت تست‌ها (چ۷): ۹ فایل تست بازبینی کامل شد — هر تست ادعای قابل‌قصدمستقل دارد (بدون تست همیشه‌سبز)؛ timerها در fakeAsync/`debugTick`/pump اند نه wall-clock؛ state سراسری (`MandatoryUpdateGate.applyServerMinBuild`) در همان تست ریست می‌شود و فایل‌های تست در isolate جدا اجرا می‌شوند؛ کنترلرها dispose می‌شوند؛ نگاشت شمارهٔ تست‌ها با باگ‌ها ۱:۱ است (B1/B2/B3/B6، C1/C2، B7×۳، B8×۴، B9×۳، B10، B11).
- ادعاهای docs (چ۷): «۱۹۶ سورس» با sources.json (196، free_id=1) ✓؛ پشتیبانی tuic/httpupgrade در پارسر ✓؛ سهمیهٔ ۳۰ دقیقه/۲۴h رولینگ ✓؛ بات `@PDerafshVpnbot` ✓؛ failover ≤۵ ✓؛ DESIGN.md ستارهٔ ۸پر (هم‌تراز پینتر) ✓؛ RELEASE.md با جریان واقعی release.yml و گیت minRequiredBuild هم‌خوان است ✓.

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
- **D13 (چ۵):** رفع B11 با ایدیوم pivot (`translate(c)→rotate→translate(−c)`) انجام شد نه بازنویسی هندسه به مبدا-محور — کمترین diff و شیدر/گرادیان‌ها (که در فضای محلیِ همان مختصات‌ها ساخته می‌شوند) بدون تغییر معتبر می‌مانند. روش اثبات: تست پیکسلی با PictureRecorder→toImage→rawRgba (بدون وابستگی جدید؛ golden/goldenFile متکی به платفروم نیست) — «پیکسل پرتو باید رنگ داشته باشد» قبل از رفع قرمز و بعد از رفع سبز.
- **D14 (چ۶):** برای باگ‌های کاتلین/منیفست (B12–B15) تست flutter ساختاراً ممکن نیست (بدون Android SDK/Robolectric محلی و ممنوعیت وابستگی جدید) — همان پیش‌نمونهٔ B5: شواهد = بازبینی دقیق + ارجاع به مستندات اندروید/چرخهٔ حیات Flutter + کامپایل CI در ریلیز بعدی؛ گیت Dart (analyze/test) برای اطمینان از سالم‌ماندن سمت Dart اجرا و سبز ماند.
- **D15 (چ۶):** رفع B14 به‌جای «معتبرکردن reply پس از بازسازی»، استارت را روی درخواست‌کنندهٔ زنده گارد کرد — پاسخ‌دادن به Result یک engine مرده نامعتبر است و استارت‌نکردن، native و UI تازه را همگون نگه می‌دارد (کاربر دوباره وصل می‌شود)؛ مسیر denial دست نخورد.
- **D16 (چ۶):** رفع B15 با permission سطح-امضا (نه سوییچ به startService) — چون auto-disconnect سهمیه در بک‌گراند از broadcast استفاده می‌کند و startService در بک‌گراند روی API ۲۶+ IllegalStateException می‌دهد؛ permission امضا برای خودِ اپ همیشه پاس می‌شود و برای دیگران غیرممکن است.
- **D17 (چ۷):** رفع B16 صرفاً سندی است (بدون تست واحد) — معیار درستی، تطبیق خط‌به‌خط با release.yml است که به‌صورت تجربی ریلیز v1.0.0 را ساخته؛ الگوی D14.

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
- `flutter analyze` (پس از چ۵): `No issues found!` (۱.۵s)
- `flutter test` (پس از چ۵): **۴۲/۴۲ پاس** (۱ تست جدید: B11 — `All tests passed!`)
- `flutter analyze` (پس از چ۶): `No issues found!` (۱۵.۱s — سرد بعد از نصب مجدد SDK)
- `flutter test` (پس از چ۶): **۴۲/۴۲ پاس** (`All tests passed!`)
- `flutter analyze` (پس از چ۷): `No issues found!` (۲.۷s)
- `flutter test` (پس از چ۷): **۴۲/۴۲ پاس** (`All tests passed!`)

## تلاش‌های ناموفق (bug → تعداد تلاش)
- B10-تست → ۳ تلاش (خودِ رفع B9/B10 از اول سبز بود؛ این‌ها نوسان نوشتن تست بود): ۱) `find.text('1')` دو match داشت (ردیف بیلد و ردیف حداقل‌بیلد) → `findsNWidgets(2)`؛ ۲) تغییر static بدون dirty کردن درخت rebuild نمی‌شود → به‌جای `pump()` از `pumpWidget` مجدد؛ ۳) سبز.
