import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static const String _prodUrl = 'https://remaki-backend.onrender.com/graphql';
  static const String _defaultQaUrl = 'https://remaki-backend-qa.onrender.com/graphql';

  static String get _baseUrl {
    // 1. Explicit override via --dart-define=API_URL=...
    const customUrl = String.fromEnvironment('API_URL');
    if (customUrl.isNotEmpty) return customUrl;

    // 2. Automatic Web Host detection
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host.contains('qa') || host.contains('preview')) {
        return _defaultQaUrl;
      }
    }

    return _prodUrl;
  }
  // Note: Appending /graphql as this is a GraphQL backend

  static final ValueNotifier<bool> authNotifier = ValueNotifier<bool>(isLoggedIn);

  static String? _token;
  static String? _role;
  static bool? _hasSecurityPin;

  static String? get token => _token;
  static String? get role => _role;
  static bool get hasSecurityPin => _hasSecurityPin ?? false;

  static bool get isLoggedIn => _token != null && _token!.isNotEmpty;

  static Future<void> initToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('auth_token');
      _role = prefs.getString('user_role');
      _hasSecurityPin = prefs.getBool('user_has_security_pin');
      authNotifier.value = isLoggedIn;
    } catch (e) {
      debugPrint('ApiService initToken error: $e');
    }
  }

  static Future<void> setAuthToken(String token, String role, {bool? hasSecurityPin, bool persist = true}) async {
    _token = token;
    _role = role;
    if (hasSecurityPin != null) {
      _hasSecurityPin = hasSecurityPin;
    }
    authNotifier.value = isLoggedIn;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (persist) {
        await prefs.setString('auth_token', token);
        await prefs.setString('user_role', role);
        if (hasSecurityPin != null) {
          await prefs.setBool('user_has_security_pin', hasSecurityPin);
        }
      } else {
        await prefs.remove('auth_token');
        await prefs.remove('user_role');
        await prefs.remove('user_has_security_pin');
      }
    } catch (e) {
      debugPrint('ApiService setAuthToken error: $e');
    }
  }

  static Future<void> setHasSecurityPin(bool value) async {
    _hasSecurityPin = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('user_has_security_pin', value);
    } catch (e) {
      debugPrint('ApiService setHasSecurityPin error: $e');
    }
  }

  static Future<void> clearAuthToken() async {
    _token = null;
    _role = null;
    _hasSecurityPin = null;
    authNotifier.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('user_role');
      await prefs.remove('user_has_security_pin');
    } catch (e) {
      debugPrint('ApiService clearAuthToken error: $e');
    }
  }

  /// Cleans technical exception strings and GraphQL error prefixes into clean, user-friendly messages.
  static String cleanErrorMessage(dynamic error) {
    if (error == null) return 'An unexpected error occurred.';
    String message = error.toString().trim();

    // Strip common exception prefixes repeatedly
    bool cleaned = true;
    while (cleaned) {
      cleaned = false;
      for (final prefix in [
        'ApiException: ',
        'ApiException:',
        'Exception: ',
        'Exception:',
        'Error: ',
        'Error:',
        'GraphQL Errors: ',
        'GraphQL error: ',
        'GraphQL Error: ',
        'ApolloError: ',
        'HttpException: ',
        'ClientException: ',
      ]) {
        if (message.startsWith(prefix)) {
          message = message.substring(prefix.length).trim();
          cleaned = true;
        }
      }
    }

    final lower = message.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('xmlhttprequest error') ||
        lower.contains('handshakeexception')) {
      return 'Unable to connect to server. Please check your internet connection.';
    }
    if (lower.contains('timeoutexception') || lower.contains('request timed out') || lower.contains('connection timeout')) {
      return 'Request timed out. The server took too long to respond. Please try again.';
    }
    if (lower.contains('jwt expired') || lower.contains('token expired') || lower.contains('session expired')) {
      return 'Your session has expired. Please log in again.';
    }
    if (lower.contains('unauthorized') || lower.contains('unauthenticated')) {
      return 'Authentication failed. Please verify your credentials or log in again.';
    }

    // If message is in raw GraphQL error array format: [{message: Bed is occupied}]
    if (message.startsWith('[') && message.endsWith(']')) {
      final match = RegExp(r'message:\s*([^,}]+)').firstMatch(message);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }

    return message.isNotEmpty ? message : 'An unexpected error occurred.';
  }

  static DateTime? _lastWarmupTime;

  /// Sends a non-blocking background ping to wake up the sleeping Render backend instance early.
  /// Free/hobby instances on Render spin down after 15 minutes of inactivity. Warming up at app start
  /// ensures the server is ready by the time the user enters credentials.
  static void warmupServer() {
    final now = DateTime.now();
    if (_lastWarmupTime != null && now.difference(_lastWarmupTime!).inMinutes < 5) {
      return;
    }
    _lastWarmupTime = now;
    try {
      http
          .get(Uri.parse('https://remaki-backend.onrender.com/'))
          .timeout(const Duration(seconds: 15))
          .then((_) {
            debugPrint('Render backend warmup ping acknowledged.');
          })
          .catchError((e) {
            debugPrint('Render backend warmup ping dispatched ($e).');
          });
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> performQuery(
    String query, {
    Map<String, dynamic>? variables,
    int maxRetries = 1,
    Duration timeout = const Duration(seconds: 55),
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
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
        ).timeout(timeout);

        // If Cloudflare / Render returns 502/503/504 Bad Gateway / Service Unavailable during container spinup, retry!
        if ((response.statusCode == 502 || response.statusCode == 503 || response.statusCode == 504) && attempts <= maxRetries) {
          debugPrint('Backend server spinning up (HTTP ${response.statusCode}), retrying in 2s (attempt $attempts)...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        Map<String, dynamic>? responseJson;
        try {
          if (response.body.isNotEmpty) {
            final decoded = jsonDecode(response.body);
            if (decoded is Map<String, dynamic>) {
              responseJson = decoded;
            }
          }
        } catch (_) {
          // Body is not valid JSON
        }

        // 1. Inspect response body for GraphQL errors array (can be present on HTTP 200, 400, or 500)
        if (responseJson != null && responseJson.containsKey('errors') && responseJson['errors'] != null) {
          final errorsList = responseJson['errors'];
          if (errorsList is List && errorsList.isNotEmpty) {
            debugPrint('GraphQL Errors: $errorsList');
            final firstErr = errorsList[0];
            String msg = 'An unknown backend error occurred.';
            if (firstErr is Map && firstErr['message'] != null) {
              msg = firstErr['message'].toString();
            } else if (firstErr is String) {
              msg = firstErr;
            }

            final lower = msg.toLowerCase();
            if (lower.contains('unauthorized') || lower.contains('unauthenticated') || lower.contains('jwt expired')) {
              await clearAuthToken();
            }
            throw ApiException(cleanErrorMessage(msg));
          }
        }

        // 2. Inspect response body for NestJS / Express HTTP exception payload: {statusCode, message, error}
        if (response.statusCode != 200 && responseJson != null) {
          String? extractedMsg;
          if (responseJson['message'] != null) {
            if (responseJson['message'] is List) {
              extractedMsg = (responseJson['message'] as List).map((e) => e.toString()).join('\n');
            } else {
              extractedMsg = responseJson['message'].toString();
            }
          } else if (responseJson['error'] != null) {
            extractedMsg = responseJson['error'].toString();
          }

          if (extractedMsg != null && extractedMsg.trim().isNotEmpty) {
            final lower = extractedMsg.toLowerCase();
            if (lower.contains('unauthorized') || lower.contains('unauthenticated') || lower.contains('jwt expired')) {
              await clearAuthToken();
            }
            throw ApiException(cleanErrorMessage(extractedMsg));
          }
        }

        // 3. Status code routing
        if (response.statusCode == 200) {
          if (responseJson != null) {
            final rootData = responseJson['data'];
            if (rootData is Map<String, dynamic>) {
              return rootData;
            }
            return responseJson;
          }
          return <String, dynamic>{};
        } else if (response.statusCode == 401) {
          await clearAuthToken();
          throw ApiException('Your session has expired. Please log in again.');
        } else if (response.statusCode == 403) {
          throw ApiException('You do not have permission to perform this action.');
        } else if (response.statusCode == 404) {
          throw ApiException('The requested resource was not found.');
        } else if (response.statusCode >= 500) {
          throw ApiException('Server error (${response.statusCode}). Please try again shortly.');
        } else {
          throw ApiException('Request failed with status ${response.statusCode}. Please try again.');
        }
      } on SocketException catch (_) {
        if (attempts <= maxRetries) {
          debugPrint('SocketException on attempt $attempts, retrying in 2s...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        throw ApiException('Unable to connect to server. Please check your internet connection.');
      } on http.ClientException catch (_) {
        if (attempts <= maxRetries) {
          debugPrint('ClientException on attempt $attempts, retrying in 2s...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        throw ApiException('Unable to connect to server. Please check your internet connection.');
      } on TimeoutException catch (_) {
        if (attempts <= maxRetries) {
          debugPrint('Request timed out on attempt $attempts (cold start), retrying once...');
          await Future.delayed(const Duration(milliseconds: 1500));
          continue;
        }
        throw ApiException('Request timed out. The server took too long to respond. Please try again.');
      } catch (e) {
        debugPrint('ApiService Error: $e');
        if (e is ApiException) rethrow;
        throw ApiException(cleanErrorMessage(e));
      }
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
          imageUrl
          emergencyContact
          tempPassword
          propertyId
          room {
            id
            roomNumber
            propertyId
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
          hasPendingRequest
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
          pendingConvenienceFee
          platformFee
          occupation
          dateOfBirth
          maritalStatus
          fatherName
          permanentAddress
          villageOrTown
          houseNo
          wardNo
          district
          state
          nationality
          pinCode
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
          email
          imageUrl
          emergencyContact
          status
          paymentStatus
          hasPendingRequest
          pendingRentAmount
          monthlyRent
          securityDeposit
          moveInDate
          rentDueDate
          latestRejectionReason
          latestRejectionDate
          occupation
          dateOfBirth
          maritalStatus
          fatherName
          permanentAddress
          villageOrTown
          houseNo
          wardNo
          district
          state
          nationality
          pinCode
          room {
            id
            roomNumber
          }
          bed {
            id
            bedLabel
          }
          defaultPaymentMode
          bills {
            id
            amount
            status
            type
            dueDate
            description
            createdAt
          }
          pendingConvenienceFee
          platformFee
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

  /// Tenant updates their own profile — uses the auth token identity (no ID needed)
  static Future<Map<String, dynamic>?> updateMyProfile(Map<String, dynamic> input) async {
    const mutation = '''
      mutation UpdateMyProfile(\$input: UpdateTenantInput!) {
        updateMyProfile(input: \$input) {
          id
          name
          email
          imageUrl
          emergencyContact
          phone
          occupation
          dateOfBirth
          maritalStatus
          fatherName
          permanentAddress
          villageOrTown
          houseNo
          wardNo
          district
          state
          nationality
          pinCode
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updateMyProfile'];
  }

  static Future<Map<String, dynamic>?> fetchAdminProfile() async {
    const query = '''
      query {
        adminProfile {
          adminName
          pgName
          pgAddress
          platformFee
          properties {
            id
            name
            address
            city
            state
            pincode
            description
            totalFloors
            platformFee
          }
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

  /// Fetches the ₹9 convenience fee summary for the logged-in admin.
  /// Returns {totalFees, pendingFees, submittedFees, totalCount, pendingCount, submittedCount}
  static Future<Map<String, dynamic>?> fetchConvenienceFeeSummary() async {
    const query = '''
      query {
        convenienceFeeSummary {
          totalFees
          pendingFees
          submittedFees
          totalCount
          pendingCount
          submittedCount
        }
      }
    ''';
    try {
      final data = await performQuery(query);
      return data['convenienceFeeSummary'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error fetching convenience fee summary: $e');
      return null;
    }
  }

  static Future<List<dynamic>> fetchAnnouncements(bool isAdmin) async {
    final queryName = isAdmin ? 'adminAnnouncements' : 'tenantAnnouncements';
    final query = '''
      query {
        $queryName {
          id
          heading
          description
          imageUrl
          createdAt
        }
      }
    ''';
    try {
      final data = await performQuery(query);
      return data[queryName] ?? [];
    } catch (e) {
      debugPrint('Error fetching announcements: $e');
      return [];
    }
  }

  static Future<void> createAnnouncement({
    required String heading,
    required String description,
    String? imageBase64,
  }) async {
    const mutation = '''
      mutation CreateAnnouncement(\$heading: String!, \$description: String!, \$imageBase64: String) {
        createAnnouncement(heading: \$heading, description: \$description, imageBase64: \$imageBase64) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {
      'heading': heading,
      'description': description,
      'imageBase64': imageBase64,
    });
  }

  static Future<bool> deleteAnnouncement(String id) async {
    const mutation = '''
      mutation DeleteAnnouncement(\$id: ID!) {
        deleteAnnouncement(id: \$id)
      }
    ''';
    final result = await performQuery(mutation, variables: {'id': id});
    return result['deleteAnnouncement'] == true;
  }

  static Future<bool> vacateTenant(String tenantId) async {
    const mutation = '''
      mutation VacateTenant(\$tenantId: ID!) {
        vacateTenant(tenantId: \$tenantId)
      }
    ''';
    final result = await performQuery(mutation, variables: {'tenantId': tenantId});
    return result['vacateTenant'] == true;
  }

  static Future<bool> transferTenant({
    required String tenantId,
    required String fromBedId,
    required String toBedId,
    String? effectiveDate,
    String? reason,
  }) async {
    const mutation = '''
      mutation TransferTenant(\$input: TransferTenantInput!) {
        transferTenant(input: \$input) {
          id
          name
        }
      }
    ''';
    final result = await performQuery(mutation, variables: {
      'input': {
        'tenantId': tenantId,
        'fromBedId': fromBedId,
        'toBedId': toBedId,
        'effectiveDate': effectiveDate ?? DateTime.now().toIso8601String(),
        'reason': reason,
      }
    });
    return result['transferTenant'] != null;
  }

  static Future<List<dynamic>> fetchPayments({String? tenantId}) async {
    try {
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
              notes
              propertyId
              billingMonth
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
              notes
              propertyId
              billingMonth
            }
          }
        ''';
      }
      final response = await performQuery(query);
      return response['payments'] ?? [];
    } catch (e) {
      debugPrint('fetchPayments error: $e');
      return [];
    }
  }

  static Future<List<dynamic>> fetchRooms() async {
    const String query = '''
      query {
        rooms {
          id
          propertyId
          roomNumber
          floorNumber
          capacity
          roomType
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

  static Future<Map<String, dynamic>?> createRoom(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation CreateRoom(\$input: CreateRoomInput!) {
        createRoom(input: \$input) {
          id
          roomNumber
          floorNumber
          capacity
          roomType
          beds {
            id
            bedLabel
            status
          }
        }
      }
    ''';
    final result = await performQuery(mutation, variables: {'input': input});
    return result['createRoom'] as Map<String, dynamic>?;
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
          description
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

  static Future<bool> changePassword(String newPassword) async {
    const String mutation = '''
      mutation ChangePassword(\$newPassword: String!) {
        changePassword(newPassword: \$newPassword)
      }
    ''';
    final data = await performQuery(mutation, variables: {'newPassword': newPassword});
    return data['changePassword'] == true;
  }

  static Future<String> resetPassword(String phoneNumber, {String? newPassword, String? securityPin}) async {
    const String mutation = '''
      mutation AdminForgotPassword(\$input: AdminForgotPasswordInput!) {
        adminForgotPassword(input: \$input)
      }
    ''';
    final Map<String, dynamic> input = {'phoneNumber': phoneNumber};
    if (newPassword != null && newPassword.isNotEmpty) {
      input['newPassword'] = newPassword;
    }
    if (securityPin != null && securityPin.isNotEmpty) {
      input['securityPin'] = securityPin;
    }
    final data = await performQuery(mutation, variables: {'input': input});
    return data['adminForgotPassword']?.toString() ?? '';
  }

  /// Sets up the compulsory 4-digit Security Recovery PIN (MPIN) for the logged-in user
  static Future<bool> setupSecurityPin(String pin) async {
    const String mutation = '''
      mutation SetupSecurityPin(\$pin: String!) {
        setupSecurityPin(pin: \$pin)
      }
    ''';
    final data = await performQuery(mutation, variables: {'pin': pin});
    if (data['setupSecurityPin'] == true) {
      await setHasSecurityPin(true);
      return true;
    }
    return false;
  }

  /// Resets password using phone number and verified 4-digit Security Recovery PIN (MPIN)
  static Future<bool> resetPasswordWithPin({
    required String phoneNumber,
    required String securityPin,
    required String newPassword,
  }) async {
    const String mutation = '''
      mutation ResetPasswordWithPin(\$input: ResetPasswordWithPinInput!) {
        resetPasswordWithPin(input: \$input)
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        'phoneNumber': phoneNumber,
        'securityPin': securityPin,
        'newPassword': newPassword,
      }
    });
    return data['resetPasswordWithPin'] == true;
  }

  /// Fetches organization support contact details
  static Future<Map<String, String>> fetchOrganizationSupportInfo() async {
    const String query = '''
      query {
        organizationSupportInfo {
          email
          phone
          message
        }
      }
    ''';
    try {
      final data = await performQuery(query);
      final info = data['organizationSupportInfo'];
      return {
        'email': info?['email']?.toString() ?? 'support@remaki.in',
        'phone': info?['phone']?.toString() ?? '9940328087',
        'message': info?['message']?.toString() ?? 'Please contact organization support to recover your Security Recovery PIN (MPIN).',
      };
    } catch (_) {
      return {
        'email': 'support@remaki.in',
        'phone': '9940328087',
        'message': 'Please contact organization support to recover your Security Recovery PIN (MPIN).',
      };
    }
  }

  // ===========================================================================
  // PROPERTY OWNERS (MULTIPLE LOGIN SUPPORT UP TO 10 OWNERS)
  // ===========================================================================

  static Future<List<dynamic>> fetchPropertyOwners() async {
    const String query = '''
      query {
        propertyOwners {
          id
          userId
          name
          phoneNumber
          role
          isPrimary
          createdAt
        }
      }
    ''';
    final data = await performQuery(query);
    return data['propertyOwners'] ?? [];
  }

  static Future<Map<String, dynamic>> addPropertyOwner({
    required String name,
    required String phoneNumber,
    required String password,
  }) async {
    const String mutation = '''
      mutation AddPropertyOwner(\$input: AddPropertyOwnerInput!) {
        addPropertyOwner(input: \$input) {
          id
          userId
          name
          phoneNumber
          role
          isPrimary
          createdAt
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        'name': name,
        'phoneNumber': phoneNumber,
        'password': password,
      }
    });
    return data['addPropertyOwner'] as Map<String, dynamic>;
  }

  static Future<bool> removePropertyOwner(String id) async {
    const String mutation = '''
      mutation RemovePropertyOwner(\$id: ID!) {
        removePropertyOwner(id: \$id)
      }
    ''';
    final data = await performQuery(mutation, variables: {'id': id});
    return data['removePropertyOwner'] == true;
  }

  // ===========================================================================
  // COMPLAINTS (INDIVIDUAL COMPLAINT FLOW WITH MEDIA)
  // ===========================================================================

  static Future<List<dynamic>> fetchMyComplaints() async {
    const String query = '''
      query {
        myComplaints {
          id
          tenantProfileId
          adminId
          category
          title
          description
          mediaUrl
          status
          adminReply
          repliedAt
          resolvedAt
          createdAt
          updatedAt
          tenant {
            name
            phoneNumber
            roomNumber
            bedLabel
          }
        }
      }
    ''';
    final data = await performQuery(query);
    return data['myComplaints'] ?? [];
  }

  static Future<List<dynamic>> fetchAdminComplaints({String? status}) async {
    const String query = '''
      query AdminComplaints(\$status: ComplaintStatus) {
        adminComplaints(status: \$status) {
          id
          tenantProfileId
          adminId
          category
          title
          description
          mediaUrl
          status
          adminReply
          repliedAt
          resolvedAt
          createdAt
          updatedAt
          tenant {
            name
            phoneNumber
            roomNumber
            bedLabel
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: status != null ? {'status': status} : {});
    return data['adminComplaints'] ?? [];
  }

  static Future<Map<String, dynamic>> createComplaint({
    required String category,
    required String title,
    required String description,
    String? mediaBase64,
  }) async {
    const String mutation = '''
      mutation CreateComplaint(\$input: CreateComplaintInput!) {
        createComplaint(input: \$input) {
          id
          tenantProfileId
          adminId
          category
          title
          description
          mediaUrl
          status
          createdAt
          tenant {
            name
            phoneNumber
            roomNumber
            bedLabel
          }
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        'category': category,
        'title': title,
        'description': description,
        if (mediaBase64 != null && mediaBase64.isNotEmpty) 'mediaBase64': mediaBase64,
      }
    });
    return data['createComplaint'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> replyComplaint({
    required String complaintId,
    required String reply,
    String? status,
  }) async {
    const String mutation = '''
      mutation ReplyComplaint(\$input: ReplyComplaintInput!) {
        replyComplaint(input: \$input) {
          id
          status
          adminReply
          repliedAt
          resolvedAt
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        'complaintId': complaintId,
        'reply': reply,
        if (status != null) 'status': status,
      }
    });
    return data['replyComplaint'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateComplaintStatus({
    required String complaintId,
    required String status,
  }) async {
    const String mutation = '''
      mutation UpdateComplaintStatus(\$input: UpdateComplaintStatusInput!) {
        updateComplaintStatus(input: \$input) {
          id
          status
          resolvedAt
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        'complaintId': complaintId,
        'status': status,
      }
    });
    return data['updateComplaintStatus'] as Map<String, dynamic>;
  }
}
