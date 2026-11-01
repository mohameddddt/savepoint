import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'discover.dart';
import 'home.dart';
import 'library.dart';
import 'log_sheet.dart';
import 'profile.dart';
import 'search.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  static final tab = ValueNotifier<int>(0);
  static void go(int i) => tab.value = i;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  final _built = <int>{Shell.tab.value};

  static const _pages = <Widget>[HomeScreen(), DiscoverScreen(), LibraryScreen(), ProfileScreen()];

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Shell.tab,
      builder: (context, t, _) {
        _built.add(t);
        return PopScope(
          canPop: t == 0,
          onPopInvokedWithResult: (did, _) {
            if (!did) Shell.go(0);
          },
          child: Scaffold(
            extendBody: true,
            body: Stack(
              children: [
                IndexedStack(index: t, children: [for (var i = 0; i < _pages.length; i++) _built.contains(i) ? _pages[i] : const SizedBox.shrink()]),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: MediaQuery.paddingOf(context).top + 14,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0, 0.7, 1],
                          colors: [C.bg, C.bg.withValues(alpha: 0.85), C.bg.withValues(alpha: 0)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: _Dock(index: t),
          ),
        );
      },
    );
  }
}

class _Dock extends StatelessWidget {
  const _Dock({required this.index});
  final int index;
  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SessionBar(),
        Container(
          margin: EdgeInsets.fromLTRB(14, 0, 14, bottom + 10),
          height: 66,
          decoration: BoxDecoration(
            color: const Color(0xF2151419),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: C.line),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 30, offset: const Offset(0, 12))],
          ),
          child: Row(
            children: [
              _DockItem(icon: Icons.space_dashboard_rounded, label: 'Home', i: 0, cur: index),
              _DockItem(icon: Icons.explore_rounded, label: 'Discover', i: 1, cur: index),
              Expanded(
                child: Center(
                  child: Pressable(
                    scale: 0.9,
                    onTap: () {
                      tick();
                      push(context, const SearchScreen());
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(17),
                        boxShadow: [BoxShadow(color: context.accent.withValues(alpha: 0.45), blurRadius: 18, offset: const Offset(0, 4))],
                      ),
                      child: Icon(Icons.add_rounded, color: context.onAccent, size: 28),
                    ),
                  ),
                ),
              ),
              _DockItem(icon: Icons.grid_view_rounded, label: 'Library', i: 2, cur: index),
              _DockItem(icon: Icons.person_rounded, label: 'Profile', i: 3, cur: index),
            ],
          ),
        ),
      ],
    );
  }
}

class _DockItem extends StatelessWidget {
  const _DockItem({required this.icon, required this.label, required this.i, required this.cur});
  final IconData icon;
  final String label;
  final int i;
  final int cur;
  @override
  Widget build(BuildContext context) {
    final on = i == cur;
    return Expanded(
      child: Pressable(
        scale: 0.9,
        onTap: () {
          if (!on) tick();
          Shell.go(i);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(icon, key: ValueKey(on), size: 23, color: on ? context.accent : C.muted),
            ),
            const SizedBox(height: 4),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              width: on ? 16 : 0,
              height: 3,
              decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Persistent "now playing" timer strip shown above the dock.
class SessionBar extends StatelessWidget {
  const SessionBar({super.key});
  @override
  Widget build(BuildContext context) {
    return Watch(
      builder: (context) {
        final s = store.session;
        final g = s == null ? null : store.game(s.gameId);
        return AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: s == null || g == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                  child: Pressable(
                    scale: 0.98,
                    onTap: () => openGame(context, g),
                    child: Container(
                      height: 58,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      decoration: BoxDecoration(
                        color: C.raised,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: context.accent.withValues(alpha: 0.55)),
                        boxShadow: [BoxShadow(color: context.accent.withValues(alpha: 0.18), blurRadius: 24)],
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 32, child: Cover(g, radius: 6)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Pulse(
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: BoxDecoration(color: context.accent, shape: BoxShape.circle),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text('SESSION', style: T.label.copyWith(fontSize: 9, color: context.accent)),
                                    const SizedBox(width: 8),
                                    LiveClock(
                                      start: s.start,
                                      style: T.label.copyWith(fontSize: 10.5, color: C.text),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 13.5)),
                              ],
                            ),
                          ),
                          Pressable(
                            onTap: () => showSessionStop(context),
                            child: Container(
                              height: 40,
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(color: context.accent, borderRadius: BorderRadius.circular(13)),
                              child: Row(
                                children: [
                                  Icon(Icons.stop_rounded, size: 18, color: context.onAccent),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Stop',
                                    style: TextStyle(fontFamily: T.display, fontWeight: FontWeight.w700, color: context.onAccent),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }
}

class LiveClock extends StatefulWidget {
  const LiveClock({super.key, required this.start, this.style});
  final int start;
  final TextStyle? style;
  @override
  State<LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<LiveClock> {
  late final Timer _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  @override
  void dispose() {
    _t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _t; // ensure started
    return Text(fmtClock(ActiveSession(0, widget.start).elapsed), style: widget.style);
  }
}
