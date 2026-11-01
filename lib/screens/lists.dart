import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'search.dart';

class ListsScreen extends StatelessWidget {
  const ListsScreen({super.key});

  Future<void> _create(BuildContext context) async {
    final l = await sheet<GameList>(context, (_) => const _ListForm());
    if (l != null && context.mounted) push(context, ListDetailScreen(id: l.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lists')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _create(context),
        backgroundColor: context.accent,
        foregroundColor: context.onAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New list',
          style: TextStyle(fontFamily: T.display, fontWeight: FontWeight.w700),
        ),
      ),
      body: Watch(
        builder: (context) {
          final ls = store.sortedLists;
          if (ls.isEmpty) {
            return const Center(
              child: EmptyState(title: 'No lists yet', body: 'Rank your favourite RPGs, plan a summer of co-op, or collect every game that made you cry.'),
            );
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 100),
            itemCount: ls.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) => _ListCard(ls[i]),
          );
        },
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  const _ListCard(this.l);
  final GameList l;
  @override
  Widget build(BuildContext context) {
    final games = l.items.map(store.game).whereType<Game>().take(5).toList();
    return Card2(
      onTap: () => push(context, ListDetailScreen(id: l.id)),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            height: 84,
            child: Stack(
              children: [
                if (games.isEmpty)
                  Container(
                    width: 62,
                    height: 84,
                    decoration: BoxDecoration(
                      color: C.raised,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.line),
                    ),
                  ),
                for (var i = games.length - 1; i >= 0; i--)
                  Positioned(
                    left: i * 22.0,
                    child: Container(
                      width: 62,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 10, offset: const Offset(4, 0))],
                      ),
                      child: Cover(games[i], radius: 8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.h3.copyWith(fontSize: 16.5)),
                const SizedBox(height: 5),
                Text('${l.items.length} ${l.items.length == 1 ? 'GAME' : 'GAMES'}${l.ranked ? ' · RANKED' : ''}', style: T.label.copyWith(fontSize: 9.5)),
                if (l.desc.isNotEmpty) ...[const SizedBox(height: 6), Text(l.desc, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.small)],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ListForm extends StatefulWidget {
  const _ListForm({this.existing});
  final GameList? existing;
  @override
  State<_ListForm> createState() => _ListFormState();
}

class _ListFormState extends State<_ListForm> {
  late final title = TextEditingController(text: widget.existing?.title);
  late final desc = TextEditingController(text: widget.existing?.desc);
  late bool ranked = widget.existing?.ranked ?? false;

  @override
  void dispose() {
    title.dispose();
    desc.dispose();
    super.dispose();
  }

  void _save() {
    if (title.text.trim().isEmpty) return;
    final ex = widget.existing;
    if (ex != null) {
      ex
        ..title = title.text.trim()
        ..desc = desc.text.trim()
        ..ranked = ranked;
      store.saveList(ex);
      Navigator.pop(context, ex);
    } else {
      Navigator.pop(context, store.createList(title.text.trim(), desc: desc.text.trim(), ranked: ranked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.existing == null ? 'New list' : 'Edit list', style: T.h2),
          const SizedBox(height: 18),
          TextField(
            controller: title,
            autofocus: widget.existing == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: desc,
            minLines: 2,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Description (optional)'),
          ),
          const SizedBox(height: 12),
          Card2(
            color: C.raised,
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
            child: Row(
              children: [
                const Icon(Icons.format_list_numbered_rounded, color: C.sub, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ranked list', style: T.title.copyWith(fontSize: 14)),
                      Text('Show #1, #2, #3… next to each game', style: T.small.copyWith(fontSize: 11.5)),
                    ],
                  ),
                ),
                Switch(value: ranked, onChanged: (v) => setState(() => ranked = v)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Btn(widget.existing == null ? 'Create list' : 'Save', expand: true, onTap: _save),
        ],
      ),
    );
  }
}

class ListDetailScreen extends StatelessWidget {
  const ListDetailScreen({super.key, required this.id});
  final String id;

  Future<void> _add(BuildContext context, GameList l) async {
    final g = await push<Game>(context, const SearchScreen(pick: true, title: 'Add a game to the list'));
    if (g == null) return;
    if (l.items.contains(g.id)) {
      if (context.mounted) toast(context, 'Already on this list');
      return;
    }
    store.toggleInList(l, g);
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      builder: (context) {
        final l = store.lists[id];
        if (l == null) return const Scaffold();
        final mq = MediaQuery.of(context);
        return Scaffold(
          appBar: AppBar(
            title: Text(l.ranked ? 'Ranked list' : 'List'),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz_rounded),
                onSelected: (v) async {
                  if (v == 'edit') {
                    sheet(context, (_) => _ListForm(existing: l));
                  } else if (v == 'delete') {
                    final nav = Navigator.of(context);
                    if (await confirm(context, 'Delete “${l.title}”?', 'The games stay in your library.')) {
                      nav.pop();
                      store.deleteList(l.id);
                    }
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit details')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete list', style: TextStyle(color: Color(0xFFFF5D5D))),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _add(context, l),
            backgroundColor: context.accent,
            foregroundColor: context.onAccent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.add_rounded),
          ),
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.title, style: T.h1),
                      if (l.desc.isNotEmpty) ...[const SizedBox(height: 10), Text(l.desc, style: T.body1)],
                      const SizedBox(height: 10),
                      Text('${l.items.length} GAMES · UPDATED ${ago(l.updatedAt).toUpperCase()}', style: T.label),
                      if (l.items.length > 1) ...[
                        const SizedBox(height: 4),
                        Text('Hold & drag to reorder · swipe left to remove', style: T.small.copyWith(fontSize: 11.5)),
                      ],
                    ],
                  ),
                ),
              ),
              if (l.items.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(title: 'Empty list', body: 'Tap + to add games.', action: 'Add a game', onAction: () => _add(context, l)),
                )
              else
                SliverReorderableList(
                  itemCount: l.items.length,
                  onReorderItem: (a, b) {
                    l.items.insert(b, l.items.removeAt(a));
                    store.saveList(l);
                  },
                  itemBuilder: (_, i) {
                    final gid = l.items[i];
                    final g = store.game(gid) ?? Game(id: gid, name: 'Unknown');
                    final e = store.entry(gid);
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(gid),
                      index: i,
                      child: Dismissible(
                        key: ValueKey('d$gid'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          color: const Color(0x22FF5D5D),
                          child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFFF5D5D)),
                        ),
                        onDismissed: (_) {
                          l.items.remove(gid);
                          store.saveList(l);
                          toast(
                            context,
                            'Removed ${g.name}',
                            action: 'UNDO',
                            onAction: () {
                              l.items.insert(i.clamp(0, l.items.length), gid);
                              store.saveList(l);
                            },
                          );
                        },
                        child: Material(
                          color: C.bg,
                          child: InkWell(
                            onTap: () => openGame(context, g),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              child: Row(
                                children: [
                                  if (l.ranked)
                                    SizedBox(
                                      width: 44,
                                      child: Text(
                                        '${i + 1}',
                                        style: T.num.copyWith(fontSize: i < 3 ? 30 : 24, color: i < 3 ? context.accent : C.sub),
                                      ),
                                    ),
                                  SizedBox(width: 52, child: Cover(g, radius: 7)),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.title),
                                        const SizedBox(height: 4),
                                        Text('${g.year ?? 'TBA'}${g.dev.isNotEmpty ? ' · ${g.dev}' : ''}', maxLines: 1, style: T.small),
                                        if (e != null) ...[
                                          const SizedBox(height: 5),
                                          Row(children: [StatusBadge(e.status), const SizedBox(width: 8), StarRow(e.rating, size: 11)]),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.drag_indicator_rounded, color: C.faint),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              SliverToBoxAdapter(child: SizedBox(height: mq.padding.bottom + 100)),
            ],
          ),
        );
      },
    );
  }
}
