/// Central configuration for the Derafsh app.
///
/// NOTE: values that will later be served by the Cloudflare Worker (PART 3)
/// are marked with `TODO(worker)`. Nothing secret and no subscription URL
/// may ever live in this file or the repository.
class Config {
  Config._();

  /// Application id / package name (must stay in sync with android/ios builds).
  static const String applicationId = 'app.derafsh.drf';

  /// Display version shown in the UI. Keep in sync with pubspec `version`.
  static const String appVersion = '1.0.0';

  /// Monotonic build number. Keep in sync with pubspec `version` (+N).
  static const int buildNumber = 1;

  /// TODO(worker): minimum build allowed to connect; served by /v1/sources.
  /// A local fallback so the gate logic is testable before the Worker exists.
  static const int minRequiredBuild = 1;

  /// Free tier: disconnect after this much connected time per rolling day.
  /// TODO(worker): authoritative value comes from /v1/config.
  static const Duration freeDailyLimit = Duration(minutes: 30);

  /// Demo price shown in the paywall. TODO(worker): served by the Worker
  /// (PRICE secret) in PART 4; never a secret, but configurable remotely.
  static const String priceLabel = '۱۲۹٬۰۰۰ تومان';

  /// Telegram bot deep link. Intentionally empty until the bot exists
  /// (PART 4). The paywall hides its CTA when this is empty.
  static const String telegramBotUrl = '';

  /// Github repository (GPLv3 source offer).
  static const String sourceUrl = 'https://github.com/derafsh/derafsh';
}
