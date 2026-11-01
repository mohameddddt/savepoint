import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../igdb.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'log_sheet.dart';
import 'shell.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _export(BuildContext context, {bool csv = false}) async {
    try {
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now().toIso8601String().substring(0, 10);
      final f = File('${dir.path}/savepoint-${csv ? 'library' : 'backup'}-$stamp.${csv ? 'csv' : 'json'}');
      await f.writeAsString(csv ? store.exportCsv() : const JsonEncoder.withIndent(' ').convert(store.exportData()));
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(f.path, mimeType: csv ? 'text/csv' : 'application/json')],
          subject: csv ? 'Savepoint library' : 'Savepoint backup',
        ),
      );
    } catch (e) {
      if (context.mounted) toast(context, 'Export failed: $e');
    }
  }

  Future<void> _import(BuildContext context) async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.any);
      if (files.isEmpty || !context.mounted) return;
      final bytes = await files.first.readAsBytes();
      final j = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final n = (j['entries'] as List?)?.length ?? 0;
      if (!context.mounted) return;
      if (!await confirm(context, 'Restore backup?', 'This replaces your current library with $n games from the backup.', yes: 'Restore')) return;
      await store.importData(j);
      if (context.mounted) toast(context, 'Restored $n games');
    } catch (e) {
      if (context.mounted) toast(context, 'That file isn’t a Savepoint backup.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Watch(
        builder: (context) {
          final goal = store.goalFor(year);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
            children: [
              const _Group('You'),
              _Row(
                icon: Icons.person_outline_rounded,
                title: 'Display name',
                value: store.name,
                onTap: () async {
                  final t = await promptText(context, 'Display name', initial: store.kv['name']);
                  if (t != null) store.setPref('name', t.trim());
                },
              ),
              const SizedBox(height: 10),
              Card2(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ACCENT', style: T.label),
                    const SizedBox(height: 14),
                    const AccentPicker(),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Card2(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$year GOAL', style: T.label),
                          const SizedBox(height: 6),
                          Text(goal == 0 ? 'No goal set' : '$goal games', style: T.h3),
                        ],
                      ),
                    ),
                    CircleBtn(Icons.remove_rounded, onTap: () => store.setGoal(year, goal - 1)),
                    const SizedBox(width: 8),
                    CircleBtn(Icons.add_rounded, onTap: () => store.setGoal(year, goal + 1)),
                  ],
                ),
              ),
              const _Group('Game data'),
              _Row(
                icon: Icons.key_rounded,
                title: 'IGDB connection',
                value: store.igdb.configured ? 'Connected' : 'Not set up',
                valueColor: store.igdb.configured ? const Color(0xFFB4F25A) : C.gold,
                onTap: () => push(context, const IgdbSetupScreen()),
              ),
              _Row(
                icon: Icons.cleaning_services_outlined,
                title: 'Clear image cache',
                onTap: () async {
                  await DefaultCacheManager().emptyCache();
                  PaintingBinding.instance.imageCache.clear();
                  if (context.mounted) toast(context, 'Image cache cleared');
                },
              ),
              const _Group('Your data'),
              _Row(icon: Icons.ios_share_rounded, title: 'Export backup', value: 'JSON', onTap: () => _export(context)),
              _Row(icon: Icons.table_chart_outlined, title: 'Export library', value: 'CSV', onTap: () => _export(context, csv: true)),
              _Row(icon: Icons.restore_rounded, title: 'Restore from backup', onTap: () => _import(context)),
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
                child: Text(
                  'Everything lives on this phone only. Export a backup now and then — it’s your only copy if the app is uninstalled.',
                  style: T.small,
                ),
              ),
              const _Group('About'),
              Card2(
                child: Row(
                  children: [
                    const Gem(size: 34),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Savepoint 1.0', style: T.title),
                          const SizedBox(height: 3),
                          Text('${store.entries.length} games · ${store.logs.length} diary entries · ${store.lists.length} lists', style: T.small),
                          const SizedBox(height: 3),
                          Text('Game data courtesy of IGDB.com', style: T.small),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class AccentPicker extends StatelessWidget {
  const AccentPicker({super.key});
  @override
  Widget build(BuildContext context) {
    return Watch(
      builder: (context) {
        final cur = store.accent;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < accents.length; i++)
              Pressable(
                onTap: () {
                  tick();
                  store.setAccent(i);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accents[i].color,
                        shape: BoxShape.circle,
                        border: Border.all(color: cur.name == accents[i].name ? C.text : Colors.transparent, width: 2.5),
                        boxShadow: cur.name == accents[i].name ? [BoxShadow(color: accents[i].color.withValues(alpha: 0.5), blurRadius: 14)] : null,
                      ),
                      child: cur.name == accents[i].name ? Icon(Icons.check_rounded, color: accents[i].ink, size: 20) : null,
                    ),
                    const SizedBox(height: 6),
                    Text(accents[i].name.toUpperCase(), style: T.label.copyWith(fontSize: 8.5, color: cur.name == accents[i].name ? C.text : C.muted)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group(this.t);
  final String t;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
    child: Text(t.toUpperCase(), style: T.label.copyWith(color: context.accent)),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, this.value, this.onTap, this.valueColor});
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Card2(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Icon(icon, size: 20, color: C.sub),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: T.title.copyWith(fontSize: 14.5))),
          if (value != null)
            Text(
              value!,
              style: T.small.copyWith(color: valueColor ?? C.muted, fontWeight: FontWeight.w700),
            ),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded, color: C.faint, size: 20),
        ],
      ),
    ),
  );
}

