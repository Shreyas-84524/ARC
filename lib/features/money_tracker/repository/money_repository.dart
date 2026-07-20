import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';

class MoneyRepository {
  final Box<Transaction> _txBox = HiveService().getBox(HiveService.moneyBoxName) as Box<Transaction>;
  final Box _settingsBox = HiveService().getBox(HiveService.settingsBoxName);
  final Box _queueBox = HiveService().getBox(HiveService.moneySyncQueueBoxName);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Transaction> getTransactions() => _txBox.values.toList();

  double getMonthlyBudget(String yearMonth) {
    return (_settingsBox.get('budget_$yearMonth', defaultValue: 0.0) as num).toDouble();
  }

  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {
    await _settingsBox.put('budget_$yearMonth', amount);
    try {
      await _firestore.collection('budgets').doc(yearMonth).set({'amount': amount});
      await _queueBox.delete('budget_$yearMonth');
    } catch (e) {
      await _queueBox.put('budget_$yearMonth', {
        'id': yearMonth,
        'type': 'budget',
        'action': 'upsert',
        'value': amount,
      });
    }
  }

  Future<void> saveTransaction(Transaction tx) async {
    await _txBox.put(tx.id, tx);
    try {
      await _firestore.collection('transactions').doc(tx.id).set(tx.toMap());
      await _queueBox.delete('tx_${tx.id}');
    } catch (e) {
      await _queueBox.put('tx_${tx.id}', {
        'id': tx.id,
        'type': 'tx',
        'action': 'upsert',
      });
    }
  }

  Future<void> deleteTransaction(String id) async {
    await _txBox.delete(id);
    try {
      await _firestore.collection('transactions').doc(id).delete();
      await _queueBox.delete('tx_$id');
    } catch (e) {
      await _queueBox.put('tx_$id', {
        'id': id,
        'type': 'tx',
        'action': 'delete',
      });
    }
  }

  Future<void> syncPending() async {
    if (_queueBox.isEmpty) return;

    final keys = List.from(_queueBox.keys);
    for (final key in keys) {
      final item = _queueBox.get(key);
      if (item == null) continue;

      final id = item['id'] as String;
      final type = item['type'] as String;
      final action = item['action'] as String;

      try {
        if (type == 'budget') {
          final val = (item['value'] as num).toDouble();
          await _firestore.collection('budgets').doc(id).set({'amount': val});
        } else if (type == 'tx') {
          if (action == 'upsert') {
            final tx = _txBox.get(id);
            if (tx != null) {
              await _firestore.collection('transactions').doc(id).set(tx.toMap());
            }
          } else if (action == 'delete') {
            await _firestore.collection('transactions').doc(id).delete();
          }
        }
        await _queueBox.delete(key);
      } catch (e) {
        debugPrint('Failed to sync queue item $key: $e');
        break; // Stop and retry later if network fails again
      }
    }
  }
}
