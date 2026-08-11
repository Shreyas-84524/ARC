import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:hive/hive.dart';
import 'package:arc/core/services/hive_service.dart';
import 'package:arc/features/money_tracker/models/transaction_model.dart';
import 'package:arc/features/money_tracker/models/monthly_summary_model.dart';

class MoneyRepository {
  final String? _userId;
  final Box<Transaction> _txBox;
  final Box _settingsBox;
  final Box _queueBox;
  final fs.FirebaseFirestore? _firestore;

  MoneyRepository({String? userId, fs.FirebaseFirestore? firestore})
      : _userId = userId,
        _txBox = HiveService().getUserBox<Transaction>(HiveService.moneyBoxName, userId),
        _settingsBox = HiveService().getUserBox(HiveService.settingsBoxName, userId),
        _queueBox = HiveService().getUserBox(HiveService.moneySyncQueueBoxName, userId),
        _firestore = firestore;

  fs.FirebaseFirestore get _db => _firestore ?? fs.FirebaseFirestore.instance;

  String? get userId => _userId;

  fs.CollectionReference<Map<String, dynamic>> _txRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _db.collection('users').doc(uid).collection('transactions');
    }
    return _db.collection('transactions');
  }

  fs.CollectionReference<Map<String, dynamic>> _budgetsRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _db.collection('users').doc(uid).collection('budgets');
    }
    return _db.collection('budgets');
  }

  fs.CollectionReference<Map<String, dynamic>> _summariesRef() {
    final uid = _userId;
    if (uid != null && uid.isNotEmpty) {
      return _db.collection('users').doc(uid).collection('monthlySummaries');
    }
    return _db.collection('monthlySummaries');
  }

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
      await _budgetsRef()
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
      await _txRef().doc(tx.id).set(tx.toMap());
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
      await _txRef().doc(id).delete();
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
      await _summariesRef()
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

  Future<bool> syncPending() async {
    if (_queueBox.isEmpty) return true;

    debugPrint('[MoneyRepository.syncPending] Found ${_queueBox.length} pending money sync items for UID: $_userId');
    final keys = List.from(_queueBox.keys);
    bool allSuccess = true;

    for (final key in keys) {
      final item = _queueBox.get(key);
      if (item == null) {
        await _queueBox.delete(key);
        continue;
      }

      final id = item['id'] as String?;
      final type = item['type'] as String?;
      final action = item['action'] as String?;

      if (id == null || type == null || action == null) {
        debugPrint('[MoneyRepository.syncPending] Removing malformed money queue item with key: $key');
        await _queueBox.delete(key);
        continue;
      }

      try {
        if (type == 'budget') {
          final docPath = _budgetsRef().doc(id).path;
          final val = (item['value'] as num).toDouble();
          debugPrint('[MoneyRepository.syncPending] Attempting budget set for month: $id on path: $docPath');
          await _budgetsRef()
              .doc(id)
              .set({'amount': val, 'month': id}).timeout(const Duration(seconds: 8));
        } else if (type == 'tx') {
          final docPath = _txRef().doc(id).path;
          debugPrint('[MoneyRepository.syncPending] Attempting $action for transaction ID: $id on path: $docPath');
          if (action == 'upsert') {
            final tx = _txBox.get(id);
            final payload = tx?.toMap() ?? (item['data'] as Map<String, dynamic>?);
            if (payload != null) {
              await _txRef().doc(id).set(payload).timeout(const Duration(seconds: 8));
            } else {
              await _queueBox.delete(key);
              continue;
            }
          } else if (action == 'delete') {
            await _txRef().doc(id).delete().timeout(const Duration(seconds: 8));
          }
        } else if (type == 'summary') {
          final docPath = _summariesRef().doc(id).path;
          final payload = item['data'] as Map<String, dynamic>?;
          debugPrint('[MoneyRepository.syncPending] Attempting summary set for month: $id on path: $docPath');
          if (payload != null) {
            await _summariesRef().doc(id).set(payload).timeout(const Duration(seconds: 8));
          } else {
            await _queueBox.delete(key);
            continue;
          }
        }
        await _queueBox.delete(key);
        debugPrint('[MoneyRepository.syncPending] SUCCESS: $action for money item $key completed. Queue item removed.');
      } catch (e) {
        debugPrint('[MoneyRepository.syncPending] FAILURE: Sync failed for money queue item $key. Error: $e');
        allSuccess = false;
        break; // Stop and retry later if network remains unavailable
      }
    }
    return allSuccess && _queueBox.isEmpty;
  }
}
