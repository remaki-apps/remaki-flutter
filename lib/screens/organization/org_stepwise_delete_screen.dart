import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../models/organization_models.dart';
import '../../providers/organization_provider.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fancy_toast.dart';

class OrgStepwiseDeleteScreen extends StatefulWidget {
  final String targetId;
  final bool isAdmin; // true = Admin deletion flow, false = Property deletion flow
  final String targetName;

  const OrgStepwiseDeleteScreen({
    super.key,
    required this.targetId,
    required this.isAdmin,
    required this.targetName,
  });

  @override
  State<OrgStepwiseDeleteScreen> createState() => _OrgStepwiseDeleteScreenState();
}

class _OrgStepwiseDeleteScreenState extends State<OrgStepwiseDeleteScreen> {
  bool _isLoading = true;
  bool _isBusy = false;
  DeletionPreview? _preview;

  @override
  void initState() {
    super.initState();
    _loadPreview();
  }

  Future<void> _loadPreview() async {
    setState(() => _isLoading = true);
    try {
      final json = widget.isAdmin
          ? await ApiService.fetchAdminDeletionPreview(widget.targetId)
          : await ApiService.fetchPropertyDeletionPreview(widget.targetId);
      if (mounted) {
        setState(() {
          _preview = DeletionPreview.fromJson(json);
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

  Future<bool> _confirmYesNo(String title, String message) async {
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: GoogleFonts.lato(fontWeight: FontWeight.w800)),
        content: Text(message, style: GoogleFonts.lato(fontSize: 13.5, color: const Color(0xFF475569))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No', style: GoogleFonts.lato(fontWeight: FontWeight.w700, color: const Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Yes, Proceed', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _runStep(String step, String label, String warning) async {
    final confirmed = await _confirmYesNo(label, warning);
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final ok = widget.isAdmin
          ? await ApiService.deleteAdminStepwiseUnderOrg(widget.targetId, step)
          : await ApiService.deletePropertyStepwiseUnderOrg(widget.targetId, step);

      if (ok && mounted) {
        FancyToast.showSuccess(context, 'Completed', message: '$label completed.');
        final orgProvider = context.read<OrganizationProvider>();
        await orgProvider.loadFromAPI(showLoading: false);

        if ((widget.isAdmin && step == 'DELETE_ADMIN') || (!widget.isAdmin && step == 'DELETE_PROPERTY')) {
          if (mounted) {
            context.go(widget.isAdmin ? '/org_admins' : '/org_properties');
          }
          return;
        }
        await _loadPreview();
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Step Failed', message: ApiService.cleanErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _softDeactivate() async {
    final confirmed = await _confirmYesNo(
      'Soft Deactivate?',
      'This will deactivate "${widget.targetName}" (isActive = false) and preserve all tenants, rooms, and financial history.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isBusy = true);
    try {
      final orgProvider = context.read<OrganizationProvider>();
      if (widget.isAdmin) {
        await orgProvider.toggleAdminStatus(widget.targetId, false);
      } else {
        await orgProvider.updateProperty({'propertyId': widget.targetId, 'isActive': false});
      }
      if (mounted) {
        FancyToast.showSuccess(context, 'Deactivated', message: '${widget.targetName} has been soft-deactivated.');
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Failed', message: ApiService.cleanErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    final bool hasTenants = (p?.tenantsCount ?? 0) > 0;
    final bool hasRoomsOrBeds = (p?.roomsCount ?? 0) > 0 || (p?.bedsCount ?? 0) > 0 || (p?.coOwnersCount ?? 0) > 0;
    final bool hasProperties = (p?.propertiesCount ?? 0) > 0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.isAdmin ? 'Manage / Delete Admin' : 'Manage / Delete PG',
          style: GoogleFonts.lato(fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          widget.targetName,
                          style: GoogleFonts.lato(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.primaryDark),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Recommended: Soft-deactivate to keep audit & payment records intact, or follow the ordered steps below to permanently delete.',
                          style: GoogleFonts.lato(fontSize: 13, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _isBusy ? null : _softDeactivate,
                            icon: const Icon(Icons.pause_circle_outline_rounded),
                            label: Text('Soft Deactivate (${widget.isAdmin ? "Admin" : "PG"})', style: GoogleFonts.lato(fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFD97706),
                              side: const BorderSide(color: Color(0xFFD97706)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'STEPWISE HARD DELETION',
                    style: GoogleFonts.lato(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 10),
                  _buildStepCard(
                    stepNum: 1,
                    title: 'Delete Tenants & Payment History',
                    subtitle: '${p?.tenantsCount ?? 0} tenant(s), ${p?.paymentsCount ?? 0} payment record(s)',
                    isDone: !hasTenants,
                    isEnabled: !_isBusy && hasTenants,
                    onTap: () => _runStep(
                      'DELETE_TENANTS',
                      'Delete All Tenants?',
                      'This permanently deletes ${p?.tenantsCount ?? 0} tenant(s), their stays, bills, complaints, and ${p?.paymentsCount ?? 0} payment records.',
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildStepCard(
                    stepNum: 2,
                    title: 'Delete Beds, Rooms & Co-Owners',
                    subtitle: '${p?.roomsCount ?? 0} room(s), ${p?.bedsCount ?? 0} bed(s), ${p?.coOwnersCount ?? 0} co-owner(s)',
                    isDone: !hasRoomsOrBeds,
                    isEnabled: !_isBusy && !hasTenants && hasRoomsOrBeds,
                    onTap: () => _runStep(
                      'DELETE_ROOMS_BEDS',
                      'Delete All Rooms & Beds?',
                      'This permanently removes ${p?.roomsCount ?? 0} room(s), ${p?.bedsCount ?? 0} bed(s), and ${p?.coOwnersCount ?? 0} co-owner mapping(s).',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.isAdmin) ...[
                    _buildStepCard(
                      stepNum: 3,
                      title: 'Delete PG Properties',
                      subtitle: '${p?.propertiesCount ?? 0} PG property(ies)',
                      isDone: !hasProperties,
                      isEnabled: !_isBusy && !hasTenants && !hasRoomsOrBeds && hasProperties,
                      onTap: () => _runStep(
                        'DELETE_PROPERTIES',
                        'Delete All PG Properties?',
                        'This permanently deletes ${p?.propertiesCount ?? 0} PG property(ies) and their fee ledgers.',
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStepCard(
                      stepNum: 4,
                      title: 'Delete Admin Account',
                      subtitle: 'Final step: permanently remove admin login & profile',
                      isDone: false,
                      isEnabled: !_isBusy && !hasTenants && !hasRoomsOrBeds && !hasProperties,
                      onTap: () => _runStep(
                        'DELETE_ADMIN',
                        'Delete Admin Account?',
                        'This permanently removes "${widget.targetName}" from Remaki.',
                      ),
                    ),
                  ] else ...[
                    _buildStepCard(
                      stepNum: 3,
                      title: 'Delete PG Property',
                      subtitle: 'Final step: permanently remove this PG property',
                      isDone: false,
                      isEnabled: !_isBusy && !hasTenants && !hasRoomsOrBeds,
                      onTap: () => _runStep(
                        'DELETE_PROPERTY',
                        'Delete PG Property?',
                        'This permanently removes "${widget.targetName}" from Remaki.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildStepCard({
    required int stepNum,
    required String title,
    required String subtitle,
    required bool isDone,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDone ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: isDone
                ? const Color(0xFFDCFCE7)
                : isEnabled
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF1F5F9),
            child: isDone
                ? const Icon(Icons.check_rounded, size: 18, color: Color(0xFF16A34A))
                : Text(
                    '$stepNum',
                    style: GoogleFonts.lato(
                      fontWeight: FontWeight.w800,
                      color: isEnabled ? AppTheme.danger : const Color(0xFF94A3B8),
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.lato(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark)),
                const SizedBox(height: 2),
                Text(subtitle, style: GoogleFonts.lato(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!isDone)
            ElevatedButton(
              onPressed: isEnabled ? onTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.danger,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE2E8F0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text('Delete', style: GoogleFonts.lato(fontWeight: FontWeight.w700, fontSize: 12.5)),
            ),
        ],
      ),
    );
  }
}
