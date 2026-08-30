import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';

class AddRoomBillScreen extends StatefulWidget {
  final String roomId;
  const AddRoomBillScreen({super.key, required this.roomId});

  @override
  State<AddRoomBillScreen> createState() => _AddRoomBillScreenState();
}

class _AddRoomBillScreenState extends State<AddRoomBillScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  Set<String> _selectedTenantIds = {};
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    // Initialize selected tenants to all tenants in the room
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      final roomTenants = appProvider.tenants.where((t) => t.roomId == widget.roomId).toList();
      setState(() {
        _selectedTenantIds = roomTenants.map((t) => t.id).toSet();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final roomTenants = appProvider.tenants.where((t) => t.roomId == widget.roomId).toList();
    final splitAmount = _selectedTenantIds.isNotEmpty ? _totalAmount / _selectedTenantIds.length : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.black), onPressed: () => context.pop()),
        actions: [IconButton(icon: const Icon(Icons.more_vert, color: Colors.black), onPressed: () {})],
      ),
      body: Column(
        children: [
          // Top section mimicking GPay
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const Text('Enter amount to split', style: TextStyle(color: AppTheme.textSecondary, fontSize: 16)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('₹', style: TextStyle(fontSize: 32, color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    IntrinsicWidth(
                      child: TextField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w300),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: '0',
                        ),
                        onChanged: (val) {
                          setState(() {
                            _totalAmount = double.tryParse(val) ?? 0.0;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _descController,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: "What's this for?",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // List of tenants
          Expanded(
            child: ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Split evenly', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (roomTenants.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('No tenants currently in this room.')),
                  ),
                ...roomTenants.map((tenant) {
                  final isSelected = _selectedTenantIds.contains(tenant.id);
                  return ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: isSelected,
                          shape: const CircleBorder(),
                          activeColor: AppTheme.primaryColor,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedTenantIds.add(tenant.id);
                              } else {
                                _selectedTenantIds.remove(tenant.id);
                              }
                            });
                          },
                        ),
                        TenantAvatar(
                          name: tenant.name,
                          imageUrl: tenant.imageUrl,
                          radius: 18,
                        ),
                      ],
                    ),
                    title: Text(tenant.name),
                    trailing: Text(
                      isSelected ? '₹${splitAmount.toStringAsFixed(2)}' : '₹0.00',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  );
                }),
              ],
            ),
          ),

          
          // Bottom button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _selectedTenantIds.isEmpty || _totalAmount <= 0 ? null : () {
                  appProvider.addBillToTenants(
                    _selectedTenantIds.toList(),
                    splitAmount,
                    _descController.text.isEmpty ? 'Room Bill' : _descController.text,
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Text('Split Bill', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
