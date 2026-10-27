import 'package:flutter/material.dart';

enum NotificationCategory {
  paymentApproval,
  rentDigest,
  overdueEscalation,
  paymentStatus,
}

enum NotificationPriority {
  urgent,
  high,
  medium,
  low,
}

class InAppNotificationItem {
  final String id;
  final String title;
  final String message;
  final NotificationCategory category;
  final NotificationPriority priority;
  final String targetRoute;
  final DateTime timestamp;
  final IconData iconData;
  final Color iconColor;
  final Color iconBgColor;
  final Map<String, dynamic>? data;
  bool isRead;

  InAppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.priority,
    required this.targetRoute,
    required this.timestamp,
    required this.iconData,
    required this.iconColor,
    required this.iconBgColor,
    this.data,
    this.isRead = false,
  });

  String get categoryLabel {
    switch (category) {
      case NotificationCategory.paymentApproval:
        return 'Payment Approval';
      case NotificationCategory.rentDigest:
        return 'Collection & Dues';
      case NotificationCategory.overdueEscalation:
        return 'Overdue Escalation';
      case NotificationCategory.paymentStatus:
        return 'Payment Status';
    }
  }

  String get priorityLabel {
    switch (priority) {
      case NotificationPriority.urgent:
        return 'Urgent';
      case NotificationPriority.high:
        return 'High';
      case NotificationPriority.medium:
        return 'Medium';
      case NotificationPriority.low:
        return 'Normal';
    }
  }

  Color get priorityColor {
    switch (priority) {
      case NotificationPriority.urgent:
        return const Color(0xFFEF4444);
      case NotificationPriority.high:
        return const Color(0xFFF59E0B);
      case NotificationPriority.medium:
        return const Color(0xFF3B82F6);
      case NotificationPriority.low:
        return const Color(0xFF10B981);
    }
  }

  Color get priorityBgColor {
    switch (priority) {
      case NotificationPriority.urgent:
        return const Color(0xFFFEE2E2);
      case NotificationPriority.high:
        return const Color(0xFFFEF3C7);
      case NotificationPriority.medium:
        return const Color(0xFFEFF6FF);
      case NotificationPriority.low:
        return const Color(0xFFDCFCE7);
    }
  }
}
