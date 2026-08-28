import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';

class RoomDetailsScreen extends StatelessWidget {
  final String roomId;
  const RoomDetailsScreen({super.key, required this.roomId});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final room = appProvider.rooms.firstWhere((r) => r.id == roomId, orElse: () => Room(id: '', number: '', capacity: 0, beds: []));

    if (room.id.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Error')), body: const Center(child: Text('Room not found')));
    }

    final roomTenants = appProvider.tenants.where((t) => t.roomId == room.id).toList();
    final totalMonthlyRent = roomTenants.fold(0.0, (sum, t) => sum + t.rentAmount);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Room Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Split Room Bill',
            onPressed: () => context.push('/add_room_bill/${room.id}'),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Bed',
            onPressed: () {
              final textController = TextEditingController();
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Add New Bed'),
                  content: TextField(
                    controller: textController,
                    decoration: const InputDecoration(labelText: 'Bed Name (e.g. Window Bed)'),
                  ),
                  actions: [
                    TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: () {
                        if (textController.text.isNotEmpty) {
                          Provider.of<AppProvider>(context, listen: false).addBed(room.id, textController.text);
                          ctx.pop();
                        }
                      },
                      child: const Text('Add'),
                    ),
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Room ${room.number}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
            Text('${room.capacity} Beds • ${room.capacity - room.availableBeds} Occupied • ${room.availableBeds} Available', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 24),

            // Top Stats Row
            Row(
              children: [
                _buildStatBox('${room.capacity - room.availableBeds}', 'Occupied'),
                const SizedBox(width: 12),
                _buildStatBox('${room.availableBeds}', 'Available'),
                const SizedBox(width: 12),
                _buildStatBox('₹${totalMonthlyRent.toStringAsFixed(0)}', 'Monthly Rent (Total)'),
              ],
            ),
            const SizedBox(height: 32),

            const Text('Beds', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            ...room.beds.map((bed) {
              Tenant? tenant;
              if (!bed.isAvailable && bed.tenantId != null) {
                tenant = appProvider.tenants.firstWhere((t) => t.id == bed.tenantId, orElse: () => Tenant(id: '', name: '', phone: '', email: '', roomId: '', bedId: '', moveInDate: DateTime.now(), rentAmount: 0, securityDeposit: 0, rentDueDate: DateTime.now()));
                if (tenant.id.isEmpty) tenant = null;
              }
              return _buildBedTile(context, room, bed, tenant);
            }),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.receipt_long, color: Colors.white),
                label: const Text('Split Room Bill', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => context.push('/add_room_bill/${room.id}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildBedTile(BuildContext context, Room room, Bed bed, Tenant? tenant) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(Icons.bed, color: bed.isAvailable ? Colors.grey[300] : AppTheme.success, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bed.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                if (tenant != null) ...[
                  const Text('Occupied', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ] else ...[
                  const Text('Available', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ],
            ),
          ),
          if (tenant != null) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('₹${tenant.rentAmount.toStringAsFixed(0)} / month', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ],
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: tenant.isPaid ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(tenant.isPaid ? 'Paid' : 'Unpaid', style: TextStyle(color: tenant.isPaid ? AppTheme.success : AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ] else ...[
            const Text('No Tenant', style: TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () => context.push('/allocate_tenant?roomId=${room.id}&bedId=${bed.id}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 12),
              ),
              child: const Text('Allocate Tenant'),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Remove Bed'),
                    content: Text('Are you sure you want to remove ${bed.name}?'),
                    actions: [
                      TextButton(onPressed: () => ctx.pop(), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                        onPressed: () {
                          Provider.of<AppProvider>(context, listen: false).removeBed(room.id, bed.id);
                          ctx.pop();
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]
        ],
      ),
    );
  }
}
