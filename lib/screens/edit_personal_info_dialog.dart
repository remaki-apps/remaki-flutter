import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../widgets/fancy_toast.dart';
import '../widgets/tenant_avatar.dart';
import '../utils/image_compress_util.dart';
import '../widgets/image_adjust_dialog.dart';

class EditPersonalInfoDialog extends StatefulWidget {
  final dynamic tenant;
  final bool isAdmin; // if true, use AppProvider, else use ApiService directly for self

  const EditPersonalInfoDialog({
    super.key,
    required this.tenant,
    this.isAdmin = true,
  });

  @override
  State<EditPersonalInfoDialog> createState() => _EditPersonalInfoDialogState();
}

class _EditPersonalInfoDialogState extends State<EditPersonalInfoDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _emergencyContactController;
  bool _isLoading = false;
  Uint8List? _selectedImageBytes;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    String initialPhone = widget.tenant.phone?.toString() ?? '';
    initialPhone = initialPhone.replaceAll(RegExp(r'\D'), '');
    if (initialPhone.startsWith('91') && initialPhone.length == 12) {
      initialPhone = initialPhone.substring(2);
    } else if (initialPhone.startsWith('0') && initialPhone.length == 11) {
      initialPhone = initialPhone.substring(1);
    }
    if (initialPhone.length > 10) {
      initialPhone = initialPhone.substring(initialPhone.length - 10);
    }

    String initialEmergency = widget.tenant.emergencyContact?.toString() ?? '';
    initialEmergency = initialEmergency.replaceAll(RegExp(r'\D'), '');
    if (initialEmergency.startsWith('91') && initialEmergency.length == 12) {
      initialEmergency = initialEmergency.substring(2);
    } else if (initialEmergency.startsWith('0') && initialEmergency.length == 11) {
      initialEmergency = initialEmergency.substring(1);
    }
    if (initialEmergency.length > 10) {
      initialEmergency = initialEmergency.substring(initialEmergency.length - 10);
    }

    _nameController = TextEditingController(text: widget.tenant.name);
    _phoneController = TextEditingController(text: initialPhone);
    _emailController = TextEditingController(text: widget.tenant.email ?? '');
    _emergencyContactController = TextEditingController(text: initialEmergency);
    _existingImageUrl = widget.tenant.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 92,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (!mounted) return;

      final adjusted = await ImageAdjustDialog.show(
        context,
        imageBytes: bytes,
        title: 'Adjust Profile Picture',
        isCircle: true,
        aspectRatio: 1.0,
      );
      if (adjusted == null) return;

      final compressed = await ImageCompressUtil.compressProfileImage(adjusted);
      setState(() {
        _selectedImageBytes = compressed;
      });
    } catch (e) {
      debugPrint('[EditPersonalInfoDialog] Pick image error: $e');
      if (mounted) {
        FancyToast.showError(context, 'Image Error', message: 'Could not process selected image.');
      }
    }
  }

  Future<void> _saveChanges() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final emergency = _emergencyContactController.text.trim();

    if (name.isEmpty || phone.isEmpty) {
      FancyToast.showError(context, 'Missing Fields', message: 'Name and Phone are required.');
      return;
    }

    if (phone.length != 10) {
      FancyToast.showError(context, 'Invalid Phone Number', message: 'Phone number must be exactly 10 digits.');
      return;
    }

    if (emergency.isNotEmpty && emergency.length != 10) {
      FancyToast.showError(context, 'Invalid Emergency Contact', message: 'Emergency contact must be exactly 10 digits.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? base64Image;
      if (_selectedImageBytes != null) {
        base64Image = 'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
      }

      final input = <String, dynamic>{
        'name': name,
        'phone': phone,
        'email': _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
        'emergencyContact': emergency.isNotEmpty ? emergency : null,
      };
      
      if (base64Image != null) {
        input['photoUrl'] = base64Image;
      }

      if (widget.isAdmin) {
        // Admin editing a tenant profile — pass the tenant ID
        await ApiService.performQuery('''
          mutation UpdateTenant(\$id: ID!, \$input: UpdateTenantInput!) {
            updateTenant(id: \$id, input: \$input) {
              id
            }
          }
        ''', variables: {
          'id': widget.tenant.id,
          'input': input,
        });
      } else {
        // Tenant editing their own profile — uses auth token identity
        await ApiService.updateMyProfile(input);
      }

      if (mounted) {
        context.pop(true); // Return true to indicate success
        FancyToast.showSuccess(context, 'Personal information updated successfully!');
      }
    } catch (e) {
      if (mounted) {
        FancyToast.showError(context, 'Update Failed', message: ApiService.cleanErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final availableHeight = mediaQuery.size.height;
    final keyboardPadding = mediaQuery.viewInsets.bottom;
    final isKeyboardOpen = keyboardPadding > 0;

    // Calculate maximum dialog height strictly fitting inside the visible space above keyboard
    final maxDialogHeight = isKeyboardOpen
        ? (availableHeight - keyboardPadding - 32.0).clamp(240.0, 560.0)
        : (availableHeight * 0.85).clamp(300.0, 720.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isKeyboardOpen ? 12 : 24,
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        constraints: BoxConstraints(
          maxWidth: 450,
          maxHeight: maxDialogHeight,
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit Personal Info',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => context.pop(false),
                      child: const Icon(Icons.close, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Profile Picture
                Center(
                  child: Stack(
                    children: [
                      if (_selectedImageBytes != null)
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: MemoryImage(_selectedImageBytes!),
                        )
                      else
                        TenantAvatar(
                          name: widget.tenant.name,
                          imageUrl: _existingImageUrl,
                          radius: 40,
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primaryColor,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                const Text('Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: _inputDecoration(hintText: 'Enter full name'),
                ),
                const SizedBox(height: 16),

                const Text('Phone Number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: _inputDecoration(hintText: 'Enter 10-digit phone number'),
                ),
                const SizedBox(height: 16),

                const Text('Email (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: _inputDecoration(hintText: 'Enter email address'),
                ),
                const SizedBox(height: 16),

                const Text('Emergency Contact (Optional)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                const SizedBox(height: 6),
                TextField(
                  controller: _emergencyContactController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: _inputDecoration(hintText: 'Enter 10-digit emergency contact'),
                ),

                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isLoading ? null : _saveChanges,
                    child: _isLoading
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('Save Changes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}
