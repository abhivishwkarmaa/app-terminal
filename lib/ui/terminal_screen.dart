import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:xterm/xterm.dart';
import '../models/host_model.dart';
import '../providers/host_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ssh_service.dart';
import 'widgets/skeleton.dart';

class TerminalScreen extends StatefulWidget {
  final HostModel host;

  const TerminalScreen({super.key, required this.host});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final FocusNode _terminalFocusNode = FocusNode();
  final ScrollController _shortcutPanelScrollController = ScrollController();
  static const List<_TerminalShortcut> _quickShortcuts = [
    _TerminalShortcut(label: 'ESC', input: '\x1B'),
    _TerminalShortcut(label: 'TAB', input: '\t'),
    _TerminalShortcut(label: 'CTRL+C', controlKey: 'C', accent: Colors.redAccent),
    _TerminalShortcut(label: 'CTRL+D', controlKey: 'D'),
    _TerminalShortcut(label: 'CTRL+Z', controlKey: 'Z'),
    _TerminalShortcut(label: 'UP', input: '\x1B[A'),
    _TerminalShortcut(label: 'DOWN', input: '\x1B[B'),
    _TerminalShortcut(label: 'LEFT', input: '\x1B[D'),
    _TerminalShortcut(label: 'RIGHT', input: '\x1B[C'),
  ];

  static const List<_TerminalShortcut> _controlShortcuts = [
    _TerminalShortcut(label: 'CTRL+A', controlKey: 'A'),
    _TerminalShortcut(label: 'CTRL+E', controlKey: 'E'),
    _TerminalShortcut(label: 'CTRL+K', controlKey: 'K'),
    _TerminalShortcut(label: 'CTRL+L', controlKey: 'L'),
    _TerminalShortcut(label: 'CTRL+O', controlKey: 'O'),
    _TerminalShortcut(label: 'CTRL+R', controlKey: 'R'),
    _TerminalShortcut(label: 'CTRL+U', controlKey: 'U'),
    _TerminalShortcut(label: 'CTRL+W', controlKey: 'W'),
    _TerminalShortcut(label: 'CTRL+X', controlKey: 'X'),
    _TerminalShortcut(label: 'CTRL+\\', input: '\x1C'),
  ];

