import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
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
  bool _isSavingConfig = false;
  bool _isEditingRate = false;
  bool _isPreviewing = false;
  bool _isGenerating = false;
  String? _errorMessage;

  bool _enabled = false;
  String _propertyId = '';
  String _propertyName = '';
  double _savedCostPerUnit = 0.0;
  double? _latestReading;
  String? _latestBillingMonth;

  final _costPerUnitCtrl = TextEditingController();
  final _prevReadingCtrl = TextEditingController();
  final _currReadingCtrl = TextEditingController();

  late String _billingMonth;

  List<Map<String, dynamic>> _rooms = [];
  Set<String> _selectedRoomIds = {};
  Map<String, dynamic>? _preview;
  List<Map<String, dynamic>> _cycles = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final now = DateTime.now();
    _billingMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _costPerUnitCtrl.dispose();
    _prevReadingCtrl.dispose();
    _currReadingCtrl.dispose();
    super.dispose();
  }

  String? get _effectivePropertyId {
    if (widget.propertyId != null && widget.propertyId!.isNotEmpty) {
      return widget.propertyId;
    }
    return context.read<AppProvider>().selectedPropertyId;
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final propId = _effectivePropertyId;
      final config = await ApiService.fetchElectricityConfig(propertyId: propId);

      final enabled = config['electricityCalculatorEnabled'] == true;
      final latestReading = (config['latestReading'] as num?)?.toDouble();
      final costPerUnit = (config['costPerUnit'] as num?)?.toDouble() ?? 0.0;
      final roomsRaw = (config['rooms'] as List<dynamic>?) ?? [];
      final rooms = roomsRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final savedRoomIds = ((config['sharedRoomIds'] as List<dynamic>?) ?? [])
          .map((e) => e.toString())
          .toSet();

      List<Map<String, dynamic>> cycles = [];
      if (enabled) {
        final cyclesRaw = await ApiService.fetchElectricityCycles(propertyId: propId);
        cycles = cyclesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }

      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _propertyId = config['propertyId']?.toString() ?? '';
        _propertyName = config['propertyName']?.toString() ?? 'PG Property';
        _savedCostPerUnit = costPerUnit;
        _isEditingRate = costPerUnit <= 0;
        _latestReading = latestReading;
        _latestBillingMonth = config['latestBillingMonth']?.toString();
        _costPerUnitCtrl.text = costPerUnit > 0 ? _fmtNum(costPerUnit) : '';
        _prevReadingCtrl.text = latestReading != null ? _fmtNum(latestReading) : '0';
        _rooms = rooms;
        _selectedRoomIds = savedRoomIds;
        _cycles = cycles;
        _preview = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }

  String _formatMonth(String ym) {
    try {
      final dt = DateTime.parse('$ym-01');
      return DateFormat('MMMM yyyy').format(dt);
    } catch (_) {
      return ym;
    }
  }

  double get _livePrevReading =>
      _latestReading ?? (double.tryParse(_prevReadingCtrl.text.trim()) ?? 0.0);

  double? get _liveCurrReading => double.tryParse(_currReadingCtrl.text.trim());

  double get _liveRate => double.tryParse(_costPerUnitCtrl.text.trim()) ?? 0.0;

  double? get _liveUnits {
    final curr = _liveCurrReading;
    if (curr == null) return null;
    return curr - _livePrevReading;
  }

  double? get _liveTotalAmount {
    final units = _liveUnits;
    if (units == null || units < 0 || _liveRate <= 0) return null;
    return units * _liveRate;
  }

  Future<void> _saveRate() async {
    final rate = double.tryParse(_costPerUnitCtrl.text.trim());
    if (rate == null || rate <= 0) {
      FancyToast.showError(
        context,
        'Invalid Rate',
        message: 'Please enter a cost per unit greater than 0.',
      );
      return;
    }

    setState(() => _isSavingConfig = true);
    try {
      await ApiService.updateElectricityConfig(
        propertyId: _propertyId,
        costPerUnit: rate,
        sharedRoomIds: _selectedRoomIds.toList(),
      );
      if (!mounted) return;
      setState(() {
        _savedCostPerUnit = rate;
        _isEditingRate = false;
        _preview = null;
      });
      FancyToast.showSuccess(
        context,
        'Rate Saved',
        message: 'Electricity rate updated to ₹${_fmtNum(rate)} per unit.',
      );
    } catch (e) {
      if (mounted) {
        FancyToast.showError(
          context,
          'Save Failed',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  Future<void> _saveSelectedRooms() async {
    setState(() => _isSavingConfig = true);
    try {
      await ApiService.updateElectricityConfig(
        propertyId: _propertyId,
        costPerUnit: _liveRate > 0 ? _liveRate : _savedCostPerUnit,
        sharedRoomIds: _selectedRoomIds.toList(),
      );
      if (!mounted) return;
      FancyToast.showSuccess(
        context,
        'Rooms Saved',
        message: 'Default room selection updated.',
      );
    } catch (e) {
      if (mounted) {
        FancyToast.showError(
          context,
          'Save Failed',
          message: e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  Future<void> _previewSplit() async {
    if (_isEditingRate) {
      FancyToast.showError(
        context,
        'Save Rate First',
        message: 'Please save the electricity rate before calculating.',
      );
      return;
    }

    final curr = _liveCurrReading;
    final prev = _livePrevReading;
    final rate = _liveRate;

    if (rate <= 0) {
      FancyToast.showError(context, 'Rate Required', message: 'Set cost per unit (> 0) first.');
      return;
    }
    if (curr == null || curr < 0) {
      FancyToast.showError(context, 'Current Reading Required', message: 'Enter a valid current meter reading.');
      return;
    }
    if (curr <= prev) {
      FancyToast.showError(
        context,
        'Invalid Reading',
        message: 'Current reading (${_fmtNum(curr)}) must be greater than previous reading (${_fmtNum(prev)}).',
      );
      return;
    }
    if (_selectedRoomIds.isEmpty) {
      FancyToast.showError(context, 'Select Rooms', message: 'Select at least one room to share the bill.');
      return;
    }

    setState(() => _isPreviewing = true);
    try {
      final preview = await ApiService.previewElectricitySplit(
        propertyId: _propertyId,
        billingMonth: _billingMonth,
        previousReading: _latestReading == null ? prev : null,
        currentReading: curr,
        costPerUnitOverride: rate,
        selectedRoomIds: _selectedRoomIds.toList(),
      );
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isPreviewing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPreviewing = false);
      FancyToast.showError(context, 'Calculation Failed', message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirmAndGenerate() async {
    if (_preview == null) return;
    final sharesCount = _preview!['eligibleTenantCount'] ?? 0;
    final total = (_preview!['totalAmount'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final monthLabel = _formatMonth(_billingMonth);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Generate Electricity Bills?', style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
        content: Text(
          'This will add a total of ₹$total split across $sharesCount tenant(s) for $monthLabel and notify them.',
          style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
            child: const Text('Generate & Notify'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isGenerating = true);
    try {
      await ApiService.generateElectricityBills(
        propertyId: _propertyId,
        billingMonth: _billingMonth,
        previousReading: _latestReading == null ? _livePrevReading : null,
        currentReading: _liveCurrReading!,
        costPerUnitOverride: _liveRate,
        selectedRoomIds: _selectedRoomIds.toList(),
      );

      await ApiService.updateElectricityConfig(
        propertyId: _propertyId,
        costPerUnit: _liveRate,
        sharedRoomIds: _selectedRoomIds.toList(),
      );

      if (!mounted) return;
      _currReadingCtrl.clear();
      setState(() {
        _isGenerating = false;
        _preview = null;
      });
      FancyToast.showSuccess(
        context,
        'Bills Generated',
        message: 'Electricity bills added and tenants notified.',
      );
      await _loadAll();
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      FancyToast.showError(context, 'Generation Failed', message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _voidCycle(String cycleId, String month) async {
    final monthLabel = _formatMonth(month);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Cancel $monthLabel Bill?', style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
        content: Text(
          'This will cancel the $monthLabel electricity bill and remove the unpaid charges from tenants. This is only allowed if no tenant has paid yet.',
          style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep Bill')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Cancel Bill'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.voidLatestElectricityCycle(cycleId);
      if (!mounted) return;
      FancyToast.showSuccess(
        context,
        'Bill Cancelled',
        message: '$monthLabel electricity bill has been cancelled.',
      );
      await _loadAll();
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Cannot Cancel', message: e.toString().replaceFirst('Exception: ', ''));
      }
    }
  }

  List<String> _monthOptions() {
    final now = DateTime.now();
    final List<String> months = [];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      months.add('${d.year}-${d.month.toString().padLeft(2, '0')}');
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Electricity Calculator',
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
            if (_propertyName.isNotEmpty)
              Text(
                _propertyName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.lato(fontSize: 11.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
              ),
          ],
        ),
        bottom: _enabled
            ? TabBar(
                controller: _tabController,
                labelColor: AppTheme.primaryColor,
                unselectedLabelColor: const Color(0xFF64748B),
                indicatorColor: AppTheme.primaryColor,
                labelStyle: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 13.5),
                tabs: const [
                  Tab(text: 'Calculate & Split'),
                  Tab(text: 'Billing History'),
                ],
              )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : !_enabled
                  ? _buildDisabledState()
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildCalculatorTab(),
                        _buildHistoryTab(),
                      ],
                    ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFEF4444)),
            const SizedBox(height: 12),
            Text(_errorMessage ?? 'Something went wrong', textAlign: TextAlign.center, style: GoogleFonts.lato(fontSize: 14)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAll, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildDisabledState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(16)),
                child: const Icon(Icons.bolt_rounded, size: 36, color: Color(0xFFD97706)),
              ),
              const SizedBox(height: 16),
              Text(
                'Feature Not Enabled',
                style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 8),
              Text(
                'The Electricity Bill Calculator is not enabled for $_propertyName. Please contact your Organization to enable it for this PG.',
                textAlign: TextAlign.center,
                style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatorTab() {
    final months = _monthOptions();
    final units = _liveUnits;
    final totalAmt = _liveTotalAmount;

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Electricity Rate Card (Edit / Save pattern)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Electricity Rate',
                        style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    if (!_isEditingRate)
                      TextButton.icon(
                        onPressed: () => setState(() => _isEditingRate = true),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      )
                    else ...[
                      if (_savedCostPerUnit > 0)
                        TextButton(
                          onPressed: _isSavingConfig
                              ? null
                              : () {
                                  setState(() {
                                    _costPerUnitCtrl.text = _fmtNum(_savedCostPerUnit);
                                    _isEditingRate = false;
                                  });
                                },
                          child: const Text('Cancel'),
                        ),
                      ElevatedButton.icon(
                        onPressed: _isSavingConfig ? null : _saveRate,
                        icon: _isSavingConfig
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (!_isEditingRate)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Cost per Unit',
                          style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '₹${_fmtNum(_savedCostPerUnit)} / unit',
                          style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  )
                else
                  TextFormField(
                    controller: _costPerUnitCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _preview = null),
                    decoration: _inputDeco('Cost per Unit (₹ / kWh)', prefixText: '₹ '),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Meter Reading Card (No Due Date)
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meter Reading & Month', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: months.contains(_billingMonth) ? _billingMonth : months.first,
                  isExpanded: true,
                  decoration: _inputDeco('Billing Month'),
                  items: months.map((m) {
                    return DropdownMenuItem(
                      value: m,
                      child: Text(_formatMonth(m), overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() { _billingMonth = val; _preview = null; });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _prevReadingCtrl,
                        readOnly: _latestReading != null,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _preview = null),
                        decoration: _inputDeco(
                          _latestReading != null
                              ? 'Previous (${_latestBillingMonth ?? ''})'
                              : 'Starting Reading',
                        ).copyWith(
                          fillColor: _latestReading != null ? const Color(0xFFF1F5F9) : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _currReadingCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (_) => setState(() => _preview = null),
                        decoration: _inputDeco('Current Reading *'),
                      ),
                    ),
                  ],
                ),
                if (units != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: units >= 0 ? const Color(0xFFEEF2FF) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Units Used: ${units >= 0 ? _fmtNum(units) : 'Invalid'}',
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.w800,
                            color: units >= 0 ? const Color(0xFF4338CA) : const Color(0xFFDC2626),
                          ),
                        ),
                        Text(
                          totalAmt != null ? 'Total Bill: ₹${totalAmt.toStringAsFixed(2)}' : 'Set rate > 0',
                          style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15, color: const Color(0xFF0F172A)),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 3. Room Selection Card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select Rooms to Share Bill',
                        style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: _isSavingConfig ? null : _saveSelectedRooms,
                      child: const Text('Save Selection'),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Select Occupied'),
                      onPressed: () {
                        setState(() {
                          _selectedRoomIds = _rooms
                              .where((r) => ((r['activeTenantCount'] as num?)?.toInt() ?? 0) > 0)
                              .map((r) => r['id'].toString())
                              .toSet();
                          _preview = null;
                        });
                      },
                    ),
                    ActionChip(
                      label: const Text('Clear All'),
                      onPressed: () => setState(() { _selectedRoomIds.clear(); _preview = null; }),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (_rooms.isEmpty)
                  Text('No rooms found in this PG.', style: GoogleFonts.lato(color: const Color(0xFF64748B)))
                else
                  ..._rooms.map((room) {
                    final id = room['id'].toString();
                    final roomNum = room['roomNumber']?.toString() ?? '';
                    final floor = room['floorNumber']?.toString() ?? '';
                    final count = (room['activeTenantCount'] as num?)?.toInt() ?? 0;
                    final checked = _selectedRoomIds.contains(id);

                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: checked,
                      activeColor: AppTheme.primaryColor,
                      title: Text(
                        'Room $roomNum (Floor $floor)',
                        style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        count > 0 ? '$count active tenant(s)' : 'Vacant (no active tenants)',
                        style: GoogleFonts.lato(
                          fontSize: 12,
                          color: count > 0 ? const Color(0xFF059669) : const Color(0xFF94A3B8),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedRoomIds.add(id);
                          } else {
                            _selectedRoomIds.remove(id);
                          }
                          _preview = null;
                        });
                      },
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isPreviewing ? null : _previewSplit,
              icon: _isPreviewing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.calculate_outlined),
              label: Text('Calculate Split', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),

          if (_preview != null) ...[
            const SizedBox(height: 18),
            _buildPreviewCard(_preview!),
          ],
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(Map<String, dynamic> preview) {
    final shares = ((preview['shares'] as List<dynamic>?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_rounded, color: Color(0xFF059669), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bill Breakdown (${_formatMonth(preview['billingMonth']?.toString() ?? '')})',
                  style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12)),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text('${preview['eligibleTenantCount']} Tenant(s)', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                Text('${preview['unitsConsumed']} units', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                Text(
                  '₹${(preview['totalAmount'] as num).toStringAsFixed(2)}',
                  style: GoogleFonts.lato(fontWeight: FontWeight.w900, fontSize: 16, color: const Color(0xFF059669)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...shares.map((s) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(s['tenantName']?.toString() ?? '', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 13.5)),
                subtitle: Text('Room ${s['roomNumber']} • Bed ${s['bedLabel'] ?? '-'}', style: GoogleFonts.lato(fontSize: 12)),
                trailing: Text(
                  '₹${(s['shareAmount'] as num).toStringAsFixed(2)}',
                  style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 14, color: const Color(0xFF0F172A)),
                ),
              )),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isGenerating ? null : _confirmAndGenerate,
              icon: _isGenerating
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text('Generate Bills & Notify Tenants', style: GoogleFonts.lato(fontSize: 14.5, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_cycles.isEmpty) {
      return Center(
        child: Text('No electricity bills generated yet.', style: GoogleFonts.lato(color: const Color(0xFF64748B))),
      );
    }

    String? latestGeneratedId;
    for (final c in _cycles) {
      if (c['status'] == 'GENERATED') {
        latestGeneratedId = c['id'].toString();
        break;
      }
    }

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _cycles.length,
        itemBuilder: (context, idx) {
          final cycle = _cycles[idx];
          final id = cycle['id'].toString();
          final month = cycle['billingMonth']?.toString() ?? '';
          final monthLabel = _formatMonth(month);
          final status = cycle['status']?.toString() ?? 'GENERATED';
          final isCancelled = status == 'VOIDED';
          final shares = ((cycle['shares'] as List<dynamic>?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final hasPaidShare = shares.any((s) => s['billStatus'] == 'PAID');
          final canCancel = id == latestGeneratedId && !hasPaidShare;

          final prevVal = (cycle['previousReading'] as num?)?.toDouble() ?? 0;
          final currVal = (cycle['currentReading'] as num?)?.toDouble() ?? 0;
          final unitsVal = (cycle['unitsConsumed'] as num?)?.toDouble() ?? 0;
          final rateVal = (cycle['costPerUnit'] as num?)?.toDouble() ?? 0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(monthLabel, style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCancelled ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isCancelled ? 'Cancelled' : 'Billed',
                              style: GoogleFonts.lato(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: isCancelled ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '₹${(cycle['totalAmount'] as num).toStringAsFixed(2)}',
                      style: GoogleFonts.lato(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Meter Reading: ${_fmtNum(prevVal)} → ${_fmtNum(currVal)} (${_fmtNum(unitsVal)} units used)',
                        style: GoogleFonts.lato(fontSize: 12.5, color: const Color(0xFF475569), fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rate: ₹${_fmtNum(rateVal)} / unit • Split among ${shares.length} tenant(s)',
                        style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                children: [
                  const Divider(),
                  ...shares.map((s) {
                    final rawStatus = s['billStatus']?.toString() ?? 'PENDING';
                    final statusLabel = rawStatus == 'PAID'
                        ? 'Paid'
                        : rawStatus == 'VOIDED'
                            ? 'Cancelled'
                            : 'Pending';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(s['tenantName']?.toString() ?? '', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 13)),
                      subtitle: Text('Room ${s['roomNumber']} • Bed ${s['bedLabel'] ?? '-'}', style: GoogleFonts.lato(fontSize: 11.5)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('₹${(s['shareAmount'] as num).toStringAsFixed(2)}', style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
                          Text(
                            statusLabel,
                            style: GoogleFonts.lato(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: rawStatus == 'PAID'
                                  ? const Color(0xFF15803D)
                                  : rawStatus == 'VOIDED'
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (canCancel) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _voidCycle(id, month),
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text('Cancel & Remove Unpaid Bills'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  InputDecoration _inputDeco(String label, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      prefixText: prefixText,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
    );
  }
}
