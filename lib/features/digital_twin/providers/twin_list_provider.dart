import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../gateways/data/gateway_dto.dart';
import '../../gateways/data/gateway_repository.dart';
import '../data/digital_twin_dto.dart';
import '../data/digital_twin_repository.dart';
import '../data/twin_list_page.dart';
import 'digital_twin_providers.dart';

final twinListEndpointProvider = Provider<Uri>(
  (ref) => ref.watch(apiClientProvider).buildUri('digital-twins'),
);

/// Deliberately uses the member catalog even for Platform Admins.
final twinMemberGatewaysProvider =
    FutureProvider.autoDispose<List<GatewayItem>>((ref) {
      ref.watch(twinSessionScopeProvider);
      if (!ref.read(sessionProvider).isAuthenticated) return const [];
      return ref.watch(gatewayRepositoryProvider).getGateways();
    });

class TwinListState {
  const TwinListState({
    this.items = const [],
    this.type,
    this.gatewayId,
    this.nextCursor,
    this.isLoading = false,
    this.error,
    this.atCapacity = false,
  });
  final List<TwinSummaryItem> items;
  final EntityType? type;
  final String? gatewayId;
  final String? nextCursor;
  final bool isLoading;
  final Object? error;
  final bool atCapacity;
}

/// Explicit load-more, at most 20 pages / 1000 rows, no persistent storage.
class TwinListNotifier extends Notifier<TwinListState> {
  static const pageSize = 50;
  static const maxPages = 20;
  int _sequence = 0;
  int _pages = 0;
  final Set<String> _cursors = {};

  @override
  TwinListState build() {
    ref.watch(twinSessionScopeProvider);
    _sequence++;
    _pages = 0;
    _cursors.clear();
    return const TwinListState();
  }

  Future<void> load({EntityType? type, String? gatewayId}) async {
    _sequence++;
    _pages = 0;
    _cursors.clear();
    state = TwinListState(type: type, gatewayId: gatewayId);
    await _fetch();
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.nextCursor == null || state.atCapacity) return;
    await _fetch(cursor: state.nextCursor);
  }

  Future<void> _fetch({String? cursor}) async {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    final snapshot = state;
    final seq = ++_sequence;
    final epoch = ref.read(sessionProvider.notifier).sessionEpoch;
    bool current() =>
        ref.mounted &&
        seq == _sequence &&
        epoch == ref.read(sessionProvider.notifier).sessionEpoch &&
        ref.read(sessionProvider).isAuthenticated;
    state = TwinListState(
      items: snapshot.items,
      type: snapshot.type,
      gatewayId: snapshot.gatewayId,
      nextCursor: cursor,
      isLoading: true,
    );
    try {
      if (snapshot.gatewayId != null) {
        EntityUrn.parse(EntityUrn.gateway(snapshot.gatewayId!));
      }
      final query = <String, String>{
        'format': 'simplified',
        'limit': '$pageSize',
        if (snapshot.type != null) 'type': snapshot.type!.value,
        if (snapshot.gatewayId != null) 'gateway_id': snapshot.gatewayId!,
        'cursor': ?cursor,
      };
      final uri = ref
          .read(twinListEndpointProvider)
          .replace(queryParameters: query);
      final response = await ref
          .read(digitalTwinRepositoryProvider)
          .listTwins(
            type: snapshot.type,
            gatewayId: snapshot.gatewayId,
            limit: pageSize,
            cursor: cursor,
            simplified: true,
          );
      if (!current()) return;
      final page = TwinListPage.parse(response, uri);
      final ids = snapshot.items.map((e) => e.id).toSet();
      final fresh = page.items.where((e) => !ids.contains(e.id)).toList();
      if (cursor != null) _cursors.add(cursor);
      _pages++;
      final loop =
          page.nextCursor != null &&
          (page.items.isEmpty ||
              fresh.isEmpty ||
              _cursors.contains(page.nextCursor));
      final duplicate = fresh.length != page.items.length;
      final capacity = _pages >= maxPages && page.nextCursor != null;
      state = TwinListState(
        items: List.unmodifiable([...snapshot.items, ...fresh]),
        type: snapshot.type,
        gatewayId: snapshot.gatewayId,
        nextCursor: loop || duplicate || capacity ? null : page.nextCursor,
        atCapacity: capacity,
        error: loop || duplicate
            ? const FormatException('Twin pagination made no progress')
            : null,
      );
    } catch (error) {
      if (!current()) return;
      final denied =
          error is ApiException &&
          (error.statusCode == 401 ||
              error.statusCode == 403 ||
              error.statusCode == 404);
      state = TwinListState(
        items: denied ? const [] : snapshot.items,
        type: snapshot.type,
        gatewayId: snapshot.gatewayId,
        nextCursor: denied ? null : cursor,
        error: error,
      );
    }
  }
}

final twinListProvider = NotifierProvider<TwinListNotifier, TwinListState>(
  TwinListNotifier.new,
);
