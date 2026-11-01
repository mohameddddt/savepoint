import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'log_sheet.dart';
import 'search.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});
  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  String filter = 'all';

  bool _keep(LogItem l) => switch (filter) {
    'sessions' => l.kind == LogKind.session,
    'milestones' => l.kind != LogKind.session,
    'finished' => l.kind == LogKind.finished || l.kind == LogKind.mastered,
    _ => true,
  };

  Future<void> _add() async {
    final g = await push<Game>(context, const SearchScreen(pick: true, title: 'Which game?'));
    if (g != null && mounted) showDiaryEntryEditor(context, g);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Diary')),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: context.accent,
        foregroundColor: context.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded),
      ),
      body: Watch(
        builder: (context) {
          final logs = store.logs.where(_keep).toList();
          // group by month
          final groups = <(int, int), List<LogItem>>{};
          for (final l in logs) {
            final d = l.when;
            groups.putIfAbsent((d.year, d.month), () => []).add(l);
          }
          final keys = groups.keys.toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 54,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    children: [
                      for (final f in const [('all', 'Everything'), ('sessions', 'Sessions'), ('finished', 'Finished'), ('milestones', 'Milestones')])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Chip2(f.$2, selected: filter == f.$1, onTap: () => setState(() => filter = f.$1)),
                        ),
                    ],
                  ),
                ),
              ),
              if (logs.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(title: 'Your diary is blank', body: 'Start a play session, mark a game beaten, or add an entry with the + button.'),
                ),
              for (final k in keys) ...[
                SliverToBoxAdapter(
                  child: _MonthHeader(year: k.$1, month: k.$2, logs: groups[k]!),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList.builder(itemCount: groups[k]!.length, itemBuilder: (_, i) => LogRow(groups[k]![i])),
                ),
              ],
              SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 90)),
            ],
          );
        },
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.year, required this.month, required this.logs});
  final int year;
  final int month;
  final List<LogItem> logs;
  @override
  Widget build(BuildContext context) {
    final mins = logs.where((l) => l.kind == LogKind.session).fold<int>(0, (a, l) => a + l.minutes);
    final fin = logs.where((l) => l.kind == LogKind.finished || l.kind == LogKind.mastered).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(months[month - 1], style: T.h2),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text('$year', style: T.label.copyWith(color: context.accent)),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Text([if (fin > 0) '$fin BEATEN', if (mins > 0) fmtMinutes(mins).toUpperCase()].join(' · '), style: T.label),
          ),
        ],
      ),
    );
  }
}
