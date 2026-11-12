import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_error.dart';
import '../../../core/api/player_api.dart';
import '../../../core/api/token_store.dart';
import '../../../core/socket/game_socket.dart';
import '../../../core/socket/socket_providers.dart';
import '../../../core/time/countdown.dart';

class Treasure {
  const Treasure({
    required this.title,
    required this.backstory,
    required this.lockObjective,
    required this.imageUrl,
  });
  final String title;
  final String backstory;
  final String lockObjective;
  final String imageUrl;

  factory Treasure.fromJson(Map<String, dynamic> j) => Treasure(
    title: '${j['title'] ?? ''}',
    backstory: '${j['backstory'] ?? ''}',
    lockObjective: '${j['lockObjective'] ?? ''}',
    imageUrl: '${j['imageUrl'] ?? ''}',
  );
}

class RoundInfo {
  const RoundInfo({
    required this.roundId,
    required this.roundNumber,
    required this.durationSeconds,
  });
  final String roundId;
  final int roundNumber;
  final int durationSeconds;

  factory RoundInfo.fromJson(Map<String, dynamic> j) => RoundInfo(
    roundId: '${j['roundId']}',
    roundNumber: (j['roundNumber'] as num?)?.toInt() ?? 1,
    durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 90,
  );
}

enum PromptStage { submitting, evaluating, scored, blocked, failed }

class PromptItem {
  const PromptItem({
    required this.key, // the idempotency key, made before the first send
    required this.text,
    required this.createdAt,
    this.promptId,
    this.stage = PromptStage.submitting,
    this.score,
    this.feedback,
    this.message,
  });

  final String key;
  final String text;
  final DateTime createdAt;
  final String? promptId;
  final PromptStage stage;
  final int? score;
  final String? feedback;
  final String? message;

  PromptItem copyWith({
    String? promptId,
    PromptStage? stage,
    int? score,
    String? feedback,
    String? message,
  }) => PromptItem(
    key: key,
    text: text,
    createdAt: createdAt,
    promptId: promptId ?? this.promptId,
    stage: stage ?? this.stage,
    score: score ?? this.score,
    feedback: feedback ?? this.feedback,
    message: message ?? this.message,
  );

  factory PromptItem.fromServer(Map<String, dynamic> j) {
    final score = (j['score'] as num?)?.toInt();
    final stage = switch ('${j['status']}') {
      'SCORED' || 'DISPLAYED' =>
        score != null ? PromptStage.scored : PromptStage.evaluating,
      'BLOCKED' => PromptStage.blocked,
      'FAILED' => PromptStage.failed,
      _ => PromptStage.evaluating,
    };
    return PromptItem(
      key: '${j['promptId']}',
      text: '${j['text']}',
      createdAt: DateTime.tryParse('${j['receivedAt']}') ?? DateTime.now(),
      promptId: '${j['promptId']}',
      stage: stage,
      score: score,
      feedback: j['feedback'] as String?,
      message: j['message'] as String?,
    );
  }
}

class GameState {
  const GameState({
    this.ready = false,
    this.treasure,
    this.round,
    this.bestScore,
    this.canSubmit = false,
    this.prompts = const [],
    this.superseded = false,
  });

  final bool ready;
  final Treasure? treasure;
  final RoundInfo? round;
  final int? bestScore;
  final bool canSubmit; // decided by the server, never by the timer
  final List<PromptItem> prompts; // oldest first
  final bool superseded; // another device took over

  GameState copyWith({
    bool? ready,
    Treasure? treasure,
    RoundInfo? round,
    int? bestScore,
    bool? canSubmit,
    List<PromptItem>? prompts,
    bool? superseded,
  }) => GameState(
    ready: ready ?? this.ready,
    treasure: treasure ?? this.treasure,
    round: round ?? this.round,
    bestScore: bestScore ?? this.bestScore,
    canSubmit: canSubmit ?? this.canSubmit,
    prompts: prompts ?? this.prompts,
    superseded: superseded ?? this.superseded,
  );
}

class GameNotifier extends Notifier<GameState> {
  final _items = <PromptItem>[]; // survives rebuilds
  final _uuid = const Uuid();

  @override
  GameState build() {
    if (ref.watch(tokenProvider) == null) {
      _items.clear();
      return const GameState();
    }
    // Rebuilds from the server every time the hydrate call is refreshed.
    final me = ref.watch(meProvider).value;
    final sub = ref.watch(playerSocketProvider).messages.listen(_onMessage);
    ref.onDispose(sub.cancel);
    return me == null ? const GameState() : _fromMe(me);
  }

  GameState _fromMe(Map<String, dynamic> me) {
    final player = Map<String, dynamic>.from(me['player'] as Map);
    final t = me['treasure'];
    final r = me['round'];
    _mergeServer((me['prompts'] as List?) ?? const []);
    if (r is Map) {
      final end = r['roundEndAt'];
      final srv = me['serverNow'];
      Future.microtask(() {
        try {
          _seed(end, srv);
        } catch (_) {
          /* provider already gone */
        }
      });
    }
    return GameState(
      ready: true,
      treasure: t is Map
          ? Treasure.fromJson(Map<String, dynamic>.from(t))
          : null,
      round: r is Map ? RoundInfo.fromJson(Map<String, dynamic>.from(r)) : null,
      bestScore: (player['bestScore'] as num?)?.toInt(),
      canSubmit: me['canSubmit'] == true,
      prompts: List.of(_items),
    );
  }

