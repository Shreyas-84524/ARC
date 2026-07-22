import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';

class MoneyRepository {
  final Box<Transaction> _txBox =
      HiveService().getBox<Transaction>(HiveService.moneyBoxName);
  final Box _settingsBox = HiveService().getBox(HiveService.settingsBoxName);
  final Box _queueBox = HiveService().getBox(HiveService.moneySyncQueueBoxName);
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;

  List<Transaction> getTransactions() => _txBox.values.toList();

  double getMonthlyBudget(String yearMonth) {
    try {
      final value = _settingsBox.get('budget_$yearMonth', defaultValue: 0.0);
      return (value as num).toDouble();
    } catch (_) {
      return 0.0;
    }
  }

  Future<void> saveMonthlyBudget(String yearMonth, double amount) async {
    await _settingsBox.put('budget_$yearMonth', amount);
    try {
      await _firestore
          .collection('budgets')
          .doc(yearMonth)
          .set({'amount': amount, 'month': yearMonth});
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
        'data': tx.toMap(),
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

  Future<void> saveMonthlySummary(MonthlySummary summary) async {
    await _settingsBox.put('summary_${summary.month}', summary.toMap());
    try {
      await _firestore
          .collection('monthlySummaries')
          .doc(summary.month)
          .set(summary.toMap());
      await _queueBox.delete('summary_${summary.month}');
    } catch (e) {
      await _queueBox.put('summary_${summary.month}', {
        'id': summary.month,
        'type': 'summary',
        'action': 'upsert',
        'data': summary.toMap(),
      });
    }
  }

  Future<void> syncPending() async {
    if (_queueBox.isEmpty) return;

    final keys = List.from(_queueBox.keys);
    for (final key in keys) {
      final item = _queueBox.get(key);
      if (item == null) continue;

      final id = item['id'] as String?;
      final type = item['type'] as String?;
      final action = item['action'] as String?;

      if (id == null || type == null || action == null) {
        await _queueBox.delete(key);
        continue;
      }

      try {
        if (type == 'budget') {
          final val = (item['value'] as num).toDouble();
          await _firestore
              .collection('budgets')
              .doc(id)
              .set({'amount': val, 'month': id});
        } else if (type == 'tx') {
          if (action == 'upsert') {
            final tx = _txBox.get(id);
            final payload = tx?.toMap() ?? (item['data'] as Map<String, dynamic>?);
            if (payload != null) {
              await _firestore.collection('transactions').doc(id).set(payload);
            }
          } else if (action == 'delete') {
            await _firestore.collection('transactions').doc(id).delete();
          }
        } else if (type == 'summary') {
          final payload = item['data'] as Map<String, dynamic>?;
          if (payload != null) {
            await _firestore.collection('monthlySummaries').doc(id).set(payload);
          }
        }
        await _queueBox.delete(key);
      } catch (e) {
        debugPrint('Failed to sync money queue item $key: $e');
        break; // Stop and retry later if network remains unavailable
      }
    }
  }
}
