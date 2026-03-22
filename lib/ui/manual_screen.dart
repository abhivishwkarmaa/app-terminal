import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ManualScreen extends StatelessWidget {
  const ManualScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connection Guide'),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.colorScheme.surface,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            _HeroCard(primary: primary),
            const SizedBox(height: 18),
            const _GuideSection(
              eyebrow: 'PASSWORD LOGIN',
              title: 'Connect with a username and password',
              body:
                  'Use this when your server allows SSH password authentication. Enter the host IP, port 22, the correct SSH username, and the password in Add Host.',
              bullets: [
                'Host: your server IP or domain name',
                'Port: usually 22',
                'Username: the SSH user on that server',
                'Authentication: choose Password',
                'Password: the SSH login password for that user',
              ],
            ),
            const SizedBox(height: 18),
            const _GuideSection(
              eyebrow: 'RSA KEY FLOW',
              title: 'Create an RSA key pair on your computer',
              body:
                  'If your server does not allow passwords, create an RSA key pair and keep the private key safe. The public key goes to the server.',
              code: 'ssh-keygen -t rsa -b 2048 -m PEM -f ~/.ssh/id_rsa_mobile',
              bullets: [
                'This creates a private key: ~/.ssh/id_rsa_mobile',
                'This creates a public key: ~/.ssh/id_rsa_mobile.pub',
                'If prompted, you can set a passphrase for extra protection',
                'For best compatibility in this app, use RSA PEM format',
              ],
            ),
            const SizedBox(height: 18),
            const _GuideSection(
              eyebrow: 'COPY PUBLIC KEY',
              title: 'Add the public key to your server',
              body:
                  'Only the public key should be copied to the server. Never upload the private key to the server.',
              code:
                  'ssh-copy-id -i ~/.ssh/id_rsa_mobile.pub username@your-server-ip',
              secondaryCode:
                  'cat ~/.ssh/id_rsa_mobile.pub >> ~/.ssh/authorized_keys',
              bullets: [
                'Use ssh-copy-id when available',
                'If doing it manually, append the .pub file to ~/.ssh/authorized_keys',
                'On the server, keep permissions strict',
                'Run chmod 700 ~/.ssh and chmod 600 ~/.ssh/authorized_keys',
              ],
            ),
            const SizedBox(height: 18),
            const _GuideSection(
              eyebrow: 'USE IN APP',
              title: 'Connect with RSA private key in the app',
              body:
                  'When you add a host in the app, choose Private Key and paste or import the full private key file content.',
              bullets: [
                'Open Add Host',
                'Enter Host, Port, and Username',
                'Choose Private Key',
                'Paste or import the full contents of the private key file',
                'If the key has a passphrase, enter it in Passphrase',
                'Tap Save and let the app test the connection',
              ],
            ),
            const SizedBox(height: 18),
            const _GuideSection(
              eyebrow: 'AWS HELP',
              title: 'Common EC2 usernames',
              body:
                  'On AWS, connection issues are often caused by the wrong username instead of a bad key.',
              bullets: [
                'Ubuntu AMI: ubuntu',
                'Amazon Linux: ec2-user',
                'Debian: admin or debian',
                'CentOS: centos',
                'Root login is often disabled',
              ],
            ),
            const SizedBox(height: 18),
            const _GuideSection(
              eyebrow: 'IMPORT AND COPY',
              title: 'Which file goes where',
              body:
                  'The private key stays on your device. The public key goes to the server. They are not interchangeable.',
              bullets: [
                'Private key file: usually no extension or .pem',
                'Public key file: usually ends with .pub',
                'App import field needs the private key',
                'Server authorized_keys needs the public key',
                'Never send your private key to chat, email, or backend',
              ],
            ),
            const SizedBox(height: 18),
            const _GuideSection(
              eyebrow: 'TROUBLESHOOTING',
              title: 'If connection fails',
              body:
                  'Most failures come from username mismatch, missing public key on the server, or using the wrong file in the app.',
              bullets: [
                'Verify the same key works from terminal first',
                'Check you pasted the private key, not the .pub key',
                'Confirm the server has the matching public key',
                'Try the correct username for that OS image',
                'If password login is disabled on the server, use Private Key',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final Color primary;

  const _HeroCard({required this.primary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            primary.withValues(alpha: 0.16),
            theme.colorScheme.secondary.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to connect',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'This guide covers password login, RSA key setup, public key copy, and the exact private key flow inside the app.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  final String eyebrow;
  final String title;
  final String body;
  final List<String> bullets;
  final String? code;
  final String? secondaryCode;

  const _GuideSection({
    required this.eyebrow,
    required this.title,
    required this.body,
    required this.bullets,
    this.code,
    this.secondaryCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primary.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: theme.textTheme.labelMedium?.copyWith(
              color: primary.withValues(alpha: 0.82),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          if (code != null) ...[
            const SizedBox(height: 14),
            _CodeBlock(code: code!),
          ],
          if (secondaryCode != null) ...[
            const SizedBox(height: 10),
            _CodeBlock(code: secondaryCode!),
          ],
          const SizedBox(height: 14),
          ...bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: primary.withValues(alpha: 0.82),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bullet,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  final String code;

  const _CodeBlock({required this.code});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: code));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Command copied'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
            ),
          ),
          SelectableText(
            code,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