  void _seed(Object? roundEndAt, Object? serverNow) => ref
      .read(countdownProvider.notifier)
      .seed(roundEndAt: roundEndAt, serverNow: serverNow);

  void _mergeServer(List server) {
    for (final raw in server) {
      final merged = PromptItem.fromServer(
        Map<String, dynamic>.from(raw as Map),
      );
      final i = _items.indexWhere((e) => e.promptId == merged.promptId);
      if (i >= 0) {
        _items[i] = _items[i].copyWith(
          stage: merged.stage,
          score: merged.score,
          feedback: merged.feedback,
        );
        continue;
      }
      // A local prompt the server already has, but whose reply we missed.
      final j = _items.indexWhere(
        (e) => e.promptId == null && e.text == merged.text,
      );
      if (j >= 0) {
        _items[j] = _items[j].copyWith(
          promptId: merged.promptId,
          stage: merged.stage,
          score: merged.score,
          feedback: merged.feedback,
        );
      } else {
        _items.add(merged);
      }
    }
    _items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  void _updateBy(
    bool Function(PromptItem) test,
    PromptItem Function(PromptItem) change,
  ) {
    final i = _items.indexWhere(test);
    if (i < 0) return;
    _items[i] = change(_items[i]);
    state = state.copyWith(prompts: List.of(_items));
  }

  void _onMessage(SocketMessage m) {
    final d = m.data;
    if (d is! Map) return;
    switch (m.event) {
      case 'round:started':
        _seed(d['roundEndAt'], d['serverNow']);
        final t = d['treasure'];
        state = state.copyWith(
          ready: true,
          treasure: t is Map
              ? Treasure.fromJson(Map<String, dynamic>.from(t))
              : null,
          round: RoundInfo.fromJson(Map<String, dynamic>.from(d)),
          canSubmit: true,
          prompts: List.of(_items),
        );
      case 'prompt:scored':
        _updateBy(
          (p) => p.promptId == '${d['promptId']}',
          (p) => p.copyWith(
            stage: PromptStage.scored,
            score: (d['score'] as num?)?.toInt(),
            feedback: d['feedback'] as String?,
          ),
        );
        state = state.copyWith(bestScore: (d['bestScore'] as num?)?.toInt());
      case 'prompt:blocked':
        _updateBy(
          (p) => p.promptId == '${d['promptId']}',
          (p) => p.copyWith(
            stage: PromptStage.blocked,
            message: d['message'] as String?,
          ),
        );
      case 'prompt:failed':
        _updateBy(
          (p) => p.promptId == '${d['promptId']}',
          (p) => p.copyWith(
            stage: PromptStage.failed,
            message: d['message'] as String?,
          ),
        );
    }
  }

  /// A new prompt: the idempotency key is made here, once, before sending.
  Future<void> submit(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || text.length > 200 || !state.canSubmit) return;
    final item = PromptItem(
      key: _uuid.v4(),
      text: text,
      createdAt: DateTime.now(),
    );
    _items.add(item);
    state = state.copyWith(prompts: List.of(_items));
    await _send(item.key);
  }

  /// Never reached the server: resend with the SAME key. Otherwise a new prompt.
  Future<void> retry(PromptItem item) async {
    if (item.promptId == null) {
      _updateBy(
        (p) => p.key == item.key,
        (p) => p.copyWith(stage: PromptStage.submitting),
      );
      await _send(item.key);
    } else {
      await submit(item.text);
    }
  }

  Future<void> _send(String key) async {
    final item = _items.firstWhere((p) => p.key == key);
    try {
      final r = await ref.read(playerApiProvider).submitPrompt(item.text, key);
      if (!ref.mounted) return;
      _updateBy(
        (p) => p.key == key,
        (p) => p.copyWith(
          promptId: '${r['promptId']}',
          // The socket may have scored it already. Do not step backwards.
          stage: p.stage == PromptStage.submitting
              ? PromptStage.evaluating
              : p.stage,
        ),
      );
    } catch (e) {
      if (!ref.mounted) return;
      var msg = 'Something went wrong. Please try again.';
      if (e is ApiException) {
        msg = switch (e.code) {
          'ROUND_EXPIRED' ||
          'ROUND_NOT_PLAYING' => 'Time is up. That prompt was not accepted.',
          'PLAYER_LOCKED' => 'You already unlocked the treasure.',
          'PROMPT_TOO_LONG' => 'That prompt is too long (200 characters max).',
          'NETWORK_ERROR' => 'No connection. Tap retry.',
          _ => e.message,
        };
        if (e.code == 'TOKEN_SUPERSEDED') {
          state = state.copyWith(superseded: true);
        }
      }
      _updateBy(
        (p) => p.key == key,
        (p) => p.copyWith(stage: PromptStage.failed, message: msg),
      );
    }
  }
}

final gameProvider = NotifierProvider<GameNotifier, GameState>(
  GameNotifier.new,
);
