import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';

class RoomsScreen extends StatefulWidget {
  const RoomsScreen({super.key});

  @override
  State<RoomsScreen> createState() => _RoomsScreenState();
}

class _RoomsScreenState extends State<RoomsScreen> {
  String _filter = 'All'; // All, Full, Partial, Empty

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    var filteredRooms = appProvider.rooms.where((r) {
      if (_filter == 'Full') return r.isFull;
      if (_filter == 'Empty') return r.isEmpty;
      if (_filter == 'Partial') return !r.isFull && !r.isEmpty;
      return true;
    }).toList();

    Map<String, List<Room>> roomsByFloor = {};
    for (var r in filteredRooms) {
      roomsByFloor.putIfAbsent(r.floor, () => []).add(r);
    }
    var floors = roomsByFloor.keys.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rooms'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          IconButton(icon: const Icon(Icons.filter_list), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All (${appProvider.rooms.length})', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Full (${appProvider.rooms.where((r) => r.isFull).length})', 'Full'),
                const SizedBox(width: 8),
                _buildFilterChip('Partial (${appProvider.rooms.where((r) => !r.isFull && !r.isEmpty).length})', 'Partial'),
                const SizedBox(width: 8),
                _buildFilterChip('Empty (${appProvider.rooms.where((r) => r.isEmpty).length})', 'Empty'),
              ],
            ),
          ),
          
          Expanded(
            child: floors.isEmpty
                ? const Center(child: Text('No rooms added yet.', style: TextStyle(color: AppTheme.textSecondary)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: floors.length,
                    itemBuilder: (context, floorIndex) {
                      var floor = floors[floorIndex];
                      var roomsInFloor = roomsByFloor[floor]!;
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(bottom: 12, top: floorIndex == 0 ? 0 : 16),
                            child: Text(floor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                          ),
                          ...roomsInFloor.map((room) => GestureDetector(
                            onTap: () => context.push('/room_details/${room.id}'),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('Room ${room.number}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                      if (room.isFull)
                                        _buildStatusBadge('FULL', AppTheme.success)
                                      else if (room.isEmpty)
                                        _buildStatusBadge('EMPTY', AppTheme.danger)
                                      else
                                        _buildStatusBadge('${room.availableBeds} Available', AppTheme.brandOrange),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('${room.capacity} Beds', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: room.beds.map((b) => Padding(
                                      padding: const EdgeInsets.only(right: 8.0),
                                      child: Icon(Icons.bed, color: b.isAvailable ? Colors.grey[300] : AppTheme.success),
                                    )).toList(),
                                  )
                                ],
                              ),
                            ),
                          )),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add_room'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!)),
    );
  }

  Widget _buildStatusBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