// ───────────────────────── IGDB setup ─────────────────────────

class IgdbSetupScreen extends StatefulWidget {
  const IgdbSetupScreen({super.key});
  @override
  State<IgdbSetupScreen> createState() => _IgdbSetupScreenState();
}

class _IgdbSetupScreenState extends State<IgdbSetupScreen> {
  final id = TextEditingController(text: store.kv['igdb_id']);
  final secret = TextEditingController(text: store.kv['igdb_secret']);
  bool hide = true;
  bool busy = false;
  String? result;
  bool ok = false;

  @override
  void dispose() {
    id.dispose();
    secret.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      result = null;
    });
    store.setKv('igdb_id', id.text.trim());
    store.setKv('igdb_secret', secret.text.trim());
    try {
      await store.igdb.test();
      ok = true;
      result = 'Connected. 300k+ games at your fingertips.';
      store.setPref('igdb_ok', '1');
    } on IgdbError catch (e) {
      ok = false;
      result = e.message;
    } catch (e) {
      ok = false;
      result = 'Something went wrong: $e';
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect IGDB')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 60),
        children: [
          Text('IGDB is the database behind Backloggd. It’s free — you just need your own Twitch developer keys. Two minutes, once.', style: T.body1),
          const SizedBox(height: 22),
          const SetupStep(
            1,
            'Open the Twitch developer console',
            'Log in with any Twitch account. Twitch requires two-factor auth to be enabled for developer apps.',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44, bottom: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                'dev.twitch.tv/console',
                icon: Icons.north_east_rounded,
                dense: true,
                ghost: true,
                onTap: () => launchUrl(Uri.parse('https://dev.twitch.tv/console/apps/create'), mode: LaunchMode.externalApplication),
              ),
            ),
          ),
          const SetupStep(
            2,
            'Register an application',
            'Name: anything (e.g. “savepoint-me”)\nOAuth Redirect URL: http://localhost\nCategory: Application Integration\nClient type: Confidential',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 44, bottom: 18),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Btn(
                'Copy redirect URL',
                icon: Icons.copy_rounded,
                dense: true,
                ghost: true,
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: 'http://localhost'));
                  toast(context, 'Copied http://localhost');
                },
              ),
            ),
          ),
          const SetupStep(3, 'Copy your keys', 'Open the app → copy the Client ID → press “New Secret” and copy it. Paste both below.'),
          const SizedBox(height: 8),
          TextField(
            controller: id,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Client ID'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: secret,
            autocorrect: false,
            obscureText: hide,
            decoration: InputDecoration(
              labelText: 'Client Secret',
              suffixIcon: IconButton(
                icon: Icon(hide ? Icons.visibility_rounded : Icons.visibility_off_rounded, color: C.muted),
                onPressed: () => setState(() => hide = !hide),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Btn(busy ? 'Connecting…' : 'Test & save', icon: Icons.bolt_rounded, expand: true, onTap: busy ? null : _connect),
          if (result != null) ...[
            const SizedBox(height: 16),
            Card2(
              color: (ok ? const Color(0xFFB4F25A) : const Color(0xFFFF5D5D)).withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: ok ? const Color(0xFFB4F25A) : const Color(0xFFFF5D5D)),
                  const SizedBox(width: 12),
                  Expanded(child: Text(result!, style: T.title.copyWith(fontSize: 13.5))),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Text('Keys stay on this device. They are never included in backups.', style: T.small),
        ],
      ),
    );
  }
}

