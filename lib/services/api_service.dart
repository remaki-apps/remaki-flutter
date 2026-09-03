import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = 'https://remaki-backend.onrender.com/graphql';
  // Note: Appending /graphql as this is a GraphQL backend

  static String? _token;
  static String? _role;

  static String? get token => _token;
  static String? get role => _role;

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static Future<void> initToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      _role = prefs.getString('user_role');
    } catch (e) {
      debugPrint('ApiService initToken error: $e');
    }
  }

  static Future<void> setAuthToken(String token, String role) async {
    _token = token;
    _role = role;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('user_role', role);
    } catch (e) {
      debugPrint('ApiService setAuthToken error: $e');
    }
  }

  static Future<void> clearAuthToken() async {
    _token = null;
    _role = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
    } catch (e) {
      debugPrint('ApiService clearAuthToken error: $e');
    }
  }

  static Future<Map<String, dynamic>> performQuery(String query, {Map<String, dynamic>? variables}) async {
    try {
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      if (_token != null) {
        headers['Authorization'] = 'Bearer $_token';
      }

      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: headers,
        body: jsonEncode({
          'query': query,
          'variables': variables ?? {},
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data.containsKey('errors')) {
          debugPrint('GraphQL Errors: ${data['errors']}');
          throw Exception(data['errors'][0]['message']);
        }
        return data['data'];
      } else {
        throw Exception('Failed to load data: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('ApiService Error: $e');
      rethrow;
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
          rentDueDate
          pendingRentAmount
          defaultPaymentMode
          bills {
            id
            amount
            type
            status
            dueDate
            description
            createdAt
          }
        }
      }
    ''';
    final data = await performQuery(query);
    return data['tenants'] ?? [];
  }

  static Future<Map<String, dynamic>?> fetchCurrentTenantProfile() async {
    const query = '''
      query {
        currentTenantProfile {
          id
          name
          phone
          status
          paymentStatus
          pendingRentAmount
          latestRejectionReason
          latestRejectionDate
          bills {
            id
            amount
            status
            type
          }
        }
      }
    ''';
    try {
      final data = await performQuery(query);
      return data['currentTenantProfile'];
    } catch (e) {
      debugPrint('Error fetching current tenant profile: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> fetchAdminProfile() async {
    const query = '''
      query {
        adminProfile {
          adminName
          pgName
          pgAddress
        }
      }
    ''';
    try {
      final data = await performQuery(query);
      return data['adminProfile'];
    } catch (e) {
      debugPrint('Error fetching admin profile: $e');
      return null;
    }
  }

  static Future<List<dynamic>> fetchPayments({String? tenantId}) async {
    String query;
    if (tenantId != null) {
      query = '''
        query {
          payments(tenantId: "$tenantId") {
            id
            tenantId
            amount
            method
            date
          }
        }
      ''';
    } else {
      query = '''
        query {
          payments {
            id
            tenantId
            amount
            method
            date
          }
        }
      ''';
    }
    final response = await performQuery(query);
    return response['payments'] ?? [];
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

  static Future<String?> createTenant(Map<String, dynamic> input) async {
    const String query = '''
      mutation CreateTenant(\$input: CreateTenantInput!) {
        createTenant(input: \$input) {
          id
          name
          status
          tempPassword
        }
      }
    ''';
    final result = await performQuery(query, variables: {'input': input});
    return result['createTenant']['tempPassword'];
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

  static Future<void> updateTenantFinancials({
    required String tenantId,
    double? rentAmount,
    double? securityDeposit,
    int? rentDueDay,
    String? paymentMode,
  }) async {
    const String mutation = '''
      mutation UpdateTenantFinancials(\$tenantId: ID!, \$rentAmount: Float, \$securityDeposit: Float, \$rentDueDay: Int, \$paymentMode: String) {
        updateTenantFinancials(tenantId: \$tenantId, rentAmount: \$rentAmount, securityDeposit: \$securityDeposit, rentDueDay: \$rentDueDay, paymentMode: \$paymentMode) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {
      'tenantId': tenantId,
      'rentAmount': rentAmount,
      'securityDeposit': securityDeposit,
      'rentDueDay': rentDueDay,
      'paymentMode': paymentMode,
    });
  }

  static Future<void> updateBill(String billId, double amount) async {
    const String mutation = '''
      mutation UpdateBill(\$billId: ID!, \$amount: Float!) {
        updateBill(billId: \$billId, amount: \$amount) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {
      'billId': billId,
      'amount': amount,
    });
  }

  static Future<List<dynamic>> fetchPendingPaymentRequests() async {
    const String query = '''
      query {
        pendingPaymentRequests {
          id
          tenantProfileId
          tenantName
          amount
          paymentType
          method
          proofImageBase64
          status
          createdAt
        }
      }
    ''';
    final data = await performQuery(query);
    return data['pendingPaymentRequests'] ?? [];
  }

  static Future<void> resolvePaymentRequest(String requestId, String action, {String? rejectionReason}) async {
    const String mutation = '''
      mutation ResolvePaymentRequest(\$input: ResolvePaymentRequestInput!) {
        resolvePaymentRequest(input: \$input) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {
      'input': {
        'requestId': requestId,
        'action': action,
        'rejectionReason': rejectionReason,
      }
    });
  }
}
