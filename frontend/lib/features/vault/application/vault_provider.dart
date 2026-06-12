import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/current_user_provider.dart';
import '../../games/application/game_backfill_provider.dart';
import '../../home/application/home_provider.dart';
import '../../reader/data/dictionary_api.dart';
import '../data/highlight_api.dart';
import '../data/vault_api.dart';

final vaultApiProvider = Provider<VaultApi>((ref) {
  return VaultApi();
});

final dictionaryApiProvider = Provider<DictionaryApi>((ref) {
  return DictionaryApi();
});

final vaultSearchQueryProvider = StateProvider<String>((ref) => '');
final vaultSelectedBookIdProvider = StateProvider<String?>((ref) => null);

final vaultItemsProvider = FutureProvider<List<VaultItemRead>>((ref) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return [];
  
  final query = ref.watch(vaultSearchQueryProvider);
  final selectedBookId = ref.watch(vaultSelectedBookIdProvider);
  final api = ref.watch(vaultApiProvider);
  return api.listVaultItems(
    userId,
    bookId: selectedBookId,
    query: query,
  );
});

final highlightApiProvider = Provider<HighlightApi>((ref) {
  return HighlightApi();
});

final bookVaultCountProvider = FutureProvider.family<int, String>((ref, bookId) async {
  final userId = ref.watch(sessionUserIdProvider);
  if (userId == null) return 0;
  final api = ref.watch(vaultApiProvider);
  final items = await api.listVaultItems(userId, bookId: bookId);
  return items.length;
});

final vaultSyncNotifierProvider = Provider<VaultSyncNotifier>((ref) {
  return VaultSyncNotifier(ref);
});

class VaultSyncNotifier {
  const VaultSyncNotifier(this._ref);
  final Ref _ref;
  void onHighlightCaptured() {
    _ref.invalidate(vaultItemsProvider);
    _ref.invalidate(homeSummaryProvider);
    _ref.invalidate(bookVaultCountProvider);
    triggerGameBackfill(_ref);
  }
}
