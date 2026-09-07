import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/app_provider.dart';
import '../widgets/fancy_toast.dart';

class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  List<dynamic> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final reqs = await ApiService.fetchPendingPaymentRequests();
      setState(() => _requests = reqs);
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Error', message: e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAccept(String requestId) async {
    try {
      await ApiService.resolvePaymentRequest(requestId, 'APPROVE');
      if (mounted) {
        // Refresh app provider to reflect paid rent
        await Provider.of<AppProvider>(context, listen: false).loadFromAPI();
        FancyToast.showSuccess(context, 'Payment Accepted');
        _loadRequests();
      }
    } catch (e) {
      if (mounted) FancyToast.showError(context, 'Error', message: e.toString());
    }
  }

  Future<void> _handleDecline(String requestId) async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Decline Payment'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Enter reason for rejection'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, reasonController.text), child: const Text('Decline')),
        ],
      ),
    );

    if (reason != null) {
      try {
        await ApiService.resolvePaymentRequest(requestId, 'REJECT', rejectionReason: reason);
        
        // Launch WhatsApp
        // Assuming we have tenant phone number or we just launch whatsapp generically.
        // We didn't fetch phone number in query, so we'll just open standard wa.me link.
        // In a real app we would fetch the phone number. Let's try to find it in AppProvider.
        final req = _requests.firstWhere((r) => r['id'] == requestId);
        final tenant = Provider.of<AppProvider>(context, listen: false).tenants.firstWhere((t) => t.id == req['tenantProfileId']);
        
        final msg = Uri.encodeComponent('Your request for marking rent payment as paid is rejected. \$reason. Kindly upload a proper and valid screenshot.');
        final url = Uri.parse('https://wa.me/\${tenant.phone}?text=\$msg');
        if (await canLaunchUrl(url)) {
          await launchUrl(url);
        }

        if (mounted) {
          FancyToast.showSuccess(context, 'Payment Declined');
          _loadRequests();
        }
      } catch (e) {
        if (mounted) FancyToast.showError(context, 'Error', message: e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pending Approvals')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _requests.isEmpty
          ? const Center(child: Text('No pending approvals'))
          : ListView.builder(
              itemCount: _requests.length,
              itemBuilder: (context, index) {
                final req = _requests[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Tenant: ${req['tenantName']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text("Amount: ₹${req['amount']}"),
                        Text("Type: ${req['paymentType']}"),
                        if (req['description'] != null && req['description'].toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text("Description: ${req['description']}", style: const TextStyle(fontStyle: FontStyle.italic)),
                          ),
                        const SizedBox(height: 8),
                        if (req['proofImageBase64'] != null && req['proofImageBase64'].isNotEmpty)
                          Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Image.memory(
                              base64Decode(req['proofImageBase64'].toString().split(',').last),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Center(child: Text('Invalid Image')),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => _handleDecline(req['id']),
                              child: const Text('Decline'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                              onPressed: () => _handleAccept(req['id']),
                              child: const Text('Accept'),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
