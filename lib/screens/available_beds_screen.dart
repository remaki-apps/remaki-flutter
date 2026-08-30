import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';

class AvailableBedsScreen extends StatelessWidget {
  const AvailableBedsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    // Get all rooms that are not full
    final availableRooms = appProvider.rooms.where((r) => !r.isFull).toList();
    final totalAvailableBeds = appProvider.availableBeds;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Available Beds'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('$totalAvailableBeds Available Beds', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          Expanded(
            child: totalAvailableBeds == 0
                ? const Center(child: Text('No available beds found.', style: TextStyle(color: AppTheme.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: availableRooms.length,
                    itemBuilder: (context, index) {
                      final room = availableRooms[index];
                      final availableBedsInRoom = room.beds.where((b) => b.isAvailable).toList();
                      
                      return Column(
                        children: availableBedsInRoom.map((bed) => Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Room ${room.number} - ${bed.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Row(
                                    children: [
                                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.success, shape: BoxShape.circle)),
                                      const SizedBox(width: 4),
                                      const Text('Available', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ],
                              ),
                              ElevatedButton(
                                onPressed: () => context.push('/allocate_tenant?roomId=${room.id}&bedId=${bed.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                                child: const Text('Allocate'),
                              ),
                            ],
                          ),
                        )).toList(),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/rooms'),
                child: const Text('View All Rooms'),
              ),
            ),
          )
        ],
      ),
    );
  }
}
