import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../util.dart';
import '../widgets/common.dart';
import 'game_detail.dart';
import 'log_sheet.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  String sort = 'recent';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: Watch(
        builder: (context) {
          final list = store.entries.values.where((e) => e.review.isNotEmpty).toList();
          if (sort == 'rating') {
            list.sort((a, b) => b.rating.compareTo(a.rating));
          } else {
            list.sort((a, b) => (b.reviewedAt ?? b.updatedAt).compareTo(a.reviewedAt ?? a.updatedAt));
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.paddingOf(context).bottom + 30),
            children: [
              Row(
                children: [
                  Chip2('Latest', selected: sort == 'recent', onTap: () => setState(() => sort = 'recent')),
                  const SizedBox(width: 8),
                  Chip2('Highest rated', selected: sort == 'rating', onTap: () => setState(() => sort = 'rating')),
                ],
              ),
              const SizedBox(height: 10),
              if (list.isEmpty) const EmptyState(title: 'No reviews yet', body: 'Open any game and tap “Review & log” to write your first one.'),
              for (final e in list) _ReviewCard(e),
            ],
          );
        },
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard(this.e);
  final Entry e;
  @override
  Widget build(BuildContext context) {
    final g = store.game(e.gameId);
    if (g == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card2(
        onTap: () => openGame(context, g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 54, child: Cover(g, radius: 7)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(g.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: T.h3.copyWith(fontSize: 17)),
                      const SizedBox(height: 4),
                      Text('${g.year ?? 'TBA'}${e.platform != null ? ' · ${e.platform}' : ''}'.toUpperCase(), style: T.label.copyWith(fontSize: 9.5)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StarRow(e.rating, size: 15),
                          if (e.liked) ...[const SizedBox(width: 8), const Icon(Icons.favorite_rounded, size: 14, color: C.heart)],
                          const Spacer(),
                          Text(ago(e.reviewedAt ?? e.updatedAt).toUpperCase(), style: T.label.copyWith(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ReviewText(e.review, spoiler: e.spoiler, maxLines: 8),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => showLogEditor(context, g),
                child: Text('EDIT', style: T.label.copyWith(color: context.accent)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
