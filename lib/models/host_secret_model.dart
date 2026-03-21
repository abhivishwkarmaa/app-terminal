import 'host_model.dart';

class HostSecretModel {
  final AuthType authType;
  final String? password;
  final String? privateKey;
  final String? passphrase;

  const HostSecretModel({
    required this.authType,
    this.password,
    this.privateKey,
    this.passphrase,
  });

  bool get hasPassword => (password ?? '').isNotEmpty;
  bool get hasPrivateKey => (privateKey ?? '').trim().isNotEmpty;
  String? get normalizedPassphrase =>
      (passphrase == null || passphrase!.isEmpty) ? null : passphrase;
}
