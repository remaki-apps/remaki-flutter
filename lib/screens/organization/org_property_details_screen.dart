import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/organization_models.dart';
import '../../providers/organization_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgPropertyDetailsScreen extends StatefulWidget {
  final String propertyId;
  final int initialTab;
  const OrgPropertyDetailsScreen({super.key, required this.propertyId, this.initialTab = 0});

  @override
  State<OrgPropertyDetailsScreen> createState() => _OrgPropertyDetailsScreenState();
}

class _OrgPropertyDetailsScreenState extends State<OrgPropertyDetailsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<OrganizationPropertyOwnerItem> _owners = [];
  List<OrganizationRoomItem> _rooms = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.fetchOrganizationPropertyOwners(widget.propertyId),
        ApiService.fetchOrganizationPropertyRooms(widget.propertyId),
      ]);
      if (mounted) {
        setState(() {
          _owners = (results[0]).map((e) => OrganizationPropertyOwnerItem.fromJson(e as Map<String, dynamic>)).toList();
          _rooms = (results[1]).map((e) => OrganizationRoomItem.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        FancyToast.showError(context, 'Error', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  Future<void> _showOwnerDialog({OrganizationPropertyOwnerItem? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final phoneCtrl = TextEditingController(text: existing?.phoneNumber ?? '');
    final emailCtrl = TextEditingController(text: existing?.email ?? '');
    final passCtrl = TextEditingController();
    String role = existing?.role ?? 'CO_OWNER';
    const roleOptions = ['CO_OWNER', 'PRIMARY_OWNER', 'MANAGER', 'ADMIN'];
    if (!roleOptions.contains(role)) {
      role = 'CO_OWNER';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(existing == null ? 'Add Co-Owner' : 'Edit Co-Owner', style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full Name *')),
                if (existing == null) ...[
                  const SizedBox(height: 8),
                  TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Number *'), keyboardType: TextInputType.phone),
                  const SizedBox(height: 8),
                  TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email (optional)')),
                  const SizedBox(height: 8),
                  TextField(controller: passCtrl, decoration: const InputDecoration(labelText: 'Password (optional)')),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'CO_OWNER', child: Text('Co-Owner')),
                    DropdownMenuItem(value: 'PRIMARY_OWNER', child: Text('Primary Owner')),
                    DropdownMenuItem(value: 'MANAGER', child: Text('Manager')),
                    DropdownMenuItem(value: 'ADMIN', child: Text('Admin')),
                  ],
                  onChanged: (v) => setModalState(() => role = v ?? 'CO_OWNER'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      try {
        if (existing == null) {
          await ApiService.addPropertyOwnerUnderOrg({
            'propertyId': widget.propertyId,
            'name': nameCtrl.text.trim(),
            'phoneNumber': phoneCtrl.text.trim(),
            if (emailCtrl.text.trim().isNotEmpty) 'email': emailCtrl.text.trim(),
            if (passCtrl.text.trim().isNotEmpty) 'password': passCtrl.text.trim(),
            'role': role,
          });
        } else {
          await ApiService.updatePropertyOwnerUnderOrg({
            'ownerId': existing.id,
            'name': nameCtrl.text.trim(),
            'role': role,
          });
        }
        if (mounted) {
          FancyToast.showSuccess(context, 'Saved', message: 'Co-owner updated.');
          _loadDetails();
        }
      } catch (e) {
        if (mounted) FancyToast.showError(context, 'Failed', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  Future<void> _deleteOwner(OrganizationPropertyOwnerItem o) async {
    try {
      await ApiService.deletePropertyOwnerUnderOrg(o.id);
      if (mounted) {
        FancyToast.showSuccess(context, 'Removed', message: 'Co-owner removed.');
        _loadDetails();
      }
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Failed', message: ApiService.cleanErrorMessage(e));
    }
  }

  Future<void> _showRoomDialog({OrganizationRoomItem? existing}) async {
    final roomCtrl = TextEditingController(text: existing?.roomNumber ?? '');
    final floorCtrl = TextEditingController(text: existing?.floorNumber ?? '1');
    final capCtrl = TextEditingController(text: '${existing?.capacity ?? 2}');
    final withFoodCtrl = TextEditingController(text: '${existing?.monthlyRentWithFood.toStringAsFixed(0) ?? "7000"}');
    final withoutFoodCtrl = TextEditingController(text: '${existing?.monthlyRentWithoutFood.toStringAsFixed(0) ?? "5500"}');
    String roomType = existing?.roomType ?? 'NON_AC';
    if (roomType != 'NON_AC' && roomType != 'AC') {
      roomType = 'NON_AC';
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(existing == null ? 'Add Room' : 'Edit Room ${existing.roomNumber}', style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: roomCtrl, decoration: const InputDecoration(labelText: 'Room Number *')),
                const SizedBox(height: 8),
                TextField(controller: floorCtrl, decoration: const InputDecoration(labelText: 'Floor Number *')),
                if (existing == null) ...[
                  const SizedBox(height: 8),
                  TextField(controller: capCtrl, decoration: const InputDecoration(labelText: 'Capacity (Beds) *'), keyboardType: TextInputType.number),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: roomType,
                  decoration: const InputDecoration(labelText: 'Room Type'),
                  items: const [
                    DropdownMenuItem(value: 'NON_AC', child: Text('Non-AC')),
                    DropdownMenuItem(value: 'AC', child: Text('AC')),
                  ],
                  onChanged: (v) => setModalState(() => roomType = v ?? 'NON_AC'),
                ),
                const SizedBox(height: 8),
                TextField(controller: withFoodCtrl, decoration: const InputDecoration(labelText: 'Rent With Food (₹)'), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                TextField(controller: withoutFoodCtrl, decoration: const InputDecoration(labelText: 'Rent Without Food (₹)'), keyboardType: TextInputType.number),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok == true && mounted) {
      try {
        if (existing == null) {
          await ApiService.createRoomUnderOrg({
            'propertyId': widget.propertyId,
            'roomNumber': roomCtrl.text.trim(),
            'floorNumber': floorCtrl.text.trim(),
            'capacity': int.tryParse(capCtrl.text.trim()) ?? 2,
            'roomType': roomType,
            'monthlyRentWithFood': double.tryParse(withFoodCtrl.text.trim()) ?? 0,
            'monthlyRentWithoutFood': double.tryParse(withoutFoodCtrl.text.trim()) ?? 0,
          });
        } else {
          await ApiService.updateRoomUnderOrg({
            'roomId': existing.id,
            'roomNumber': roomCtrl.text.trim(),
            'floorNumber': floorCtrl.text.trim(),
            'roomType': roomType,
            'monthlyRentWithFood': double.tryParse(withFoodCtrl.text.trim()) ?? 0,
            'monthlyRentWithoutFood': double.tryParse(withoutFoodCtrl.text.trim()) ?? 0,
          });
        }
        if (mounted) {
          FancyToast.showSuccess(context, 'Saved', message: 'Room saved.');
          context.read<OrganizationProvider>().loadFromAPI(showLoading: false);
          _loadDetails();
        }
      } catch (e) {
        if (mounted) FancyToast.showError(context, 'Error', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  Future<void> _addBed(OrganizationRoomItem room) async {
    final labelCtrl = TextEditingController(text: 'Bed ${room.beds.length + 1}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Bed to Room ${room.roomNumber}'),
        content: TextField(controller: labelCtrl, decoration: const InputDecoration(labelText: 'Bed Label')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && mounted) {
      try {
        await ApiService.addBedUnderOrg(room.id, labelCtrl.text.trim());
        if (mounted) _loadDetails();
      } catch (e) {
        if (mounted) FancyToast.showError(context, 'Failed', message: ApiService.cleanErrorMessage(e));
      }
    }
  }

  Future<void> _deleteRoom(OrganizationRoomItem room) async {
    try {
      await ApiService.deleteRoomUnderOrg(room.id);
      if (mounted) {
        FancyToast.showSuccess(context, 'Deleted', message: 'Room ${room.roomNumber} deleted.');
        _loadDetails();
      }
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Failed', message: ApiService.cleanErrorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final orgProvider = context.watch<OrganizationProvider>();
    OrganizationPropertyItem? prop;
    try {
      prop = orgProvider.properties.firstWhere((p) => p.id == widget.propertyId);
    } catch (_) {}

    if (prop == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('PG Details')),
        body: const Center(child: Text('Property not found')),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(prop.name, style: GoogleFonts.lato(fontWeight: FontWeight.w800, color: AppTheme.primaryDark)),
        actions: [
          IconButton(
            tooltip: 'Edit PG',
            icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
            onPressed: () => context.push('/org_property_form?propertyId=${prop!.id}'),
          ),
          IconButton(
            tooltip: 'Manage / Delete PG',
            icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.danger),
            onPressed: () => context.push(
              '/org_stepwise_delete?targetId=${prop!.id}&isAdmin=false&name=${Uri.encodeComponent(prop.name)}',
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: [
            Tab(text: 'Rooms & Beds (${_rooms.length})'),
            Tab(text: 'Co-Owners (${_owners.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Rooms & Beds
                Scaffold(
                  backgroundColor: Colors.transparent,
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _showRoomDialog(),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Room'),
                  ),
                  body: RefreshIndicator(
                    onRefresh: _loadDetails,
                    child: _rooms.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 140),
                              Center(child: Text('No rooms configured yet.')),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: _rooms.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final r = _rooms[i];
                              return Container(
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
                                        Expanded(
                                          child: Text(
                                            'Room ${r.roomNumber} (Floor ${r.floorNumber}) • ${r.roomType}',
                                            style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_box_outlined, size: 20, color: AppTheme.primaryColor),
                                          tooltip: 'Add Bed',
                                          onPressed: () => _addBed(r),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20),
                                          onPressed: () => _showRoomDialog(existing: r),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                                          onPressed: () => _deleteRoom(r),
                                        ),
                                      ],
                                    ),
                                    Text(
                                      'With Food: ₹${r.monthlyRentWithFood.toStringAsFixed(0)} | Without Food: ₹${r.monthlyRentWithoutFood.toStringAsFixed(0)}',
                                      style: GoogleFonts.lato(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: r.beds.map((b) {
                                        final occ = b.status == 'OCCUPIED';
                                        return Chip(
                                          label: Text(
                                            occ && b.tenantName != null ? '${b.bedLabel}: ${b.tenantName}' : b.bedLabel,
                                            style: GoogleFonts.lato(fontSize: 11.5, fontWeight: FontWeight.w600),
                                          ),
                                          backgroundColor: occ ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                                          deleteIcon: occ ? null : const Icon(Icons.close, size: 14),
                                          onDeleted: occ
                                              ? null
                                              : () async {
                                                  await ApiService.deleteBedUnderOrg(b.id);
                                                  _loadDetails();
                                                },
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // Tab 2: Co-Owners
                Scaffold(
                  backgroundColor: Colors.transparent,
                  floatingActionButton: FloatingActionButton.extended(
                    onPressed: () => _showOwnerDialog(),
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    icon: const Icon(Icons.person_add_alt_1_rounded),
                    label: const Text('Add Co-Owner'),
                  ),
                  body: RefreshIndicator(
                    onRefresh: _loadDetails,
                    child: _owners.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: const [
                              SizedBox(height: 140),
                              Center(child: Text('No co-owners mapped to this PG.')),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                            itemCount: _owners.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final o = _owners[i];
                              return ListTile(
                                tileColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                title: Text(o.name, style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                                subtitle: Text('${o.phoneNumber} • ${o.role}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20),
                                      onPressed: () => _showOwnerDialog(existing: o),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.danger),
                                      onPressed: () => _deleteOwner(o),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
