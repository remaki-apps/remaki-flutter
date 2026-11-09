import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';

/// Clean, expandable slide-down card showing exact payment split-up:
/// - Monthly Rent
/// - Utility / EB / Other Bills (itemized)
/// - Platform Convenience Fee
/// - Total Settled Amount & Transaction Details
class PaymentSplitupCard extends StatelessWidget {
  final double paymentAmount;
  final double rentAmount;
  final double platformFee;
  final List<dynamic>? bills; // Can be List<AdditionalCharge> or List<Map<String, dynamic>>
  final String method;
  final String? notes;
  final DateTime paymentDate;
  final bool isDark;

  const PaymentSplitupCard({
    super.key,
    required this.paymentAmount,
    required this.rentAmount,
    this.platformFee = 5.0,
    this.bills,
    this.method = 'UPI',
    this.notes,
    required this.paymentDate,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Calculate Split-up logic
    double rentPortion = 0.0;
    double feePortion = 0.0;
    double billsPortion = 0.0;
    final List<Map<String, dynamic>> itemizedBills = [];

    // Extract raw bill objects
    final List<Map<String, dynamic>> normalizedBills = [];
    if (bills != null) {
      for (var b in bills!) {
        if (b is AdditionalCharge) {
          if (b.billType != 'RENT') {
            normalizedBills.add({
              'name': b.description.isNotEmpty ? b.description : (b.billType == 'CURRENT' ? 'Electricity / EB Bill' : 'Utility Charge'),
              'amount': b.amount,
              'status': b.status,
            });
          }
        } else if (b is Map<String, dynamic>) {
          final type = b['billType']?.toString() ?? b['type']?.toString();
          if (type != 'RENT') {
            final desc = b['description']?.toString() ?? '';
            normalizedBills.add({
              'name': desc.isNotEmpty ? desc : (type == 'CURRENT' ? 'Electricity / EB Bill' : 'Utility Charge'),
              'amount': (b['amount'] as num?)?.toDouble() ?? 0.0,
              'status': b['status']?.toString() ?? 'PAID',
            });
          }
        }
      }
    }

    final double effectiveFee = platformFee > 0 ? platformFee : 0.0;

    final String notesLower = (notes ?? '').toLowerCase();
    final bool hasExplicitBillNote = notesLower.contains('bill') ||
        notesLower.contains('utility') ||
        notesLower.contains('electric') ||
        notesLower.contains('current') ||
        notesLower.contains('water') ||
        notesLower.contains('wifi') ||
        notesLower.contains('wi-fi') ||
        notesLower.contains('eb') ||
        notesLower.contains('food') ||
        notesLower.contains('mess') ||
        notesLower.contains('room');

    final bool isRent = !hasExplicitBillNote && ((notesLower.contains('rent')) || (rentAmount > 0));
    final bool isExplicitBill = hasExplicitBillNote || (!isRent && rentAmount <= 0);

    if (isRent) {
      final double effectiveRent = rentAmount > 0
          ? rentAmount
          : (effectiveFee > 0 && paymentAmount > effectiveFee ? paymentAmount - effectiveFee : paymentAmount);
      rentPortion = effectiveRent;
      feePortion = (paymentAmount > effectiveRent) ? (paymentAmount - effectiveRent) : 0.0;
      billsPortion = 0.0;
    } else if (isExplicitBill) {
      rentPortion = 0.0;
      feePortion = 0.0;
      billsPortion = paymentAmount;
    } else {
      // Default fallback
      billsPortion = paymentAmount;
      rentPortion = 0.0;
      feePortion = 0.0;
    }

    // Itemize bills if billsPortion > 0
    if (billsPortion > 0 && itemizedBills.isEmpty) {
      final bool hasSpecificNote = notes != null &&
          notes!.trim().isNotEmpty &&
          !notesLower.contains('utility bills payment') &&
          !notesLower.contains('bill payment') &&
          !notesLower.contains('approved via payment request') &&
          !notesLower.contains('rent');

      if (hasSpecificNote) {
        if (notes!.contains(',')) {
          final parts = notes!.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
          final double splitAmount = billsPortion / parts.length;
          for (final part in parts) {
            itemizedBills.add({
              'name': part,
              'amount': splitAmount,
            });
          }
        } else {
          itemizedBills.add({
            'name': notes!.trim(),
            'amount': billsPortion,
          });
        }
      } else if (normalizedBills.isNotEmpty) {
        // Try exact single bill match by amount
        final exactMatch = normalizedBills.firstWhere(
          (b) {
            final bAmt = (b['amount'] as num?)?.toDouble() ?? 0.0;
            return (bAmt - billsPortion).abs() < 0.01;
          },
          orElse: () => <String, dynamic>{},
        );

        if (exactMatch.isNotEmpty && exactMatch['name'] != null && exactMatch['name'].toString().trim().isNotEmpty) {
          itemizedBills.add({
            'name': exactMatch['name'].toString().trim(),
            'amount': billsPortion,
          });
        } else {
          itemizedBills.add({
            'name': (notes != null && notes!.isNotEmpty) ? notes! : 'Utility Bill',
            'amount': billsPortion,
          });
        }
      } else {
        itemizedBills.add({
          'name': (notes != null && notes!.isNotEmpty) ? notes! : 'Utility Bill',
          'amount': billsPortion,
        });
      }
    }

    final cardBg = isDark ? const Color(0xFF1E1B4B).withValues(alpha: 0.6) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF4338CA).withValues(alpha: 0.4) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final labelColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
    final valueColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final dividerColor = isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0);

