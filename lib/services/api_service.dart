import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String _baseUrl = 'https://remaki-backend.onrender.com/graphql';
  // Note: Appending /graphql as this is a GraphQL backend

  static Future<Map<String, dynamic>> performQuery(String query, {Map<String, dynamic>? variables}) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer YOUR_TOKEN', // If auth is implemented
        },
        body: jsonEncode({
          'query': query,
          'variables': variables ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('errors')) {
          print('GraphQL Errors: ${data['errors']}');
          throw Exception(data['errors'][0]['message']);
        }
        return data['data'];
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      print('ApiService Error: $e');
      throw e;
    }
  }

  // --- Queries ---

  static Future<List<dynamic>> fetchTenants() async {
    const String query = '''
      query {
        tenants {
          id
          name
          phone
          email
          emergencyContact
          room {
            id
            roomNumber
          }
          bed {
            id
            bedLabel
          }
          monthlyRent
          securityDeposit
          moveInDate
          status
          paymentStatus
          bills {
            id
            amount
            description
            createdAt
          }
        }
      }
    ''';
    final data = await performQuery(query);
    return data['tenants'] ?? [];
  }

  static Future<List<dynamic>> fetchRooms() async {
    const String query = '''
      query {
        rooms {
          id
          roomNumber
          floorNumber
          capacity
          status
          occupiedBeds
          availableBeds
          beds {
            id
            roomId
            roomNumber
            bedLabel
            status
          }
        }
      }
    ''';
    final data = await performQuery(query);
    return data['rooms'] ?? [];
  }

  static Future<Map<String, dynamic>> fetchOwnerDashboard() async {
    const String query = '''
      query {
        ownerDashboard {
          totalBeds
          occupiedBeds
          availableBeds
          maintenanceBeds
          occupancyPercentage
          rentExpected
          rentCollected
          rentPending
          totalTenants
          newTenantsThisMonth
          movingOutSoon
          totalRooms
          fullRooms
          partiallyOccupiedRooms
          emptyRooms
        }
      }
    ''';
    final data = await performQuery(query);
    return data['ownerDashboard'];
  }

  // --- Mutations ---

  static Future<void> createTenant(Map<String, dynamic> input) async {
    const String query = '''
      mutation CreateTenant(\$input: CreateTenantInput!) {
        createTenant(input: \$input) {
          id
          name
          status
        }
      }
    ''';
    await performQuery(query, variables: {'input': input});
  }

  static Future<void> createRoom(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation CreateRoom(\$input: CreateRoomInput!) {
        createRoom(input: \$input) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {'input': input});
  }

  static Future<void> recordRentPayment(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation RecordRentPayment(\$input: RecordRentPaymentInput!) {
        recordRentPayment(input: \$input) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {'input': input});
  }

  static Future<void> generateRoomCurrentBill(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation GenerateRoomCurrentBill(\$input: GenerateRoomCurrentBillInput!) {
        generateRoomCurrentBill(input: \$input) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {'input': input});
  }

  static Future<void> allocateTenantToBed(String tenantId, String bedId, {double? rentAmount, double? securityDeposit, String? moveInDate}) async {
    const String mutation = '''
      mutation AllocateTenantToBed(\$tenantId: ID!, \$bedId: ID!, \$rentAmount: Float, \$securityDeposit: Float, \$moveInDate: String) {
        allocateTenantToBed(tenantId: \$tenantId, bedId: \$bedId, rentAmount: \$rentAmount, securityDeposit: \$securityDeposit, moveInDate: \$moveInDate) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {
      'tenantId': tenantId, 
      'bedId': bedId,
      'rentAmount': rentAmount,
      'securityDeposit': securityDeposit,
      'moveInDate': moveInDate,
    });
  }
}
