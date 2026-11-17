import 'package:flutter/material.dart';
import '../models/organization_models.dart';
import '../services/api_service.dart';

class OrganizationProvider with ChangeNotifier {
  Organization? currentOrganization;
  OrganizationDashboardMetrics metrics = OrganizationDashboardMetrics.empty();
  List<OrganizationAdminSummary> admins = [];
  List<OrganizationPropertyItem> properties = [];

  bool isLoading = false;
  String? errorMessage;

  String filterStatus = 'ALL'; // 'ALL', 'ACTIVE', 'INACTIVE'
  String searchQuery = '';

  List<OrganizationAdminSummary> get filteredAdmins {
    return admins.where((admin) {
      if (filterStatus == 'ACTIVE' && !admin.isActive) return false;
      if (filterStatus == 'INACTIVE' && admin.isActive) return false;

      if (searchQuery.trim().isNotEmpty) {
        final query = searchQuery.trim().toLowerCase();
        final nameMatch = admin.displayName.toLowerCase().contains(query);
        final codeMatch = admin.adminCode.toLowerCase().contains(query);
        final phoneMatch = admin.phoneNumber.contains(query);
        final propMatch = admin.propertyNames.any((p) => p.toLowerCase().contains(query));
        if (!nameMatch && !codeMatch && !phoneMatch && !propMatch) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void setFilterStatus(String status) {
    if (filterStatus != status) {
      filterStatus = status;
      notifyListeners();
    }
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void reset() {
    currentOrganization = null;
    metrics = OrganizationDashboardMetrics.empty();
    admins = [];
    properties = [];
    isLoading = false;
    errorMessage = null;
    filterStatus = 'ALL';
    searchQuery = '';
    notifyListeners();
  }

  Future<void> loadFromAPI({bool showLoading = true}) async {
    if (!ApiService.isLoggedIn || ApiService.role != 'ORGANIZATION') {
      return;
    }

    if (showLoading) {
      isLoading = true;
      errorMessage = null;
      notifyListeners();
    }

    try {
      final futures = await Future.wait([
        ApiService.fetchMyOrganization().catchError((e) => <String, dynamic>{}),
        ApiService.fetchOrganizationDashboard().catchError((e) => <String, dynamic>{}),
        ApiService.fetchOrganizationAdmins().catchError((e) => <dynamic>[]),
        ApiService.fetchOrganizationProperties().catchError((e) => <dynamic>[]),
      ]);

      final orgData = futures[0] as Map<String, dynamic>;
      final metricsData = futures[1] as Map<String, dynamic>;
      final adminsData = futures[2] as List<dynamic>;
      final propsData = futures[3] as List<dynamic>;

      if (orgData.isNotEmpty) {
        currentOrganization = Organization.fromJson(orgData);
      }
      if (metricsData.isNotEmpty) {
        metrics = OrganizationDashboardMetrics.fromJson(metricsData);
      }

      admins = adminsData
          .map((a) => OrganizationAdminSummary.fromJson(a as Map<String, dynamic>))
          .toList();

      properties = propsData
          .map((p) => OrganizationPropertyItem.fromJson(p as Map<String, dynamic>))
          .toList();

      errorMessage = null;
    } catch (e) {
      errorMessage = ApiService.cleanErrorMessage(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<AdminCreatedPayload> createAdmin(Map<String, dynamic> input) async {
    try {
      final data = await ApiService.createAdminUnderOrg(input);
      final payload = AdminCreatedPayload.fromJson(data);

      admins.insert(0, payload.admin);
      // Reload metrics in background
      loadFromAPI(showLoading: false);
      notifyListeners();
      return payload;
    } catch (e) {
      throw ApiService.cleanErrorMessage(e);
    }
  }

  Future<OrganizationAdminSummary> updateAdmin(Map<String, dynamic> input) async {
    try {
      final data = await ApiService.updateAdminUnderOrg(input);
      final updated = OrganizationAdminSummary.fromJson(data);

      final index = admins.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        admins[index] = updated;
      }
      notifyListeners();
      return updated;
    } catch (e) {
      throw ApiService.cleanErrorMessage(e);
    }
  }

  Future<void> toggleAdminStatus(String adminId, bool isActive) async {
    try {
      final data = await ApiService.toggleAdminStatus(adminId, isActive);
      final updated = OrganizationAdminSummary.fromJson(data);

      final index = admins.indexWhere((a) => a.id == updated.id);
      if (index != -1) {
        admins[index] = updated;
      }
      loadFromAPI(showLoading: false);
      notifyListeners();
    } catch (e) {
      throw ApiService.cleanErrorMessage(e);
    }
  }

  Future<void> deleteAdmin(String adminId) async {
    try {
      final success = await ApiService.deleteAdminUnderOrg(adminId);
      if (success) {
        admins.removeWhere((a) => a.id == adminId);
        loadFromAPI(showLoading: false);
        notifyListeners();
      }
    } catch (e) {
      throw ApiService.cleanErrorMessage(e);
    }
  }

  Future<void> updateProfile(Map<String, dynamic> input) async {
    try {
      final data = await ApiService.updateMyOrganization(input);
      currentOrganization = Organization.fromJson(data);
      notifyListeners();
    } catch (e) {
      throw ApiService.cleanErrorMessage(e);
    }
  }
}

