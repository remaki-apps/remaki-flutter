import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/env_config.dart';
import '../providers/network_provider.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  static String get _baseUrl => EnvConfig.apiUrl;
  static String get baseUrl => EnvConfig.apiUrl;
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
      final savedEnv = prefs.getString('auth_env');

      // On mobile devices (Android / iOS), app sandbox storage is isolated per package ID.
      // If a saved session exists, align EnvConfig with that session if not explicitly set by flavor.
      if (!kIsWeb && savedEnv != null) {
        if (savedEnv == 'qa' && EnvConfig.environment != Environment.qa) {
          EnvConfig.initialize(Environment.qa);
        } else if (savedEnv == 'prod' && EnvConfig.environment != Environment.prod) {
          EnvConfig.initialize(Environment.prod);
        }
      }

      final currentEnv = EnvConfig.environment.name;
      if (savedEnv != null && savedEnv != currentEnv) {
        // Environment switched (e.g. was QA, now Prod on same web origin)
        // Only clear cached token on web where origins might be shared across environments.
        if (kIsWeb) {
          await clearAuthToken();
        } else {
          _token = prefs.getString('auth_token');
          _role = prefs.getString('user_role');
          _hasSecurityPin = prefs.getBool('user_has_security_pin');
          authNotifier.value = isLoggedIn;
        }
      } else {
        _token = prefs.getString('auth_token');
        _role = prefs.getString('user_role');
        _hasSecurityPin = prefs.getBool('user_has_security_pin');
        authNotifier.value = isLoggedIn;
      }
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
        await prefs.setString('auth_env', EnvConfig.environment.name);
        await prefs.setString('auth_token', token);
        await prefs.setString('user_role', role);
        if (hasSecurityPin != null) {
          await prefs.setBool('user_has_security_pin', hasSecurityPin);
        }
      } else {
        await prefs.remove('auth_env');
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
      await prefs.remove('auth_env');
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
    if (lower.contains('unique constraint failed') || lower.contains('duplicate key')) {
      if (lower.contains('phone')) {
        return 'An account with this mobile number already exists. Each account must have a unique mobile number.';
      }
      if (lower.contains('email')) {
        return 'An account with this email address already exists. Please use a different email.';
      }
      return 'An account with these details already exists. Duplicate entries are not allowed.';
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
          .get(Uri.parse(EnvConfig.warmupUrl))
          .timeout(const Duration(seconds: 15))
          .then((_) {
            debugPrint('Render backend warmup ping acknowledged (${EnvConfig.appName}).');
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
            final code = (firstErr is Map && firstErr['extensions'] is Map)
                ? (firstErr['extensions']['code']?.toString().toUpperCase() ?? '')
                : '';
            final httpStatus = (firstErr is Map && firstErr['extensions'] is Map && firstErr['extensions']['http'] is Map)
                ? (firstErr['extensions']['http']['status']?.toString() ?? '')
                : '';

            final bool isAuthFailure = code == 'UNAUTHORIZED' ||
                code == 'UNAUTHENTICATED' ||
                httpStatus == '401' ||
                lower.contains('unauthorized') ||
                lower.contains('unauthenticated') ||
                lower.contains('jwt expired') ||
                lower.contains('invalid token') ||
                lower.contains('invalid credentials');

            if (isAuthFailure) {
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
            if (lower.contains('unauthorized') ||
                lower.contains('unauthenticated') ||
                lower.contains('jwt expired') ||
                lower.contains('invalid token')) {
              await clearAuthToken();
            }
            throw ApiException(cleanErrorMessage(extractedMsg));
          }
        }

        // 3. Status code routing
        if (response.statusCode == 200) {
          NetworkProvider.instance.setOffline(false);
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
          throw ApiException('Requested resource was not found.');
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
        NetworkProvider.instance.setOffline(true);
        throw ApiException('Unable to connect to server. Please check your internet connection.');
      } on http.ClientException catch (_) {
        if (attempts <= maxRetries) {
          debugPrint('ClientException on attempt $attempts, retrying in 2s...');
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        NetworkProvider.instance.setOffline(true);
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
          reminderDaysBeforeDue
          isReminderDue
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
          gender
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
          foodIncluded
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
          latestPaymentRequestStatus
          occupation
          dateOfBirth
          gender
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
          propertyId
          propertyName
          propertyUpiId
          propertyUpiPayeeName
        }
      }
    ''';
    try {
      final data = await performQuery(query);
      final profile = data['currentTenantProfile'] as Map<String, dynamic>?;
      if (profile == null) {
        debugPrint('[ApiService] currentTenantProfile is null. Clearing auth and logging out.');
        await clearAuthToken();
        return null;
      }
      return profile;
    } catch (e) {
      final errLower = e.toString().toLowerCase();
      if (errLower.contains('unauthorized') ||
          errLower.contains('unauthenticated') ||
          errLower.contains('not found') ||
          errLower.contains('invalid token') ||
          errLower.contains('jwt expired')) {
        await clearAuthToken();
        return null;
      }
      if (e.toString().contains('latestPaymentRequestStatus')) {
        debugPrint('Falling back to query without latestPaymentRequestStatus');
        try {
          const fallbackQuery = '''
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
                propertyId
                propertyName
                propertyUpiId
                propertyUpiPayeeName
              }
            }
          ''';
          final fallbackData = await performQuery(fallbackQuery);
          final fallbackProfile = fallbackData['currentTenantProfile'] as Map<String, dynamic>?;
          if (fallbackProfile == null) {
            debugPrint('[ApiService] Fallback currentTenantProfile is null. Clearing auth and logging out.');
            await clearAuthToken();
            return null;
          }
          return fallbackProfile;
        } catch (fallbackError) {
          final fbLower = fallbackError.toString().toLowerCase();
          if (fbLower.contains('unauthorized') ||
              fbLower.contains('unauthenticated') ||
              fbLower.contains('not found') ||
              fbLower.contains('invalid token') ||
              fbLower.contains('jwt expired')) {
            await clearAuthToken();
          }
          debugPrint('Error fetching current tenant profile on fallback: $fallbackError');
          return null;
        }
      }
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
          gender
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
          foodIncluded
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
            upiId
            upiPayeeName
            electricityCalculatorEnabled
            electricityCostPerUnit
            genderPolicy
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

  static Future<bool> updatePropertyUpi({
    required String propertyId,
    required String upiId,
    String? upiPayeeName,
  }) async {
    const mutation = '''
      mutation UpdateProperty(\$id: ID!, \$input: UpdatePropertyInput!) {
        updateProperty(id: \$id, input: \$input) {
          id
          upiId
          upiPayeeName
        }
      }
    ''';
    try {
      final res = await performQuery(mutation, variables: {
        'id': propertyId,
        'input': {
          'upiId': upiId,
          'upiPayeeName': upiPayeeName,
        },
      });
      return res['updateProperty'] != null;
    } catch (e) {
      debugPrint('Error updating property UPI: $e');
      rethrow;
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
          durationDays
          expiresAt
          targetPropertyIds
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
    String? imageUrl,
    int durationDays = 3,
    List<String>? propertyIds,
  }) async {
    const mutation = '''
      mutation CreateAnnouncement(\$heading: String!, \$description: String!, \$imageBase64: String, \$imageUrl: String, \$durationDays: Int, \$propertyIds: [ID!]) {
        createAnnouncement(heading: \$heading, description: \$description, imageBase64: \$imageBase64, imageUrl: \$imageUrl, durationDays: \$durationDays, propertyIds: \$propertyIds) {
          id
        }
      }
    ''';
    await performQuery(mutation, variables: {
      'heading': heading,
      'description': description,
      'imageBase64': imageBase64,
      'imageUrl': imageUrl,
      'durationDays': durationDays,
      if (propertyIds != null) 'propertyIds': propertyIds,
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
              platformFee
              rentAmount
              billAmount
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
              platformFee
              rentAmount
              billAmount
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
          foodOption
          monthlyRentWithFood
          monthlyRentWithoutFood
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

  static Future<String?> resetTenantPassword(String tenantId) async {
    const String query = '''
      mutation ResetTenantPassword(\$tenantId: ID!) {
        resetTenantPassword(tenantId: \$tenantId)
      }
    ''';
    final result = await performQuery(query, variables: {'tenantId': tenantId});
    return result['resetTenantPassword'] as String?;
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
          foodOption
          monthlyRentWithFood
          monthlyRentWithoutFood
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

  static Future<Map<String, dynamic>?> updateRoom(String id, Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdateRoom(\$id: ID!, \$input: UpdateRoomInput!) {
        updateRoom(id: \$id, input: \$input) {
          id
          roomNumber
          floorNumber
          capacity
          roomType
          foodOption
          monthlyRentWithFood
          monthlyRentWithoutFood
        }
      }
    ''';
    final result = await performQuery(mutation, variables: {'id': id, 'input': input});
    return result['updateRoom'] as Map<String, dynamic>?;
  }

  static Future<bool> deleteRoom(String id) async {
    const String mutation = '''
      mutation DeleteRoom(\$id: ID!) {
        deleteRoom(id: \$id)
      }
    ''';
    final result = await performQuery(mutation, variables: {'id': id});
    return result['deleteRoom'] == true;
  }

  static Future<Map<String, dynamic>?> addBed(String roomId, String label) async {
    const String mutation = '''
      mutation AddBed(\$roomId: ID!, \$label: String!) {
        addBed(roomId: \$roomId, label: \$label) {
          id
          roomId
          roomNumber
          bedLabel
          status
        }
      }
    ''';
    final result = await performQuery(mutation, variables: {'roomId': roomId, 'label': label});
    return result['addBed'] as Map<String, dynamic>?;
  }

  static Future<Map<String, dynamic>?> updateBed(String id, Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdateBed(\$id: ID!, \$input: UpdateBedInput!) {
        updateBed(id: \$id, input: \$input) {
          id
          roomId
          roomNumber
          bedLabel
          status
        }
      }
    ''';
    final result = await performQuery(mutation, variables: {'id': id, 'input': input});
    return result['updateBed'] as Map<String, dynamic>?;
  }

  static Future<bool> deleteBed(String id) async {
    const String mutation = '''
      mutation DeleteBed(\$id: ID!) {
        deleteBed(id: \$id)
      }
    ''';
    final result = await performQuery(mutation, variables: {'id': id});
    return result['deleteBed'] == true;
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
    bool? foodIncluded,
    String? moveInDate,
  }) async {
    const String mutation = '''
      mutation UpdateTenantFinancials(\$tenantId: ID!, \$rentAmount: Float, \$securityDeposit: Float, \$rentDueDay: Int, \$paymentMode: String, \$foodIncluded: Boolean, \$moveInDate: String) {
        updateTenantFinancials(tenantId: \$tenantId, rentAmount: \$rentAmount, securityDeposit: \$securityDeposit, rentDueDay: \$rentDueDay, paymentMode: \$paymentMode, foodIncluded: \$foodIncluded, moveInDate: \$moveInDate) {
          id
          monthlyRent
          pendingRentAmount
          rentDueDate
          securityDeposit
          moveInDate
          paymentStatus
          foodIncluded
        }
      }
    ''';
    await performQuery(mutation, variables: {
      'tenantId': tenantId,
      'rentAmount': rentAmount,
      'securityDeposit': securityDeposit,
      'rentDueDay': rentDueDay,
      'paymentMode': paymentMode,
      'foodIncluded': foodIncluded,
      'moveInDate': moveInDate,
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

  static Future<String> fetchPaymentRequestProof(String requestId) async {
    const String query = '''
      query GetPaymentProof(\$id: ID!) {
        paymentRequestProof(id: \$id)
      }
    ''';
    try {
      final data = await performQuery(query, variables: {'id': requestId});
      return data['paymentRequestProof']?.toString() ?? '';
    } catch (e) {
      debugPrint('Error fetching payment proof: \$e');
      return '';
    }
  }

  static Future<int> fetchPendingApprovalsCount({String? propertyId}) async {
    const String query = '''
      query GetPendingApprovalsCount(\$propertyId: ID) {
        pendingPaymentRequestsCount(propertyId: \$propertyId)
      }
    ''';
    try {
      final data = await performQuery(query, variables: {'propertyId': propertyId});
      return (data['pendingPaymentRequestsCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error fetching pending approvals count: \$e');
      return 0;
    }
  }

  static Future<int> fetchPendingComplaintsCount() async {
    const String query = '''
      query {
        pendingComplaintsCount
      }
    ''';
    try {
      final data = await performQuery(query);
      return (data['pendingComplaintsCount'] as num?)?.toInt() ?? 0;
    } catch (e) {
      debugPrint('Error fetching pending complaints count: \$e');
      return 0;
    }
  }

  static Future<Map<String, dynamic>> getPresignedUploadUrl({
    String folder = 'receipts',
    required String fileName,
    required String contentType,
  }) async {
    const String mutation = '''
      mutation GetPresignedUploadUrl(\$folder: String, \$fileName: String!, \$contentType: String!) {
        getPresignedUploadUrl(folder: \$folder, fileName: \$fileName, contentType: \$contentType) {
          uploadUrl
          publicUrl
          key
          expiresInSeconds
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'folder': folder,
      'fileName': fileName,
      'contentType': contentType,
    });
    return (data['getPresignedUploadUrl'] as Map<String, dynamic>?) ?? {};
  }

  static Future<bool> uploadBytesToR2(String uploadUrl, Uint8List bytes, String contentType) async {
    try {
      final uri = Uri.parse(uploadUrl);
      final response = await http.put(
        uri,
        headers: {'Content-Type': contentType},
        body: bytes,
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('[ApiService] Failed to upload direct to R2: \$e');
      return false;
    }
  }

  static Future<List<dynamic>> fetchPendingPaymentRequests({String? propertyId}) async {
    const String query = '''
      query GetPendingPayments(\$propertyId: ID) {
        pendingPaymentRequests(propertyId: \$propertyId) {
          id
          tenantProfileId
          tenantName
          amount
          paymentType
          method
          imageUrl
          proofImageBase64
          hasProofImage
          description
          status
          createdAt
        }
      }
    ''';
    final data = await performQuery(query, variables: {'propertyId': propertyId});
    return data['pendingPaymentRequests'] ?? [];
  }

  static Future<List<dynamic>> fetchApprovalHistory({int limit = 100, int offset = 0, String? propertyId}) async {
    const String query = '''
      query GetApprovalHistory(\$limit: Int, \$offset: Int, \$propertyId: ID) {
        approvalHistory(limit: \$limit, offset: \$offset, propertyId: \$propertyId) {
          id
          tenantProfileId
          tenantName
          roomNumber
          bedLabel
          amount
          paymentType
          method
          imageUrl
          hasProofImage
          description
          status
          rejectionReason
          createdAt
          updatedAt
        }
      }
    ''';
    final data = await performQuery(query, variables: {'limit': limit, 'offset': offset, 'propertyId': propertyId});
    return data['approvalHistory'] ?? [];
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
    String? category,
    required String title,
    String? description,
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
        'category': (category != null && category.trim().isNotEmpty) ? category.trim() : 'OTHER',
        'title': title.trim(),
        'description': (description != null) ? description.trim() : '',
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

  static Future<Map<String, dynamic>> fetchPropertyPlatformFeeSummary({
    String? propertyId,
    String? month,
  }) async {
    const String query = '''
      query PropertyPlatformFeeSummary(\$propertyId: ID, \$month: String) {
        propertyPlatformFeeSummary(propertyId: \$propertyId, month: \$month) {
          propertyId
          propertyName
          billingMonth
          monthlyPlatformFeeCollected
          platformFeePaid
          feePerTenant
          totalTenantsContributed
          resetsOn
          organizationUpiId
          organizationPayeeName
          availableMonths
          items {
            id
            tenantName
            tenantPhone
            roomNumber
            bedLabel
            amount
            month
            status
            date
          }
          settlements {
            id
            propertyId
            adminId
            billingMonth
            amountPaid
            paymentMode
            referenceId
            notes
            paidAt
            recordedBy
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {
      if (propertyId != null) 'propertyId': propertyId,
      if (month != null) 'month': month,
    });
    return data['propertyPlatformFeeSummary'] as Map<String, dynamic>;
  }

  // ==========================================
  // ORGANIZATION MANAGEMENT APIS
  // ==========================================

  static Future<Map<String, dynamic>> fetchMyOrganization() async {
    const String query = '''
      query MyOrganization {
        myOrganization {
          id
          name
          code
          email
          phoneNumber
          address
          city
          state
          pincode
          logoUrl
          isActive
          createdAt
          updatedAt
        }
      }
    ''';
    final data = await performQuery(query);
    return data['myOrganization'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> fetchOrganizationDashboard() async {
    const String query = '''
      query OrganizationDashboard {
        organizationDashboard {
          totalAdmins
          activeAdmins
          inactiveAdmins
          totalProperties
          totalRooms
          totalOccupiedBeds
          totalAvailableBeds
          totalTenants
          totalRentExpected
          totalRentCollected
          totalRentPending
        }
      }
    ''';
    final data = await performQuery(query);
    return data['organizationDashboard'] as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchOrganizationAdmins({
    String? search,
    bool? isActive,
  }) async {
    const String query = '''
      query OrganizationAdmins(\$search: String, \$isActive: Boolean) {
        organizationAdmins(search: \$search, isActive: \$isActive) {
          id
          displayName
          phoneNumber
          email
          adminCode
          isActive
          createdAt
          lastLoginAt
          propertyCount
          propertyNames
          totalRooms
          totalBeds
          occupiedBeds
          availableBeds
          totalTenants
          rentCollected
          rentPending
        }
      }
    ''';
    final data = await performQuery(query, variables: {
      if (search != null) 'search': search,
      if (isActive != null) 'isActive': isActive,
    });
    return data['organizationAdmins'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> fetchOrganizationAdminDetails(String adminId) async {
    const String query = '''
      query OrganizationAdminDetails(\$adminId: ID!) {
        organizationAdminDetails(adminId: \$adminId) {
          id
          displayName
          phoneNumber
          email
          adminCode
          isActive
          createdAt
          lastLoginAt
          propertyCount
          propertyNames
          totalRooms
          totalBeds
          occupiedBeds
          availableBeds
          totalTenants
          rentCollected
          rentPending
        }
      }
    ''';
    final data = await performQuery(query, variables: {'adminId': adminId});
    return data['organizationAdminDetails'] as Map<String, dynamic>;
  }

  static const String _orgPropertyFields = '''
    id
    name
    description
    address
    city
    state
    pincode
    totalFloors
    isActive
    adminId
    adminName
    adminCode
    upiId
    upiPayeeName
    platformFee
    platformFeeUpiId
    platformFeePayeeName
    monthlyPlatformFeeCollected
    platformFeePaid
    platformFeeBillingMonth
    totalRooms
    totalBeds
    occupiedBeds
    availableBeds
    totalTenants
    coOwnersCount
    electricityCalculatorEnabled
    electricityCostPerUnit
    genderPolicy
  ''';

  static Future<List<dynamic>> fetchOrganizationProperties() async {
    const String query = '''
      query OrganizationProperties {
        organizationProperties {
          $_orgPropertyFields
        }
      }
    ''';
    final data = await performQuery(query);
    return data['organizationProperties'] as List<dynamic>;
  }

  static Future<bool> changeAdminPasswordUnderOrg(String adminId, String newPassword) async {
    const String mutation = '''
      mutation ChangeAdminPasswordUnderOrg(\$adminId: ID!, \$newPassword: String!) {
        changeAdminPasswordUnderOrg(adminId: \$adminId, newPassword: \$newPassword)
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'adminId': adminId,
      'newPassword': newPassword,
    });
    return data['changeAdminPasswordUnderOrg'] == true;
  }

  static Future<Map<String, dynamic>> fetchAdminDeletionPreview(String adminId) async {
    const String query = '''
      query AdminDeletionPreviewUnderOrg(\$adminId: ID!) {
        adminDeletionPreviewUnderOrg(adminId: \$adminId) {
          propertiesCount
          roomsCount
          bedsCount
          tenantsCount
          coOwnersCount
          paymentsCount
        }
      }
    ''';
    final data = await performQuery(query, variables: {'adminId': adminId});
    return data['adminDeletionPreviewUnderOrg'] as Map<String, dynamic>;
  }

  static Future<bool> deleteAdminStepwiseUnderOrg(String adminId, String step) async {
    const String mutation = '''
      mutation DeleteAdminStepwiseUnderOrg(\$adminId: ID!, \$step: String!) {
        deleteAdminStepwiseUnderOrg(adminId: \$adminId, step: \$step)
      }
    ''';
    final data = await performQuery(mutation, variables: {'adminId': adminId, 'step': step});
    return data['deleteAdminStepwiseUnderOrg'] == true;
  }

  static Future<Map<String, dynamic>> createPropertyUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation CreatePropertyUnderOrg(\$input: CreatePropertyUnderOrgInput!) {
        createPropertyUnderOrg(input: \$input) {
          $_orgPropertyFields
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['createPropertyUnderOrg'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updatePropertyUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdatePropertyUnderOrg(\$input: UpdatePropertyUnderOrgInput!) {
        updatePropertyUnderOrg(input: \$input) {
          $_orgPropertyFields
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updatePropertyUnderOrg'] as Map<String, dynamic>;
  }

  static Future<bool> deletePropertyUnderOrg(String propertyId) async {
    const String mutation = '''
      mutation DeletePropertyUnderOrg(\$propertyId: ID!) {
        deletePropertyUnderOrg(propertyId: \$propertyId)
      }
    ''';
    final data = await performQuery(mutation, variables: {'propertyId': propertyId});
    return data['deletePropertyUnderOrg'] == true;
  }

  static Future<Map<String, dynamic>> fetchPropertyDeletionPreview(String propertyId) async {
    const String query = '''
      query PropertyDeletionPreviewUnderOrg(\$propertyId: ID!) {
        propertyDeletionPreviewUnderOrg(propertyId: \$propertyId) {
          propertiesCount
          roomsCount
          bedsCount
          tenantsCount
          coOwnersCount
          paymentsCount
        }
      }
    ''';
    final data = await performQuery(query, variables: {'propertyId': propertyId});
    return data['propertyDeletionPreviewUnderOrg'] as Map<String, dynamic>;
  }

  static Future<bool> deletePropertyStepwiseUnderOrg(String propertyId, String step) async {
    const String mutation = '''
      mutation DeletePropertyStepwiseUnderOrg(\$propertyId: ID!, \$step: String!) {
        deletePropertyStepwiseUnderOrg(propertyId: \$propertyId, step: \$step)
      }
    ''';
    final data = await performQuery(mutation, variables: {'propertyId': propertyId, 'step': step});
    return data['deletePropertyStepwiseUnderOrg'] == true;
  }

  static Future<List<dynamic>> fetchOrganizationPropertyOwners(String propertyId) async {
    const String query = '''
      query OrganizationPropertyOwners(\$propertyId: ID!) {
        organizationPropertyOwners(propertyId: \$propertyId) {
          id
          userId
          propertyId
          name
          phoneNumber
          email
          role
          isPrimary
          isActive
        }
      }
    ''';
    final data = await performQuery(query, variables: {'propertyId': propertyId});
    return data['organizationPropertyOwners'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> addPropertyOwnerUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation AddPropertyOwnerUnderOrg(\$input: AddPropertyOwnerUnderOrgInput!) {
        addPropertyOwnerUnderOrg(input: \$input) {
          id
          userId
          propertyId
          name
          phoneNumber
          email
          role
          isPrimary
          isActive
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['addPropertyOwnerUnderOrg'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updatePropertyOwnerUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdatePropertyOwnerUnderOrg(\$input: UpdatePropertyOwnerUnderOrgInput!) {
        updatePropertyOwnerUnderOrg(input: \$input) {
          id
          userId
          propertyId
          name
          phoneNumber
          email
          role
          isPrimary
          isActive
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updatePropertyOwnerUnderOrg'] as Map<String, dynamic>;
  }

  static Future<bool> deletePropertyOwnerUnderOrg(String ownerId) async {
    const String mutation = '''
      mutation DeletePropertyOwnerUnderOrg(\$ownerId: ID!) {
        deletePropertyOwnerUnderOrg(ownerId: \$ownerId)
      }
    ''';
    final data = await performQuery(mutation, variables: {'ownerId': ownerId});
    return data['deletePropertyOwnerUnderOrg'] == true;
  }

  static Future<List<dynamic>> fetchOrganizationPropertyRooms(String propertyId) async {
    const String query = '''
      query OrganizationPropertyRooms(\$propertyId: ID!) {
        organizationPropertyRooms(propertyId: \$propertyId) {
          id
          propertyId
          roomNumber
          floorNumber
          capacity
          roomType
          foodOption
          monthlyRentWithFood
          monthlyRentWithoutFood
          status
          occupiedBeds
          availableBeds
          beds {
            id
            roomId
            bedLabel
            status
            tenantName
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {'propertyId': propertyId});
    return data['organizationPropertyRooms'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> createRoomUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation CreateRoomUnderOrg(\$input: CreateRoomUnderOrgInput!) {
        createRoomUnderOrg(input: \$input) {
          id
          propertyId
          roomNumber
          floorNumber
          capacity
          roomType
          foodOption
          monthlyRentWithFood
          monthlyRentWithoutFood
          status
          occupiedBeds
          availableBeds
          beds {
            id
            roomId
            bedLabel
            status
            tenantName
          }
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['createRoomUnderOrg'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateRoomUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdateRoomUnderOrg(\$input: UpdateRoomUnderOrgInput!) {
        updateRoomUnderOrg(input: \$input) {
          id
          propertyId
          roomNumber
          floorNumber
          capacity
          roomType
          foodOption
          monthlyRentWithFood
          monthlyRentWithoutFood
          status
          occupiedBeds
          availableBeds
          beds {
            id
            roomId
            bedLabel
            status
            tenantName
          }
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updateRoomUnderOrg'] as Map<String, dynamic>;
  }

  static Future<bool> deleteRoomUnderOrg(String roomId) async {
    const String mutation = '''
      mutation DeleteRoomUnderOrg(\$roomId: ID!) {
        deleteRoomUnderOrg(roomId: \$roomId)
      }
    ''';
    final data = await performQuery(mutation, variables: {'roomId': roomId});
    return data['deleteRoomUnderOrg'] == true;
  }

  static Future<Map<String, dynamic>> addBedUnderOrg(String roomId, String bedLabel) async {
    const String mutation = '''
      mutation AddBedUnderOrg(\$roomId: ID!, \$bedLabel: String!) {
        addBedUnderOrg(roomId: \$roomId, bedLabel: \$bedLabel) {
          id
          roomId
          bedLabel
          status
          tenantName
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'roomId': roomId, 'bedLabel': bedLabel});
    return data['addBedUnderOrg'] as Map<String, dynamic>;
  }

  static Future<bool> deleteBedUnderOrg(String bedId) async {
    const String mutation = '''
      mutation DeleteBedUnderOrg(\$bedId: ID!) {
        deleteBedUnderOrg(bedId: \$bedId)
      }
    ''';
    final data = await performQuery(mutation, variables: {'bedId': bedId});
    return data['deleteBedUnderOrg'] == true;
  }

  static Future<List<dynamic>> fetchOrganizationPlatformFeeOverview({String? billingMonth}) async {
    const String query = '''
      query OrganizationPlatformFeeOverview(\$billingMonth: String) {
        organizationPlatformFeeOverview(billingMonth: \$billingMonth) {
          propertyId
          propertyName
          adminId
          adminName
          adminCode
          billingMonth
          feePerTenant
          platformFeeUpiId
          platformFeePayeeName
          totalCollected
          totalSettled
          pendingAmount
          tenantsContributed
          availableMonths
          settlements {
            id
            propertyId
            adminId
            billingMonth
            amountPaid
            paymentMode
            referenceId
            notes
            paidAt
            recordedBy
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {
      if (billingMonth != null) 'billingMonth': billingMonth,
    });
    return data['organizationPlatformFeeOverview'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> markPlatformFeePaidUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation MarkPlatformFeePaidUnderOrg(\$input: MarkPlatformFeePaidUnderOrgInput!) {
        markPlatformFeePaidUnderOrg(input: \$input) {
          id
          propertyId
          adminId
          billingMonth
          amountPaid
          paymentMode
          referenceId
          notes
          paidAt
          recordedBy
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['markPlatformFeePaidUnderOrg'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updatePlatformFeeSettlementUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdatePlatformFeeSettlementUnderOrg(\$input: UpdatePlatformFeeSettlementUnderOrgInput!) {
        updatePlatformFeeSettlementUnderOrg(input: \$input) {
          id
          propertyId
          adminId
          billingMonth
          amountPaid
          paymentMode
          referenceId
          notes
          paidAt
          recordedBy
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updatePlatformFeeSettlementUnderOrg'] as Map<String, dynamic>;
  }

  static Future<bool> deletePlatformFeeSettlementUnderOrg(String settlementId) async {
    const String mutation = '''
      mutation DeletePlatformFeeSettlementUnderOrg(\$settlementId: ID!) {
        deletePlatformFeeSettlementUnderOrg(settlementId: \$settlementId)
      }
    ''';
    final data = await performQuery(mutation, variables: {'settlementId': settlementId});
    return data['deletePlatformFeeSettlementUnderOrg'] == true;
  }

  static Future<Map<String, dynamic>> createAdminUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation CreateAdminUnderOrg(\$input: CreateAdminUnderOrgInput!) {
        createAdminUnderOrg(input: \$input) {
          admin {
            id
            displayName
            phoneNumber
            email
            adminCode
            isActive
            createdAt
            lastLoginAt
            propertyCount
            propertyNames
            totalRooms
            totalBeds
            occupiedBeds
            availableBeds
            totalTenants
            rentCollected
            rentPending
          }
          tempPassword
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['createAdminUnderOrg'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateAdminUnderOrg(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdateAdminUnderOrg(\$input: UpdateAdminUnderOrgInput!) {
        updateAdminUnderOrg(input: \$input) {
          id
          displayName
          phoneNumber
          email
          adminCode
          isActive
          createdAt
          lastLoginAt
          propertyCount
          propertyNames
          totalRooms
          totalBeds
          occupiedBeds
          availableBeds
          totalTenants
          rentCollected
          rentPending
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updateAdminUnderOrg'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> toggleAdminStatus(String adminId, bool isActive) async {
    const String mutation = '''
      mutation ToggleAdminStatus(\$adminId: ID!, \$isActive: Boolean!) {
        toggleAdminStatus(adminId: \$adminId, isActive: \$isActive) {
          id
          displayName
          phoneNumber
          email
          adminCode
          isActive
          createdAt
          lastLoginAt
          propertyCount
          propertyNames
          totalRooms
          totalBeds
          occupiedBeds
          availableBeds
          totalTenants
          rentCollected
          rentPending
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'adminId': adminId,
      'isActive': isActive,
    });
    return data['toggleAdminStatus'] as Map<String, dynamic>;
  }

  static Future<bool> deleteAdminUnderOrg(String adminId) async {
    const String mutation = '''
      mutation DeleteAdminUnderOrg(\$adminId: ID!) {
        deleteAdminUnderOrg(adminId: \$adminId)
      }
    ''';
    final data = await performQuery(mutation, variables: {'adminId': adminId});
    return data['deleteAdminUnderOrg'] == true;
  }

  static Future<Map<String, dynamic>> updateMyOrganization(Map<String, dynamic> input) async {
    const String mutation = '''
      mutation UpdateMyOrganization(\$input: UpdateOrganizationProfileInput!) {
        updateMyOrganization(input: \$input) {
          id
          name
          code
          email
          phoneNumber
          address
          city
          state
          pincode
          logoUrl
          isActive
          createdAt
          updatedAt
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updateMyOrganization'] as Map<String, dynamic>;
  }

  // ----------------------------------------------------
  // Push Notification & Reminder Settings API Methods
  // ----------------------------------------------------

  static Future<bool> registerDeviceToken(String token, String platform) async {
    const String mutation = '''
      mutation RegisterDeviceToken(\$input: RegisterDeviceTokenInput!) {
        registerDeviceToken(input: \$input)
      }
    ''';
    try {
      final res = await performQuery(mutation, variables: {
        'input': {
          'token': token,
          'platform': platform,
        }
      });
      return res['registerDeviceToken'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> unregisterDeviceToken(String token) async {
    const String mutation = '''
      mutation UnregisterDeviceToken(\$token: String!) {
        unregisterDeviceToken(token: \$token)
      }
    ''';
    try {
      final res = await performQuery(mutation, variables: {'token': token});
      return res['unregisterDeviceToken'] == true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, dynamic>?> fetchReminderSettings({String? propertyId}) async {
    const String query = '''
      query ReminderSettings(\$propertyId: String) {
        reminderSettings(propertyId: \$propertyId) {
          adminDefault
          propertyOverride
          effectiveThreshold
        }
      }
    ''';
    try {
      final res = await performQuery(query, variables: {'propertyId': propertyId});
      return res['reminderSettings'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateReminderSettings({
    String? propertyId,
    required int reminderDaysBeforeDue,
  }) async {
    const String mutation = '''
      mutation UpdateReminderSettings(\$input: UpdateReminderSettingsInput!) {
        updateReminderSettings(input: \$input) {
          adminDefault
          propertyOverride
          effectiveThreshold
        }
      }
    ''';
    try {
      final res = await performQuery(mutation, variables: {
        'input': {
          'propertyId': propertyId,
          'reminderDaysBeforeDue': reminderDaysBeforeDue,
        }
      });
      return res['updateReminderSettings'] as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  // ==================== ELECTRICITY CALCULATOR ====================

  static Future<Map<String, dynamic>> fetchElectricityConfig({String? propertyId}) async {
    const String query = '''
      query ElectricityConfig(\$propertyId: ID) {
        electricityConfig(propertyId: \$propertyId) {
          propertyId
          propertyName
          electricityCalculatorEnabled
          costPerUnit
          sharedRoomIds
          latestReading
          latestBillingMonth
          rooms {
            id
            roomNumber
            floorNumber
            activeTenantCount
            isSelected
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {'propertyId': propertyId});
    return data['electricityConfig'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateElectricityConfig({
    String? propertyId,
    required double costPerUnit,
    required List<String> sharedRoomIds,
  }) async {
    const String mutation = '''
      mutation UpdateElectricityConfig(\$input: UpdateElectricityConfigInput!) {
        updateElectricityConfig(input: \$input) {
          propertyId
          propertyName
          electricityCalculatorEnabled
          costPerUnit
          sharedRoomIds
          latestReading
          latestBillingMonth
          rooms {
            id
            roomNumber
            floorNumber
            activeTenantCount
            isSelected
          }
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        'propertyId': propertyId,
        'costPerUnit': costPerUnit,
        'sharedRoomIds': sharedRoomIds,
      }
    });
    return data['updateElectricityConfig'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> previewElectricitySplit({
    String? propertyId,
    required String billingMonth,
    double? previousReading,
    required double currentReading,
    double? costPerUnitOverride,
    required List<String> selectedRoomIds,
  }) async {
    const String query = '''
      query PreviewElectricitySplit(\$input: PreviewElectricitySplitInput!) {
        previewElectricitySplit(input: \$input) {
          propertyId
          billingMonth
          previousReading
          currentReading
          unitsConsumed
          costPerUnit
          totalAmount
          eligibleTenantCount
          selectedRoomCount
          shares {
            tenantId
            tenantName
            roomId
            roomNumber
            bedLabel
            shareAmount
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {
      'input': {
        'propertyId': propertyId,
        'billingMonth': billingMonth,
        if (previousReading != null) 'previousReading': previousReading,
        'currentReading': currentReading,
        if (costPerUnitOverride != null) 'costPerUnitOverride': costPerUnitOverride,
        'selectedRoomIds': selectedRoomIds,
      }
    });
    return data['previewElectricitySplit'] as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchElectricityGroups({String? propertyId}) async {
    const String query = '''
      query ElectricityGroups(\$propertyId: ID) {
        electricityGroups(propertyId: \$propertyId) {
          id
          propertyId
          name
          costPerUnitOverride
          propertyDefaultCostPerUnit
          effectiveCostPerUnit
          lastMeterReading
          activeTenantCount
          createdAt
          updatedAt
          rooms {
            id
            roomId
            roomNumber
            floorNumber
            activeTenantCount
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {'propertyId': propertyId});
    return data['electricityGroups'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> fetchRoomElectricityContext(String roomId) async {
    const String query = '''
      query RoomElectricityContext(\$roomId: ID!) {
        roomElectricityContext(roomId: \$roomId) {
          roomId
          roomNumber
          propertyId
          inGroup
          lastReading
          costPerUnitOverride
          propertyDefaultCostPerUnit
          effectiveCostPerUnit
          group {
            id
            propertyId
            name
            costPerUnitOverride
            propertyDefaultCostPerUnit
            effectiveCostPerUnit
            lastMeterReading
            activeTenantCount
            createdAt
            updatedAt
            rooms {
              id
              roomId
              roomNumber
              floorNumber
              activeTenantCount
            }
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {'roomId': roomId});
    return data['roomElectricityContext'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createElectricityGroup({
    String? propertyId,
    required String name,
    required List<String> roomIds,
    double? costPerUnitOverride,
  }) async {
    const String mutation = '''
      mutation CreateElectricityGroup(\$input: CreateElectricityGroupInput!) {
        createElectricityGroup(input: \$input) {
          id
          propertyId
          name
          costPerUnitOverride
          propertyDefaultCostPerUnit
          effectiveCostPerUnit
          lastMeterReading
          activeTenantCount
          createdAt
          updatedAt
          rooms {
            id
            roomId
            roomNumber
            floorNumber
            activeTenantCount
          }
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        if (propertyId != null) 'propertyId': propertyId,
        'name': name,
        'roomIds': roomIds,
        if (costPerUnitOverride != null) 'costPerUnitOverride': costPerUnitOverride,
      }
    });
    return data['createElectricityGroup'] as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateElectricityGroup({
    required String groupId,
    String? name,
    List<String>? roomIds,
    double? costPerUnitOverride,
    bool updateCostOverride = false,
  }) async {
    const String mutation = '''
      mutation UpdateElectricityGroup(\$input: UpdateElectricityGroupInput!) {
        updateElectricityGroup(input: \$input) {
          id
          propertyId
          name
          costPerUnitOverride
          propertyDefaultCostPerUnit
          effectiveCostPerUnit
          lastMeterReading
          activeTenantCount
          createdAt
          updatedAt
          rooms {
            id
            roomId
            roomNumber
            floorNumber
            activeTenantCount
          }
        }
      }
    ''';
    final Map<String, dynamic> input = {'groupId': groupId};
    if (name != null) input['name'] = name;
    if (roomIds != null) input['roomIds'] = roomIds;
    if (updateCostOverride || costPerUnitOverride != null) {
      input['costPerUnitOverride'] = costPerUnitOverride;
    }
    final data = await performQuery(mutation, variables: {'input': input});
    return data['updateElectricityGroup'] as Map<String, dynamic>;
  }

  static Future<bool> deleteElectricityGroup(String groupId) async {
    const String mutation = '''
      mutation DeleteElectricityGroup(\$groupId: ID!) {
        deleteElectricityGroup(groupId: \$groupId)
      }
    ''';
    final data = await performQuery(mutation, variables: {'groupId': groupId});
    return data['deleteElectricityGroup'] == true;
  }

  static Future<Map<String, dynamic>> updateElectricityRoomRate({
    required String roomId,
    double? costPerUnitOverride,
  }) async {
    const String mutation = '''
      mutation UpdateElectricityRoomRate(\$roomId: ID!, \$costPerUnitOverride: Float) {
        updateElectricityRoomRate(roomId: \$roomId, costPerUnitOverride: \$costPerUnitOverride) {
          roomId
          roomNumber
          propertyId
          inGroup
          lastReading
          costPerUnitOverride
          propertyDefaultCostPerUnit
          effectiveCostPerUnit
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'roomId': roomId,
      'costPerUnitOverride': costPerUnitOverride,
    });
    return data['updateElectricityRoomRate'] as Map<String, dynamic>;
  }

  static Future<double> updatePropertyElectricityRate({
    String? propertyId,
    required double costPerUnit,
  }) async {
    const String mutation = '''
      mutation UpdatePropertyElectricityRate(\$propertyId: ID, \$costPerUnit: Float!) {
        updatePropertyElectricityRate(propertyId: \$propertyId, costPerUnit: \$costPerUnit)
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'propertyId': propertyId,
      'costPerUnit': costPerUnit,
    });
    return (data['updatePropertyElectricityRate'] as num).toDouble();
  }

  static Future<Map<String, dynamic>> generateElectricityBills({
    String? propertyId,
    required String billingMonth,
    String scopeType = 'PROPERTY',
    String? roomId,
    String? groupId,
    double? previousReading,
    required double currentReading,
    double? costPerUnitOverride,
    List<String>? selectedRoomIds,
    List<String>? selectedTenantIds,
    String splitMode = 'EQUAL',
    List<Map<String, dynamic>>? customSplits,
    String? description,
    String? dueDate,
  }) async {
    const String mutation = '''
      mutation GenerateElectricityBills(\$input: GenerateElectricityBillsInput!) {
        generateElectricityBills(input: \$input) {
          id
          propertyId
          billingMonth
          scopeType
          roomId
          groupId
          groupNameSnapshot
          splitMode
          description
          previousReading
          currentReading
          unitsConsumed
          costPerUnit
          totalAmount
          selectedRoomIds
          status
          generatedBy
          generatedAt
          shares {
            id
            tenantId
            tenantName
            roomId
            roomNumber
            bedLabel
            shareAmount
            billId
            billStatus
          }
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {
      'input': {
        if (propertyId != null) 'propertyId': propertyId,
        'billingMonth': billingMonth,
        'scopeType': scopeType,
        if (roomId != null) 'roomId': roomId,
        if (groupId != null) 'groupId': groupId,
        if (previousReading != null) 'previousReading': previousReading,
        'currentReading': currentReading,
        if (costPerUnitOverride != null) 'costPerUnitOverride': costPerUnitOverride,
        if (selectedRoomIds != null) 'selectedRoomIds': selectedRoomIds,
        if (selectedTenantIds != null) 'selectedTenantIds': selectedTenantIds,
        'splitMode': splitMode,
        if (customSplits != null) 'customSplits': customSplits,
        if (description != null) 'description': description,
        if (dueDate != null) 'dueDate': dueDate,
      }
    });
    return data['generateElectricityBills'] as Map<String, dynamic>;
  }

  static Future<List<dynamic>> fetchElectricityCycles({String? propertyId}) async {
    const String query = '''
      query ElectricityCycles(\$propertyId: ID) {
        electricityCycles(propertyId: \$propertyId) {
          id
          propertyId
          billingMonth
          scopeType
          roomId
          groupId
          groupNameSnapshot
          splitMode
          description
          previousReading
          currentReading
          unitsConsumed
          costPerUnit
          totalAmount
          selectedRoomIds
          status
          generatedBy
          generatedAt
          voidedAt
          voidedBy
          shares {
            id
            tenantId
            tenantName
            roomId
            roomNumber
            bedLabel
            shareAmount
            billId
            billStatus
          }
        }
      }
    ''';
    final data = await performQuery(query, variables: {'propertyId': propertyId});
    return data['electricityCycles'] as List<dynamic>;
  }

  static Future<Map<String, dynamic>> voidLatestElectricityCycle(String cycleId) async {
    const String mutation = '''
      mutation VoidLatestElectricityCycle(\$cycleId: ID!) {
        voidLatestElectricityCycle(cycleId: \$cycleId) {
          id
          status
          voidedAt
          voidedBy
        }
      }
    ''';
    final data = await performQuery(mutation, variables: {'cycleId': cycleId});
    return data['voidLatestElectricityCycle'] as Map<String, dynamic>;
  }
}
