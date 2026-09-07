import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/models.dart';
import '../widgets/fancy_toast.dart';
import 'edit_personal_info_dialog.dart';
import 'complete_profile_dialog.dart';

class TenantHomeScreen extends StatefulWidget {
  const TenantHomeScreen({super.key});

  @override
  State<TenantHomeScreen> createState() => _TenantHomeScreenState();
}

class _TenantHomeScreenState extends State<TenantHomeScreen> {
  static const double _convenienceFee = 9.0; // ₹9 platform fee per payment
  final String _paymentType = 'BOTH';
  bool _isLoading = false;
  bool _isFetchingProfile = true;
  double _totalDue = 0;
  Map<String, dynamic>? _profileData;
  String? _rejectionReason;
  Uint8List? _selectedImageBytes;
  final TextEditingController _descriptionController = TextEditingController();
  List<dynamic> _announcements = [];

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    final announcements = await ApiService.fetchAnnouncements(false);
    if (mounted) {
      setState(() {
        _announcements = announcements;
      });
    }
  }

  Future<void> _fetchProfile() async {
    setState(() => _isFetchingProfile = true);
    final profile = await ApiService.fetchCurrentTenantProfile();
    if (profile != null) {
      double pendingRent = (profile['pendingRentAmount'] as num?)?.toDouble() ?? 0;
      double pendingBills = 0;
      final bills = profile['bills'] as List<dynamic>? ?? [];
      for (var b in bills) {
        if (b['status'] == 'PENDING') {
          pendingBills += (b['amount'] as num).toDouble();
        }
      }
      // Check for rejected payment request
      final rejectionReason = profile['latestRejectionReason'] as String?;
      if (mounted) {
        setState(() {
      // _totalDue = rent + bills + ₹9 convenience fee (charged on every payment submission)
          _totalDue = pendingRent + pendingBills + _convenienceFee;
          _profileData = profile;
          _rejectionReason = (rejectionReason != null && rejectionReason.isNotEmpty) ? rejectionReason : null;
          _isFetchingProfile = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isFetchingProfile = false);
        FancyToast.showError(context, 'Failed to Load', message: 'Failed to load profile details.');
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 10);
    
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _selectedImageBytes = bytes;
    });
  }

  Future<void> _submitRequest() async {
    if (_totalDue <= 0) {
      FancyToast.showError(context, 'No Dues', message: 'No due amount to pay.');
      return;
    }
    if (_selectedImageBytes == null) {
      FancyToast.showError(context, 'Screenshot Required', message: 'Please upload a screenshot first.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final base64Image = base64Encode(_selectedImageBytes!);

      await ApiService.performQuery('''
        mutation SubmitPaymentRequest(\$input: SubmitPaymentRequestInput!) {
          submitPaymentRequest(input: \$input) {
            id
          }
        }
      ''', variables: {
        'input': {
          'tenantId': "WILL_BE_FILLED_BY_BACKEND_USING_AUTH_TOKEN_BUT_SCHEMA_NEEDS_IT",
          'amount': _totalDue,
          'paymentType': _paymentType,
          'proofImageBase64': 'data:image/jpeg;base64,$base64Image',
          'description': _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
        }
      }); 

      if (mounted) {
        FancyToast.showSuccess(context, 'Payment Request Submitted Successfully!');
        setState(() {
          _selectedImageBytes = null;
          _descriptionController.clear();
          _totalDue = 0; // Optimistically clear amount, though real sync needs refresh
        });
        _fetchProfile();
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Payment Failed', message: e.toString());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearAuthToken();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _isFetchingProfile 
      ? const Center(child: CircularProgressIndicator()) 
      : Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_profileData != null) ...[
                _buildProfileSection(_profileData!),
                const SizedBox(height: 16),
                _buildCompleteProfileBanner(),
                const SizedBox(height: 24),
              ],
              
              if (_announcements.isNotEmpty) ...[
                _buildAnnouncementsSection(),
                const SizedBox(height: 24),
              ],
              
              // Rejection reason banner
              if (_rejectionReason != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.cancel_rounded, color: Color(0xFFEF4444), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Payment Rejected',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626), fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Reason: $_rejectionReason\n\nPlease re-upload a valid UPI screenshot.',
                              style: const TextStyle(color: Color(0xFF7F1D1D), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const Text('Submit Payment', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              const SizedBox(height: 24),
              
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: Text('Total Amount Due', style: TextStyle(fontSize: 16, color: Colors.blueGrey, fontWeight: FontWeight.w500))),
                      const SizedBox(height: 8),
                      Center(
                        child: Text(
                          '₹${_totalDue.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: _totalDue > 0 ? AppTheme.danger : AppTheme.success),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Convenience fee breakdown
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Rent + Bills', style: TextStyle(fontSize: 13, color: Colors.blueGrey)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFF59E0B)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.info_outline, size: 12, color: Color(0xFFB45309)),
                                          SizedBox(width: 4),
                                          Text('+ ₹9 Platform Fee', style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w600)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text('A ₹9 convenience fee is added per payment to maintain the platform.', style: TextStyle(fontSize: 11, color: Color(0xFF78716C))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              if (_selectedImageBytes != null) ...[
                const Text('Screenshot Preview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_selectedImageBytes!, fit: BoxFit.contain),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: _isLoading ? null : _pickImage,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Change Screenshot'),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitRequest,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: _isLoading 
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('Submit Payment Request', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: _totalDue > 0 ? _pickImage : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Upload UPI Screenshot', style: TextStyle(fontSize: 16)),
                ),
                if (_totalDue == 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text('You have no pending dues to pay.', textAlign: TextAlign.center, style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(Map<String, dynamic> profile, double radius) {
    final imageUrl = profile['imageUrl'] as String?;
    final name = profile['name'] as String? ?? 'T';
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'T';
    final bg = AppTheme.primaryColor.withValues(alpha: 0.1);

    if (imageUrl == null || imageUrl.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: bg,
        child: Text(initial, style: TextStyle(fontSize: radius * 0.68, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
      );
    }

    if (imageUrl.startsWith('data:')) {
      try {
        final commaIdx = imageUrl.indexOf(',');
        if (commaIdx != -1) {
          final bytes = base64Decode(imageUrl.substring(commaIdx + 1));
          return CircleAvatar(
            radius: radius,
            backgroundColor: bg,
            child: ClipOval(
              child: Image.memory(bytes, width: radius * 2, height: radius * 2, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Text(initial, style: TextStyle(fontSize: radius * 0.68, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
            ),
          );
        }
      } catch (_) {}
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bg,
      child: ClipOval(
        child: Image.network(imageUrl, width: radius * 2, height: radius * 2, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Text(initial, style: TextStyle(fontSize: radius * 0.68, fontWeight: FontWeight.bold, color: AppTheme.primaryColor))),
      ),
    );
  }

  Widget _buildProfileSection(Map<String, dynamic> profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileAvatar(profile, 35),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile['name'] ?? 'Tenant',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Room ${profile['room']?['roomNumber'] ?? '-'} • Bed ${profile['bed']?['bedLabel'] ?? '-'}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
                onPressed: () => _openEditDialog(profile),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.phone_outlined, 'Phone', profile['phone'] ?? '-')),
              Expanded(child: _buildInfoItem(Icons.email_outlined, 'Email', (profile['email'] != null && profile['email'].toString().isNotEmpty) ? profile['email'] : '-')),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildInfoItem(Icons.contact_phone_outlined, 'Emergency', (profile['emergencyContact'] != null && profile['emergencyContact'].toString().isNotEmpty) ? profile['emergencyContact'] : '-')),
              Expanded(child: _buildInfoItem(Icons.payments_outlined, 'Rent', '₹${profile['monthlyRent']?.toString() ?? '-'}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openEditDialog(Map<String, dynamic> profileData) async {
    // Create a dummy Tenant object since EditPersonalInfoDialog expects it
    // Or we just adapt it
    final dummyTenant = Tenant(
      id: profileData['id'],
      name: profileData['name'],
      phone: profileData['phone'],
      email: profileData['email'] ?? '',
      emergencyContact: profileData['emergencyContact'],
      imageUrl: profileData['imageUrl'],
      roomId: '',
      bedId: '',
      moveInDate: DateTime.now(),
      rentAmount: 0,
      securityDeposit: 0,
      rentDueDate: DateTime.now(),
    );

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => EditPersonalInfoDialog(
        tenant: dummyTenant,
        isAdmin: false,
      ),
    );

    if (result == true) {
      _fetchProfile(); // refresh
    }
  }

  Widget _buildCompleteProfileBanner() {
    if (_profileData == null) return const SizedBox.shrink();
    
    // Check if key fields are missing to consider it incomplete
    final isComplete = _profileData!['permanentAddress'] != null && 
                       _profileData!['district'] != null &&
                       _profileData!['nationality'] != null;
                       
    if (isComplete) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF166534), size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Complete Your Profile', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF166534), fontSize: 14)),
                SizedBox(height: 2),
                Text('Add more details to complete your tenant profile.', style: TextStyle(color: Color(0xFF14532D), fontSize: 12)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _openCompleteProfileDialog(_profileData!),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF166534),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              minimumSize: const Size(0, 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Complete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Announcements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
        const SizedBox(height: 16),
        ..._announcements.map((a) {
          return Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a['heading'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                  const SizedBox(height: 8),
                  Text(a['description'] ?? '', style: const TextStyle(fontSize: 14, color: Color(0xFF475569))),
                  if (a['imageUrl'] != null) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(a['imageUrl'], height: 150, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _openCompleteProfileDialog(Map<String, dynamic> profileData) async {
    final dummyTenant = Tenant(
      id: profileData['id'],
      name: profileData['name'],
      phone: profileData['phone'],
      email: profileData['email'] ?? '',
      emergencyContact: profileData['emergencyContact'],
      imageUrl: profileData['imageUrl'],
      roomId: '',
      bedId: '',
      moveInDate: DateTime.now(),
      rentAmount: 0,
      securityDeposit: 0,
      rentDueDate: DateTime.now(),
      dateOfBirth: profileData['dateOfBirth'],
      maritalStatus: profileData['maritalStatus'],
      fatherName: profileData['fatherName'],
      permanentAddress: profileData['permanentAddress'],
      villageOrTown: profileData['villageOrTown'],
      houseNo: profileData['houseNo'],
      wardNo: profileData['wardNo'],
      district: profileData['district'],
      state: profileData['state'],
      nationality: profileData['nationality'],
      pinCode: profileData['pinCode'],
      occupation: profileData['occupation'],
    );

    // This uses complete_profile_dialog.dart which we will import
    // Note: ensure we import it at the top
    await showDialog(
      context: context,
      builder: (ctx) => CompleteProfileDialog(
        tenant: dummyTenant,
        onProfileUpdated: () {
          _fetchProfile();
        },
      ),
    );
  }
}
