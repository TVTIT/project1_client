import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../data/digital_twin_dto.dart';
import '../data/digital_twin_repository.dart';
import '../data/twin_detail.dart';
import 'digital_twin_providers.dart';

class TwinDetailState {
  const TwinDetailState({
    this.detail,
    this.sensors = const [],
    this.nextCursor,
    this.isLoading = false,
    this.error,
    this.atCapacity = false,
  });
  final TwinDetail? detail;
  final List<EntityUrn> sensors;
  final String? nextCursor;
  final bool isLoading, atCapacity;
  final Object? error;
}

/// Member-only detail, explicit bounded relationship pages; never N+1 reads.
class TwinDetailNotifier extends Notifier<TwinDetailState> {
  TwinDetailNotifier(this.entityId);
  final String entityId;
  static const pageSize = 20;
  static const maxPages = 20;
  int _sequence = 0, _pages = 0;
  final _cursors = <String>{};

  @override
  TwinDetailState build() {
    ref.watch(twinSessionScopeProvider);
    final generation = ++_sequence;
    _pages = 0;
    _cursors.clear();
    if (ref.read(sessionProvider).isAuthenticated) {
      scheduleMicrotask(() {
        if (ref.mounted && generation == _sequence) load();
      });
    }
    return const TwinDetailState(isLoading: true);
  }

  Future<void> load() async {
    _sequence++;
    _pages = 0;
    _cursors.clear();
    state = const TwinDetailState();
    await _fetch();
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.nextCursor == null || state.atCapacity) return;
    await _fetch(cursor: state.nextCursor);
  }

  Future<void> retry() => state.nextCursor != null ? loadMore() : _fetch();

  Future<void> _fetch({String? cursor}) async {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    final snapshot = state;
    final sequence = ++_sequence;
    final epoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final identity = ref.read(sessionProvider).user?.userId;
    bool current() =>
        ref.mounted &&
        sequence == _sequence &&
        epoch == ref.read(sessionProvider.notifier).sessionEpoch &&
        identity == ref.read(sessionProvider).user?.userId &&
        ref.read(sessionProvider).isAuthenticated;
    state = TwinDetailState(
      detail: snapshot.detail,
      sensors: snapshot.sensors,
      nextCursor: cursor,
      isLoading: true,
    );
    try {
      EntityUrn.parse(entityId);
      final page = await ref
          .read(digitalTwinRepositoryProvider)
          .getTwinDetail(
            entityId,
            relationshipLimit: pageSize,
            relationshipAfter: cursor,
          );
      if (!current()) return;
      if (page.detail.entity.urn != entityId) {
        throw const FormatException('Wrong entity identity');
      }
      final accumulated = cursor == null ? <EntityUrn>[] : snapshot.sensors;
      final ids = accumulated.map((s) => s.urn).toSet();
      final fresh = page.detail.sensors
          .where((s) => !ids.contains(s.urn))
          .toList();
      if (cursor != null) _cursors.add(cursor);
      if (cursor == null) {
        _pages = 0;
        _cursors.clear();
      }
      _pages++;
      final loop =
          page.nextCursor != null &&
          (fresh.isEmpty || _cursors.contains(page.nextCursor));
      final duplicate = fresh.length != page.detail.sensors.length;
      final capacity = _pages >= maxPages && page.nextCursor != null;
      state = TwinDetailState(
        detail: page.detail,
        sensors: List.unmodifiable([...accumulated, ...fresh]),
        nextCursor: loop || duplicate || capacity ? null : page.nextCursor,
        atCapacity: capacity,
        error: loop || duplicate
            ? const FormatException('Relationship pagination made no progress')
            : null,
      );
    } catch (error) {
      if (!current()) return;
      final denied =
          error is ApiException &&
          (error.statusCode == 401 ||
              error.statusCode == 403 ||
              error.statusCode == 404);
      state = TwinDetailState(
        detail: denied ? null : snapshot.detail,
        sensors: denied ? const [] : snapshot.sensors,
        nextCursor: denied ? null : cursor,
        error: error,
      );
    }
  }
}

final twinDetailProvider = NotifierProvider.autoDispose
    .family<TwinDetailNotifier, TwinDetailState, String>(
      TwinDetailNotifier.new,
    );
