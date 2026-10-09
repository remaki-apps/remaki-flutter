import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shimmer.dart';

class AvailableBedsScreen extends StatelessWidget {
  const AvailableBedsScreen({super.key});

  String _normalizeFloorName(String rawFloor) {
    final f = rawFloor.trim().toLowerCase();
    if (f == 'g' || f == 'ground' || f == 'ground floor' || f == '0') return 'Ground Floor';
    if (f == '1' || f == '1st' || f == '1st floor' || f == 'floor 1') return '1st Floor';
    if (f == '2' || f == '2nd' || f == '2nd floor' || f == 'floor 2') return '2nd Floor';
    if (f == '3' || f == '3rd' || f == '3rd floor' || f == 'floor 3') return '3rd Floor';
    if (f == '4' || f == '4th' || f == '4th floor' || f == 'floor 4') return '4th Floor';
    if (f == '5' || f == '5th' || f == '5th floor' || f == 'floor 5') return '5th Floor';
    return rawFloor.trim().isEmpty ? 'Ground Floor' : rawFloor.trim();
  }

  int _floorOrderIndex(String floor) {
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

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);

    // Group available beds by floor
    final Map<String, List<({Room room, Bed bed})>> bedsByFloor = {};
    int totalAvailableBeds = 0;

    for (final room in appProvider.rooms) {
      final floorName = _normalizeFloorName(room.floor);
      for (final bed in room.beds) {
        if (bed.isAvailable) {
          totalAvailableBeds++;
          bedsByFloor.putIfAbsent(floorName, () => []).add((room: room, bed: bed));
        }
      }
    }

    final sortedFloors = bedsByFloor.keys.toList()
      ..sort((a, b) => _floorOrderIndex(a).compareTo(_floorOrderIndex(b)));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        title: const Text('Available Beds'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: () => appProvider.loadFromAPI(),
        color: AppTheme.primaryColor,
        child: appProvider.isLoading
            ? const SimpleListSkeleton()
            : Column(
                children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '$totalAvailableBeds Available Beds',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          Expanded(
            child: totalAvailableBeds == 0
                ? Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/no_available_beds.png',
                            height: 180,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No Available Beds',
                            style: GoogleFonts.lato(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'All beds are currently occupied or allocated.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.lato(
                              fontSize: 13,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: sortedFloors.length,
                    itemBuilder: (context, index) {
                      final floor = sortedFloors[index];
                      final beds = bedsByFloor[floor] ?? [];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                            child: Text(
                              floor,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          ...beds.map((item) => Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Room ${item.room.number} - ${item.bed.name}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(
                                                color: AppTheme.success,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            const Text(
                                              'Available',
                                              style: TextStyle(
                                                color: AppTheme.textSecondary,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    ElevatedButton(
                                      onPressed: () => context.push(
                                        '/allocate_tenant?roomId=${item.room.id}&bedId=${item.bed.id}',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        textStyle: const TextStyle(fontSize: 12),
                                      ),
                                      child: const Text('Allocate'),
                                    ),
                                  ],
                                ),
                              )),
                        ],
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
          ),
        ],
      ),
    ),
      ),
    );
  }
}
