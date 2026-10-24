import '../../../core/network/api_client.dart';
import '../../../core/network/link_header.dart';
import 'digital_twin_dto.dart';

/// A typed root-array page. Never fetches a Link URI directly.
class TwinListPage {
  const TwinListPage(this.items, this.nextCursor);
  final List<TwinSummaryItem> items;
  final String? nextCursor;

  factory TwinListPage.parse(ApiResponse response, Uri requestUri) {
    final items = response.asList
        .map((row) {
          if (row is! Map<String, dynamic>) {
            throw const FormatException('Invalid Twin summary row');
          }
          return TwinSummaryItem.fromJson(row);
        })
        .toList(growable: false);
    final query = requestUri.queryParameters;
    final limit = int.parse(query['limit'] ?? '50');
    if (items.length > limit ||
        items.map((e) => e.id).toSet().length != items.length) {
      throw const FormatException(
        'Invalid Twin page size or duplicate identity',
      );
    }
    for (final item in items) {
      if ((query['type'] != null && item.type != query['type']) ||
          (query['gateway_id'] != null &&
              item.gatewayId != query['gateway_id'])) {
        throw const FormatException('Twin response violates active filters');
      }
    }
    final next = SafeLinkParser.resolveAndValidateNextLink(
      rawLinkHeader: response.link,
      requestUri: requestUri,
      baseUri: requestUri,
      expectedPath: requestUri.path,
      allowedQueryParams: const {
        'type',
        'gateway_id',
        'limit',
        'cursor',
        'format',
      },
    );
    if (next == null) return TwinListPage(List.unmodifiable(items), null);
    final nextQuery = next.queryParameters;
    for (final key in ['type', 'gateway_id', 'format']) {
      if (nextQuery[key] != query[key]) {
        throw const FormatException(
          'Twin Link changes active filters or format',
        );
      }
    }
    if (nextQuery['limit'] != null && nextQuery['limit'] != query['limit']) {
      throw const FormatException('Twin Link changes page size');
    }
    final cursor = nextQuery['cursor'];
    if (cursor == null || cursor.isEmpty) {
      throw const FormatException('Twin Link is missing cursor');
    }
    return TwinListPage(List.unmodifiable(items), cursor);
  }
}
