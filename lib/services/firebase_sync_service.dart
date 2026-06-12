import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import 'db_service.dart';

class SyncRunResult {
  final bool configured;
  final int attempted;
  final int synced;
  final int failed;
  final String? message;

  const SyncRunResult({
    required this.configured,
    required this.attempted,
    required this.synced,
    required this.failed,
    this.message,
  });
}

class PullRunResult {
  final bool configured;
  final int records;
  final String? message;

  const PullRunResult({
    required this.configured,
    required this.records,
    this.message,
  });
}

class FirebaseSyncService {
  FirebaseSyncService({
    required DatabaseService databaseService,
    FirebaseFirestore? firestore,
  })  : _databaseService = databaseService,
        _firestore = firestore;

  final DatabaseService _databaseService;
  final FirebaseFirestore? _firestore;

  Future<SyncRunResult> syncPendingChanges({int limit = 50, bool retryFailed = true}) async {
    if (Firebase.apps.isEmpty) {
      return const SyncRunResult(
        configured: false,
        attempted: 0,
        synced: 0,
        failed: 0,
        message: 'Firebase is not initialized yet. Run FlutterFire configure and initialize Firebase in main().',
      );
    }

    if (retryFailed) {
      await _databaseService.retryFailedSyncItems();
    }
    final pending = List<Map<String, dynamic>>.from(
      await _databaseService.getPendingSyncQueue(limit: limit, includeFailed: retryFailed),
    );
    pending.sort((a, b) => _syncPriority(a).compareTo(_syncPriority(b)));
    var synced = 0;
    var failed = 0;
    final firestore = _firestore ?? FirebaseFirestore.instance;

    for (final queueItem in pending) {
      final queueId = queueItem['id']?.toString();
      if (queueId == null || queueId.isEmpty) continue;

      try {
        await _pushQueueItem(firestore, queueItem);
        await _databaseService.markSyncQueueItemSynced(queueId);
        synced++;
      } catch (error) {
        failed++;
        await _databaseService.markSyncQueueItemFailed(queueId, error.toString());
      }
    }

    return SyncRunResult(
      configured: true,
      attempted: pending.length,
      synced: synced,
      failed: failed,
    );
  }

  int _syncPriority(Map<String, dynamic> queueItem) {
    switch (queueItem['entity_type']?.toString()) {
      case 'company':
        return 0;
      case 'app_user':
        return 1;
      case 'store':
        return 2;
      case 'register':
        return 3;
      case 'product':
      case 'customer':
        return 4;
      case 'sale':
      case 'sale_item':
      case 'inventory_movement':
        return 5;
      default:
        return 9;
    }
  }

  Future<PullRunResult> pullCompanyData({
    required String companyId,
    required String storeId,
    String? userId,
  }) async {
    if (Firebase.apps.isEmpty) {
      return const PullRunResult(
        configured: false,
        records: 0,
        message: 'Firebase is not initialized yet.',
      );
    }

    final firestore = _firestore ?? FirebaseFirestore.instance;
    final companyRef = firestore.collection('companies').doc(companyId);
    var records = 0;
    try {
      final companySnap = await companyRef.get();
      final storeSnap = await companyRef.collection('stores').doc(storeId).get();
      DocumentSnapshot<Map<String, dynamic>>? userSnap;
      if (userId != null && userId.trim().isNotEmpty) {
        userSnap = await companyRef.collection('users').doc(userId).get();
      }
      if (companySnap.exists && storeSnap.exists && (userSnap == null || userSnap.exists)) {
        final company = _cleanFirestoreData(companySnap.data() ?? {})..['id'] = companySnap.id;
        final store = _cleanFirestoreData(storeSnap.data() ?? {})..['id'] = storeSnap.id;
        final user = _cleanFirestoreData(userSnap?.data() ?? {})
          ..['id'] = userSnap?.id ?? userId
          ..['company_id'] = companyId
          ..['store_id'] = storeId;
        await _databaseService.upsertRemoteCompanyProfile(
          company: company,
          store: store,
          user: user,
        );
        records += 3;
      }

      for (final entry in const {
        'products': 'products',
        'sales': 'sales',
        'sale_items': 'sale_items',
        'customers': 'customers',
        'inventory_movements': 'inventory_movements',
      }.entries) {
        final snapshot = await companyRef.collection(entry.key).where('store_id', isEqualTo: storeId).get();
        final rows = snapshot.docs.map((doc) {
          final data = _cleanFirestoreData(doc.data());
          data['sync_id'] ??= doc.id;
          return data;
        }).toList();
        await _databaseService.upsertRemoteRows(entry.value, rows);
        records += rows.length;
      }
    } catch (error) {
      return PullRunResult(configured: true, records: records, message: error.toString());
    }

    return PullRunResult(configured: true, records: records);
  }

  Future<void> _pushQueueItem(FirebaseFirestore firestore, Map<String, dynamic> queueItem) async {
    final payload = jsonDecode(queueItem['payload_json']?.toString() ?? '{}') as Map<String, dynamic>;
    final entityType = queueItem['entity_type']?.toString() ?? '';
    final entityId = queueItem['entity_id']?.toString() ?? '';
    final companyId = queueItem['company_id']?.toString() ?? DatabaseService.defaultCompanyId;

    if (entityType.isEmpty || entityId.isEmpty) {
      throw StateError('Sync queue item is missing entity metadata.');
    }

    final docData = {
      ...payload,
      'sync_meta': {
        'operation': queueItem['operation'],
        'queue_id': queueItem['id'],
        'synced_at': FieldValue.serverTimestamp(),
      },
    };

    if (entityType == 'company') {
      await firestore.collection('companies').doc(companyId).set(docData, SetOptions(merge: true));
      return;
    }

    final collectionName = _collectionNameFor(entityType);
    await firestore
        .collection('companies')
        .doc(companyId)
        .collection(collectionName)
        .doc(entityId)
        .set(docData, SetOptions(merge: true));

    if (entityType == 'app_user') {
      await firestore
          .collection('user_memberships')
          .doc(entityId)
          .collection('companies')
          .doc(companyId)
          .set({
        'company_id': companyId,
        'user_id': entityId,
        'role': payload['role'] ?? 'cashier',
        'company_name': payload['company_name'],
        'store_id': payload['store_id'],
        'register_id': payload['register_id'],
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  String _collectionNameFor(String entityType) {
    switch (entityType) {
      case 'store':
        return 'stores';
      case 'app_user':
        return 'users';
      case 'product':
        return 'products';
      case 'sale':
        return 'sales';
      case 'sale_item':
        return 'sale_items';
      case 'customer':
        return 'customers';
      case 'inventory_movement':
        return 'inventory_movements';
      default:
        return entityType;
    }
  }

  Map<String, dynamic> _cleanFirestoreData(Map<String, dynamic> data) {
    return data.map((key, value) => MapEntry(key, _cleanFirestoreValue(value)));
  }

  dynamic _cleanFirestoreValue(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map<String, dynamic>) return _cleanFirestoreData(value);
    if (value is List) return value.map(_cleanFirestoreValue).toList();
    return value;
  }
}