    final localDate = paymentDate.toLocal();
    final timeStr = (localDate.hour == 0 && localDate.minute == 0 && localDate.second == 0)
        ? DateFormat('dd MMM yyyy').format(localDate)
        : DateFormat('dd MMM yyyy, hh:mm a').format(localDate);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Title & Settlement badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 15,
                      color: Color(0xFF4F46E5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Payment Split-up',
                    style: GoogleFonts.lato(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: titleColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFBBF7D0), width: 0.6),
                ),
                child: Text(
                  'SETTLED',
                  style: GoogleFonts.lato(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: const Color(0xFF15803D),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 0.8, color: dividerColor),
          const SizedBox(height: 10),

          // 1. Monthly Rent Row
          if (rentPortion > 0) ...[
            _buildSplitRow(
              icon: Icons.home_outlined,
              iconColor: const Color(0xFF6366F1),
              label: (notes != null && notes!.isNotEmpty) ? notes! : 'Monthly Rent',
              amount: rentPortion,
              labelColor: labelColor,
              valueColor: valueColor,
            ),
            const SizedBox(height: 7),
          ],

          // 2. Bill Items (e.g. Electricity, Water, Maintenance)
          for (var bill in itemizedBills) ...[
            _buildSplitRow(
              icon: _getBillIcon(bill['name']?.toString() ?? ''),
              iconColor: const Color(0xFFF59E0B),
              label: bill['name']?.toString() ?? 'Bill',
              amount: (bill['amount'] as num?)?.toDouble() ?? 0.0,
              labelColor: labelColor,
              valueColor: valueColor,
            ),
            const SizedBox(height: 7),
          ],

          // 3. Platform Convenience Fee Row
          if (feePortion > 0) ...[
            _buildSplitRow(
              icon: Icons.verified_user_outlined,
              iconColor: const Color(0xFF0EA5E9),
              label: 'Platform Convenience Fee',
              amount: feePortion,
              labelColor: labelColor,
              valueColor: valueColor,
            ),
            const SizedBox(height: 7),
          ],

          // Divider before Total
          Divider(height: 14, thickness: 0.8, color: dividerColor),

          // Total Paid Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Amount Paid',
                style: GoogleFonts.lato(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              Text(
                '₹${paymentAmount.toStringAsFixed(0)}',
                style: GoogleFonts.lato(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4F46E5),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          // Transaction metadata footer (Date, Time, Payment Mode, Notes)
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                width: 0.8,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_available_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Paid on $timeStr  •  $method${(notes != null && notes!.isNotEmpty) ? '  •  $notes' : ''}',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSplitRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required double amount,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13.5, color: iconColor),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.lato(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: labelColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(0)}',
          style: GoogleFonts.lato(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  IconData _getBillIcon(String billName) {
    final lower = billName.toLowerCase();
    if (lower.contains('elect') || lower.contains('eb') || lower.contains('current') || lower.contains('power')) {
      return Icons.bolt_rounded;
    }
    if (lower.contains('water')) {
      return Icons.water_drop_outlined;
    }
    if (lower.contains('wifi') || lower.contains('internet')) {
      return Icons.wifi_rounded;
    }
    if (lower.contains('maintenance')) {
      return Icons.build_outlined;
    }
    if (lower.contains('food') || lower.contains('mess')) {
      return Icons.restaurant_outlined;
    }
    return Icons.receipt_outlined;
  }
}
