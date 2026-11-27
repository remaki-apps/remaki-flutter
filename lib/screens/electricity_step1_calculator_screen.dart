import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';

class ElectricityStep1CalculatorScreen extends StatefulWidget {
  final String? propertyId;
  final String? roomId;
  final String? groupId;

  const ElectricityStep1CalculatorScreen({
    super.key,
    this.propertyId,
    this.roomId,
    this.groupId,
  });

  @override
  State<ElectricityStep1CalculatorScreen> createState() =>
      _ElectricityStep1CalculatorScreenState();
}

class _ElectricityStep1CalculatorScreenState
    extends State<ElectricityStep1CalculatorScreen> {
  bool _isLoading = true;
  String? _loadError;

  String _resolvedPropertyId = '';
  String _scopeTitle = 'Electricity Calculator';
  String _scopeSubtitle = '';
  List<String> _roomIds = [];

  double _propertyDefaultRate = 0.0;
  double? _overrideRate;
  double _effectiveRate = 0.0;
  double _oldReading = 0.0;

  late String _billingMonth; // YYYY-MM
  final _oldReadingCtrl = TextEditingController();
  final _newReadingCtrl = TextEditingController();
  final _rateCtrl = TextEditingController();

  bool _isEditingRate = false;
  bool _isSavingRate = false;

  bool get _isGroupMode => widget.groupId != null && widget.groupId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _billingMonth = DateFormat('yyyy-MM').format(DateTime.now());
    _loadContext();
  }

  @override
  void dispose() {
    _oldReadingCtrl.dispose();
    _newReadingCtrl.dispose();
    _rateCtrl.dispose();
    super.dispose();
  }

  String _formatNum(double v) =>
      v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);

  String _formatMmYy(String yyyyMm) {
    final parts = yyyyMm.split('-');
    if (parts.length == 2 && parts[0].length >= 2) {
      return '${parts[1]}/${parts[0].substring(parts[0].length - 2)}';
    }
    return yyyyMm;
  }

  Future<void> _loadContext() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      if (_isGroupMode) {
        final rawGroups =
            await ApiService.fetchElectricityGroups(propertyId: widget.propertyId);
        final groups = rawGroups
            .map((g) => ElectricityRoomGroup.fromJson(g as Map<String, dynamic>))
            .toList();
        final group = groups.firstWhere(
          (g) => g.id == widget.groupId,
          orElse: () => throw Exception('Combined group not found'),
        );
        if (!mounted) return;
        setState(() {
          _resolvedPropertyId = group.propertyId;
          _scopeTitle = group.name;
          final roomLabels = group.rooms.map((r) => r.roomNumber).join(', ');
          _scopeSubtitle = 'Combined Group • Rooms: $roomLabels';
          _roomIds = group.rooms.map((r) => r.roomId).toList();
          _propertyDefaultRate = group.propertyDefaultCostPerUnit;
          _overrideRate = group.costPerUnitOverride;
          _effectiveRate = group.effectiveCostPerUnit;
          _oldReading = group.lastMeterReading ?? 0.0;
          _oldReadingCtrl.text = _formatNum(_oldReading);
          _rateCtrl.text = _effectiveRate > 0 ? _formatNum(_effectiveRate) : '';
          _isLoading = false;
        });
      } else if (widget.roomId != null && widget.roomId!.isNotEmpty) {
        final raw = await ApiService.fetchRoomElectricityContext(widget.roomId!);
        final ctx = RoomElectricityContext.fromJson(raw);
        if (!mounted) return;
        setState(() {
          _resolvedPropertyId = ctx.propertyId;
          _scopeTitle = 'Room ${ctx.roomNumber}';
          _scopeSubtitle = 'Single Room Meter';
          _roomIds = [ctx.roomId];
          _propertyDefaultRate = ctx.propertyDefaultCostPerUnit;
          _overrideRate = ctx.costPerUnitOverride;
          _effectiveRate = ctx.effectiveCostPerUnit;
          _oldReading = ctx.lastReading ?? 0.0;
          _oldReadingCtrl.text = _formatNum(_oldReading);
          _rateCtrl.text = _effectiveRate > 0 ? _formatNum(_effectiveRate) : '';
          _isLoading = false;
        });
      } else {
        throw Exception('Room or group ID is required.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = ApiService.cleanErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveRateOverride({bool clearToDefault = false}) async {
    double? newOverride;
    if (!clearToDefault) {
      final parsed = double.tryParse(_rateCtrl.text.trim());
      if (parsed == null || parsed <= 0) {
        FancyToast.showError(
          context,
          'Invalid Rate',
          message: 'Enter a valid cost per unit greater than 0.',
        );
        return;
      }
      newOverride = parsed;
    }

    setState(() => _isSavingRate = true);
    try {
      if (_isGroupMode) {
        final raw = await ApiService.updateElectricityGroup(
          groupId: widget.groupId!,
          costPerUnitOverride: newOverride,
          updateCostOverride: true,
        );
        final updated = ElectricityRoomGroup.fromJson(raw);
        if (!mounted) return;
        setState(() {
          _overrideRate = updated.costPerUnitOverride;
          _effectiveRate = updated.effectiveCostPerUnit;
          _rateCtrl.text = _effectiveRate > 0 ? _formatNum(_effectiveRate) : '';
          _isEditingRate = false;
        });
      } else {
        final raw = await ApiService.updateElectricityRoomRate(
          roomId: widget.roomId!,
          costPerUnitOverride: newOverride,
        );
        final updated = RoomElectricityContext.fromJson(raw);
        if (!mounted) return;
        setState(() {
          _overrideRate = updated.costPerUnitOverride;
          _effectiveRate = updated.effectiveCostPerUnit;
          _rateCtrl.text = _effectiveRate > 0 ? _formatNum(_effectiveRate) : '';
          _isEditingRate = false;
        });
      }
      FancyToast.showSuccess(
        context,
        clearToDefault
            ? 'Reverted to PG default rate.'
            : 'Saved custom rate for $_scopeTitle.',
      );
    } catch (e) {
      if (mounted) {
        FancyToast.showError(
          context,
          'Rate Update Failed',
          message: ApiService.cleanErrorMessage(e),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingRate = false);
    }
  }

  Future<void> _pickBillingMonth() async {
    final now = DateTime.now();
    final parts = _billingMonth.split('-');
    final initYear = int.tryParse(parts[0]) ?? now.year;
    final initMonth = parts.length > 1 ? (int.tryParse(parts[1]) ?? now.month) : now.month;

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(initYear, initMonth, 1),
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Select Billing Month',
    );
    if (picked != null && mounted) {
      setState(() {
        _billingMonth = DateFormat('yyyy-MM').format(picked);
      });
    }
  }

  double get _parsedOld => double.tryParse(_oldReadingCtrl.text.trim()) ?? 0.0;
  double get _parsedNew => double.tryParse(_newReadingCtrl.text.trim()) ?? 0.0;
  double get _unitsConsumed =>
      _parsedNew > _parsedOld ? (_parsedNew - _parsedOld) : 0.0;
  double get _calculatedTotal =>
      double.parse((_unitsConsumed * _effectiveRate).toStringAsFixed(2));

  Future<void> _proceedToStep2() async {
    if (_isEditingRate) {
      FancyToast.showError(
        context,
        'Save Rate First',
        message: 'Please save or cancel your cost per unit edit before continuing.',
      );
      return;
    }

    final oldVal = double.tryParse(_oldReadingCtrl.text.trim());
    final newVal = double.tryParse(_newReadingCtrl.text.trim());
    if (oldVal == null || oldVal < 0) {
      FancyToast.showError(
        context,
        'Invalid Old Reading',
        message: 'Enter a valid non-negative old unit reading.',
      );
      return;
    }
    if (newVal == null || newVal <= oldVal) {
      FancyToast.showError(
        context,
        'Invalid New Reading',
        message: 'New unit reading must be greater than old unit reading (${_formatNum(oldVal)}).',
      );
      return;
    }
    if (_effectiveRate <= 0) {
      FancyToast.showError(
        context,
        'Rate Required',
        message: 'Please set a valid cost per unit (> 0) before continuing.',
      );
      return;
    }

    final units = double.parse((newVal - oldVal).toStringAsFixed(2));
    final total = double.parse((units * _effectiveRate).toStringAsFixed(2));
    final draft = ElectricitySplitDraft(
      scopeType: _isGroupMode ? 'COMBINED_GROUP' : 'SINGLE_ROOM',
      propertyId: _resolvedPropertyId,
      roomId: _isGroupMode ? null : widget.roomId,
      groupId: _isGroupMode ? widget.groupId : null,
      roomIds: _roomIds,
      title: '$_scopeTitle Electricity',
      billingMonth: _billingMonth,
      previousReading: oldVal,
      currentReading: newVal,
      unitsConsumed: units,
      costPerUnit: _effectiveRate,
      totalAmount: total,
      defaultDescription: 'Electricity bill - ${_formatMmYy(_billingMonth)}',
    );

    final res = await context.push('/add_room_bill', extra: draft);
    if (res == true && mounted) {
      context.pop(true);
    }
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
        title: Text(
          'Electricity Calculator',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: const Color(0xFF0F172A),
          ),
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
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFEF4444), size: 40),
                        const SizedBox(height: 12),
                        Text(
                          _loadError!,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.lato(
                              fontSize: 14, color: const Color(0xFF334155)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadContext,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Scope Header Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.bolt_rounded,
                                      color: Color(0xFFD97706), size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _scopeTitle,
                                        style: GoogleFonts.lato(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _scopeSubtitle,
                                        style: GoogleFonts.lato(
                                          fontSize: 12.5,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  onPressed: _pickBillingMonth,
                                  icon: const Icon(Icons.calendar_month_rounded, size: 16),
                                  label: Text(
                                    _formatMmYy(_billingMonth),
                                    style: GoogleFonts.lato(
                                        fontWeight: FontWeight.w700, fontSize: 12.5),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Meter Readings Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'METER READINGS',
                                  style: GoogleFonts.lato(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _oldReadingCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true),
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          labelText: 'Old Unit Reading',
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: _newReadingCtrl,
                                        autofocus: true,
                                        keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true),
                                        onChanged: (_) => setState(() {}),
                                        decoration: InputDecoration(
                                          labelText: 'New Unit Reading',
                                          hintText: 'e.g. 150',
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Cost Per Unit with Edit -> Save
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'COST PER UNIT (THIS ${_isGroupMode ? 'GROUP' : 'ROOM'} ONLY)',
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                        color: const Color(0xFF64748B),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: _overrideRate != null
                                            ? const Color(0xFFFEF3C7)
                                            : const Color(0xFFEEF2FF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _overrideRate != null
                                            ? 'Custom Rate'
                                            : 'PG Default (₹${_formatNum(_propertyDefaultRate)})',
                                        style: GoogleFonts.lato(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: _overrideRate != null
                                              ? const Color(0xFF92400E)
                                              : const Color(0xFF4338CA),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _rateCtrl,
                                        readOnly: !_isEditingRate,
                                        keyboardType: const TextInputType.numberWithOptions(
                                            decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Cost per Unit (₹)',
                                          prefixText: '₹ ',
                                          filled: !_isEditingRate,
                                          fillColor: _isEditingRate
                                              ? Colors.white
                                              : const Color(0xFFF8FAFC),
                                          border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                          contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    if (!_isEditingRate)
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                            setState(() => _isEditingRate = true),
                                        icon: const Icon(Icons.edit_rounded, size: 16),
                                        label: const Text('Edit'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFEEF2FF),
                                          foregroundColor: AppTheme.primaryColor,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                      )
                                    else ...[
                                      ElevatedButton(
                                        onPressed: _isSavingRate
                                            ? null
                                            : () => _saveRateOverride(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFD97706),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 16, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12)),
                                        ),
                                        child: _isSavingRate
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white),
                                              )
                                            : const Text('Save'),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed: _isSavingRate
                                            ? null
                                            : () {
                                                setState(() {
                                                  _isEditingRate = false;
                                                  _rateCtrl.text = _effectiveRate > 0
                                                      ? _formatNum(_effectiveRate)
                                                      : '';
                                                });
                                              },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ],
                                ),
                                if (_overrideRate != null && !_isEditingRate) ...[
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _isSavingRate
                                          ? null
                                          : () => _saveRateOverride(clearToDefault: true),
                                      child: Text(
                                        'Reset to PG Default (₹${_formatNum(_propertyDefaultRate)})',
                                        style: GoogleFonts.lato(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Live Calculation Summary
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'UNITS CONSUMED',
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFC7D2FE),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_formatNum(_unitsConsumed)} units',
                                      style: GoogleFonts.lato(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'TOTAL ELECTRICITY BILL',
                                      style: GoogleFonts.lato(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFC7D2FE),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '₹${_calculatedTotal.toStringAsFixed(2)}',
                                      style: GoogleFonts.lato(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        color: const Color(0xFFFDE68A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: _proceedToStep2,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: Text(
                                'Next: Select Tenants & Split',
                                style: GoogleFonts.lato(
                                    fontSize: 15.5, fontWeight: FontWeight.w800),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}
