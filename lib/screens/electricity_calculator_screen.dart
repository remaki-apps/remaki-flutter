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
  bool _isPreviewing = false;
  bool _isGenerating = false;
  String? _errorMessage;

  bool _enabled = false;
  String _propertyId = '';
  String _propertyName = '';
  double? _latestReading;
  String? _latestBillingMonth;

  final _costPerUnitCtrl = TextEditingController();
  final _prevReadingCtrl = TextEditingController();
  final _currReadingCtrl = TextEditingController();

  late String _billingMonth;
  DateTime? _dueDate;

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

  Future<void> _saveConfig() async {
    final rate = double.tryParse(_costPerUnitCtrl.text.trim());
    if (rate == null || rate < 0) {
      FancyToast.showError(context, 'Invalid Rate', message: 'Enter a valid cost per unit (>= 0).');
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
      FancyToast.showSuccess(
        context,
        'Configuration Saved',
        message: 'Default unit rate and shared rooms updated.',
      );
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Save Failed', message: e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  Future<void> _previewSplit() async {
    final curr = _liveCurrReading;
    final prev = _livePrevReading;
    final rate = _liveRate;

    if (rate <= 0) {
      FancyToast.showError(context, 'Rate Required', message: 'Enter cost per unit (> 0).');
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
      FancyToast.showError(context, 'Preview Failed', message: e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _confirmAndGenerate() async {
    if (_preview == null) return;
    final sharesCount = _preview!['eligibleTenantCount'] ?? 0;
    final total = _preview!['totalAmount'] ?? 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Generate Electricity Bills?', style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
        content: Text(
          'This will generate ₹$total across $sharesCount tenant(s) for $_billingMonth and send push notifications. Continue?',
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
        dueDate: _dueDate?.toIso8601String(),
      );

      // Persist selected rooms & unit rate as convenience defaults
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
        message: 'Electricity bills created and tenants notified.',
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Void $month Cycle?', style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
        content: Text(
          'This will void the $month electricity cycle and remove its unpaid tenant bills. You can only void if no tenant has paid yet.',
          style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF475569)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Void Cycle'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiService.voidLatestElectricityCycle(cycleId);
      if (!mounted) return;
      FancyToast.showSuccess(context, 'Cycle Voided', message: '$month electricity cycle has been voided.');
      await _loadAll();
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Cannot Void', message: e.toString().replaceFirst('Exception: ', ''));
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
              style: GoogleFonts.lato(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
            ),
            if (_propertyName.isNotEmpty)
              Text(
                _propertyName,
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
                  Tab(text: 'Calculator & Split'),
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
          // 1. Unit Rate Configuration Card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.bolt_rounded, color: Color(0xFFD97706), size: 20),
                    const SizedBox(width: 8),
                    Text('Tariff & Default Rooms', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _isSavingConfig ? null : _saveConfig,
                      icon: _isSavingConfig
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined, size: 16),
                      label: const Text('Save Defaults'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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

          // 2. Meter Reading Card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Meter Reading & Cycle', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: months.contains(_billingMonth) ? _billingMonth : months.first,
                  decoration: _inputDeco('Billing Month'),
                  items: months.map((m) {
                    final dt = DateTime.parse('$m-01');
                    return DropdownMenuItem(value: m, child: Text('${DateFormat('MMMM yyyy').format(dt)} ($m)'));
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
                          _latestReading != null ? 'Previous ($_latestBillingMonth)' : 'Initial Reading',
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
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate ?? DateTime.now().add(const Duration(days: 5)),
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 90)),
                    );
                    if (picked != null) setState(() => _dueDate = picked);
                  },
                  child: InputDecorator(
                    decoration: _inputDeco('Due Date (Optional)'),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _dueDate != null ? DateFormat('dd MMM yyyy').format(_dueDate!) : 'No due date set',
                          style: GoogleFonts.lato(
                            fontSize: 13.5,
                            color: _dueDate != null ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (_dueDate != null)
                          GestureDetector(
                            onTap: () => setState(() => _dueDate = null),
                            child: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                          )
                        else
                          const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF64748B)),
                      ],
                    ),
                  ),
                ),
                if (units != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: units >= 0 ? const Color(0xFFEEF2FF) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Units: ${units >= 0 ? _fmtNum(units) : 'Invalid'}',
                          style: GoogleFonts.lato(
                            fontWeight: FontWeight.w800,
                            color: units >= 0 ? const Color(0xFF4338CA) : const Color(0xFFDC2626),
                          ),
                        ),
                        Text(
                          totalAmt != null ? 'Total: ₹${totalAmt.toStringAsFixed(2)}' : 'Enter rate > 0',
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
                    Text('Rooms Sharing This Bill', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedRoomIds = _rooms
                              .where((r) => ((r['activeTenantCount'] as num?)?.toInt() ?? 0) > 0)
                              .map((r) => r['id'].toString())
                              .toSet();
                          _preview = null;
                        });
                      },
                      child: const Text('Select Occupied'),
                    ),
                    TextButton(
                      onPressed: () => setState(() { _selectedRoomIds.clear(); _preview = null; }),
                      child: const Text('Clear'),
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
                      title: Text('Room $roomNum (Floor $floor)', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 13.5)),
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
              label: Text('Preview Tenant Split', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
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
              Text('Split Preview (${preview['billingMonth']})', style: GoogleFonts.lato(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF0FDF4), borderRadius: BorderRadius.circular(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        child: Text('No electricity billing cycles generated yet.', style: GoogleFonts.lato(color: const Color(0xFF64748B))),
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
          final status = cycle['status']?.toString() ?? 'GENERATED';
          final isVoided = status == 'VOIDED';
          final shares = ((cycle['shares'] as List<dynamic>?) ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final hasPaidShare = shares.any((s) => s['billStatus'] == 'PAID');
          final canVoid = id == latestGeneratedId && !hasPaidShare;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _card(
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Text(month, style: GoogleFonts.lato(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isVoided ? const Color(0xFFFEE2E2) : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.lato(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: isVoided ? const Color(0xFFDC2626) : const Color(0xFF15803D),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '₹${(cycle['totalAmount'] as num).toStringAsFixed(2)}',
                      style: GoogleFonts.lato(fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ],
                ),
                subtitle: Text(
                  'Prev ${cycle['previousReading']} → Curr ${cycle['currentReading']} (${cycle['unitsConsumed']} units @ ₹${cycle['costPerUnit']}/unit)',
                  style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF64748B)),
                ),
                children: [
                  const Divider(),
                  ...shares.map((s) {
                    final billStatus = s['billStatus']?.toString() ?? 'PENDING';
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
                            billStatus,
                            style: GoogleFonts.lato(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: billStatus == 'PAID'
                                  ? const Color(0xFF15803D)
                                  : billStatus == 'VOIDED'
                                      ? const Color(0xFF94A3B8)
                                      : const Color(0xFFD97706),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  if (canVoid) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _voidCycle(id, month),
                        icon: const Icon(Icons.undo_rounded, size: 16),
                        label: const Text('Void Latest Cycle'),
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
