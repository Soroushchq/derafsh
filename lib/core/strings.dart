/// All user-facing strings. Persian-first, RTL. Single source of truth.
abstract final class S {
  // --- identity ---
  static const String appName = 'درفش';
  static const String tagline = 'وصل‌شدن با یک لمس';

  // --- connection states ---
  static const String statusDisconnected = 'قطع';
  static const String statusConnecting = 'در حال برافراشتن درفش…';
  static const String statusConnectedTo = 'متصل به';
  static const String statusDisconnecting = 'در حال پایین‌کشیدن درفش…';
  static const String btnConnect = 'اتصال';
  static const String btnCancel = 'لغو';
  static const String btnDisconnect = 'قطع اتصال';

  // --- header chips ---
  static const String chipFree = 'رایگان';
  static const String chipPremium = 'پرمیوم';
  static const String chipAdmin = 'ادمین';

  // --- admin gate (long-press on the account chip) ---
  static const String adminPromptTitle = 'ورود ادمین';
  static const String adminFieldHint = 'کد ادمین را وارد کن';
  static const String adminConfirm = 'فعال‌سازی';
  static const String adminCancel = 'انصراف';
  static const String adminOk = 'حالت ادمین فعال شد — همهٔ سورس‌ها باز است';
  static const String adminBad = 'کد ادمین اشتباه است';

  // --- sources ---
  static const String sourcesTitle = 'سورس‌ها';
  static const String connectedSource = 'فعال';

  // --- free usage ---
  static const String usageTitle = 'زمان رایگان امروز';
  static const String usageRemainingSuffix = 'باقی‌مانده';
  static const String unlimited = 'بی‌نهایت';

  // --- upsell line ---
  static const String upgradeLine = 'بی‌نهایت کن — همهٔ سورس‌ها، بدون محدودیت';

  // --- footer ---
  static const String openLicenses = 'متن‌باز و لایسنس‌ها';
  static const String gplShort = 'GPLv3';

  // --- timed-out dialog ---
  static const String timedOutTitle = 'زمان رایگان امروز تمام شد';
  static const String timedOutBody =
      'سهمیهٔ ۳۰ دقیقه‌ایِ امروز به پایان رسید و اتصال قطع شد. '
      'با پرمیوم هیچ‌وقت وسط کار قطع نمی‌شوی.';
  static const String timedOutOk = 'متوجه شدم';
  static const String timedOutPremium = 'می‌خواهم پرمیوم بشوم';

  // --- paywall ---
  static const String paywallTitle = 'درفش پرمیوم';
  static const String paywallHeadline = 'همهٔ سورس‌ها. بی‌نهایت زمان. بدون قطع‌شدن.';
  static const String paywallMathFree = '۳۰ دقیقه در روز ≈ ۱۵ ساعت در ماه';
  static const String paywallMathPremium = 'پرمیوم ≈ ۷۲۰ ساعت در ماه';
  static const String paywallPunch =
      '۴۸ برابر بیشتر؛ به‌بهای کمتر از یک نوشیدنی در هفته.';
  static const String paywallCompareTitle = 'رایگان در برابر پرمیوم';
  static const String paywallStepTitle = 'فعال‌سازی زیر یک دقیقه';
  static const String paywallStep1 = 'پرداخت با کارت بانکی';
  static const String paywallStep2 = 'ارسال رسید به بات تلگرام';
  static const String paywallStep3 = 'دریافت کد از بات';
  static const String paywallStep4 = 'وارد کردن کد در اپ';
  static const String paywallBindNote =
      'کد فقط روی یک دستگاه فعال می‌شود — مخصوص دستگاه شما.';
  static const String paywallCta = 'دریافت کد فعال‌سازی';
  static const String paywallCtaSoon =
      'اتصال به بات تلگرام در نسخهٔ بعدی فعال می‌شود.';
  static const String colFree = 'رایگان';
  static const String colPremium = 'پرمیوم';

  // comparison rows: [feature, freeValue, premiumValue]
  static const List<(String, String, String)> paywallRows = [
    ('سورس‌های فعال', '۱ سورس', 'همهٔ سورس‌ها'),
    ('محدودیت زمان', '۳۰ دقیقه در روز', 'بی‌نهایت'),
    ('قطع‌شدن وسط کار', 'بله', 'هرگز'),
    ('اولویت سرور', 'ندارد', 'دارد'),
    ('تبلیغ و لاگ', 'هیچ', 'هیچ'),
  ];

  // --- licenses ---
  static const String licensesTitle = 'متن‌باز و لایسنس‌ها';
  static const String licensesAppTitle = 'درفش';
  static const String licensesAppDesc =
      'این اپ نرم‌افزاری آزاد است؛ تحت اجازه‌نامهٔ GPLv3. '
      'سورس کامل همین باینری در ریپوی زیر موجود است.';
  static const String licensesFontTitle = 'وزیرمتن (Vazirmatn)';
  static const String licensesFontDesc = 'قلم فارسی — اجازه‌نامهٔ SIL OFL 1.1';
  static const String licensesEngineTitle = 'sing-box / libbox';
  static const String licensesEngineDesc =
      'موتور اتصال — GPLv3. از زحمات سازندگان sing-box سپاسگزاریم.';
  static const String licensesView = 'دیدن متن کامل';
  static const String licensesClose = 'بستن';

  // --- advanced ---
  static const String advancedTitle = 'بخش پیشرفته';
  static const String advancedRowVersion = 'نسخه';
  static const String advancedRowBuild = 'شمارهٔ بیلد';
  static const String advancedRowEngine = 'موتور اتصال';
  static const String advancedRowMinBuild = 'حداقل نسخهٔ مجاز (سرور)';
  static const String advancedRowGate = 'وضعیت گیت به‌روزرسانی';
  static const String advancedRowDevice = 'شناسهٔ دستگاه';
  static const String advancedDevicePlaceholder = '— (در نسخهٔ بعدی)';
  static const String advancedGatePass = 'عبور';
  static const String advancedGateBlock = 'مسدود — به‌روزرسانی لازم است';
  static const String advancedEngineStub = 'استاب نمایشی (تست)';
  static const String advancedFooter = 'این بخش برای اشکال‌زدایی است.';

  // --- update gate ---
  static const String updateTitle = 'به‌روزرسانی لازم است';
  static const String updateBody =
      'این نسخهٔ درفش قدیمی است و دیگر اجازهٔ اتصال ندارد. '
      'برای ادامه، نسخهٔ جدید را نصب کن.';
  static const String updateBtn = 'دریافت نسخهٔ جدید';
  static const String updateSoon = 'لینک دانلود در نسخهٔ بعدی فعال می‌شود.';

  // --- intro ---
  static const String introSkip = 'برای رد شدن لمس کن';

  // --- misc ---
  static const String errorConnect =
      'اتصال برقرار نشد. چند لحظه بعد دوباره امتحان کن.';
  static const String of = 'از';
  static const String active = 'فعال';

  // --- engine ---
  static const String engineUnsupported =
      'اتصال در این نسخه فقط روی اندروید فعال است؛ نسخهٔ iOS پس از امضای '
      'توسعه‌دهندهٔ اپل فعال می‌شود.';
  static const String sourcesEmpty = 'سورسی موجود نیست';
  static const String sourcesCount = 'سورس';
  static const String engineRowSingbox = 'sing-box (libbox) — GPLv3';
  static const String defaultSourceName = 'سورس فعال';
}
