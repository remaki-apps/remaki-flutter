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
  });
}
