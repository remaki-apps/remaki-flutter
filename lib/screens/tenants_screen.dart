import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../providers/app_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/tenant_avatar.dart';

class TenantsScreen extends StatefulWidget {
  const TenantsScreen({super.key});

  @override
  State<TenantsScreen> createState() => _TenantsScreenState();
}

class _TenantsScreenState extends State<TenantsScreen> {
  String _filter = 'All'; // All, Paid, Unpaid

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    
    var filteredTenants = appProvider.tenants.where((t) {
      if (_filter == 'Paid') return t.isPaid;
      if (_filter == 'Unpaid') return !t.isPaid;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenants'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),
      body: Column(
        children: [
          // Filter Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('All (${appProvider.tenants.length})', 'All'),
                const SizedBox(width: 8),
                _buildFilterChip('Paid (${appProvider.tenants.where((t) => t.isPaid).length})', 'Paid'),
                const SizedBox(width: 8),
                _buildFilterChip('Unpaid (${appProvider.tenants.where((t) => !t.isPaid).length})', 'Unpaid'),
              ],
            ),
          ),
          
          Expanded(
            child: filteredTenants.isEmpty
                ? const Center(
                    child: Text('No tenants found.', style: TextStyle(color: AppTheme.textSecondary)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredTenants.length,
                    itemBuilder: (context, index) {
                      var tenant = filteredTenants[index];
                      var roomIndex = appProvider.rooms.indexWhere((r) => r.id == tenant.roomId);
                      var roomNumber = roomIndex != -1 ? appProvider.rooms[roomIndex].number : 'N/A';
                      var bedName = roomIndex != -1
                          ? appProvider.rooms[roomIndex].beds.firstWhere((b) => b.id == tenant.bedId, orElse: () => appProvider.rooms[roomIndex].beds.first).name
                          : 'N/A';
                      var dueDateStr = DateFormat('dd MMM yyyy').format(tenant.rentDueDate);
                      
                      return GestureDetector(
                        onTap: () => context.push('/tenant_profile/${tenant.id}'),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Row(
                            children: [
                              TenantAvatar(
                                name: tenant.name,
                                imageUrl: tenant.imageUrl,
                                radius: 22,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(tenant.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text('Room $roomNumber - $bedName', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                                    Text('Rent Due: $dueDateStr', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 10)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tenant.isPaid ? AppTheme.success.withValues(alpha: 0.1) : AppTheme.danger.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(tenant.isPaid ? 'Paid' : 'Unpaid', style: TextStyle(color: tenant.isPaid ? AppTheme.success : AppTheme.danger, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add_tenant'),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    bool isSelected = _filter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filter = value);
      },
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : AppTheme.textPrimary),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? AppTheme.primaryColor : Colors.grey[300]!)),
    );
  }
}

