import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client_meter_record.dart';
import '../utils/text_normalize.dart';
import 'meter_providers.dart';

/// Text typed in the client list search bar.
final clientSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Status filter for the client list; null means "Todos".
final clientFilterStatusProvider =
    StateProvider.autoDispose<VisitStatus?>((ref) => null);

/// Clients matching the search query (name or client number) and the
/// status filter, sorted by owner name.
final filteredClientsProvider =
    Provider.autoDispose<List<ClientMeterRecord>>((ref) {
  final clients = ref.watch(clientRecordsProvider);
  final query = normalizeForSearch(ref.watch(clientSearchQueryProvider));
  final status = ref.watch(clientFilterStatusProvider);

  final filtered = clients.where((client) {
    if (status != null && client.visitStatus != status) return false;
    if (query.isEmpty) return true;
    return normalizeForSearch(client.ownerName).contains(query) ||
        normalizeForSearch(client.clientNumber).contains(query);
  }).toList()
    ..sort((a, b) => normalizeForSearch(a.ownerName)
        .compareTo(normalizeForSearch(b.ownerName)));

  return filtered;
});
