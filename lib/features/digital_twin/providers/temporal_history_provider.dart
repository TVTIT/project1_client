import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/session.dart';
import '../../../core/network/api_exception.dart';
import '../data/digital_twin_dto.dart';
import '../data/digital_twin_repository.dart';
import 'digital_twin_providers.dart';

enum TemporalGuidanceCode {
  rawLimitExceeded,
  rawResolutionRequired,
  resolutionTooFine,
  queryRangeExceeded,
  invalidDateFormat,
}

@immutable
class TemporalHistoryState {
  static const _unchanged = Object();

  const TemporalHistoryState({
    this.isLoading = false,
    this.response,
    this.error,
    this.isStale = false,
    this.appliedQuery,
    this.guidanceCode,
    this.requestId,
  });

  final bool isLoading;
  final TwinTemporalResponse? response;
  final Object? error;
  final bool isStale;
  final TemporalQueryParameters? appliedQuery;
  final TemporalGuidanceCode? guidanceCode;
  final String? requestId;

  bool get hasError => error != null;

  TemporalHistoryState copyWith({
    bool? isLoading,
    Object? response = _unchanged,
    Object? Function()? error,
    bool? isStale,
    Object? appliedQuery = _unchanged,
    Object? Function()? guidanceCode,
    Object? Function()? requestId,
  }) {
    return TemporalHistoryState(
      isLoading: isLoading ?? this.isLoading,
      response: identical(response, _unchanged)
          ? this.response
          : response as TwinTemporalResponse?,
      error: error != null ? error() : this.error,
      isStale: isStale ?? this.isStale,
      appliedQuery: identical(appliedQuery, _unchanged)
          ? this.appliedQuery
          : appliedQuery as TemporalQueryParameters?,
      guidanceCode: guidanceCode != null
          ? guidanceCode() as TemporalGuidanceCode?
          : this.guidanceCode,
      requestId: requestId != null ? requestId() as String? : this.requestId,
    );
  }
}

class TemporalHistoryNotifier extends Notifier<TemporalHistoryState> {
  TemporalHistoryNotifier(this.sensorUrn);

  final String sensorUrn;
  int _seq = 0;

  @override
  TemporalHistoryState build() {
    ref.watch(twinSessionScopeProvider);
    _seq++;
    return const TemporalHistoryState();
  }

  Future<void> refreshApplied() async {
    final query = state.appliedQuery;
    if (query != null) {
      await fetchTemporal(query);
    }
  }

  Future<void> fetchTemporal(TemporalQueryParameters query) async {
    if (!ref.read(sessionProvider).isAuthenticated) return;
    final seq = ++_seq;

    try {
      query.validate();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: () => e,
        guidanceCode: () => query.range > const Duration(hours: 744)
            ? TemporalGuidanceCode.queryRangeExceeded
            : query.isRaw && query.range > const Duration(seconds: 10)
            ? TemporalGuidanceCode.rawResolutionRequired
            : TemporalGuidanceCode.invalidDateFormat,
      );
      return;
    }

    final expectedEpoch = ref.read(sessionProvider.notifier).sessionEpoch;
    final expectedUserId = ref.read(currentUserProvider)?.userId;

    state = state.copyWith(
      isLoading: true,
      error: () => null,
      guidanceCode: () => null,
      requestId: () => null,
    );

    try {
      final repo = ref.read(digitalTwinRepositoryProvider);
      final res = await repo.getSensorTemporal(
        sensorUrn,
        attrs: query.attrs,
        timeAt: query.timeAt,
        endTimeAt: query.endTimeAt,
        aggrPeriodDuration: query.effectiveAggrPeriodDuration,
        aggrMethods: query.isRaw ? null : query.aggrMethods,
        maxPoints: query.maxPoints,
      );

      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      if (res.id != sensorUrn) {
        throw const FormatException(
          'Sensor URN identity mismatch in temporal response',
        );
      }

      res.validateFor(sensorUrn, query);
      state = TemporalHistoryState(
        isLoading: false,
        response: res,
        error: null,
        isStale: false,
        appliedQuery: query,
        guidanceCode: null,
        requestId: null,
      );
    } catch (e) {
      if (!ref.mounted) return;
      if (seq != _seq ||
          expectedEpoch != ref.read(sessionProvider.notifier).sessionEpoch ||
          expectedUserId != ref.read(currentUserProvider)?.userId) {
        return;
      }

      TemporalGuidanceCode? guidance;
      String? reqId;
      bool denied = false;

      if (e is ApiException) {
        reqId = e.requestId;
        if (e.code == 'raw_limit_exceeded') {
          guidance = TemporalGuidanceCode.rawLimitExceeded;
        } else if (e.code == 'raw_resolution_required') {
          guidance = TemporalGuidanceCode.rawResolutionRequired;
        } else if (e.code == 'resolution_too_fine') {
          guidance = TemporalGuidanceCode.resolutionTooFine;
        }
        denied =
            e.statusCode == 401 || e.statusCode == 403 || e.statusCode == 404;
      }

      final isTransient =
          e is ApiException && (e.statusCode == 503 || e.statusCode == 504);
      final retainStale =
          !denied &&
          state.response != null &&
          (isTransient || e is NetworkException || e is TimeoutException);

      state = state.copyWith(
        isLoading: false,
        response: denied ? null : state.response,
        error: () => e,
        isStale: retainStale,
        guidanceCode: () => guidance,
        requestId: () => reqId,
      );
    }
  }
}

final temporalHistoryProvider = NotifierProvider.autoDispose
    .family<TemporalHistoryNotifier, TemporalHistoryState, String>(
      TemporalHistoryNotifier.new,
    );
