import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/in_app_notification.dart';
import '../models/models.dart';
import '../widgets/in_app_notification_banner.dart';
import 'app_provider.dart';

class NotificationProvider extends ChangeNotifier {
  static const String _readIdsKey = 'remaki_read_notification_ids';

  final List<InAppNotificationItem> _notifications = [];
  final Set<String> _readIds = {};
  final Set<String> _shownBannerIds = {};

  List<InAppNotificationItem> get notifications => List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  NotificationProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedReadIds = prefs.getStringList(_readIdsKey) ?? [];
      _readIds.addAll(savedReadIds);
      notifyListeners();
    } catch (e) {
      debugPrint('NotificationProvider _init error: $e');
    }
  }

  Future<void> markAsRead(String id) async {
    _readIds.add(id);
    for (var n in _notifications) {
      if (n.id == id) {
        n.isRead = true;
      }
    }
    notifyListeners();
    _saveReadIds();
  }

  Future<void> markAllAsRead() async {
    for (var n in _notifications) {
      n.isRead = true;
      _readIds.add(n.id);
    }
    notifyListeners();
    _saveReadIds();
  }

  void clearAll() {
    _notifications.clear();
    notifyListeners();
  }

  void reset() {
    _notifications.clear();
    _readIds.clear();
    _shownBannerIds.clear();
    notifyListeners();
  }

  Future<void> _saveReadIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readIdsKey, _readIds.toList());
    } catch (_) {}
  }

  // ===========================================================================
  // OWNER / ADMIN NOTIFICATION ENGINE
  // ===========================================================================
  void checkOwnerNotifications({
    required AppProvider appProvider,
    required List<dynamic> pendingRequests,
    BuildContext? context,
  }) {
    final List<InAppNotificationItem> items = [];
    final now = DateTime.now();
    InAppNotificationItem? bannerCandidate;

    // 1. Payment Approval: Tenant Submitted Payment Proof
    for (var req in pendingRequests) {
      final reqId = req['id']?.toString() ?? '';
      if (reqId.isEmpty) continue;

      final tenantId = req['tenantProfileId']?.toString() ?? '';
      final tenantName = req['tenantName']?.toString() ?? 'Resident';
      final amount = (req['amount'] as num?)?.toDouble() ?? 0.0;

      // Find tenant's room
      String roomStr = 'Assigned Bed';
      final matchedTenant = appProvider.currentTenants.firstWhere(
        (t) => t.id == tenantId || t.name == tenantName,
        orElse: () => Tenant(
          id: '',
          name: '',
          phone: '',
          email: '',
          roomId: '',
          bedId: '',
          moveInDate: DateTime.now(),
          rentAmount: 0,
          securityDeposit: 0,
          rentDueDate: DateTime.now(),
        ),
      );

      if (matchedTenant.roomId.isNotEmpty) {
        final room = appProvider.rooms.firstWhere(
          (r) => r.id == matchedTenant.roomId,
          orElse: () => Room(id: '', number: '', floor: '', capacity: 0, beds: []),
        );
        if (room.number.isNotEmpty) {
          roomStr = formatRoomName(room.number);
        }
      }

      final id = 'approval_$reqId';
      final isRead = _readIds.contains(id);

      final item = InAppNotificationItem(
        id: id,
        title: '💰 New Payment for Approval',
        message: '$tenantName ($roomStr) submitted ₹${amount.toStringAsFixed(0)} proof for approval.',
        category: NotificationCategory.paymentApproval,
        priority: NotificationPriority.urgent,
        targetRoute: '/approvals',
        timestamp: req['createdAt'] != null
            ? (DateTime.tryParse(req['createdAt'].toString())?.toLocal() ?? now)
            : now,
        iconData: Icons.verified_outlined,
        iconColor: const Color(0xFF4F46E5),
        iconBgColor: const Color(0xFFEEF2FF),
        data: req as Map<String, dynamic>?,
        isRead: isRead,
      );

      items.add(item);

      if (!isRead && !_shownBannerIds.contains(id) && bannerCandidate == null) {
        bannerCandidate = item;
      }
    }

    // 2. Collection & Dues: Daily Morning Rent Digest (Active 1st to 5th or when rent is pending)
    final unpaidRentTenants = appProvider.unpaidRentTenants;
    if (unpaidRentTenants.isNotEmpty) {
      final pendingSum = appProvider.pendingRentOnly;
      final digestId = 'rent_digest_${now.year}_${now.month}_${now.day}';
      final isRead = _readIds.contains(digestId);

      final item = InAppNotificationItem(
        id: digestId,
        title: '📊 Rent Collection Update',
        message: '${unpaidRentTenants.length} tenants have rent due this week. Total pending: ₹${NumberFormat('#,##,###').format(pendingSum)}.',
        category: NotificationCategory.rentDigest,
        priority: NotificationPriority.medium,
        targetRoute: '/unpaid_tenants',
        timestamp: DateTime(now.year, now.month, now.day, 9, 0),
        iconData: Icons.analytics_rounded,
        iconColor: const Color(0xFF2563EB),
        iconBgColor: const Color(0xFFEFF6FF),
        isRead: isRead,
      );

      items.add(item);
    }

    // 3. Overdue Escalation: Tenant Exceeds Due Date by 3+ Days
    for (var t in appProvider.currentTenants) {
      if (t.pendingRentAmount > 0) {
        final daysOverdue = now.difference(t.rentDueDate).inDays;
        if (daysOverdue >= 3) {
          final room = appProvider.rooms.firstWhere(
            (r) => r.id == t.roomId,
            orElse: () => Room(id: '', number: '', floor: '', capacity: 0, beds: []),
          );
          final roomStr = room.number.isNotEmpty ? formatRoomName(room.number) : 'Assigned Bed';
          final overdueId = 'overdue_${t.id}_${now.year}_${now.month}_${now.day}';
          final isRead = _readIds.contains(overdueId);

          final item = InAppNotificationItem(
            id: overdueId,
            title: '⚠️ Overdue Rent Alert',
            message: '${t.name} ($roomStr) is $daysOverdue days overdue (₹${t.pendingRentAmount.toStringAsFixed(0)} pending).',
            category: NotificationCategory.overdueEscalation,
            priority: NotificationPriority.urgent,
            targetRoute: '/tenant_profile/${t.id}',
            timestamp: now,
            iconData: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBgColor: const Color(0xFFFEE2E2),
            data: {'tenantId': t.id, 'daysOverdue': daysOverdue},
            isRead: isRead,
          );

          items.add(item);

          if (!isRead && !_shownBannerIds.contains(overdueId) && bannerCandidate == null) {
            bannerCandidate = item;
          }
        }
      }
    }

    _notifications.clear();
    _notifications.addAll(items);
    notifyListeners();

    // Trigger in-app floating banner for the newest urgent notification if context available
    if (context != null && bannerCandidate != null && context.mounted) {
      _shownBannerIds.add(bannerCandidate.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          InAppNotificationBanner.show(context, bannerCandidate!);
        }
      });
    }
  }

  // ===========================================================================
  // TENANT NOTIFICATION ENGINE (Payment Status Only)
  // ===========================================================================
  void checkTenantNotifications({
    required Map<String, dynamic>? profileData,
    required double totalDue,
    required bool isPending,
    required String? rejectionReason,
    BuildContext? context,
  }) {
    if (profileData == null) return;

    final tenantId = profileData['id']?.toString() ?? '';
    final paymentStatus = profileData['paymentStatus']?.toString() ?? 'UNPAID';
    final rentDueDate = profileData['rentDueDate']?.toString() ?? '';
    final now = DateTime.now();

    final List<InAppNotificationItem> items = [];
    InAppNotificationItem? bannerCandidate;

    final bool isPaid = !isPending && (paymentStatus == 'PAID' || totalDue <= 0);
    final bool isRejected = paymentStatus == 'REJECTED' ||
        (rejectionReason != null && rejectionReason.isNotEmpty);

    // 1. Payment Approved
    if (isPaid) {
      final id = 'tenant_paid_${tenantId}_$rentDueDate';
      final isRead = _readIds.contains(id);

      final item = InAppNotificationItem(
        id: id,
        title: '✅ Payment Confirmed & Approved',
        message: 'Your rent payment has been verified & approved by management. Rent receipt is available.',
        category: NotificationCategory.paymentStatus,
        priority: NotificationPriority.high,
        targetRoute: '/tenant_home?tab=1',
        timestamp: now,
        iconData: Icons.check_circle_rounded,
        iconColor: const Color(0xFF10B981),
        iconBgColor: const Color(0xFFDCFCE7),
        isRead: isRead,
      );

      items.add(item);

      if (!isRead && !_shownBannerIds.contains(id)) {
        bannerCandidate = item;
      }
    }
    // 2. Payment Rejected
    else if (isRejected) {
      final id = 'tenant_rejected_${tenantId}_${rejectionReason.hashCode}';
      final isRead = _readIds.contains(id);
      final reasonMsg = rejectionReason != null && rejectionReason.isNotEmpty
          ? 'Declined: "$rejectionReason". Tap to review and re-upload valid proof.'
          : 'Payment proof was declined. Tap to re-upload valid proof.';

      final item = InAppNotificationItem(
        id: id,
        title: '❌ Payment Proof Declined',
        message: reasonMsg,
        category: NotificationCategory.paymentStatus,
        priority: NotificationPriority.urgent,
        targetRoute: '/tenant_home?tab=1',
        timestamp: now,
        iconData: Icons.cancel_rounded,
        iconColor: const Color(0xFFEF4444),
        iconBgColor: const Color(0xFFFEE2E2),
        isRead: isRead,
      );

      items.add(item);

      if (!isRead && !_shownBannerIds.contains(id)) {
        bannerCandidate = item;
      }
    }
    // 3. Payment Pending Review
    else if (isPending) {
      final id = 'tenant_pending_$tenantId';
      final isRead = _readIds.contains(id);

      final item = InAppNotificationItem(
        id: id,
        title: '⏳ Payment Under Verification',
        message: 'Your payment submission is pending review by PG management.',
        category: NotificationCategory.paymentStatus,
        priority: NotificationPriority.medium,
        targetRoute: '/tenant_home?tab=1',
        timestamp: now,
        iconData: Icons.hourglass_top_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBgColor: const Color(0xFFFEF3C7),
        isRead: isRead,
      );

      items.add(item);
    }

    _notifications.clear();
    _notifications.addAll(items);
    notifyListeners();

    // Trigger in-app floating banner for tenant payment status change
    if (context != null && bannerCandidate != null && context.mounted) {
      _shownBannerIds.add(bannerCandidate.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          InAppNotificationBanner.show(context, bannerCandidate!);
        }
      });
    }
  }
}