  static const List<_TerminalShortcut> _shellShortcuts = [
    _TerminalShortcut(label: '|', input: '|'),
    _TerminalShortcut(label: '/', input: '/'),
    _TerminalShortcut(label: '-', input: '-'),
    _TerminalShortcut(label: '_', input: '_'),
    _TerminalShortcut(label: '~', input: '~'),
    _TerminalShortcut(label: '.', input: '.'),
    _TerminalShortcut(label: '*', input: '*'),
    _TerminalShortcut(label: '&', input: '&'),
    _TerminalShortcut(label: ';', input: ';'),
    _TerminalShortcut(label: ':', input: ':'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _connect();
    });
  }

  @override
  void dispose() {
    _shortcutPanelScrollController.dispose();
    _terminalFocusNode.dispose();
    super.dispose();
  }

  void _connect() async {
    final hostProvider = Provider.of<HostProvider>(context, listen: false);
    final sshService = Provider.of<SSHService>(context, listen: false);
    
    String? password;
    try {
      password = await hostProvider.getPassword(widget.host.id);
    } catch (e) {
      // If decryption fails (e.g. key mismatch), we treat it as null to prompt again
      debugPrint('Decryption error, prompting for password: $e');
      password = null;
    }
    
    if (password == null) {
      if (mounted) {
        password = await _showPasswordPrompt();
        if (password == null || password.isEmpty) return;
        
        // Save it locally for future use on this device
        await hostProvider.updateHost(widget.host, password);
      } else {
        return;
      }
    }

    await sshService.connect(
      host: widget.host.host,
      port: widget.host.port,
      username: widget.host.username,
      password: password,
    );
  }

  Future<String?> _showPasswordPrompt() {
    final passwordController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Authentication Required', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This terminal was synced from another device. Please enter the SSH password to decrypt and connect.'),
              const SizedBox(height: 20),
              TextField(
                controller: passwordController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'SSH Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (val) => Navigator.pop(context, val),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, passwordController.text),
              child: const Text('CONNECT'),
            ),
          ],
        );
      },
    );
  }

  TerminalTheme _getTerminalTheme(String themeName) {
    switch (themeName) {
      case 'Light':
        return const TerminalTheme(
          cursor: Color(0XFF000000),
          selection: Color(0XFFB5D5FF),
          foreground: Color(0XFF000000),
          background: Color(0XFFFFFFFF),
          black: Color(0XFF000000),
          red: Color(0XFFCD3131),
          green: Color(0XFF0DBC79),
          yellow: Color(0XFFE5E510),
          blue: Color(0XFF2472C8),
          magenta: Color(0XFFBC3FBC),
          cyan: Color(0XFF11A8CD),
          white: Color(0XFFE5E5E5),
          brightBlack: Color(0XFF666666),
          brightRed: Color(0XFFF14C4C),
          brightGreen: Color(0XFF23D18B),
          brightYellow: Color(0XFFF5F543),
          brightBlue: Color(0XFF3B8EEA),
          brightMagenta: Color(0XFFD670D6),
          brightCyan: Color(0XFF29B8DB),
          brightWhite: Color(0XFF000000),
          searchHitBackground: Color(0XFFFFFF2B),
          searchHitBackgroundCurrent: Color(0XFF31FF26),
          searchHitForeground: Color(0XFF000000),
        );
      case 'Matrix':
        return const TerminalTheme(
          cursor: Color(0XFF00FF00),
          selection: Color(0XFF005500),
          foreground: Color(0XFF00FF00),
          background: Color(0XFF050505),
          black: Color(0XFF000000),
          red: Color(0XFFCD3131),
          green: Color(0XFF0DBC79),
          yellow: Color(0XFFE5E510),
          blue: Color(0XFF2472C8),
          magenta: Color(0XFFBC3FBC),
          cyan: Color(0XFF11A8CD),
          white: Color(0XFFE5E5E5),
          brightBlack: Color(0XFF666666),
          brightRed: Color(0XFFF14C4C),
          brightGreen: Color(0XFF23D18B),
          brightYellow: Color(0XFFF5F543),
          brightBlue: Color(0XFF3B8EEA),
          brightMagenta: Color(0XFFD670D6),
          brightCyan: Color(0XFF29B8DB),
          brightWhite: Color(0XFFFFFFFF),
          searchHitBackground: Color(0XFFFFFF2B),
          searchHitBackgroundCurrent: Color(0XFF31FF26),
          searchHitForeground: Color(0XFF000000),
        );
      case 'Ubuntu':
        return const TerminalTheme(
          cursor: Color(0XFFFFFFFF),
          selection: Color(0XFF505050),
          foreground: Color(0XFFFFFFFF),
          background: Color(0XFF300A24),
          black: Color(0XFF2E3436),
          red: Color(0XFFCC0000),
          green: Color(0XFF4E9A06),
          yellow: Color(0XFFC4A000),
          blue: Color(0XFF3465A4),
          magenta: Color(0XFF75507B),
          cyan: Color(0XFF06989A),
          white: Color(0XFFD3D7CF),
          brightBlack: Color(0XFF555753),
          brightRed: Color(0XFFEF2929),
          brightGreen: Color(0XFF8AE234),
          brightYellow: Color(0XFFFCE94F),
          brightBlue: Color(0XFF729FCF),
          brightMagenta: Color(0XFFAD7FA8),
          brightCyan: Color(0XFF34E2E2),
          brightWhite: Color(0XFFEEEEEE),
          searchHitBackground: Color(0XFFFFFF2B),
          searchHitBackgroundCurrent: Color(0XFF31FF26),
          searchHitForeground: Color(0XFF000000),
        );
      case 'Dark':
      default:
        return TerminalThemes.defaultTheme;
    }
  }

  bool _isKeyboardExpanded = false;

  void _toggleKeyboard() {
    setState(() => _isKeyboardExpanded = !_isKeyboardExpanded);
  }

  String _controlSequence(String key) {
    final upper = key.toUpperCase();
    final codeUnit = upper.codeUnitAt(0);
    return String.fromCharCode(codeUnit - 64);
  }

  void _sendShortcut(SSHService ssh, _TerminalShortcut shortcut) {
    if (shortcut.controlKey != null) {
      ssh.writeToStdin(_controlSequence(shortcut.controlKey!));
      return;
    }

    if (shortcut.input != null) {
      ssh.writeToStdin(shortcut.input!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final terminalTheme = _getTerminalTheme(themeProvider.currentTheme);

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            titleSpacing: 12,
            title: _TerminalAppBarTitle(
              hostName: widget.host.name,
              descriptor: '${widget.host.username}@${widget.host.host}',
            ),
            actions: [
              Consumer<SSHService>(
                builder: (context, ssh, child) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Theme.of(context)
                            .cardColor
                            .withValues(alpha: 0.78),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      onPressed: () {
                        if (ssh.status == SSHStatus.connected) {
                          ssh.disconnect();
                        } else {
                          _connect();
                        }
                      },
                      icon: Icon(
                        ssh.status == SSHStatus.connected
                            ? Icons.link_off_rounded
                            : Icons.link_rounded,
                        color: ssh.status == SSHStatus.connected
                            ? Colors.redAccent
                            : Colors.greenAccent,
                        size: 18,
                      ),
                      label: Text(
                        ssh.status == SSHStatus.connected ? 'Connected' : 'Connect',
                        style: TextStyle(
                          color: ssh.status == SSHStatus.connected
                              ? Colors.redAccent
                              : Colors.greenAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Consumer2<SSHService, ThemeProvider>(
                    builder: (context, ssh, theme, child) {
                      if (ssh.status == SSHStatus.connecting) {
                        return _TerminalSkeleton(
                          hostName: widget.host.name,
                          descriptor: '${widget.host.username}@${widget.host.host}',
                        );
                      }

                      return Container(
                        color: terminalTheme.background,
                        padding: const EdgeInsets.all(12.0),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate terminal dimensions (approximate)
                            final charWidth = theme.terminalFontSize * 0.6;
                            final charHeight = theme.terminalFontSize * 1.2;
                            final cols = (constraints.maxWidth / charWidth).floor();
                            final rows = (constraints.maxHeight / charHeight).floor();
                            
                            // Signal resize to SSH session
                            ssh.resize(cols, rows);

                            return TerminalView(
                              ssh.terminal,
                              focusNode: _terminalFocusNode,
                              autofocus: true,
                              backgroundOpacity: 1.0,
                              theme: terminalTheme,
                              textStyle: TerminalStyle(fontSize: theme.terminalFontSize),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
                _buildExtraKeyboard(themeProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExtraKeyboard(ThemeProvider themeProvider) {
    final ssh = Provider.of<SSHService>(context, listen: false);
    final isDark = themeProvider.isDarkBg;
    final bgColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey[200]!;
    final textColor = isDark ? Colors.white : Colors.black87;
    final keyColor = isDark ? const Color(0xFF2D2D2D) : Colors.white;
    final sectionBg = isDark ? Colors.black26 : Colors.white54;
    final screenHeight = MediaQuery.of(context).size.height;

    // Check if keyboard is visible to toggle icon
    final isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final expandedPanelMaxHeight = isKeyboardVisible
        ? screenHeight * 0.24
        : screenHeight * 0.34;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _keyboardIconButton(
                _isKeyboardExpanded ? Icons.keyboard_arrow_down : Icons.tune_rounded,
                _toggleKeyboard,
                textColor,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final shortcut in _quickShortcuts)
                        _keyButton(
                          shortcut.label,
                          () => _sendShortcut(ssh, shortcut),
                          shortcut.accent ?? textColor,
                          keyColor,
                        ),
                      _keyButton(
                        'CLR',
                        () => ssh.terminal.write('\x1b[2J\x1b[H'),
                        textColor,
                        keyColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _keyboardIconButton(
                isKeyboardVisible ? Icons.keyboard_hide_rounded : Icons.keyboard_rounded,
                () {
                  if (isKeyboardVisible) {
                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                    _terminalFocusNode.unfocus();
                  } else {
                    _terminalFocusNode.requestFocus();
                    SystemChannels.textInput.invokeMethod('TextInput.show');
                  }
                },
                textColor,
                tooltip: isKeyboardVisible ? 'Hide Keyboard' : 'Show Keyboard',
              ),
            ],
          ),
          if (_isKeyboardExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              constraints: BoxConstraints(
                maxHeight: expandedPanelMaxHeight.clamp(150.0, 280.0),
              ),
              decoration: BoxDecoration(
                color: sectionBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Scrollbar(
                controller: _shortcutPanelScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _shortcutPanelScrollController,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      _shortcutSection(
                        title: 'CTRL SHORTCUTS',
                        textColor: textColor,
                        child: Wrap(
                          children: [
                            for (final shortcut in _controlShortcuts)
                              _keyButton(
                                shortcut.label,
                                () => _sendShortcut(ssh, shortcut),
                                shortcut.accent ?? textColor,
                                keyColor,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      _shortcutSection(
                        title: 'SHELL SYMBOLS',
                        textColor: textColor,
                        child: Wrap(
                          children: [
                            for (final shortcut in _shellShortcuts)
                              _keyButton(
                                shortcut.label,
                                () => _sendShortcut(ssh, shortcut),
                                textColor,
                                keyColor,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Text('FONT SIZE', style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                              color: textColor.withValues(alpha: 0.5),
                            )),
                            _controlButton(Icons.remove_rounded, themeProvider.decreaseFontSize, textColor, keyColor),
                            Container(
                              constraints: const BoxConstraints(minWidth: 40.0),
                              alignment: Alignment.center,
                              child: Text(
                                '${themeProvider.terminalFontSize.toInt()}',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: textColor),
                              ),
                            ),
                            _controlButton(Icons.add_rounded, themeProvider.increaseFontSize, textColor, keyColor),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _shortcutSection({
    required String title,
    required Color textColor,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              color: textColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _keyboardIconButton(IconData icon, VoidCallback onTap, Color color, {String? tooltip}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }

  Widget _keyButton(String label, VoidCallback onPressed, Color textColor, Color bgColor) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
      child: Material(
        color: bgColor,
        elevation: 1,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onPressed();
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 40),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onPressed, Color textColor, Color bgColor) {
    return Material(
      color: bgColor,
      elevation: 1,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onPressed();
        },
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Icon(icon, color: textColor, size: 20),
        ),
      ),
    );
  }
}

class _TerminalShortcut {
  final String label;
  final String? input;
  final String? controlKey;
  final Color? accent;

  const _TerminalShortcut({
    required this.label,
    this.input,
    this.controlKey,
    this.accent,
  });
}

class _TerminalAppBarTitle extends StatelessWidget {
  final String hostName;
  final String descriptor;

  const _TerminalAppBarTitle({
    required this.hostName,
    required this.descriptor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(hostName, style: theme.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          descriptor,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
          ),
        ),
      ],
    );
  }
}

class _TerminalSkeleton extends StatelessWidget {
  final String hostName;
  final String descriptor;

  const _TerminalSkeleton({
    required this.hostName,
    required this.descriptor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const lineHeight = 18.0;
          const lineGap = 10.0;
          const reservedHeight = 140.0;
          final availableLineSpace = (constraints.maxHeight - reservedHeight)
              .clamp(120.0, double.infinity);
          final lineCount =
              (availableLineSpace / (lineHeight + lineGap)).floor().clamp(8, 24);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Connecting to $hostName',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Text(
                descriptor,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.64),
                ),
              ),
              const SizedBox(height: 20),
              const SkeletonBox(height: 16, width: 180),
              const SizedBox(height: 12),
              const SkeletonBox(height: 14),
              const SizedBox(height: 10),
              const SkeletonBox(height: 14, width: 280),
              const SizedBox(height: 24),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: lineCount,
                    itemBuilder: (context, index) {
                      return SkeletonBox(
                        height: lineHeight,
                        width: index % 3 == 0
                            ? double.infinity
                            : (index.isEven ? 260 : 320),
                        borderRadius: BorderRadius.circular(8),
                        margin: EdgeInsets.only(
                          bottom: index == lineCount - 1 ? 0 : lineGap,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
