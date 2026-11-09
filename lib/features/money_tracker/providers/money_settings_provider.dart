import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:arc/features/money_tracker/repository/money_repository.dart';
import 'package:arc/providers/global_providers.dart';

/// Provider for user preference: Whether income should be added to the monthly budget
/// and included on the Analytics page.
final addIncomeToBudgetProvider =
    StateNotifierProvider<AddIncomeToBudgetNotifier, bool>((ref) {
      final repo = ref.watch(moneyRepositoryProvider);
      return AddIncomeToBudgetNotifier(repo);
    });

class AddIncomeToBudgetNotifier extends StateNotifier<bool> {
  final MoneyRepository _repository;

  AddIncomeToBudgetNotifier(this._repository) : super(false) {
    state = _repository.getAddIncomeToBudget();
  }

  Future<void> setAddIncomeToBudget(bool value) async {
    await _repository.setAddIncomeToBudget(value);
    state = value;
  }

  void refresh() {
    state = _repository.getAddIncomeToBudget();
  }
}
