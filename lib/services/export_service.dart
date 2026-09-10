import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../providers/app_provider.dart';

class ExportResult {
  final bool success;
  final String fileName;
  final String filePath;
  final int recordCount;
  final String? error;

  ExportResult({
    required this.success,
    required this.fileName,
    required this.filePath,
    required this.recordCount,
    this.error,
  });
}

class ExportService {
  /// Helper to safely escape CSV cell content
  static String _escape(dynamic value) {
    if (value == null) return '""';
    final str = value.toString().replaceAll('"', '""');
    return '"$str"';
  }

  /// Generate Master Property Backup CSV for Excel
  static String generateMasterCsv(AppProvider provider) {
    final buffer = StringBuffer();
    final now = DateTime.now();
    final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    // UTF-8 BOM so Microsoft Excel automatically recognizes UTF-8 formatting
    buffer.write('\uFEFF');

    // 1. PROPERTY HEADER
    buffer.writeln('${_escape('REMAKI PROPERTY MANAGEMENT SYSTEM - FULL EXCEL BACKUP')},,,,');
    buffer.writeln('${_escape('Property Name:')},${_escape(provider.pgName)},${_escape('Export Date:')},${_escape(dateStr)},');
    buffer.writeln('${_escape('Administrator:')},${_escape(provider.adminName)},${_escape('Total Tenants:')},${_escape(provider.tenants.length)},');
    buffer.writeln('');

    // 2. TENANTS DATA
    buffer.writeln('${_escape('=== SECTION 1: TENANT DIRECTORY & FINANCIAL BALANCES ===')},,,,,,,,,,,,,');
    buffer.writeln([
      _escape('Tenant ID'),
      _escape('Full Name'),
      _escape('Mobile Number'),
      _escape('Email'),
      _escape('Room No'),
      _escape('Bed Label'),
      _escape('Monthly Rent (₹)'),
      _escape('Security Deposit (₹)'),
      _escape('Rent Due Date'),
      _escape('Move-in Date'),
      _escape('Rent Status'),
      _escape('Pending Rent (₹)'),
      _escape('Pending Utility Bills (₹)'),
      _escape('Total Outstanding Due (₹)'),
      _escape('Emergency Contact'),
      _escape('Occupation'),
      _escape('Permanent Address'),
    ].join(','));

    for (final t in provider.tenants) {
      final room = provider.rooms.where((r) => r.id == t.roomId).firstOrNull;
      final roomNo = room?.number ?? t.roomId;
      final bed = room?.beds.where((b) => b.id == t.bedId).firstOrNull;
      final bedLabel = bed?.name ?? t.bedId;

      buffer.writeln([
        _escape(t.id),
        _escape(t.name),
        _escape(t.phone),
        _escape(t.email),
        _escape(roomNo),
        _escape(bedLabel),
        _escape(t.rentAmount.toStringAsFixed(2)),
        _escape(t.securityDeposit.toStringAsFixed(2)),
        _escape(DateFormat('yyyy-MM-dd').format(t.rentDueDate)),
        _escape(DateFormat('yyyy-MM-dd').format(t.moveInDate)),
        _escape(t.isPaid ? 'PAID' : 'PENDING'),
        _escape(t.pendingRentAmount.toStringAsFixed(2)),
        _escape(t.totalPendingBills.toStringAsFixed(2)),
        _escape(t.totalDue.toStringAsFixed(2)),
        _escape(t.emergencyContact ?? '-'),
        _escape(t.occupation ?? '-'),
        _escape(t.permanentAddress ?? '-'),
      ].join(','));
    }

    buffer.writeln('');
    buffer.writeln('');

    // 3. ROOMS & INVENTORY DATA
    buffer.writeln('${_escape('=== SECTION 2: ROOM & BED INVENTORY ===')},,,,,');
    buffer.writeln([
      _escape('Room Number'),
      _escape('Floor'),
      _escape('Total Bed Capacity'),
      _escape('Available Beds'),
      _escape('Occupied Beds'),
      _escape('Room Status'),
    ].join(','));

    for (final r in provider.rooms) {
      final occupied = r.capacity - r.availableBeds;
      final status = r.isFull ? 'FULL' : (r.isEmpty ? 'VACANT' : 'PARTIALLY OCCUPIED');
      buffer.writeln([
        _escape(r.number),
        _escape(r.floor),
        _escape(r.capacity),
        _escape(r.availableBeds),
        _escape(occupied),
        _escape(status),
      ].join(','));
    }

    buffer.writeln('');
    buffer.writeln('');

    // 4. PAYMENTS & TRANSACTIONS
    buffer.writeln('${_escape('=== SECTION 3: PAYMENT & TRANSACTION RECORDS ===')},,,,,');
    buffer.writeln([
      _escape('Transaction ID'),
      _escape('Payment Date'),
      _escape('Tenant Name'),
      _escape('Amount Paid (₹)'),
      _escape('Payment Mode'),
    ].join(','));

    for (final p in provider.payments) {
      final tenant = provider.tenants.where((t) => t.id == p.tenantId).firstOrNull;
      final tenantName = tenant?.name ?? 'Tenant #${p.tenantId}';

      buffer.writeln([
        _escape(p.id),
        _escape(DateFormat('yyyy-MM-dd HH:mm').format(p.date)),
        _escape(tenantName),
        _escape(p.amount.toStringAsFixed(2)),
        _escape(p.method),
      ].join(','));
    }

    return buffer.toString();
  }

  /// Save CSV Content to Downloads or Documents directory
  static Future<ExportResult> exportToExcelFile(AppProvider provider) async {
    try {
      final csvContent = generateMasterCsv(provider);
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final cleanPgName = provider.pgName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final fileName = '${cleanPgName}_Backup_$timestamp.csv';

      String? targetPath;

      // On Android, attempt to save directly in the public Downloads folder
      if (!kIsWeb && Platform.isAndroid) {
        final downloadDir = Directory('/storage/emulated/0/Download');
        if (await downloadDir.exists()) {
          targetPath = '${downloadDir.path}/$fileName';
        }
      }

      // Fallback or iOS / desktop: use App Documents Directory or Downloads directory
      if (targetPath == null) {
        Directory? dir;
        try {
          dir = await getDownloadsDirectory();
        } catch (_) {}
        dir ??= await getApplicationDocumentsDirectory();
        targetPath = '${dir.path}/$fileName';
      }

      final file = File(targetPath);
      await file.writeAsString(csvContent, flush: true);

      return ExportResult(
        success: true,
        fileName: fileName,
        filePath: targetPath,
        recordCount: provider.tenants.length + provider.rooms.length + provider.payments.length,
      );
    } catch (e) {
      debugPrint('ExportService error: $e');
      return ExportResult(
        success: false,
        fileName: '',
        filePath: '',
        recordCount: 0,
        error: e.toString(),
      );
    }
  }
}
