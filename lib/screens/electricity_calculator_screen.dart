import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';

class ElectricityCalculatorScreen extends StatefulWidget {
  final String? propertyId;

  const ElectricityCalculatorScreen({super.key, this.propertyId});

  @override
  State<ElectricityCalculatorScreen> createState() =>
      _ElectricityCalculatorScreenState();
}

class _ElectricityCalculatorScreenState
    extends State<ElectricityCalculatorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String? _loadError;

  List<ElectricityRoomGroup> _groups = [];
  List<ElectricityBillCycle> _cycles = [];
  List<Map<String, dynamic>> _configRooms = [];
  String _propertyName = 'PG';
  double _propertyDefaultRate = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? get _activePropertyId =>
      widget.propertyId ??
      Provider.of<AppProvider>(context, listen: false).selectedPropertyId;

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final pid = _activePropertyId;
      final results = await Future.wait([
        ApiService.fetchElectricityConfig(propertyId: pid),
        ApiService.fetchElectricityGroups(propertyId: pid),
        ApiService.fetchElectricityCycles(propertyId: pid),
      ]);
      if (!mounted) return;
      final config = results[0] as Map<String, dynamic>;
      final rawGroups = results[1] as List<dynamic>;
      final rawCycles = results[2] as List<dynamic>;

      setState(() {
        _propertyName = config['propertyName']?.toString() ?? 'PG';
        _propertyDefaultRate =
            (config['costPerUnit'] as num?)?.toDouble() ?? 0.0;
        _configRooms = (config['rooms'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        _groups = rawGroups
            .map((g) => ElectricityRoomGroup.fromJson(g as Map<String, dynamic>))
            .toList();
        _cycles = rawCycles
            .map((c) => ElectricityBillCycle.fromJson(c as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = ApiService.cleanErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _openGroupFormDialog({ElectricityRoomGroup? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final existingIds = existing?.rooms.map((r) => r.roomId).toSet() ?? <String>{};
    final selectedRoomIds = Set<String>.from(existingIds);

    // Only rooms that are ungrouped OR already in this group
    final availableRooms = _configRooms.where((r) {
      final gid = r['groupId']?.toString();
      return gid == null || gid.isEmpty || (existing != null && gid == existing.id);
    }).toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              title: Text(
                existing == null
                    ? 'Create Combined Room Group'
                    : 'Edit ${existing.name}',
                style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'Group Name',
                          hintText: 'e.g. Floor 1 Shared Meter (101-103)',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        existing == null
                            ? 'Select at least 2 ungrouped rooms:'
                            : 'Select rooms in this group (old meter reading stays intact):',
                        style: GoogleFonts.lato(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF475569)),
                      ),
                      const SizedBox(height: 8),
                      if (availableRooms.isEmpty)
                        Text(
                          'All rooms are already assigned to other groups.',
                          style: GoogleFonts.lato(
                              fontSize: 12.5, color: const Color(0xFF64748B)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableRooms.map((r) {
                            final rid = r['id'].toString();
                            final numStr = r['roomNumber'].toString();
                            final isSelected = selectedRoomIds.contains(rid);
                            return FilterChip(
                              label: Text('Room $numStr'),
                              selected: isSelected,
                              selectedColor: const Color(0xFFFEF3C7),
                              checkmarkColor: const Color(0xFFD97706),
                              onSelected: (val) {
                                setModalState(() {
                                  if (val) {
                                    selectedRoomIds.add(rid);
                                  } else {
                                    selectedRoomIds.remove(rid);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dlgCtx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      FancyToast.showError(context, 'Name Required',
                          message: 'Enter a group name.');
                      return;
                    }
                    final minRooms = existing == null ? 2 : 1;
                    if (selectedRoomIds.length < minRooms) {
                      FancyToast.showError(
                        context,
                        'Select Rooms',
                        message: existing == null
                            ? 'Select at least 2 rooms to combine.'
                            : 'Group must have at least 1 room.',
                      );
                      return;
                    }
                    try {
                      if (existing == null) {
                        await ApiService.createElectricityGroup(
                          propertyId: _activePropertyId,
                          name: name,
                          roomIds: selectedRoomIds.toList(),
                        );
                      } else {
                        await ApiService.updateElectricityGroup(
                          groupId: existing.id,
                          name: name,
                          roomIds: selectedRoomIds.toList(),
                        );
                      }
                      if (dlgCtx.mounted) Navigator.of(dlgCtx).pop(true);
                    } catch (e) {
                      if (context.mounted) {
                        FancyToast.showError(context, 'Error',
                            message: ApiService.cleanErrorMessage(e));
                      }
                    }
                  },
                  child: Text(existing == null ? 'Create Group' : 'Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );

    nameCtrl.dispose();
    if (saved == true) {
      FancyToast.showSuccess(
        context,
        existing == null ? 'Combined group created!' : 'Combined group updated!',
      );
      _loadAll();
    }
  }

  Future<void> _confirmDeleteGroup(ElectricityRoomGroup group) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Combined Group?'),
        content: Text(
          'Remove "${group.name}"? Rooms in this group will become available for individual billing again. Previously generated bills (paid or unpaid) will be preserved in History.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dlgCtx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dlgCtx).pop(true),
            child: const Text('Delete Group'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteElectricityGroup(group.id);
      if (mounted) {
        FancyToast.showSuccess(context, 'Deleted group "${group.name}".');
        _loadAll();
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Delete Failed',
            message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  String _formatNum(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  String _formatMonthHeader(String yyyyMm) {
    try {
      final parts = yyyyMm.split('-');
      if (parts.length == 2) {
        final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]), 1);
        return DateFormat('MMMM yyyy').format(dt);
      }
    } catch (_) {}
    return yyyyMm;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 18),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Multi-Room Electricity',
              style: GoogleFonts.lato(
                fontWeight: FontWeight.w800,
                fontSize: 17.5,
                color: const Color(0xFF0F172A),
              ),
            ),
            Text(
              '$_propertyName • Default ₹${_formatNum(_propertyDefaultRate)}/unit',
              style: GoogleFonts.lato(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppTheme.primaryColor,
          labelStyle: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 13.5),
          tabs: const [
            Tab(text: 'Combined Groups'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadAll,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGroupsTab(),
                    _buildHistoryTab(),
                  ],
                ),
      floatingActionButton: _tabController.index == 0 && !_isLoading
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              onPressed: () => _openGroupFormDialog(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Combine Rooms'),
            )
          : null,
    );
  }

  Widget _buildGroupsTab() {
    if (_groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Color(0xFFD97706), size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'No Combined Room Groups Yet',
                style: GoogleFonts.lato(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Combine multiple rooms that share a single electricity meter (e.g., 101, 102, 103). Single-room billing is available directly inside each room.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(
                    fontSize: 13, color: const Color(0xFF64748B)),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () => _openGroupFormDialog(),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create Combined Group'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: _groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final group = _groups[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bolt_rounded,
                          color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: GoogleFonts.lato(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Last Reading: ${_formatNum(group.lastMeterReading ?? 0)} • ₹${_formatNum(group.effectiveCostPerUnit)}/unit • ${group.activeTenantCount} active tenant(s)',
                            style: GoogleFonts.lato(
                              fontSize: 12,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Edit Group Rooms',
                      icon: const Icon(Icons.edit_outlined,
                          size: 20, color: Color(0xFF475569)),
                      onPressed: () => _openGroupFormDialog(existing: group),
                    ),
                    IconButton(
                      tooltip: 'Delete Group',
                      icon: const Icon(Icons.delete_outline_rounded,
                          size: 20, color: Color(0xFFEF4444)),
                      onPressed: () => _confirmDeleteGroup(group),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: group.rooms.map((r) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Room ${r.roomNumber} (${r.activeTenantCount})',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF334155),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await context.push(
                        '/electricity_step1?groupId=${group.id}&propertyId=${group.propertyId}',
                      );
                      _loadAll();
                    },
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(
                      'Calculate & Split Bill',
                      style: GoogleFonts.lato(fontWeight: FontWeight.w800),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_cycles.isEmpty) {
      return Center(
        child: Text(
          'No electricity bill cycles generated yet.',
          style: GoogleFonts.lato(fontSize: 14, color: const Color(0xFF64748B)),
        ),
      );
    }

    // Group cycles month-wise preserving order (newest first)
    final Map<String, List<ElectricityBillCycle>> groupedByMonth = {};
    for (final c in _cycles) {
      groupedByMonth.putIfAbsent(c.billingMonth, () => []).add(c);
    }
    final months = groupedByMonth.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: months.length,
        itemBuilder: (context, mIndex) {
          final month = months[mIndex];
          final items = groupedByMonth[month]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 6),
                child: Text(
                  _formatMonthHeader(month).toUpperCase(),
                  style: GoogleFonts.lato(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.7,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ),
              ...items.map((cycle) => _buildCycleHistoryCard(cycle)),
              const SizedBox(height: 10),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCycleHistoryCard(ElectricityBillCycle cycle) {
    final scopeLabel = cycle.groupNameSnapshot?.isNotEmpty == true
        ? cycle.groupNameSnapshot!
        : (cycle.scopeType == 'SINGLE_ROOM'
            ? 'Single Room'
            : 'PG Shared Split');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: cycle.scopeType == 'COMBINED_GROUP'
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  scopeLabel,
                  style: GoogleFonts.lato(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: cycle.scopeType == 'COMBINED_GROUP'
                        ? const Color(0xFF92400E)
                        : const Color(0xFF4338CA),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cycle.splitMode == 'CUSTOM' ? 'Custom Split' : 'Equal Split',
                  style: GoogleFonts.lato(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '₹${cycle.totalAmount.toStringAsFixed(2)}',
                style: GoogleFonts.lato(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Meter Reading: ${_formatNum(cycle.previousReading)} → ${_formatNum(cycle.currentReading)} (${_formatNum(cycle.unitsConsumed)} units @ ₹${_formatNum(cycle.costPerUnit)}/unit)',
            style: GoogleFonts.lato(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334155),
            ),
          ),
          if (cycle.description != null && cycle.description!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              cycle.description!,
              style: GoogleFonts.lato(
                  fontSize: 11.5, color: const Color(0xFF64748B)),
            ),
          ],
          if (cycle.shares.isNotEmpty) ...[
            const Divider(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: cycle.shares.map((s) {
                final isPaid = s.billStatus == 'PAID';
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isPaid
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Text(
                    '${s.tenantName} (R${s.roomNumber}): ₹${s.shareAmount.toStringAsFixed(0)} • ${s.billStatus ?? 'PENDING'}',
                    style: GoogleFonts.lato(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isPaid
                          ? const Color(0xFF065F46)
                          : const Color(0xFF334155),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
