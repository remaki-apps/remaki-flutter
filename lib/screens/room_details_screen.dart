import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/fancy_toast.dart';

class RoomDetailsScreen extends StatelessWidget {
  final String roomId;
  const RoomDetailsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final room = appProvider.rooms.firstWhere(
      (r) => r.id == roomId,
      orElse: () => Room(id: '', number: '', capacity: 0, beds: []),
    );

    if (room.id.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FD),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text('Room not found', style: TextStyle(color: Color(0xFF64748B))),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final roomTenants = appProvider.tenants.where((t) => t.roomId == room.id).toList();
    final totalMonthlyRent = roomTenants.fold(0.0, (sum, t) => sum + t.rentAmount);
    final occupiedBeds = room.capacity - room.availableBeds;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF0F172A), size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room ${room.number}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${room.floor} • ${room.capacity} Beds Total',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Stats Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                        boxShadow: const [
                          BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSummaryBox(
                              title: 'Occupied',
                              value: '$occupiedBeds Beds',
                              bgColor: const Color(0xFFF0FDF4),
                              borderColor: const Color(0xFFDCFCE7),
                              textColor: const Color(0xFF15803D),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryBox(
                              title: 'Available',
                              value: '${room.availableBeds} Beds',
                              bgColor: const Color(0xFFFFF7ED),
                              borderColor: const Color(0xFFFFEDD5),
                              textColor: const Color(0xFFC2410C),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildSummaryBox(
                              title: 'Total Rent',
                              value: '₹${totalMonthlyRent.toStringAsFixed(0)}',
                              bgColor: const Color(0xFFF8FAFC),
                              borderColor: const Color(0xFFE2E8F0),
                              textColor: const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Beds Section Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Beds (${room.beds.length})',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showAddBedDialog(context, room.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.add, size: 14, color: AppTheme.primaryColor),
                                SizedBox(width: 4),
                                Text(
                                  'Add Bed',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bed Items List
                    ...room.beds.map((bed) {
                      Tenant? tenant;
                      if (!bed.isAvailable) {
                        if (bed.tenantId != null) {
                          tenant = appProvider.tenants.firstWhere(
                            (t) => t.id == bed.tenantId,
                            orElse: () => Tenant(id: '', name: '', phone: '', email: '', roomId: '', bedId: '', moveInDate: DateTime.now(), rentAmount: 0, securityDeposit: 0, rentDueDate: DateTime.now()),
                          );
                          if (tenant.id.isEmpty) tenant = null;
                        }
                        if (tenant == null) {
                          tenant = appProvider.tenants.firstWhere(
                            (t) => t.roomId == room.id && t.bedId == bed.id,
                            orElse: () => Tenant(id: '', name: '', phone: '', email: '', roomId: '', bedId: '', moveInDate: DateTime.now(), rentAmount: 0, securityDeposit: 0, rentDueDate: DateTime.now()),
                          );
                          if (tenant.id.isEmpty) tenant = null;
                        }
                      }
                      return _buildBedCard(context, room, bed, tenant);
                    }),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Bottom Action Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.receipt_long_outlined, color: Colors.white, size: 20),
                  label: const Text(
                    'Split Room Bill',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => context.push('/add_room_bill/${room.id}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required String value,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: textColor.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBedCard(BuildContext context, Room room, Bed bed, Tenant? tenant) {
    Widget cardContent = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bed.isAvailable ? const Color(0xFFF1F5F9) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.single_bed_rounded,
              color: bed.isAvailable ? const Color(0xFF94A3B8) : const Color(0xFF16A34A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bed.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tenant != null ? 'Occupied by ${tenant.name}' : 'Available',
                  style: TextStyle(
                    fontSize: 12,
                    color: tenant != null ? const Color(0xFF059669) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          if (tenant != null) ...[
            Row(
              children: [
                TenantAvatar(
                  name: tenant.name,
                  imageUrl: tenant.imageUrl,
                  radius: 14,
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: tenant.totalDue == 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tenant.totalDue == 0 ? 'PAID' : 'UNPAID',
                    style: TextStyle(
                      color: tenant.totalDue == 0 ? const Color(0xFF16A34A) : const Color(0xFFEF4444),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => context.push('/allocate_tenant?roomId=${room.id}&bedId=${bed.id}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Allocate', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
          ],
        ],
      ),
    );

    if (tenant != null) {
      return GestureDetector(
        onTap: () => context.push('/tenant_profile/${tenant.id}'),
        child: cardContent,
      );
    }

    return Dismissible(
      key: ValueKey(bed.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Swipe to Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            SizedBox(width: 6),
            Icon(Icons.delete_outline, color: Colors.white, size: 20),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Remove Bed'),
            content: Text('Are you sure you want to remove ${bed.name}?'),
            actions: [
              TextButton(onPressed: () => ctx.pop(false), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                onPressed: () => ctx.pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (direction) {
        Provider.of<AppProvider>(context, listen: false).removeBed(room.id, bed.id);
        FancyToast.showSuccess(
          context,
          'Bed Removed!',
          message: '${bed.name} has been removed from Room ${room.number}.',
        );
      },
      child: cardContent,
    );
  }

  void _showAddBedDialog(BuildContext context, String roomId) {
    final textController = TextEditingController();
    final presets = ['Bed 1', 'Bed 2', 'Window Bed', 'Door Side', 'Upper Bunk', 'Lower Bunk'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header with Icon and Close Button
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: const Icon(Icons.king_bed_outlined, color: AppTheme.primaryColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Add New Bed',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Enter a label or pick a quick suggestion',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => ctx.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Preset Suggestion Chips
                  const Text(
                    'QUICK SUGGESTIONS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: presets.map((preset) {
                      final isSelected = textController.text == preset;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            textController.text = preset;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? AppTheme.primaryColor : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            preset,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Input Field
                  TextField(
                    controller: textController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Bed Name / Label *',
                      hintText: 'e.g. Bed 1 or Window Bed',
                      prefixIcon: const Icon(Icons.single_bed_outlined, color: Color(0xFF64748B), size: 20),
                      labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Bottom Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => ctx.pop(),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () {
                            if (textController.text.trim().isNotEmpty) {
                              Provider.of<AppProvider>(context, listen: false).addBed(roomId, textController.text.trim());
                              ctx.pop();
                            }
                          },
                          child: const Text(
                            'Add Bed',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

