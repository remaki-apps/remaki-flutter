import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/fancy_toast.dart';

class AddRoomBillScreen extends StatefulWidget {
  final String roomId;
  const AddRoomBillScreen({super.key, required this.roomId});

  @override
  State<AddRoomBillScreen> createState() => _AddRoomBillScreenState();
}

class _AddRoomBillScreenState extends State<AddRoomBillScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  Set<String> _selectedTenantIds = {};
  double _totalAmount = 0.0;
  String? _selectedCategory;

  final List<Map<String, dynamic>> _quickCategories = [
    {'label': 'Electricity', 'icon': Icons.bolt_rounded, 'color': Color(0xFFF59E0B)},
    {'label': 'Water', 'icon': Icons.water_drop_rounded, 'color': Color(0xFF3B82F6)},
    {'label': 'Cleaning', 'icon': Icons.cleaning_services_rounded, 'color': Color(0xFF10B981)},
    {'label': 'Wi-Fi', 'icon': Icons.wifi_rounded, 'color': Color(0xFF8B5CF6)},
    {'label': 'Mess / Food', 'icon': Icons.restaurant_rounded, 'color': Color(0xFFEC4899)},
    {'label': 'Maintenance', 'icon': Icons.build_rounded, 'color': Color(0xFF6366F1)},
  ];

  @override
  void initState() {
    super.initState();
    // Initialize selected tenants to all tenants in the room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final roomTenants = appProvider.tenants.where((t) => t.roomId == widget.roomId).toList();
      setState(() {
        _selectedTenantIds = roomTenants.map((t) => t.id).toSet();
      });
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _toggleSelectAll(List<Tenant> roomTenants) {
    setState(() {
      if (_selectedTenantIds.length == roomTenants.length) {
        _selectedTenantIds.clear();
      } else {
        _selectedTenantIds = roomTenants.map((t) => t.id).toSet();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final room = appProvider.rooms.firstWhere(
      (r) => r.id == widget.roomId,
      orElse: () => Room(id: widget.roomId, number: widget.roomId, capacity: 0, beds: []),
    );
    final roomTenants = appProvider.tenants.where((t) => t.roomId == widget.roomId).toList();
    final splitAmount = _selectedTenantIds.isNotEmpty ? _totalAmount / _selectedTenantIds.length : 0.0;
    final isAllSelected = roomTenants.isNotEmpty && _selectedTenantIds.length == roomTenants.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9FE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9FE),
        elevation: 0,
        centerTitle: false,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A), size: 20),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split Room Bill',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Room ${room.number}',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '• ${roomTenants.length} tenants',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero Bill Input Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.06),
                            const Color(0xFFEEF2FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x08000000),
                            blurRadius: 16,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.call_split_rounded, color: AppTheme.primaryColor, size: 16),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'ENTER TOTAL BILL AMOUNT',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Large Amount Input
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _amountController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -1,
                                  ),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: '0',
                                    hintStyle: TextStyle(
                                      color: Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w300,
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _totalAmount = double.tryParse(val) ?? 0.0;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Live Per-Tenant Breakdown Chip
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: _totalAmount > 0 && _selectedTenantIds.isNotEmpty
                                  ? const Color(0xFFDCFCE7)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _totalAmount > 0 && _selectedTenantIds.isNotEmpty
                                    ? const Color(0xFF86EFAC)
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.pie_chart_outline_rounded,
                                  size: 14,
                                  color: _totalAmount > 0 && _selectedTenantIds.isNotEmpty
                                      ? const Color(0xFF15803D)
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _selectedTenantIds.isEmpty
                                      ? 'Select tenants below'
                                      : '₹${splitAmount.toStringAsFixed(2)} / tenant',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _totalAmount > 0 && _selectedTenantIds.isNotEmpty
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Quick Category Suggestions
                    const Text(
                      'QUICK CATEGORY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _quickCategories.map((cat) {
                          final label = cat['label'] as String;
                          final icon = cat['icon'] as IconData;
                          final color = cat['color'] as Color;
                          final isSelected = _selectedCategory == label;

                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    size: 15,
                                    color: isSelected ? Colors.white : color,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(label),
                                ],
                              ),
                              selected: isSelected,
                              selectedColor: AppTheme.primaryColor,
                              backgroundColor: Colors.white,
                              elevation: 0,
                              pressElevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              side: BorderSide(
                                color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                              ),
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : const Color(0xFF475569),
                              ),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    _selectedCategory = label;
                                    _descController.text = label;
                                  } else {
                                    _selectedCategory = null;
                                    _descController.clear();
                                  }
                                });
                              },
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description Input Field
                    TextField(
                      controller: _descController,
                      decoration: InputDecoration(
                        labelText: 'Bill Description / Note',
                        hintText: 'e.g. Electricity Bill for July',
                        prefixIcon: const Icon(Icons.description_outlined, color: Color(0xFF64748B), size: 20),
                        filled: true,
                        fillColor: Colors.white,
                        labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        // Reset chip if text changed manually
                        if (_selectedCategory != val) {
                          setState(() {
                            _selectedCategory = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 28),

                    // Tenant Selection Header & Toggle All
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'SELECT TENANTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedTenantIds.length} of ${roomTenants.length} selected',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        if (roomTenants.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _toggleSelectAll(roomTenants),
                            icon: Icon(
                              isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            label: Text(
                              isAllSelected ? 'Deselect All' : 'Select All',
                              style: const TextStyle(
                                color: AppTheme.primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // List of Tenants
                    if (roomTenants.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline_rounded, color: Color(0xFF94A3B8), size: 40),
                            const SizedBox(height: 10),
                            const Text(
                              'No tenants in this room',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Allocate tenants to Room ${room.number} first before splitting bills.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: roomTenants.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final tenant = roomTenants[index];
                          final isSelected = _selectedTenantIds.contains(tenant.id);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF4EFFE) : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x03000000),
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedTenantIds.remove(tenant.id);
                                  } else {
                                    _selectedTenantIds.add(tenant.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    // Custom Rounded Checkbox
                                    Container(
                                      width: 22,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                                          : null,
                                    ),
                                    const SizedBox(width: 12),

                                    // Avatar & Info
                                    TenantAvatar(
                                      name: tenant.name,
                                      imageUrl: tenant.imageUrl,
                                      radius: 20,
                                    ),
                                    const SizedBox(width: 12),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tenant.name,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF475569),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Bed: ${tenant.bedId}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Calculated Split Amount Display
                                    Text(
                                      isSelected ? '₹${splitAmount.toStringAsFixed(2)}' : '₹0.00',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isSelected ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Sticky Bottom Summary & Split Bill Button
            Container(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0F000000),
                    blurRadius: 16,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Amount',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${_totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 32,
                        width: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Share (${_selectedTenantIds.length} tenants)',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '₹${splitAmount.toStringAsFixed(2)} / each',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _selectedTenantIds.isEmpty || _totalAmount <= 0
                          ? null
                          : () {
                              final desc = _descController.text.trim().isEmpty
                                  ? 'Room Bill'
                                  : _descController.text.trim();
                              appProvider.addBillToTenants(
                                _selectedTenantIds.toList(),
                                splitAmount,
                                desc,
                              );
                              FancyToast.showSuccess(
                                context,
                                'Bill Split Successfully!',
                                message: '₹${splitAmount.toStringAsFixed(2)} added to ${_selectedTenantIds.length} tenant(s).',
                              );
                              context.pop();
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        disabledBackgroundColor: const Color(0xFFCBD5E1),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 20),
                      label: const Text(
                        'Split Bill',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
