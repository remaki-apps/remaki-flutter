import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';

class ConfigurationScreen extends StatefulWidget {
  const ConfigurationScreen({super.key});

  @override
  State<ConfigurationScreen> createState() => _ConfigurationScreenState();
}

class _ConfigurationScreenState extends State<ConfigurationScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  String? _selectedPropertyId; // null = Global Admin Default
  int _adminDefaultDays = 5;
  int? _propertyOverrideDays;
  int _currentSliderDays = 5;
  bool _isPropertyOverrideActive = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiService.fetchReminderSettings(propertyId: _selectedPropertyId);
      if (res != null) {
        setState(() {
          _adminDefaultDays = (res['adminDefault'] as num?)?.toInt() ?? 5;
          _propertyOverrideDays = (res['propertyOverride'] as num?)?.toInt();
          _isPropertyOverrideActive = _selectedPropertyId != null && _propertyOverrideDays != null;
          _currentSliderDays = _isPropertyOverrideActive ? (_propertyOverrideDays ?? 5) : _adminDefaultDays;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final int daysToSave = _currentSliderDays;
      final String? propIdToSave = (_isPropertyOverrideActive && _selectedPropertyId != null) ? _selectedPropertyId : null;

      final res = await ApiService.updateReminderSettings(
        propertyId: propIdToSave,
        reminderDaysBeforeDue: daysToSave,
      );

      if (res != null && mounted) {
        FancyToast.showSuccess(context, 'Configuration updated successfully!');
        await _loadSettings();
      } else if (mounted) {
        FancyToast.showError(context, 'Save Failed', message: 'Could not update reminder settings.');
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Save Error', message: ApiService.cleanErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();
    final properties = appProvider.properties;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0F172A), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Configuration',
          style: GoogleFonts.lato(
            fontWeight: FontWeight.w700,
            fontSize: 19,
            color: const Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF1F5F9), height: 1),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF4F46E5), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rent Due Date Reminders',
                                style: GoogleFonts.lato(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'Configure automated 08:30 AM IST countdown alerts',
                                style: GoogleFonts.lato(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Scope / Property Selector
                      if (properties.isNotEmpty) ...[
                        Text(
                          'CONFIGURATION SCOPE',
                          style: GoogleFonts.lato(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _selectedPropertyId,
                              icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  child: Row(
                                    children: [
                                      const Icon(Icons.public_rounded, size: 18, color: Color(0xFF4F46E5)),
                                      const SizedBox(width: 10),
                                      Text(
                                        'All Properties (Global Default)',
                                        style: GoogleFonts.lato(fontSize: 13.5, fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ),
                                ),
                                ...properties.map((p) => DropdownMenuItem<String?>(
                                      value: p.id,
                                      child: Row(
                                        children: [
                                          const Icon(Icons.apartment_rounded, size: 18, color: Color(0xFF64748B)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              p.name,
                                              style: GoogleFonts.lato(fontSize: 13.5, fontWeight: FontWeight.w600),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                              ],
                              onChanged: (val) {
                                setState(() => _selectedPropertyId = val);
                                _loadSettings();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Main Reminder Window Card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Property override toggle if a specific property is chosen
                            if (_selectedPropertyId != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Custom Override for this Property',
                                        style: GoogleFonts.lato(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0F172A),
                                        ),
                                      ),
                                      Text(
                                        _isPropertyOverrideActive
                                            ? 'Overriding global default of $_adminDefaultDays days'
                                            : 'Currently using global default of $_adminDefaultDays days',
                                        style: GoogleFonts.lato(fontSize: 12, color: const Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                  Switch(
                                    value: _isPropertyOverrideActive,
                                    activeThumbColor: const Color(0xFF4F46E5),
                                    onChanged: (val) {
                                      setState(() {
                                        _isPropertyOverrideActive = val;
                                        _currentSliderDays = val ? (_propertyOverrideDays ?? 5) : _adminDefaultDays;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const Divider(height: 28, color: Color(0xFFF1F5F9)),
                            ],

                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Reminder Window',
                                  style: GoogleFonts.lato(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$_currentSliderDays Days Before',
                                    style: GoogleFonts.lato(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Daily countdown notifications will trigger starting $_currentSliderDays days prior to rent due date.',
                              style: GoogleFonts.lato(fontSize: 12.5, color: const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 16),

                            // Slider (3 to 7 days)
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: const Color(0xFF4F46E5),
                                inactiveTrackColor: const Color(0xFFE2E8F0),
                                thumbColor: const Color(0xFF4F46E5),
                                overlayColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                trackHeight: 6,
                              ),
                              child: Slider(
                                value: _currentSliderDays.toDouble(),
                                min: 3,
                                max: 7,
                                divisions: 4,
                                label: '$_currentSliderDays Days',
                                onChanged: (_selectedPropertyId != null && !_isPropertyOverrideActive)
                                    ? null
                                    : (val) {
                                        setState(() => _currentSliderDays = val.round());
                                      },
                              ),
                            ),

                            // Segmented Days Chips
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [3, 4, 5, 6, 7].map((days) {
                                final isSelected = _currentSliderDays == days;
                                return InkWell(
                                  onTap: (_selectedPropertyId != null && !_isPropertyOverrideActive)
                                      ? null
                                      : () => setState(() => _currentSliderDays = days),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
                                      ),
                                    ),
                                    child: Text(
                                      '$days D',
                                      style: GoogleFonts.lato(
                                        fontSize: 12,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Live Notification Preview Card
                      Text(
                        'LIVE TENANT PREVIEW',
                        style: GoogleFonts.lato(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1B4B),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1E1B4B).withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Remaki • 08:30 AM',
                                        style: GoogleFonts.lato(fontSize: 10.5, color: const Color(0xFFC7D2FE), fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        'IST',
                                        style: GoogleFonts.lato(fontSize: 10, color: const Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Rent Due in $_currentSliderDays Days',
                                    style: GoogleFonts.lato(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Your monthly rent of ₹8,500 is due in $_currentSliderDays days. Tap to record payment.',
                                    style: GoogleFonts.lato(
                                      fontSize: 12,
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4F46E5),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _isSaving ? null : _saveSettings,
                          child: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Save Configuration',
                                  style: GoogleFonts.lato(fontSize: 14.5, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Informational Rules Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 8),
                                Text(
                                  'Automated Notification Policies',
                                  style: GoogleFonts.lato(fontSize: 12.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _buildBullet('⏰ 08:30 AM Daily Run', 'Evaluates dues daily in Indian Standard Time (IST).'),
                            _buildBullet('🛡️ Paid Suppression', 'Automatically suppressed once tenant rent is marked PAID.'),
                            _buildBullet('📋 Pending Payment Notice', 'If proof is uploaded, reminder informs tenant review is pending.'),
                            _buildBullet('📊 Single Admin Rollup', 'Admins receive 1 consolidated summary of all unpaid tenants daily.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBullet(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.lato(fontSize: 11.5, fontWeight: FontWeight.w700, color: const Color(0xFF334155))),
          const SizedBox(width: 6),
          Expanded(
            child: Text(desc, style: GoogleFonts.lato(fontSize: 11.5, color: const Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }
}
