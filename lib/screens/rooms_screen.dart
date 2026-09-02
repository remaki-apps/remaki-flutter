import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final Set<String> _collapsedFloors = {};
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  String _normalizeFloorName(String rawFloor) {
    final f = rawFloor.trim().toLowerCase();
    if (f == 'g' || f == 'ground' || f == 'ground floor' || f == '0') return 'Ground Floor';
    if (f == '1' || f == '1st' || f == '1st floor' || f == 'floor 1') return '1st Floor';
    if (f == '2' || f == '2nd' || f == '2nd floor' || f == 'floor 2') return '2nd Floor';
    if (f == '3' || f == '3rd' || f == '3rd floor' || f == 'floor 3') return '3rd Floor';
    if (f == '4' || f == '4th' || f == '4th floor' || f == 'floor 4') return '4th Floor';
    if (f == '5' || f == '5th' || f == '5th floor' || f == 'floor 5') return '5th Floor';
    return rawFloor;
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final allRooms = appProvider.rooms;

    final totalCount = allRooms.length;
    final fullCount = allRooms.where((r) => r.isFull).length;
    final partialCount = allRooms.where((r) => !r.isFull && !r.isEmpty).length;
    final emptyCount = allRooms.where((r) => r.isEmpty).length;

    var filteredRooms = allRooms.where((r) {
      final matchesFilter = (_filter == 'Full' && r.isFull) ||
          (_filter == 'Empty' && r.isEmpty) ||
          (_filter == 'Partial' && !r.isFull && !r.isEmpty) ||
          (_filter == 'All');
      final matchesSearch = _searchQuery.isEmpty ||
          r.number.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.floor.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesFilter && matchesSearch;
    }).toList();

    Map<String, List<Room>> roomsByFloor = {};
    for (var r in filteredRooms) {
      final normalized = _normalizeFloorName(r.floor);
      roomsByFloor.putIfAbsent(normalized, () => []).add(r);
    }

    int floorOrderIndex(String floor) {
      final f = floor.toLowerCase();
      if (f.contains('ground')) return 0;
      if (f.contains('1')) return 1;
      if (f.contains('2')) return 2;
      if (f.contains('3')) return 3;
      if (f.contains('4')) return 4;
      if (f.contains('5')) return 5;
      if (f.contains('6')) return 6;
      return 99;
    }

    var floors = roomsByFloor.keys.toList()
      ..sort((a, b) => floorOrderIndex(a).compareTo(floorOrderIndex(b)));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _isSearching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search room number or floor...',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryColor)),
                              prefixIcon: const Icon(Icons.search, color: Color(0xFF64748B), size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF475569)),
                          onPressed: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Rooms',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Manage all rooms in your property',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _isSearching = true),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.search, color: AppTheme.primaryColor, size: 20),
                          ),
                        ),
                      ],
                    ),
            ),

            // KPI Stats Cards Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Total',
                      value: '$totalCount',
                      activeColor: AppTheme.primaryColor,
                      cardBg: const Color(0xFFF8FAFC),
                      valueColor: const Color(0xFF0F172A),
                      filterValue: 'All',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Full',
                      value: '$fullCount',
                      activeColor: const Color(0xFF16A34A),
                      cardBg: const Color(0xFFF0FDF4),
                      valueColor: const Color(0xFF15803D),
                      filterValue: 'Full',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Partial',
                      value: '$partialCount',
                      activeColor: const Color(0xFFEA580C),
                      cardBg: const Color(0xFFFFF7ED),
                      valueColor: const Color(0xFFC2410C),
                      filterValue: 'Partial',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Empty',
                      value: '$emptyCount',
                      activeColor: const Color(0xFFEF4444),
                      cardBg: const Color(0xFFFEF2F2),
                      valueColor: const Color(0xFFB91C1C),
                      filterValue: 'Empty',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Floor Cards List or Centered Empty State
            Expanded(
              child: floors.isEmpty
                  ? Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/no_rooms1.png',
                              height: 180,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No rooms matching "$_searchQuery"'
                                  : 'No Rooms Available',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Try searching with a different room number or floor.'
                                  : 'Add rooms to manage beds, tenants, and occupancy.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                      itemCount: floors.length,
                      itemBuilder: (context, floorIndex) {
                        final floor = floors[floorIndex];
                        final roomsInFloor = roomsByFloor[floor]!;
                        final isCollapsed = _collapsedFloors.contains(floor);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    if (isCollapsed) {
                                      _collapsedFloors.remove(floor);
                                    } else {
                                      _collapsedFloors.add(floor);
                                    }
                                  });
                                },
                                behavior: HitTestBehavior.opaque,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEF2FF),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Icon(Icons.domain_outlined, color: AppTheme.primaryColor, size: 20),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            floor,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEEF2FF),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              '${roomsInFloor.length} ${roomsInFloor.length == 1 ? "Room" : "Rooms"}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Icon(
                                        isCollapsed
                                            ? Icons.keyboard_arrow_down_rounded
                                            : Icons.keyboard_arrow_up_rounded,
                                        color: const Color(0xFF475569),
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (!isCollapsed) ...[
                                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    children: roomsInFloor.map((room) {
                                      return GestureDetector(
                                        onTap: () => context.push('/room_details/${room.id}'),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: const Color(0xFFF1F5F9)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 38,
                                                    height: 38,
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF3F0FF),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: const Icon(Icons.door_sliding_outlined, color: AppTheme.primaryColor, size: 18),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Room ${room.number}',
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        '${room.capacity} Beds Total',
                                                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              Row(
                                                children: [
                                                  _buildStatusBadge(room),
                                                  const SizedBox(width: 8),
                                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add_room'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.add, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required Color activeColor,
    required Color cardBg,
    required Color valueColor,
    required String filterValue,
  }) {
    final isSelected = _filter == filterValue;
    return GestureDetector(
      onTap: () => setState(() => _filter = filterValue),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: valueColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: valueColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Room room) {
    if (room.isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'FULL',
          style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else if (room.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEE2E2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'EMPTY',
          style: TextStyle(color: Color(0xFFEF4444), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEDD5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${room.availableBeds} Available',
          style: const TextStyle(color: Color(0xFFEA580C), fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
    }
  }
}
