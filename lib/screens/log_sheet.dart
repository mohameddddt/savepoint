import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import '../widgets/rating.dart';

// ───────────────────────── shared bits ─────────────────────────

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.g, {this.trailing, this.kicker});
  final Game g;
  final Widget? trailing;
  final String? kicker;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 46, child: Cover(g, radius: 7)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kicker != null) ...[Text(kicker!.toUpperCase(), style: T.label.copyWith(color: context.accent)), const SizedBox(height: 4)],
              Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.h3),
              const SizedBox(height: 3),
              Text('${g.year ?? 'TBA'}${g.dev.isNotEmpty ? ' · ${g.dev}' : ''}'.toUpperCase(), maxLines: 1, style: T.label.copyWith(fontSize: 9.5)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class StatusGrid extends StatelessWidget {
  const StatusGrid({super.key, required this.value, required this.onChanged});
  final Status? value;
  final ValueChanged<Status> onChanged;
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: EdgeInsets.zero,
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.05,
      children: [
        for (final s in Status.values)
          Pressable(
            onTap: () {
              tick();
              onChanged(s);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              decoration: BoxDecoration(
                color: value == s ? s.color : C.raised,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: value == s ? s.color : C.line),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s.icon, color: value == s ? C.bg : s.color, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    s.label,
                    maxLines: 1,
                    style: TextStyle(fontFamily: T.body, fontWeight: FontWeight.w700, fontSize: 11.5, color: value == s ? C.bg : C.sub),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _Pad extends StatelessWidget {
  const _Pad({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: children),
    ),
  );
}

Future<DateTime?> pickDate(BuildContext context, DateTime? initial) =>
    showDatePicker(context: context, initialDate: initial ?? DateTime.now(), firstDate: DateTime(1970), lastDate: DateTime.now().add(const Duration(days: 1)));

class DateField extends StatelessWidget {
  const DateField({super.key, required this.label, required this.value, required this.onChanged});
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () async {
        final d = await pickDate(context, value == null ? null : DateTime.fromMillisecondsSinceEpoch(value!));
        if (d != null) onChanged(DateTime(d.year, d.month, d.day, 12).millisecondsSinceEpoch);
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: C.raised,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.line),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: T.label.copyWith(fontSize: 9)),
                  const SizedBox(height: 4),
                  Text(value == null ? 'Not set' : fmtMs(value), style: T.title.copyWith(fontSize: 14, color: value == null ? C.muted : C.text)),
                ],
              ),
            ),
            if (value != null)
              GestureDetector(
                onTap: () => onChanged(null),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, size: 16, color: C.muted),
                ),
              )
            else
              const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.calendar_today_rounded, size: 15, color: C.muted),
              ),
          ],
        ),
      ),
    );
  }
}

class MinutesField extends StatelessWidget {
  const MinutesField({super.key, required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleBtn(Icons.remove_rounded, size: 46, onTap: () => onChanged((value - 15).clamp(0, 100000))),
            Expanded(
              child: Column(
                children: [
                  Text(
                    value == 0 ? '0m' : '${value ~/ 60 > 0 ? '${value ~/ 60}h ' : ''}${value % 60 > 0 ? '${value % 60}m' : ''}'.trim(),
                    style: T.num.copyWith(fontSize: 34),
                  ),
                  Text('DURATION', style: T.label.copyWith(fontSize: 9)),
                ],
              ),
            ),
            CircleBtn(Icons.add_rounded, size: 46, onTap: () => onChanged(value + 15)),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in [30, 60, 90, 120, 180, 240]) Chip2(fmtMinutes(m), selected: value == m, onTap: () => onChanged(m)),
          ],
        ),
      ],
    );
  }
}

class PlatformPicker extends StatelessWidget {
  const PlatformPicker({super.key, required this.game, required this.value, required this.onChanged});
  final Game game;
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    final opts = {...game.platforms, ?value, ...store.entries.values.map((e) => e.platform).whereType<String>().where((p) => game.platforms.isEmpty)}.toList();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final p in opts) Chip2(p, selected: value == p, onTap: () => onChanged(value == p ? null : p)),
        Chip2(
          'Other…',
          icon: Icons.add_rounded,
          onTap: () async {
            final t = await promptText(context, 'Platform', hint: 'e.g. Steam Deck');
            if (t != null && t.trim().isNotEmpty) onChanged(t.trim());
          },
        ),
      ],
    );
  }
}

Future<String?> promptText(BuildContext context, String title, {String? initial, String? hint, String ok = 'Save'}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel', style: TextStyle(color: C.sub)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, c.text),
          child: Text(ok, style: const TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  );
}