class SetupStep extends StatelessWidget {
  const SetupStep(this.n, this.title, this.body, {super.key});
  final int n;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(9)),
          child: Text(
            '$n',
            style: TextStyle(fontFamily: T.mono, fontWeight: FontWeight.w800, color: context.onAccent),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(title, style: T.title),
              const SizedBox(height: 5),
              Text(body, style: T.small.copyWith(fontSize: 13, height: 1.5)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────── first launch ─────────────────────────

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void _go() {
    if (name.text.trim().isNotEmpty) store.setKv('name', name.text.trim());
    store.setPref('onboarded', '1');
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, _, _) => const Shell(),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      body: Stack(
        children: [
          Positioned(top: -160, right: -140, child: Glow(size: 520, opacity: 0.32)),
          Positioned(bottom: -200, left: -160, child: Glow(size: 480, opacity: 0.14, color: const Color(0xFF9D7CFF))),
          ListView(
            padding: EdgeInsets.fromLTRB(26, mq.padding.top + 50, 26, mq.padding.bottom + 30),
            children: [
              const Align(alignment: Alignment.centerLeft, child: Gem(size: 58)),
              const SizedBox(height: 30),
              Text('SAVEPOINT', style: T.label.copyWith(color: context.accent, fontSize: 12, letterSpacing: 4)),
              const SizedBox(height: 12),
              Text('Every game\nyou play,\nremembered.', style: T.hero.copyWith(fontSize: 48)),
              const SizedBox(height: 18),
              Text('A private diary, backlog and stats board for one player: you. No feed, no followers, no noise.', style: T.body1.copyWith(fontSize: 15.5)),
              const SizedBox(height: 34),
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'What should we call you?'),
              ),
              const SizedBox(height: 22),
              Text('PICK YOUR COLOUR', style: T.label),
              const SizedBox(height: 14),
              const AccentPicker(),
              const SizedBox(height: 30),
              Watch(
                builder: (context) => Card2(
                  onTap: () => push(context, const IgdbSetupScreen()),
                  child: Row(
                    children: [
                      Icon(
                        store.igdb.configured ? Icons.check_circle_rounded : Icons.key_rounded,
                        color: store.igdb.configured ? const Color(0xFFB4F25A) : context.accent,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(store.igdb.configured ? 'IGDB connected' : 'Connect IGDB (recommended)', style: T.title),
                            const SizedBox(height: 3),
                            Text('Covers, details & discovery for 300k+ games.', style: T.small),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: C.muted),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Btn('Press start', icon: Icons.arrow_forward_rounded, expand: true, onTap: _go),
            ],
          ),
        ],
      ),
    );
  }
}
