/// Epic Developer Portal settings the host passes to `EpicProvider` to create
/// the EOS platform.
///
/// The values come from the Epic Developer Portal: the product, its sandbox and
/// deployment, and a client created under the product. Only [encryptionKey] is
/// optional, and only cloud save needs it (see [encryptionKey]).
///
/// The package bundles none of these values; the host supplies them.
/// [clientSecret] ships inside game clients but gates scoped backend
/// permissions, so keep it out of source control.
class EpicCredentials {
  /// Creates credentials from Epic Developer Portal values.
  ///
  /// [productName] and [productVersion] only identify the application to
  /// `EOS_Initialize`; the defaults are placeholders.
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

  /// The product id. Not secret (ships in clients).
  final String productId;

  /// The sandbox id (dev, stage or live environment). Not secret.
  final String sandboxId;

  /// The deployment id within the sandbox. Not secret.
  final String deploymentId;

  /// The id of the client created under the product. Not secret.
  final String clientId;

  /// The secret matching [clientId]. Keep it out of source control.
  final String clientSecret;

  /// The 256-bit Player Data Storage encryption key, as 64 hex characters.
  ///
  /// Required for `EpicProvider.saveData` and `EpicProvider.loadData`, which
  /// throw a `PlatformOperationException` when it is `null` or empty. Other
  /// operations do not need it.
  final String? encryptionKey;

  /// The product name reported to `EOS_Initialize`.
  final String productName;

  /// The product version reported to `EOS_Initialize`.
  final String productVersion;
}
