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
  static const String appVersion = '1.0.2';

  /// Monotonic build number. Keep in sync with pubspec `version` (+N).
  static const int buildNumber = 3;

  /// TODO(worker): minimum build allowed to connect; served by /v1/sources.
  /// A local fallback so the gate logic is testable before the Worker exists.
  static const int minRequiredBuild = 1;

  /// Free tier: disconnect after this much connected time per rolling day.
  /// TODO(worker): authoritative value comes from /v1/config.
  static const Duration freeDailyLimit = Duration(minutes: 30);

  /// Demo price shown in the paywall. TODO(worker): served by the Worker
  /// (PRICE secret) in PART 4; never a secret, but configurable remotely.
  static const String priceLabel = '۱۲۹٬۰۰۰ تومان';

  /// Telegram bot deep link (payment/activation). Overridable by the remote
  /// config endpoint at startup.
  static const String telegramBotUrl = 'https://t.me/PDerafshVpnbot';

  /// SHA-256 of the owner-only admin code. The code itself is never stored
  /// in the repository — entering it (long-press on the account chip)
  /// unlocks every source and removes the free quota (admin mode).
  static const String adminCodeSha256 =
      '0a62aa214638e09e0bf0d3d609d4972bc2e6c99073a9570e2368b5f3c70a952e';

  /// Optional remote config endpoint (owner-operated, Cloudflare Worker).
  /// Best-effort at startup: may override bot_url and report the latest
  /// version. Failure is never fatal — the bundled catalog keeps working.
  static const String remoteConfigUrl = 'https://imsoroush.top/v1/config';

  /// Github repository (GPLv3 source offer).
  static const String sourceUrl = 'https://github.com/Soroushchq/derafsh';

  /// Releases page used by the mandatory-update gate.
  static const String updateUrl = 'https://github.com/Soroushchq/derafsh/releases';
}
