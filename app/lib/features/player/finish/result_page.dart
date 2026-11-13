import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/player_api.dart';
import '../../../core/api/token_store.dart';
import '../../../shared/shape_marker.dart';
import '../battle/game_state.dart';

const _blue = Color(0xFF4285F4);
const _red = Color(0xFFEA4335);
const _yellow = Color(0xFFFBBC05);
const _green = Color(0xFF34A853);

/// GET /api/player/result. PENDING until the Controller confirms.
final resultProvider = FutureProvider.autoDispose<Json>((ref) {
  ref.watch(tokenProvider);
  return ref.watch(playerApiProvider).result();
});

String ordinal(int n) {
  final m100 = n % 100;
  if (m100 >= 11 && m100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

class ResultPage extends ConsumerWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final res = ref.watch(resultProvider);
    final mySlot = ref.watch(gameProvider.select((g) => g.mySlot));
    return Scaffold(
      body: SafeArea(
        child: res.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Cannot load the result.'),
                TextButton(
                  onPressed: () => ref.invalidate(resultProvider),
                  child: const Text('Try again'),
                ),
              ],
            ),
          ),
          data: (d) {
            if (d['status'] != 'CONFIRMED') {
              // Not confirmed yet: back to the time up screen.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) context.go('/player/timeup');
              });
              return const Center(child: CircularProgressIndicator());
            }
            return _ResultView(d, mySlot: mySlot);
          },
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView(this.d, {required this.mySlot});
  final Json d;
  final int? mySlot;

  @override
  Widget build(BuildContext context) {
    final ranking = [
      for (final r in (d['ranking'] as List))
        Map<String, dynamic>.from(r as Map),
    ];
    final myRank = (d['myRank'] as num?)?.toInt();
    final mine = ranking.where((r) => r['rank'] == myRank).toList();
    final myBest = mine.isEmpty
        ? null
        : (mine.first['bestScore'] as num?)?.toInt();
    final tie = d['tieBreakExplanation'] as String?;
    final story = d['story'] is Map
        ? Map<String, dynamic>.from(d['story'] as Map)
        : null;

    final String headline;
    final String sub;
    final Color color;
    final IconData icon;
    if (myBest == null) {
      // No score at all: shown as zero.
      headline = 'Your score is zero';
      sub = myRank == null
          ? 'Better luck next time'
          : 'You came ${ordinal(myRank)}';
      color = _red;
      icon = Icons.sentiment_neutral_rounded;
    } else if (myRank == 1) {
      headline = 'You won!';
      sub = 'Best score: $myBest';
      color = _green;
      icon = Icons.emoji_events_rounded;
    } else {
      headline = myRank == null
          ? 'Final result'
          : 'You came ${ordinal(myRank)}';
      sub = 'Best score: $myBest';
      color = _blue;
      icon = Icons.flag_rounded;
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: color),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 16),
            ),
            const SizedBox(height: 24),
            _Podium(ranking.take(3).toList(), mySlot),
            if (ranking.length > 3) ...[
              const SizedBox(height: 16),
              for (final r in ranking.skip(3))
                _RankRow(r, isMe: r['slotNumber'] == mySlot),
            ],
            if (tie != null && tie.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _yellow.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(tie),
              ),
            ],
            if (story != null) ...[
              const SizedBox(height: 20),
              _StoryCard(story),
            ],
          ],
        ),
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium(this.top, this.mySlot);
  final List<Map<String, dynamic>> top;
  final int? mySlot;

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd, 1st, 3rd.
    final order = [1, 0, 2].where((i) => i < top.length).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final i in order)
          Expanded(child: _PodiumColumn(top[i], i, mySlot)),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  const _PodiumColumn(this.r, this.index, this.mySlot);
  final Map<String, dynamic> r;
  final int index; // 0 = first place
  final int? mySlot;

  @override
  Widget build(BuildContext context) {
    const heights = [120.0, 90.0, 70.0];
    const colors = [_yellow, _blue, _red];
    final isMe = r['slotNumber'] == mySlot;
    final score = (r['bestScore'] as num?)?.toInt();
    return Column(
      children: [
        ShapeMarker('${r['shape']}', size: 22),
        const SizedBox(height: 6),
        Text(
          isMe ? '${r['label']} (you)' : '${r['label']}',
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isMe ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        Text(
          '${score ?? 0}',
          style: const TextStyle(
            fontFamily: 'AppMono',
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: heights[index],
          margin: const EdgeInsets.symmetric(horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors[index],
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: index == 0 ? Colors.black87 : Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow(this.r, {required this.isMe});
  final Map<String, dynamic> r;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final score = (r['bestScore'] as num?)?.toInt();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isMe ? _blue : Colors.black12,
          width: isMe ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${r['rank']}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: 32,
            child: Center(child: ShapeMarker('${r['shape']}', size: 16)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(isMe ? '${r['label']} (you)' : '${r['label']}')),
          Text(
            '${score ?? 0}',
            style: const TextStyle(
              fontFamily: 'AppMono',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  const _StoryCard(this.story);
  final Map<String, dynamic> story;

  Widget _placeholder() => Container(
    color: const Color(0xFFEAF1FE),
    alignment: Alignment.center,
    child: const Icon(Icons.diamond_outlined, size: 56, color: _blue),
  );

  @override
  Widget build(BuildContext context) {
    final url = '${story['imageUrl'] ?? ''}';
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: url.isEmpty
                ? _placeholder()
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                    loadingBuilder: (_, child, p) =>
                        p == null ? child : _placeholder(),
                    errorBuilder: (_, _, _) => _placeholder(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THE STORY',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${story['title']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${story['backstory']}',
                  style: const TextStyle(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
