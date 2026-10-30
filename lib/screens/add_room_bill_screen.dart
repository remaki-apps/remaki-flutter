import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/tenant_avatar.dart';
import '../widgets/fancy_toast.dart';

enum SplitMode { even, byAmount }

class AddRoomBillScreen extends StatefulWidget {
  final String roomId;
  final double? initialAmount;
  const AddRoomBillScreen({super.key, required this.roomId, this.initialAmount});

  @override
  State<AddRoomBillScreen> createState() => _AddRoomBillScreenState();
}

class _AddRoomBillScreenState extends State<AddRoomBillScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  final Map<String, TextEditingController> _tenantControllers = {};
  final Map<String, double> _customAmounts = {};

  SplitMode _splitMode = SplitMode.even;
  Set<String> _selectedTenantIds = {};
  double _totalAmount = 0.0;
  String? _selectedCategory;
  bool _isSubmitting = false;

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
    if (widget.initialAmount != null && widget.initialAmount! > 0) {
      _totalAmount = widget.initialAmount!;
      _amountController.text = widget.initialAmount! % 1 == 0
          ? widget.initialAmount!.toInt().toString()
          : widget.initialAmount!.toString();
    }
    // Initialize selected tenants to all tenants in the room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final roomTenants = appProvider.tenants.where((t) => t.roomId == widget.roomId).toList();
      setState(() {
        _selectedTenantIds = roomTenants.map((t) => t.id).toSet();
        _syncTenantControllers(roomTenants);
      });
    });
  }

  void _syncTenantControllers(List<Tenant> roomTenants) {
    for (var tenant in roomTenants) {
      if (!_tenantControllers.containsKey(tenant.id)) {
        _tenantControllers[tenant.id] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    for (var c in _tenantControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double get _customTotalSum {
    double sum = 0.0;
    for (final id in _selectedTenantIds) {
      sum += _customAmounts[id] ?? 0.0;
    }
    return sum;
  }

  void _switchToByAmount(List<Tenant> roomTenants) {
    setState(() {
      _splitMode = SplitMode.byAmount;
      _syncTenantControllers(roomTenants);

      // If no custom amounts set yet and totalAmount > 0, pre-fill even distribution
      if (_customTotalSum <= 0 && _totalAmount > 0 && _selectedTenantIds.isNotEmpty) {
        final share = (_totalAmount / _selectedTenantIds.length);
        for (final t in roomTenants) {
          if (_selectedTenantIds.contains(t.id)) {
            final val = double.parse(share.toStringAsFixed(2));
            _customAmounts[t.id] = val;
            _tenantControllers[t.id]?.text = val % 1 == 0 ? val.toInt().toString() : val.toString();
          } else {
            _customAmounts[t.id] = 0.0;
            _tenantControllers[t.id]?.clear();
          }
        }
      }
    });
  }

  void _toggleSelectAll(List<Tenant> roomTenants) {
    setState(() {
      if (_selectedTenantIds.length == roomTenants.length) {
        _selectedTenantIds.clear();
        if (_splitMode == SplitMode.byAmount) {
          for (var t in roomTenants) {
            _customAmounts[t.id] = 0.0;
            _tenantControllers[t.id]?.clear();
          }
        }
      } else {
        _selectedTenantIds = roomTenants.map((t) => t.id).toSet();
      }
    });
  }

  void _updateTotalToCustomSum() {
    setState(() {
      _totalAmount = _customTotalSum;
      _amountController.text = _customTotalSum % 1 == 0
          ? _customTotalSum.toInt().toString()
          : _customTotalSum.toStringAsFixed(2);
    });
  }

  void _autoFillRemaining(List<Tenant> roomTenants) {
    final diff = _totalAmount - _customTotalSum;
    if (diff <= 0) return;

    // Find first selected tenant or tenant with 0 amount to allocate remainder
    final targetTenant = roomTenants.firstWhere(
      (t) => _selectedTenantIds.contains(t.id) && ((_customAmounts[t.id] ?? 0) <= 0),
      orElse: () => roomTenants.firstWhere((t) => _selectedTenantIds.contains(t.id), orElse: () => roomTenants.first),
    );

    setState(() {
      _selectedTenantIds.add(targetTenant.id);
      final current = _customAmounts[targetTenant.id] ?? 0.0;
      final newVal = current + diff;
      _customAmounts[targetTenant.id] = newVal;
      _tenantControllers[targetTenant.id]?.text = newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toStringAsFixed(2);
    });
  }

  void _navigateBackToRoom() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/room_details/${widget.roomId}');
    }
  }

  Future<void> _handleSplitBill() async {
    if (_isSubmitting) return;

    if (_totalAmount <= 0) {
      FancyToast.showError(
        context,
        'Enter Bill Amount',
        message: 'Please enter a total bill amount greater than ₹0.',
      );
      return;
    }

    if (_selectedTenantIds.isEmpty) {
      FancyToast.showError(
        context,
        'No Tenants Selected',
        message: 'Please select at least one tenant to split this bill with.',
      );
      return;
    }

    if (_splitMode == SplitMode.byAmount) {
      final diff = _totalAmount - _customTotalSum;
      if (diff.abs() >= 0.01) {
        if (diff > 0) {
          FancyToast.showError(
            context,
            'Amount Remaining',
            message: 'Please allocate the remaining ₹${diff.toStringAsFixed(2)} to tenants before splitting.',
          );
        } else {
          FancyToast.showError(
            context,
            'Amount Exceeded',
            message: 'Allocated sum exceeds total bill by ₹${(-diff).toStringAsFixed(2)}. Please adjust amounts.',
          );
        }
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final desc = _descController.text.trim().isEmpty ? 'Room Bill' : _descController.text.trim();
    final splitAmount = _selectedTenantIds.isNotEmpty ? _totalAmount / _selectedTenantIds.length : 0.0;

    try {
      if (_splitMode == SplitMode.even) {
        await appProvider.addBillToTenants(
          _selectedTenantIds.toList(),
          splitAmount,
          desc,
        );
      } else {
        await appProvider.addBillWithCustomSplits(
          roomId: widget.roomId,
          totalAmount: _totalAmount,
          splitsByTenantId: {
            for (var id in _selectedTenantIds) id: _customAmounts[id] ?? 0.0,
          },
          description: desc,
        );
      }
      if (!mounted) return;
      FancyToast.showSuccess(
        context,
        'Bill Split Successfully!',
        message: '₹${_totalAmount.toStringAsFixed(2)} added to ${_selectedTenantIds.length} tenant(s).',
      );
      _navigateBackToRoom();
    } catch (e) {
      if (!mounted) return;
      FancyToast.showError(
        context,
        'Failed to split bill',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final room = appProvider.rooms.firstWhere(
      (r) => r.id == widget.roomId,
      orElse: () => Room(id: widget.roomId, number: widget.roomId, capacity: 0, beds: []),
    );
    final roomTenants = appProvider.tenants.where((t) => t.roomId == widget.roomId).toList();
    _syncTenantControllers(roomTenants);

    final splitAmount = _selectedTenantIds.isNotEmpty ? _totalAmount / _selectedTenantIds.length : 0.0;
    final isAllSelected = roomTenants.isNotEmpty && _selectedTenantIds.length == roomTenants.length;
    final customSum = _customTotalSum;
    final diff = _totalAmount - customSum;
    final isExactMatch = diff.abs() < 0.01;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigateBackToRoom();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFAF9FE),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFAF9FE),
          elevation: 0,
          centerTitle: false,
          leading: Padding(
            padding: const EdgeInsets.all(8.0),
            child: GestureDetector(
              onTap: _navigateBackToRoom,
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Container(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                    // Compact Classic Bill Input Card with original subtle gradient
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryColor.withValues(alpha: 0.06),
                            const Color(0xFFEEF2FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.15)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x06000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Flexible(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.receipt_long_rounded,
                                        color: AppTheme.primaryColor,
                                        size: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 7),
                                    const Flexible(
                                      child: Text(
                                        'TOTAL BILL AMOUNT',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _splitMode == SplitMode.even
                                      ? (_totalAmount > 0 && _selectedTenantIds.isNotEmpty ? const Color(0xFFDCFCE7) : Colors.white)
                                      : (isExactMatch && _totalAmount > 0 ? const Color(0xFFDCFCE7) : (diff > 0 ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2))),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _splitMode == SplitMode.even
                                        ? (_totalAmount > 0 && _selectedTenantIds.isNotEmpty ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0))
                                        : (isExactMatch && _totalAmount > 0 ? const Color(0xFF86EFAC) : (diff > 0 ? const Color(0xFFFCD34D) : const Color(0xFFFCA5A5))),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _splitMode == SplitMode.even
                                          ? Icons.pie_chart_outline_rounded
                                          : (isExactMatch ? Icons.check_circle_outline_rounded : Icons.tune_rounded),
                                      size: 13,
                                      color: _splitMode == SplitMode.even
                                          ? (_totalAmount > 0 && _selectedTenantIds.isNotEmpty ? const Color(0xFF15803D) : const Color(0xFF64748B))
                                          : (isExactMatch ? const Color(0xFF15803D) : (diff > 0 ? const Color(0xFFB45309) : const Color(0xFFB91C1C))),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _splitMode == SplitMode.even
                                          ? (_selectedTenantIds.isEmpty ? 'Select tenants' : '₹${splitAmount.toStringAsFixed(2)} / each')
                                          : (isExactMatch
                                              ? '✓ Matched'
                                              : (diff > 0 ? '₹${diff.toStringAsFixed(2)} left' : '₹${(-diff).toStringAsFixed(2)} over')),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: _splitMode == SplitMode.even
                                            ? (_totalAmount > 0 && _selectedTenantIds.isNotEmpty ? const Color(0xFF15803D) : const Color(0xFF64748B))
                                            : (isExactMatch ? const Color(0xFF15803D) : (diff > 0 ? const Color(0xFFB45309) : const Color(0xFFB91C1C))),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text(
                                '₹',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IntrinsicWidth(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(minWidth: 50, maxWidth: 240),
                                  child: TextField(
                                    controller: _amountController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      height: 1.2,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        color: Color(0xFFCBD5E1),
                                        fontWeight: FontWeight.w400,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(vertical: 2),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _totalAmount = double.tryParse(val) ?? 0.0;
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick Category Suggestions
                    const Text(
                      'QUICK CATEGORY',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
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
                                    size: 16,
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
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                ),
                              ),
                              labelStyle: TextStyle(
                                fontSize: 13,
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
                    const SizedBox(height: 12),

                    // Description Input Field
                    TextField(
                      controller: _descController,
                      style: const TextStyle(
                        fontSize: 14.5,
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Bill description / note (e.g. Electricity)',
                        prefixIcon: const Icon(Icons.notes_rounded, color: Color(0xFF64748B), size: 20),
                        prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 42),
                        filled: true,
                        fillColor: Colors.white,
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                        ),
                      ),
                      onChanged: (val) {
                        if (_selectedCategory != val) {
                          setState(() {
                            _selectedCategory = null;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Split Mode Switcher (Split Evenly vs By Amounts)
                    Container(
                      height: 40,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _splitMode = SplitMode.even),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _splitMode == SplitMode.even ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _splitMode == SplitMode.even
                                      ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.pie_chart_outline_rounded,
                                      size: 15,
                                      color: _splitMode == SplitMode.even ? AppTheme.primaryColor : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Split Evenly',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _splitMode == SplitMode.even ? FontWeight.bold : FontWeight.w600,
                                        color: _splitMode == SplitMode.even ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _switchToByAmount(roomTenants),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: _splitMode == SplitMode.byAmount ? Colors.white : Colors.transparent,
                                  borderRadius: BorderRadius.circular(9),
                                  boxShadow: _splitMode == SplitMode.byAmount
                                      ? const [BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1))]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.tune_rounded,
                                      size: 15,
                                      color: _splitMode == SplitMode.byAmount ? AppTheme.primaryColor : const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Split by Amounts',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: _splitMode == SplitMode.byAmount ? FontWeight.bold : FontWeight.w600,
                                        color: _splitMode == SplitMode.byAmount ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Balance Helper Banner for "By Amounts" mode
                    if (_splitMode == SplitMode.byAmount) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isExactMatch && _totalAmount > 0
                              ? const Color(0xFFDCFCE7)
                              : (diff > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2)),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isExactMatch && _totalAmount > 0
                                ? const Color(0xFF86EFAC)
                                : (diff > 0 ? const Color(0xFFFDE68A) : const Color(0xFFFECACA)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isExactMatch && _totalAmount > 0
                                  ? Icons.check_circle_rounded
                                  : (diff > 0 ? Icons.info_outline_rounded : Icons.warning_amber_rounded),
                              size: 16,
                              color: isExactMatch && _totalAmount > 0
                                  ? const Color(0xFF15803D)
                                  : (diff > 0 ? const Color(0xFFB45309) : const Color(0xFFB91C1C)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isExactMatch && _totalAmount > 0
                                    ? 'Exact match: All ₹${_totalAmount.toStringAsFixed(2)} allocated!'
                                    : (diff > 0
                                        ? 'Allocated ₹${customSum.toStringAsFixed(2)} • ₹${diff.toStringAsFixed(2)} remaining'
                                        : 'Allocated ₹${customSum.toStringAsFixed(2)} • ₹${(-diff).toStringAsFixed(2)} over total'),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isExactMatch && _totalAmount > 0
                                      ? const Color(0xFF15803D)
                                      : (diff > 0 ? const Color(0xFFB45309) : const Color(0xFFB91C1C)),
                                ),
                              ),
                            ),
                            if (!isExactMatch)
                              GestureDetector(
                                onTap: diff > 0
                                    ? () => _autoFillRemaining(roomTenants)
                                    : _updateTotalToCustomSum,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: diff > 0 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    diff > 0 ? 'Fill Remainder' : 'Match Total',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Tenant Selection Header & Toggle All
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'SELECT TENANTS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                                color: Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${_selectedTenantIds.length}/${roomTenants.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (roomTenants.isNotEmpty)
                          InkWell(
                            onTap: () => _toggleSelectAll(roomTenants),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isAllSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                                    size: 14,
                                    color: AppTheme.primaryColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isAllSelected ? 'Deselect All' : 'Select All',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // List of Tenants
                    if (roomTenants.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.people_outline_rounded, color: Color(0xFF94A3B8), size: 32),
                            const SizedBox(height: 8),
                            const Text(
                              'No tenants in this room',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
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
                        separatorBuilder: (context, index) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final tenant = roomTenants[index];
                          final isSelected = _selectedTenantIds.contains(tenant.id);

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFFF8F5FE) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
                                width: isSelected ? 1.5 : 1,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x03000000),
                                  blurRadius: 4,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedTenantIds.remove(tenant.id);
                                    if (_splitMode == SplitMode.byAmount) {
                                      _customAmounts[tenant.id] = 0.0;
                                      _tenantControllers[tenant.id]?.clear();
                                    }
                                  } else {
                                    _selectedTenantIds.add(tenant.id);
                                    if (_splitMode == SplitMode.byAmount) {
                                      // If there is remainder, suggest it into this newly selected tenant
                                      final currentDiff = _totalAmount - _customTotalSum;
                                      if (currentDiff > 0) {
                                        _customAmounts[tenant.id] = currentDiff;
                                        _tenantControllers[tenant.id]?.text = currentDiff % 1 == 0
                                            ? currentDiff.toInt().toString()
                                            : currentDiff.toStringAsFixed(2);
                                      }
                                    }
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    // Custom Rounded Checkbox
                                    Container(
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: isSelected
                                          ? const Icon(Icons.check_rounded, color: Colors.white, size: 12)
                                          : null,
                                    ),
                                    const SizedBox(width: 10),

                                    // Avatar
                                    TenantAvatar(
                                      name: tenant.name,
                                      imageUrl: tenant.imageUrl,
                                      radius: 16,
                                    ),
                                    const SizedBox(width: 10),

                                    // Tenant Name only (Bed removed per request)
                                    Expanded(
                                      child: Text(
                                        tenant.name,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),

                                    // Amount display: Static split or Editable input field
                                    if (_splitMode == SplitMode.even) ...[
                                      Text(
                                        isSelected ? '₹${splitAmount.toStringAsFixed(2)}' : '₹0.00',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected ? AppTheme.primaryColor : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        width: 100,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: isSelected ? Colors.white : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: isSelected ? AppTheme.primaryColor : const Color(0xFFCBD5E1),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 8),
                                        alignment: Alignment.center,
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            const Text(
                                              '₹',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryColor,
                                              ),
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: TextField(
                                                controller: _tenantControllers[tenant.id],
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                decoration: const InputDecoration(
                                                  isDense: true,
                                                  border: InputBorder.none,
                                                  hintText: '0',
                                                  hintStyle: TextStyle(
                                                    color: Color(0xFF94A3B8),
                                                    fontSize: 13.5,
                                                  ),
                                                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                                                ),
                                                onChanged: (val) {
                                                  final parsed = double.tryParse(val) ?? 0.0;
                                                  setState(() {
                                                    _customAmounts[tenant.id] = parsed;
                                                    if (parsed > 0 && !isSelected) {
                                                      _selectedTenantIds.add(tenant.id);
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'TOTAL BILL',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              alignment: Alignment.centerLeft,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '₹${_totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 26,
                        width: 1,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        color: const Color(0xFFE2E8F0),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _splitMode == SplitMode.even
                                  ? 'SHARE (${_selectedTenantIds.length} TENANTS)'
                                  : 'ALLOCATED (${_selectedTenantIds.length} TENANTS)',
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            FittedBox(
                              alignment: Alignment.centerRight,
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _splitMode == SplitMode.even
                                    ? '₹${splitAmount.toStringAsFixed(2)} / each'
                                    : '₹${customSum.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: _splitMode == SplitMode.even
                                      ? AppTheme.primaryColor
                                      : (isExactMatch ? const Color(0xFF15803D) : const Color(0xFFE11D48)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _handleSplitBill,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        elevation: 2,
                        shadowColor: AppTheme.primaryColor.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Splitting Bill...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Icon(Icons.call_split_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'Split Bill',
                                  style: TextStyle(
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
