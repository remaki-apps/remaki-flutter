import 'package:flutter_test/flutter_test.dart';
import 'package:sunshine_pg_app/models/organization_models.dart';
import 'package:sunshine_pg_app/providers/organization_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Organization Domain Models', () {
    test('Organization deserializes cleanly', () {
      final json = {
        'id': 'org_123',
        'name': 'Premier Living Group',
        'code': 'PLG',
        'email': 'contact@premierliving.com',
        'phoneNumber': '9876543210',
        'address': '123 Tech Park',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'pincode': '560001',
        'logoUrl': 'https://example.com/logo.png',
        'isActive': true,
        'createdAt': '2026-11-15T00:00:00.000Z',
        'updatedAt': '2026-11-16T00:00:00.000Z',
      };

      final org = Organization.fromJson(json);

      expect(org.id, 'org_123');
      expect(org.name, 'Premier Living Group');
      expect(org.code, 'PLG');
      expect(org.email, 'contact@premierliving.com');
      expect(org.phoneNumber, '9876543210');
      expect(org.city, 'Bengaluru');
      expect(org.isActive, true);
    });

    test('Organization deserializes safely with missing optional fields', () {
      final json = {
        'id': 'org_456',
        'name': 'Minimal Org',
        'code': 'MIN',
      };

      final org = Organization.fromJson(json);

      expect(org.id, 'org_456');
      expect(org.name, 'Minimal Org');
      expect(org.code, 'MIN');
      expect(org.email, isNull);
      expect(org.phoneNumber, isNull);
      expect(org.city, isNull);
      expect(org.isActive, false); // defaults to false when not true
    });

    test('OrganizationDashboardMetrics parses complete metrics hierarchy', () {
      final json = {
        'totalAdmins': 5,
        'activeAdmins': 4,
        'inactiveAdmins': 1,
        'totalProperties': 8,
        'totalRooms': 40,
        'totalOccupiedBeds': 90,
        'totalAvailableBeds': 30,
        'totalTenants': 90,
        'totalRentExpected': 450000.0,
        'totalRentCollected': 380000.0,
        'totalRentPending': 70000.0,
      };

      final metrics = OrganizationDashboardMetrics.fromJson(json);

      expect(metrics.totalAdmins, 5);
      expect(metrics.activeAdmins, 4);
      expect(metrics.inactiveAdmins, 1);
      expect(metrics.totalProperties, 8);
      expect(metrics.totalRooms, 40);
      expect(metrics.totalOccupiedBeds, 90);
      expect(metrics.totalAvailableBeds, 30);
      expect(metrics.totalBeds, 120);
      expect(metrics.occupancyRate, 0.75);
      expect(metrics.totalTenants, 90);
      expect(metrics.totalRentExpected, 450000.0);
      expect(metrics.totalRentCollected, 380000.0);
      expect(metrics.totalRentPending, 70000.0);
    });

    test('OrganizationDashboardMetrics handles empty fallback data safely', () {
      final metrics = OrganizationDashboardMetrics.fromJson({});

      expect(metrics.totalAdmins, 0);
      expect(metrics.totalProperties, 0);
      expect(metrics.totalBeds, 0);
      expect(metrics.occupancyRate, 0.0);
      expect(metrics.totalRentExpected, 0.0);
    });

    test('OrganizationAdminSummary parses correctly with properties and operational stats', () {
      final json = {
        'id': 'usr_admin_1',
        'displayName': 'Rahul Sharma',
        'phoneNumber': '9123456780',
        'email': 'rahul@premierliving.com',
        'adminCode': 'ADM001',
        'isActive': true,
        'createdAt': '2026-11-15T10:00:00.000Z',
        'propertyCount': 2,
        'propertyNames': ['Green View PG', 'Sunrise Living'],
        'totalRooms': 10,
        'totalBeds': 30,
        'occupiedBeds': 24,
        'availableBeds': 6,
        'totalTenants': 24,
        'rentCollected': 150000.0,
        'rentPending': 20000.0,
      };

      final admin = OrganizationAdminSummary.fromJson(json);

      expect(admin.id, 'usr_admin_1');
      expect(admin.displayName, 'Rahul Sharma');
      expect(admin.adminCode, 'ADM001');
      expect(admin.phoneNumber, '9123456780');
      expect(admin.isActive, true);
      expect(admin.propertyCount, 2);
      expect(admin.propertyNames.length, 2);
      expect(admin.propertyNames[0], 'Green View PG');
      expect(admin.totalRooms, 10);
      expect(admin.totalBeds, 30);
      expect(admin.occupiedBeds, 24);
      expect(admin.availableBeds, 6);
      expect(admin.occupancyRate, 0.8);
      expect(admin.totalTenants, 24);
      expect(admin.rentCollected, 150000.0);
    });

    test('OrganizationPropertyItem parses fields correctly', () {
      final json = {
        'id': 'prop_10',
        'name': 'Royal Comforts PG',
        'address': 'Koramangala 4th Block',
        'city': 'Bengaluru',
        'state': 'Karnataka',
        'pincode': '560034',
        'totalFloors': 3,
        'adminId': 'usr_admin_1',
        'adminName': 'Rahul Sharma',
        'adminCode': 'ADM001',
        'totalRooms': 5,
        'totalBeds': 20,
        'occupiedBeds': 15,
        'availableBeds': 5,
        'totalTenants': 15,
      };

      final prop = OrganizationPropertyItem.fromJson(json);

      expect(prop.id, 'prop_10');
      expect(prop.name, 'Royal Comforts PG');
      expect(prop.adminName, 'Rahul Sharma');
      expect(prop.totalBeds, 20);
      expect(prop.occupiedBeds, 15);
      expect(prop.availableBeds, 5);
    });

    test('buildAdminCredentialsMessage builds complete URL-encoded WhatsApp invitation', () {
      final encodedMsg = buildAdminCredentialsMessage(
        orgName: 'Premier Living',
        adminName: 'Vikas Kumar',
        adminCode: 'ADM005',
        phone: '9988776655',
        password: 'hostel9281',
        propertyName: 'Vikas PG Residency',
      );

      final decoded = Uri.decodeComponent(encodedMsg);

      expect(decoded, contains('Welcome to Premier Living!'));
      expect(decoded, contains('Vikas Kumar'));
      expect(decoded, contains('ADM005'));
      expect(decoded, contains('9988776655'));
      expect(decoded, contains('hostel9281'));
      expect(decoded, contains('Vikas PG Residency'));
      expect(decoded, contains('https://remaki-flutter.vercel.app'));
    });
  });

  group('OrganizationProvider Filtering and Search', () {
    test('Filtering by status and query works in memory', () {
      final provider = OrganizationProvider();

      // Verify initial state
      expect(provider.isLoading, isFalse);
      expect(provider.admins, isEmpty);
      expect(provider.filteredAdmins, isEmpty);
      expect(provider.filterStatus, 'ALL');

      // Populate test admins
      final admin1 = OrganizationAdminSummary(
        id: 'adm_1',
        displayName: 'Rahul Sharma',
        phoneNumber: '9876543210',
        adminCode: 'ADM001',
        isActive: true,
        createdAt: '2026-11-15T00:00:00Z',
        propertyCount: 1,
        propertyNames: ['Green View PG'],
        totalRooms: 10,
        totalBeds: 20,
        occupiedBeds: 15,
        availableBeds: 5,
        totalTenants: 15,
        rentCollected: 50000.0,
        rentPending: 5000.0,
      );

      final admin2 = OrganizationAdminSummary(
        id: 'adm_2',
        displayName: 'Pooja Verma',
        phoneNumber: '9123456789',
        adminCode: 'ADM002',
        isActive: false,
        createdAt: '2026-11-16T00:00:00Z',
        propertyCount: 1,
        propertyNames: ['Blue Sky Residency'],
        totalRooms: 5,
        totalBeds: 10,
        occupiedBeds: 0,
        availableBeds: 10,
        totalTenants: 0,
        rentCollected: 0.0,
        rentPending: 0.0,
      );

      provider.admins = [admin1, admin2];
      expect(provider.filteredAdmins.length, 2);

      // Filter by active
      provider.setFilterStatus('ACTIVE');
      expect(provider.filterStatus, 'ACTIVE');
      expect(provider.filteredAdmins.length, 1);
      expect(provider.filteredAdmins.first.displayName, 'Rahul Sharma');

      // Filter by inactive
      provider.setFilterStatus('INACTIVE');
      expect(provider.filteredAdmins.length, 1);
      expect(provider.filteredAdmins.first.displayName, 'Pooja Verma');

      // Search by query
      provider.setFilterStatus('ALL');
      provider.setSearchQuery('Rahul');
      expect(provider.filteredAdmins.length, 1);
      expect(provider.filteredAdmins.first.displayName, 'Rahul Sharma');

      // Search by admin code
      provider.setSearchQuery('ADM002');
      expect(provider.filteredAdmins.length, 1);
      expect(provider.filteredAdmins.first.displayName, 'Pooja Verma');

      // Search by property name
      provider.setSearchQuery('Green View');
      expect(provider.filteredAdmins.length, 1);
      expect(provider.filteredAdmins.first.displayName, 'Rahul Sharma');

      // Reset
      provider.reset();
      expect(provider.filterStatus, 'ALL');
      expect(provider.searchQuery, '');
      expect(provider.admins, isEmpty);
      expect(provider.currentOrganization, isNull);
    });
  });
}
