/// Configuration the host passes to [EpicProvider] to create the EOS platform.
///
/// These come from the Epic Developer Portal (Product Settings → Sandbox →
/// Deployment, and a BackendClient under the product). Only [encryptionKey] is
/// optional — it is required exclusively when using Player Data Storage (cloud
/// save).
///
/// None of these are baked into the package: the host supplies them, exactly
/// like Steam's app id or the Google Play REST `AuthStrategy`. [clientSecret]
/// is "secret" in the keep-it-out-of-source sense — EOS client secrets are
/// embedded in shipping game clients but gate scoped backend permissions, so
/// treat it as a credential and never commit it.
class EpicCredentials {
  const EpicCredentials({
    required this.productId,
    required this.sandboxId,
    required this.deploymentId,
    required this.clientId,
    required this.clientSecret,
    this.encryptionKey,
    this.productName = 'unified_game_services',
    this.productVersion = '1.0.0',
  });

  /// Identifies the product. Not secret (ships in clients).
  final String productId;

  /// Environment (dev/stage/live). Not secret.
  final String sandboxId;

  /// A specific deployment within a sandbox. Not secret.
  final String deploymentId;

  /// BackendClient id created under the product. Not secret.
  final String clientId;

  /// The matching client secret. Keep out of source control.
  final String clientSecret;

  /// 256-bit key as 64 hex chars, for Player Data Storage file encryption.
  /// Required only when advertising/using cloud save.
  final String? encryptionKey;

  /// Product name reported to `EOS_Initialize`.
  final String productName;

  /// Product version reported to `EOS_Initialize`.
  final String productVersion;
}
