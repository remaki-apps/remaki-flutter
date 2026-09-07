import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/fancy_toast.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  bool _isLoading = true;
  List<dynamic> _announcements = [];
  final TextEditingController _headingCtrl = TextEditingController();
  final TextEditingController _descCtrl = TextEditingController();
  Uint8List? _selectedImageBytes;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  @override
  void dispose() {
    _headingCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchAnnouncements() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchAnnouncements(true);
    if (mounted) {
      setState(() {
        _announcements = data;
        _isLoading = false;
      });
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

  Future<void> _sendAnnouncement() async {
    if (_headingCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      FancyToast.showError(context, 'Missing Details', message: 'Please provide both heading and description.');
      return;
    }

    setState(() => _isSending = true);
    try {
      String? imageBase64;
      if (_selectedImageBytes != null) {
        imageBase64 = 'data:image/jpeg;base64,${base64Encode(_selectedImageBytes!)}';
      }

      await ApiService.createAnnouncement(
        heading: _headingCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imageBase64: imageBase64,
      );

      if (mounted) {
        FancyToast.showSuccess(context, 'Announcement Sent Successfully!');
        setState(() {
          _headingCtrl.clear();
          _descCtrl.clear();
          _selectedImageBytes = null;
        });
        _fetchAnnouncements();
      }
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Failed to send announcement', message: e.toString());
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text('Announcements', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Create Announcement Form
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('New Announcement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                TextField(
                  controller: _headingCtrl,
                  decoration: InputDecoration(
                    labelText: 'Heading',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (_selectedImageBytes != null)
                      Container(
                        height: 50,
                        width: 50,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(image: MemoryImage(_selectedImageBytes!), fit: BoxFit.cover),
                        ),
                      ),
                    OutlinedButton.icon(
                      onPressed: _isSending ? null : _pickImage,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(_selectedImageBytes != null ? 'Change Image' : 'Attach Image'),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _isSending ? null : _sendAnnouncement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Send to Tenants', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // List of Announcements
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _announcements.isEmpty
                    ? const Center(child: Text('No announcements sent yet.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _announcements.length,
                        itemBuilder: (context, index) {
                          final a = _announcements[index];
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
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