// ───────────────────────── quick actions (long-press) ─────────────────────────

void showQuickActions(BuildContext context, Game g) {
  sheet(
    context,
    (c) => Watch(
      builder: (c) {
        final e = store.entry(g.id);
        return _Pad(
          children: [
            _SheetHeader(g, trailing: e == null ? null : StatusBadge(e.status)),
            const SizedBox(height: 18),
            StatusGrid(value: e?.status, onChanged: (s) => store.setStatus(g, s)),
            const SizedBox(height: 16),
            Card2(
              color: C.raised,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  RatingBar(value: e?.rating ?? 0, size: 32, onChanged: (v) => store.rate(g, v)),
                  const Spacer(),
                  Pressable(
                    onTap: () {
                      thud();
                      store.toggleLike(g);
                    },
                    child: Icon(e?.liked == true ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: e?.liked == true ? C.heart : C.sub, size: 28),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Btn(
                    'Session',
                    icon: Icons.timer_outlined,
                    dense: true,
                    expand: true,
                    ghost: true,
                    onTap: () {
                      Navigator.pop(c);
                      startSessionFlow(context, g);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(
                    'List',
                    icon: Icons.playlist_add_rounded,
                    dense: true,
                    expand: true,
                    ghost: true,
                    onTap: () {
                      Navigator.pop(c);
                      showAddToList(context, g);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Btn(
                    'Review',
                    icon: Icons.edit_note_rounded,
                    dense: true,
                    expand: true,
                    onTap: () {
                      Navigator.pop(c);
                      showLogEditor(context, g);
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    ),
  );
}

// ───────────────────────── full log editor ─────────────────────────

Future<void> showLogEditor(BuildContext context, Game g) => sheet(context, (_) => _LogEditor(g));

class _LogEditor extends StatefulWidget {
  const _LogEditor(this.g);
  final Game g;
  @override
  State<_LogEditor> createState() => _LogEditorState();
}

class _LogEditorState extends State<_LogEditor> {
  late final Entry? original = store.entry(widget.g.id);
  late final Entry e = original?.copy() ?? Entry(gameId: widget.g.id, status: Status.played);
  late final review = TextEditingController(text: e.review);
  late final notes = TextEditingController(text: e.notes);
  late final hours = TextEditingController(text: e.baseMinutes == 0 ? '' : (e.baseMinutes / 60).toStringAsFixed(e.baseMinutes % 60 == 0 ? 0 : 1));
  final tagC = TextEditingController();

  @override
  void dispose() {
    review.dispose();
    notes.dispose();
    hours.dispose();
    tagC.dispose();
    super.dispose();
  }

  void _save() {
    e.review = review.text.trim();
    e.notes = notes.text.trim();
    e.baseMinutes = ((double.tryParse(hours.text.replaceAll(',', '.')) ?? 0) * 60).round();
    if (e.status.finished) e.finishedAt ??= DateTime.now().millisecondsSinceEpoch;
    store.saveEntry(widget.g, e, prev: original?.status, isNew: original == null);
    if (e.finishedAt != null && e.status.finished) {
      store.syncMilestoneDate(widget.g.id, e.status == Status.mastered ? LogKind.mastered : LogKind.finished, e.finishedAt!);
    }
    if (e.startedAt != null) store.syncMilestoneDate(widget.g.id, LogKind.started, e.startedAt!);
    Navigator.pop(context);
    toast(context, original == null ? 'Added to your library' : 'Saved');
  }

  void _addTag(String t) {
    final v = t.trim().replaceAll('#', '').toLowerCase();
    if (v.isEmpty || e.tags.contains(v)) return;
    setState(() => e.tags.add(v));
    tagC.clear();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    final allTags = {for (final x in store.entries.values) ...x.tags}.difference(e.tags.toSet()).toList()..sort();
    return _Pad(
      children: [
        _SheetHeader(
          g,
          kicker: original == null ? 'New log' : 'Edit log',
          trailing: Btn('Save', dense: true, onTap: _save),
        ),
        const SizedBox(height: 22),
        Labeled(
          'Status',
          StatusGrid(
            value: e.status,
            onChanged: (s) => setState(() {
              e.status = s;
              if (s.finished) e.finishedAt ??= DateTime.now().millisecondsSinceEpoch;
              if (s == Status.playing) e.startedAt ??= DateTime.now().millisecondsSinceEpoch;
            }),
          ),
        ),
        const SizedBox(height: 22),
        Labeled(
          'Rating',
          Row(
            children: [
              RatingBar(value: e.rating, size: 40, onChanged: (v) => setState(() => e.rating = v)),
              const SizedBox(width: 10),
              Text(e.rating == 0 ? '' : (e.rating / 2).toStringAsFixed(1), style: T.h3.copyWith(color: C.gold)),
              const Spacer(),
              Pressable(
                onTap: () {
                  thud();
                  setState(() => e.liked = !e.liked);
                },
                child: Icon(e.liked ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: e.liked ? C.heart : C.sub, size: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Labeled(
          'Review',
          Column(
            children: [
              TextField(
                controller: review,
                minLines: 3,
                maxLines: 10,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'What did it make you feel? Write it down before you forget…'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.visibility_off_outlined, size: 17, color: C.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Contains spoilers', style: T.small.copyWith(color: C.sub, fontSize: 13.5)),
                  ),
                  Switch(value: e.spoiler, onChanged: (v) => setState(() => e.spoiler = v)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: DateField(label: 'Started', value: e.startedAt, onChanged: (v) => setState(() => e.startedAt = v)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DateField(label: 'Finished', value: e.finishedAt, onChanged: (v) => setState(() => e.finishedAt = v)),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Labeled('Platform', PlatformPicker(game: g, value: e.platform, onChanged: (v) => setState(() => e.platform = v))),
        const SizedBox(height: 22),
        Labeled(
          'Playtime outside sessions',
          TextField(
            controller: hours,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: 'e.g. 42.5',
              suffixText: 'hours',
              helperText: store.sessionsFor(g.id) > 0
                  ? '+ ${fmtMinutes(store.minutesFor(g.id) - (original?.baseMinutes ?? 0))} from ${store.sessionsFor(g.id)} tracked sessions'
                  : null,
              helperStyle: T.small,
            ),
          ),
        ),
        if (e.status.unplayed) ...[
          const SizedBox(height: 22),
          Labeled(
            'Priority',
            Wrap(
              spacing: 8,
              children: [
                for (final p in const [(0, 'None'), (1, 'Low'), (2, 'Medium'), (3, 'High')])
                  Chip2(p.$2, selected: e.priority == p.$1, onTap: () => setState(() => e.priority = p.$1)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Labeled(
          'Tags',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (e.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final t in e.tags) Chip2('#$t', selected: true, icon: Icons.close_rounded, onTap: () => setState(() => e.tags.remove(t)))],
                ),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: tagC,
                decoration: const InputDecoration(hintText: 'Add a tag — cozy, co-op, comfort…', prefixText: '# '),
                onSubmitted: _addTag,
              ),
              if (allTags.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final t in allTags.take(12)) Chip2('#$t', onTap: () => _addTag(t))]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Labeled(
          'Private notes',
          TextField(
            controller: notes,
            minLines: 2,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Builds, codes, where you left off…'),
          ),
        ),
        const SizedBox(height: 26),
        Btn(original == null ? 'Add to library' : 'Save changes', expand: true, onTap: _save),
        if (original != null) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () async {
                final nav = Navigator.of(context);
                if (await confirm(context, 'Remove from library?', 'Deletes your log, review and diary entries for ${g.name}.')) {
                  store.removeEntry(g.id);
                  nav.pop();
                }
              },
              child: const Text(
                'Remove from library',
                style: TextStyle(color: Color(0xFFFF5D5D), fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ───────────────────────── lists ─────────────────────────

void showAddToList(BuildContext context, Game g) {
  sheet(
    context,
    (c) => Watch(
      builder: (c) {
        final ls = store.sortedLists;
        return _Pad(
          children: [
            _SheetHeader(g, kicker: 'Add to list'),
            const SizedBox(height: 18),
            if (ls.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('No lists yet. Make your first one.', style: T.small),
              ),
            for (final l in ls)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card2(
                  color: C.raised,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  onTap: () {
                    tick();
                    store.toggleInList(l, g);
                  },
                  child: Row(
                    children: [
                      Icon(l.ranked ? Icons.format_list_numbered_rounded : Icons.grid_view_rounded, size: 18, color: C.muted),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.title, style: T.title)),
                      Text('${l.items.length}', style: T.label),
                      const SizedBox(width: 12),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: l.items.contains(g.id)
                            ? Icon(Icons.check_circle_rounded, key: const ValueKey(1), color: c.accent)
                            : const Icon(Icons.radio_button_unchecked_rounded, key: ValueKey(0), color: C.faint),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Btn(
              'New list',
              icon: Icons.add_rounded,
              ghost: true,
              expand: true,
              onTap: () async {
                final t = await promptText(c, 'New list', hint: 'e.g. Comfort games', ok: 'Create');
                if (t != null && t.trim().isNotEmpty) {
                  store.cacheGame(g);
                  store.createList(t.trim(), items: [g.id]);
                }
              },
            ),
          ],
        );
      },
    ),
  );
}

// ───────────────────────── play sessions ─────────────────────────

Future<void> startSessionFlow(BuildContext context, Game g) async {
  final s = store.session;
  if (s != null && s.gameId != g.id) {
    final other = store.game(s.gameId);
    final ok = await confirm(context, 'Session already running', 'Finish your ${other?.name ?? 'current'} session first?', yes: 'Finish it', danger: false);
    if (!ok || !context.mounted) return;
    await showSessionStop(context);
    if (store.session != null) return;
  }
  store.startSession(g);
  thud();
  if (context.mounted) toast(context, 'Timer started — have fun.');
}

Future<void> showSessionStop(BuildContext context) async {
  final s = store.session;
  if (s == null) return;
  final g = store.game(s.gameId);
  if (g == null) {
    store.endSession();
    return;
  }
  await sheet(context, (_) => _SessionStop(g, s));
}

class _SessionStop extends StatefulWidget {
  const _SessionStop(this.g, this.s);
  final Game g;
  final ActiveSession s;
  @override
  State<_SessionStop> createState() => _SessionStopState();
}

class _SessionStopState extends State<_SessionStop> {
  late int minutes = widget.s.elapsed.inMinutes.clamp(1, 24 * 60);
  final note = TextEditingController();
  Status? after;
  late String? platform = store.entry(widget.g.id)?.platform;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _t?.cancel();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.g;
    return _Pad(
      children: [
        _SheetHeader(g, kicker: 'Session running'),
        const SizedBox(height: 18),
        Center(
          child: Text(
            fmtClock(widget.s.elapsed),
            style: T.hero.copyWith(fontFamily: T.mono, fontSize: 44, letterSpacing: -1, color: context.accent),
          ),
        ),
        Center(
          child: Text(
            'STARTED ${fmtMs(widget.s.start, year: false).toUpperCase()} · ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(widget.s.start)).format(context)}',
            style: T.label,
          ),
        ),
        const SizedBox(height: 22),
        Labeled('Log as', MinutesField(value: minutes, onChanged: (v) => setState(() => minutes = v))),
        const SizedBox(height: 20),
        TextField(
          controller: note,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Session note — boss beaten, chapter reached…'),
        ),
        const SizedBox(height: 20),
        Labeled('Platform', PlatformPicker(game: g, value: platform, onChanged: (v) => setState(() => platform = v))),
        const SizedBox(height: 20),
        Labeled(
          'After this session',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip2('Still playing', selected: after == null, onTap: () => setState(() => after = null)),
              for (final s in [Status.completed, Status.mastered, Status.shelved, Status.dropped])
                Chip2(s.label, icon: s.icon, color: s.color, selected: after == s, onTap: () => setState(() => after = s)),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Row(
          children: [
            Btn(
              'Discard',
              ghost: true,
              onTap: () async {
                final nav = Navigator.of(context);
                if (await confirm(context, 'Discard session?', 'The timer will be cleared and nothing will be logged.', yes: 'Discard')) {
                  store.endSession();
                  nav.pop();
                }
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Btn(
                'Save session',
                icon: Icons.check_rounded,
                expand: true,
                onTap: minutes <= 0
                    ? null
                    : () {
                        store.saveSession(g, start: widget.s.start, minutes: minutes, note: note.text.trim(), platform: platform, newStatus: after);
                        Navigator.pop(context);
                        toast(context, '${fmtMinutes(minutes, long: true)} logged for ${g.name}');
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── diary entries ─────────────────────────

Future<void> showDiaryEntryEditor(BuildContext context, Game g, [LogItem? existing]) => sheet(context, (_) => _DiaryEditor(g, existing));

class _DiaryEditor extends StatefulWidget {
  const _DiaryEditor(this.g, this.existing);
  final Game g;
  final LogItem? existing;
  @override
  State<_DiaryEditor> createState() => _DiaryEditorState();
}

class _DiaryEditorState extends State<_DiaryEditor> {
  late LogKind kind = widget.existing?.kind ?? LogKind.session;
  late int date = widget.existing?.date ?? DateTime.now().millisecondsSinceEpoch;
  late int minutes = widget.existing?.minutes ?? 60;
  late String? platform = widget.existing?.platform ?? store.entry(widget.g.id)?.platform;
  late final note = TextEditingController(text: widget.existing?.note);

  @override
  void dispose() {
    note.dispose();
    super.dispose();
  }

  void _save() {
    final ex = widget.existing;
    final m = kind == LogKind.session ? minutes : 0;
    if (ex != null) {
      ex
        ..kind = kind
        ..date = date
        ..minutes = m
        ..note = note.text.trim()
        ..platform = platform;
      store.updateLog(ex);
    } else {
      store.addLog(widget.g, kind, date: date, minutes: m, note: note.text.trim(), platform: platform);
      if (store.entry(widget.g.id) == null) {
        store.setStatus(widget.g, kind == LogKind.finished ? Status.completed : (kind == LogKind.mastered ? Status.mastered : Status.playing));
      }
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _Pad(
      children: [
        _SheetHeader(
          widget.g,
          kicker: widget.existing == null ? 'New diary entry' : 'Edit diary entry',
          trailing: Btn('Save', dense: true, onTap: _save),
        ),
        const SizedBox(height: 20),
        Labeled(
          'What happened',
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final k in LogKind.values) Chip2(k.label, icon: k.icon, selected: kind == k, onTap: () => setState(() => kind = k))],
          ),
        ),
        const SizedBox(height: 20),
        DateField(label: 'Date', value: date, onChanged: (v) => setState(() => date = v ?? date)),
        if (kind == LogKind.session) ...[
          const SizedBox(height: 20),
          Labeled('Played for', MinutesField(value: minutes, onChanged: (v) => setState(() => minutes = v))),
        ],
        const SizedBox(height: 20),
        Labeled('Platform', PlatformPicker(game: widget.g, value: platform, onChanged: (v) => setState(() => platform = v))),
        const SizedBox(height: 20),
        TextField(
          controller: note,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Note (optional)'),
        ),
        const SizedBox(height: 24),
        Btn('Save entry', expand: true, onTap: _save),
        if (widget.existing != null)
          Center(
            child: TextButton(
              onPressed: () {
                store.deleteLog(widget.existing!.id);
                Navigator.pop(context);
              },
              child: const Text(
                'Delete entry',
                style: TextStyle(color: Color(0xFFFF5D5D), fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

/// Diary row: big date numeral, cover, what happened.
class LogRow extends StatelessWidget {
  const LogRow(this.l, {super.key, this.showGame = true, this.showDate = true, this.monthLabel = false});
  final LogItem l;
  final bool monthLabel;
  final bool showGame;
  final bool showDate;
  @override
  Widget build(BuildContext context) {
    final g = store.game(l.gameId) ?? Game(id: l.gameId, name: 'Unknown game');
    final e = store.entry(l.gameId);
    final d = l.when;
    final kindColor = switch (l.kind) {
      LogKind.finished => Status.completed.color,
      LogKind.mastered => Status.mastered.color,
      LogKind.dropped => Status.dropped.color,
      LogKind.shelved => Status.shelved.color,
      LogKind.started => Status.playing.color,
      LogKind.replay => Status.playing.color,
      LogKind.session => C.sub,
    };
    return Pressable(
      scale: 0.98,
      onTap: () => showDiaryEntryEditor(context, g, l),
      onLongPress: showGame ? () => openGame(context, g) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (showDate)
              SizedBox(
                width: 44,
                child: Column(
                  children: [
                    Text('${d.day}', style: T.h2.copyWith(fontSize: 24, height: 1)),
                    const SizedBox(height: 2),
                    Text(monthLabel ? mon[d.month - 1] : wd[d.weekday - 1], style: T.label.copyWith(fontSize: 8.5)),
                  ],
                ),
              ),
            if (showDate) const SizedBox(width: 10),
            if (showGame) ...[SizedBox(width: 40, child: Cover(g, radius: 6)), const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showGame) Text(g.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: T.title.copyWith(fontSize: 14)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(l.kind.icon, size: 13, color: kindColor),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          [l.kind.label, if (l.minutes > 0) fmtMinutes(l.minutes), if (l.platform != null) l.platform!].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: T.small.copyWith(color: kindColor == C.sub ? C.sub : kindColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if ((l.kind == LogKind.finished || l.kind == LogKind.mastered) && (e?.rating ?? 0) > 0) ...[
                        const SizedBox(width: 8),
                        StarRow(e!.rating, size: 11),
                      ],
                    ],
                  ),
                  if (l.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      l.note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: T.small.copyWith(fontStyle: FontStyle.italic),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
