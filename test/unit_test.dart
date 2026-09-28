import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sunshine_pg_app/models/models.dart';
import 'package:sunshine_pg_app/providers/app_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Domain Model Tests', () {
    test('Bed deserializes safely with missing fields', () {
      final bed = Bed.fromJson({});
      expect(bed.id, '');
      expect(bed.name, 'Bed');
      expect(bed.isAvailable, isTrue);
      expect(bed.tenantId, isNull);
    });

    test('Room deserializes safely with beds list', () {
      final roomJson = {
        'id': 'r1',
        'number': '101',
        'floor': '1st Floor',
        'capacity': 2,
        'beds': [
          {'id': 'b1', 'name': 'Bed A', 'isAvailable': true},
          {'id': 'b2', 'name': 'Bed B', 'isAvailable': false},
        ]
      };
      final room = Room.fromJson(roomJson);
      expect(room.id, 'r1');
      expect(room.number, '101');
      expect(room.capacity, 2);
      expect(room.beds.length, 2);
      expect(room.availableBeds, 1);
      expect(room.isFull, isFalse);
    });

    test('Tenant calculates total pending bills and total due correctly', () {
      final tenant = Tenant(
        id: 't1',
        name: 'John Doe',
        phone: '9876543210',
        email: 'john@example.com',
        roomId: 'r1',
        bedId: 'b1',
        moveInDate: DateTime.now(),
        rentAmount: 10000,
        securityDeposit: 5000,
        rentDueDate: DateTime.now(),
        pendingRentAmount: 4000,
        additionalCharges: [
          AdditionalCharge(
            id: 'ac1',
            description: 'Electricity',
            amount: 500,
            date: DateTime.now(),
            billType: 'CURRENT',
            status: 'PENDING',
          ),
          AdditionalCharge(
            id: 'ac2',
            description: 'Water',
            amount: 200,
            date: DateTime.now(),
            billType: 'OTHER',
            status: 'PAID',
          ),
        ],
      );

      expect(tenant.totalPendingBills, 500);
      expect(tenant.totalPaidBills, 200);
      expect(tenant.totalDue, 4500); // 4000 pending rent + 500 pending bill
    });
  });

  group('AppProvider Metric Tests', () {
    test('Calculates rent and bill metrics correctly', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AppProvider();
      
      provider.tenants = [
        Tenant(
          id: 't1',
          name: 'Alice',
          phone: '1111111111',
          email: 'alice@test.com',
          roomId: 'r1',
          bedId: 'b1',
          moveInDate: DateTime.now(),
          rentAmount: 8000,
          securityDeposit: 4000,
          rentDueDate: DateTime.now(),
          pendingRentAmount: 2000,
        ),
      ];

      expect(provider.expectedRentOnly, 8000);
      expect(provider.collectedRentOnly, 6000);
      expect(provider.pendingRentOnly, 2000);
    });

    test('Filters rooms and tenants when property is selected', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AppProvider();

      provider.properties = [
        PropertyItem(id: 'prop-1', name: 'Sunshine PG 1'),
        PropertyItem(id: 'prop-2', name: 'Sunshine PG 2'),
      ];

      provider.rooms = [
        Room(id: 'r1', number: '101', floor: '1', capacity: 2, propertyId: 'prop-1', beds: [
          Bed(id: 'b1', name: 'B1', isAvailable: false),
          Bed(id: 'b2', name: 'B2', isAvailable: true),
        ]),
        Room(id: 'r2', number: '201', floor: '2', capacity: 1, propertyId: 'prop-2', beds: [
          Bed(id: 'b3', name: 'B3', isAvailable: false),
        ]),
      ];

      provider.tenants = [
        Tenant(
          id: 't1',
          name: 'Alice',
          phone: '1111111111',
          email: 'alice@test.com',
          roomId: 'r1',
          bedId: 'b1',
          moveInDate: DateTime.now(),
          rentAmount: 8000,
          securityDeposit: 0,
          rentDueDate: DateTime.now(),
          pendingRentAmount: 3000,
          paymentStatus: 'PARTIAL',
        ),
        Tenant(
          id: 't2',
          name: 'Bob',
          phone: '2222222222',
          email: 'bob@test.com',
          roomId: 'r2',
          bedId: 'b3',
          moveInDate: DateTime.now(),
          rentAmount: 6000,
          securityDeposit: 0,
          rentDueDate: DateTime.now(),
          pendingRentAmount: 0,
          paymentStatus: 'PAID',
        ),
      ];

      // Default (All properties)
      expect(provider.currentRooms.length, 2);
      expect(provider.currentTenants.length, 2);
      expect(provider.totalBeds, 3);
      expect(provider.occupiedBeds, 2);

      // Select prop-1
      provider.selectProperty('prop-1');
      expect(provider.selectedPropertyId, 'prop-1');
      expect(provider.currentRooms.length, 1);
      expect(provider.currentRooms.first.id, 'r1');
      expect(provider.currentTenants.length, 1);
      expect(provider.currentTenants.first.name, 'Alice');
      expect(provider.currentTenants.first.isPartiallyPaid, isTrue);
      expect(provider.totalBeds, 2);
      expect(provider.occupiedBeds, 1);
      expect(provider.expectedRentOnly, 8000);
      expect(provider.collectedRentOnly, 5000);
      expect(provider.pendingRentOnly, 3000);

      // Select prop-2
      provider.selectProperty('prop-2');
      expect(provider.currentRooms.length, 1);
      expect(provider.currentRooms.first.id, 'r2');
      expect(provider.currentTenants.length, 1);
      expect(provider.currentTenants.first.name, 'Bob');
      expect(provider.currentTenants.first.isPartiallyPaid, isFalse);
      expect(provider.totalBeds, 1);
      expect(provider.occupiedBeds, 1);
      expect(provider.expectedRentOnly, 6000);
      expect(provider.collectedRentOnly, 6000);
      expect(provider.pendingRentOnly, 0);

      // Deselect back to all
      provider.selectProperty(null);
      expect(provider.currentRooms.length, 2);
      expect(provider.currentTenants.length, 2);
    });

    test('Filters currentPayments correctly by property and tenant', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = AppProvider();

      provider.properties = [
        PropertyItem(id: 'prop-1', name: 'Sunshine PG 1'),
        PropertyItem(id: 'prop-2', name: 'Sunshine PG 2'),
      ];

      provider.rooms = [
        Room(id: 'r1', number: '101', floor: '1', capacity: 2, propertyId: 'prop-1', beds: []),
        Room(id: 'r2', number: '201', floor: '2', capacity: 2, propertyId: 'prop-2', beds: []),
      ];

      provider.tenants = [
        Tenant(
          id: 't1',
          name: 'Alice',
          phone: '1111111111',
          email: 'alice@test.com',
          roomId: 'r1',
          bedId: 'b1',
          propertyId: 'prop-1',
          moveInDate: DateTime.now(),
          rentAmount: 8000,
          securityDeposit: 0,
          rentDueDate: DateTime.now(),
          pendingRentAmount: 0,
        ),
        Tenant(
          id: 't2',
          name: 'Bob',
          phone: '2222222222',
          email: 'bob@test.com',
          roomId: 'r2',
          bedId: 'b2',
          propertyId: 'prop-2',
          moveInDate: DateTime.now(),
          rentAmount: 6000,
          securityDeposit: 0,
          rentDueDate: DateTime.now(),
          pendingRentAmount: 2000,
        ),
      ];

      provider.payments = [
        Payment(
          id: 'p1',
          tenantId: 't1',
          amount: 8000,
          date: DateTime.now(),
          method: 'UPI',
          propertyId: 'prop-1',
        ),
        Payment(
          id: 'p2',
          tenantId: 't2',
          amount: 4000,
          date: DateTime.now(),
          method: 'CASH',
          propertyId: 'prop-2',
        ),
      ];

      // All properties
      expect(provider.currentPayments.length, 2);

      // Switch to prop-1
      provider.selectProperty('prop-1');
      expect(provider.currentPayments.length, 1);
      expect(provider.currentPayments.first.id, 'p1');
      expect(provider.currentPayments.first.amount, 8000);
      expect(provider.pgName, 'Sunshine PG 1');

      // Switch to prop-2
      provider.selectProperty('prop-2');
      expect(provider.currentPayments.length, 1);
      expect(provider.currentPayments.first.id, 'p2');
      expect(provider.currentPayments.first.amount, 4000);
      expect(provider.pgName, 'Sunshine PG 2');

      // Unpaid tenants in prop-2
      expect(provider.unpaidRentTenants.length, 1);
      expect(provider.unpaidRentTenants.first.name, 'Bob');

      // Switch back to prop-1, no unpaid tenants
      provider.selectProperty('prop-1');
      expect(provider.unpaidRentTenants.length, 0);
    });
  });
}

