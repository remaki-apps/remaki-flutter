import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AppProvider with ChangeNotifier {
  List<Room> rooms = [];
  List<Tenant> tenants = [];
  List<Payment> payments = [];

  // Admin/PG identity — fetched from backend, replaces hardcoded strings
  String pgName = 'Your PG';
  String adminName = 'Admin';
  String pgAddress = '';
  bool isLoading = true;

  static const String _roomsKey = 'sunshine_pg_rooms';
  static const String _tenantsKey = 'sunshine_pg_tenants';
  static const String _paymentsKey = 'sunshine_pg_payments';

  AppProvider() {
    loadFromAPI();
  }

  Future<void> loadFromAPI({bool showLoading = true}) async {
    if (showLoading && rooms.isEmpty && tenants.isEmpty) {
      isLoading = true;
      notifyListeners();
    }
    try {
      final tenantsData = await ApiService.fetchTenants();
      final roomsData = await ApiService.fetchRooms();
      final paymentsData = await ApiService.fetchPayments();

      // Fetch admin profile for dynamic PG name (only if logged in as ADMIN)
      if (ApiService.role == 'ADMIN') {
        final adminData = await ApiService.fetchAdminProfile();
        if (adminData != null) {
          pgName = adminData['pgName'] ?? 'Your PG';
          adminName = adminData['adminName'] ?? 'Admin';
          pgAddress = adminData['pgAddress'] ?? '';
        }
      }
      
      rooms = roomsData.whereType<Map<String, dynamic>>().map((e) {
        final rawBeds = (e['beds'] as List<dynamic>?) ?? [];
        return Room(
          id: e['id']?.toString() ?? '',
          number: e['roomNumber']?.toString() ?? '',
          floor: e['floorNumber']?.toString() ?? 'Ground Floor',
          capacity: (e['capacity'] as num?)?.toInt() ?? rawBeds.length,
          beds: rawBeds.whereType<Map<String, dynamic>>().map((b) => Bed(
            id: b['id']?.toString() ?? '',
            name: b['bedLabel']?.toString() ?? 'Bed',
            isAvailable: b['status'] == 'AVAILABLE' || b['status'] == 'VACANT',
          )).toList(),
        );
      }).toList();

      tenants = tenantsData.whereType<Map<String, dynamic>>().map((e) {
        final roomMap = e['room'] as Map<String, dynamic>?;
        final bedMap = e['bed'] as Map<String, dynamic>?;
        final billsList = (e['bills'] as List<dynamic>?) ?? [];
        final monthlyRent = (e['monthlyRent'] as num?)?.toDouble() ?? 0.0;
        final pendingRent = (e['pendingRentAmount'] as num?)?.toDouble() ?? monthlyRent;

        return Tenant(
          id: e['id']?.toString() ?? '',
          name: e['name']?.toString() ?? 'Tenant',
          phone: e['phone']?.toString() ?? '',
          email: e['email']?.toString() ?? '',
          emergencyContact: e['emergencyContact']?.toString(),
          imageUrl: e['imageUrl']?.toString(),
          roomId: roomMap?['id']?.toString() ?? '',
          bedId: bedMap?['id']?.toString() ?? '',
          moveInDate: e['moveInDate'] != null ? DateTime.tryParse(e['moveInDate'].toString()) ?? DateTime.now() : DateTime.now(),
          rentAmount: monthlyRent,
          securityDeposit: (e['securityDeposit'] as num?)?.toDouble() ?? 0.0,
          isPaid: e['paymentStatus'] == 'PAID',
          rentDueDate: e['rentDueDate'] != null ? DateTime.tryParse(e['rentDueDate'].toString()) ?? DateTime.now() : DateTime.now(),
          pendingRentAmount: pendingRent,
          defaultPaymentMode: e['defaultPaymentMode']?.toString(),
          occupation: e['occupation']?.toString(),
          dateOfBirth: e['dateOfBirth']?.toString(),
          maritalStatus: e['maritalStatus']?.toString(),
          fatherName: e['fatherName']?.toString(),
          permanentAddress: e['permanentAddress']?.toString(),
          villageOrTown: e['villageOrTown']?.toString(),
          houseNo: e['houseNo']?.toString(),
          wardNo: e['wardNo']?.toString(),
          district: e['district']?.toString(),
          state: e['state']?.toString(),
          nationality: e['nationality']?.toString(),
          pinCode: e['pinCode']?.toString(),
          pendingConvenienceFee: (e['pendingConvenienceFee'] as num?)?.toDouble() ?? 0.0,
          additionalCharges: billsList.whereType<Map<String, dynamic>>().map((b) => AdditionalCharge(
            id: b['id']?.toString() ?? '',
            description: b['description']?.toString() ?? 'Bill',
            amount: (b['amount'] as num?)?.toDouble() ?? 0.0,
            date: b['createdAt'] != null ? DateTime.tryParse(b['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
            billType: b['type']?.toString() ?? 'OTHER',
            status: b['status']?.toString() ?? 'PENDING',
            billDueDate: b['dueDate'] != null ? DateTime.tryParse(b['dueDate'].toString()) : null,
          )).toList(),
        );
      }).toList();

      payments = paymentsData.whereType<Map<String, dynamic>>().map((e) {
        final tId = e['tenantId']?.toString() ?? '';
        Tenant? matchedTenant;
        try {
          matchedTenant = tenants.firstWhere((t) => t.id == tId);
        } catch (_) {}

        String? roomInfo = e['roomNumber']?.toString();
        if (roomInfo == null && matchedTenant != null && matchedTenant.roomId.isNotEmpty) {
          try {
            final r = rooms.firstWhere((room) => room.id == matchedTenant!.roomId);
            String label = 'Room ${r.number}';
            if (matchedTenant.bedId.isNotEmpty) {
              try {
                final b = r.beds.firstWhere((bed) => bed.id == matchedTenant!.bedId);
                label = 'Room ${r.number} (${b.name})';
              } catch (_) {}
            }
            roomInfo = label;
          } catch (_) {}
        }

        return Payment(
          id: e['id']?.toString() ?? '',
          tenantId: tId,
          amount: (e['amount'] as num?)?.toDouble() ?? 0.0,
          method: e['method']?.toString() ?? 'UPI',
          date: e['date'] != null ? DateTime.tryParse(e['date'].toString()) ?? DateTime.now() : DateTime.now(),
          tenantName: e['tenantName']?.toString() ?? matchedTenant?.name ?? 'Tenant',
          roomNumber: roomInfo,
          notes: e['notes']?.toString(),
        );
      }).toList();

      for (var tenant in tenants) {
        if (tenant.roomId.isNotEmpty && tenant.bedId.isNotEmpty) {
          final roomIndex = rooms.indexWhere((r) => r.id == tenant.roomId);
          if (roomIndex != -1) {
            final bedIndex = rooms[roomIndex].beds.indexWhere((b) => b.id == tenant.bedId);
            if (bedIndex != -1) {
              rooms[roomIndex].beds[bedIndex].tenantId = tenant.id;
              rooms[roomIndex].beds[bedIndex].isAvailable = false;
            }
          }
        }
      }

    } catch (e) {
      debugPrint('Error loading from API: $e');
      await loadFromStorage();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final roomsRaw = prefs.getString(_roomsKey);
      if (roomsRaw != null) {
        final List<dynamic> decoded = jsonDecode(roomsRaw);
        rooms = decoded.map((e) => Room.fromJson(e as Map<String, dynamic>)).toList();
      }

      final tenantsRaw = prefs.getString(_tenantsKey);
      if (tenantsRaw != null) {
        final List<dynamic> decoded = jsonDecode(tenantsRaw);
        tenants = decoded.map((e) => Tenant.fromJson(e as Map<String, dynamic>)).toList();
      }

      final paymentsRaw = prefs.getString(_paymentsKey);
      if (paymentsRaw != null) {
        final List<dynamic> decoded = jsonDecode(paymentsRaw);
        payments = decoded.map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList();
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading from storage: $e');
    }
  }

  Future<void> saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_roomsKey, jsonEncode(rooms.map((r) => r.toJson()).toList()));
      await prefs.setString(_tenantsKey, jsonEncode(tenants.map((t) => t.toJson()).toList()));
      await prefs.setString(_paymentsKey, jsonEncode(payments.map((p) => p.toJson()).toList()));
    } catch (e) {
      debugPrint('Error saving to storage: $e');
    }
  }

  int get totalBeds => rooms.fold(0, (sum, room) => sum + room.capacity);
  int get occupiedBeds => totalBeds - availableBeds;
  int get availableBeds => rooms.fold(0, (sum, room) => sum + room.availableBeds);
  double get occupancyRate => totalBeds == 0 ? 0 : occupiedBeds / totalBeds;

  // Expected is total rent of all tenants + any pending bills
  // --- Combined Metrics (if needed elsewhere) ---
  double get expectedRent => tenants.fold(0.0, (sum, t) => sum + t.rentAmount + t.totalExpectedBills);
  double get collectedRent => tenants.fold(0.0, (sum, t) => sum + (t.rentAmount - t.pendingRentAmount) + t.totalPaidBills);
  double get pendingRent => expectedRent - collectedRent;

  // --- Rent Only Metrics ---
  double get expectedRentOnly => tenants.fold(0.0, (sum, t) => sum + t.rentAmount);
  double get collectedRentOnly => tenants.fold(0.0, (sum, t) => sum + (t.rentAmount - t.pendingRentAmount));
  double get pendingRentOnly => expectedRentOnly - collectedRentOnly;

  // --- Bills Only Metrics ---
  double get expectedBillsOnly => tenants.fold(0.0, (sum, t) => sum + t.totalExpectedBills);
  double get collectedBillsOnly => tenants.fold(0.0, (sum, t) => sum + t.totalPaidBills);
  double get pendingBillsOnly => tenants.fold(0.0, (sum, t) => sum + t.totalPendingBills);

  List<Tenant> get newTenantsThisMonth => tenants.where((t) => t.moveInDate.month == DateTime.now().month).toList();
  List<Tenant> get unpaidTenants => tenants.where((t) => t.totalDue > 0).toList();
  List<Tenant> get unpaidRentTenants => tenants.where((t) => t.pendingRentAmount > 0).toList();
  List<Tenant> get unpaidBillsTenants => tenants.where((t) => t.totalPendingBills > 0).toList();

  Future<String?> addTenant(Tenant tenant) async {
    tenants.add(tenant);
    // update bed status if assigned
    final roomIdx = rooms.indexWhere((r) => r.id == tenant.roomId);
    if (roomIdx != -1) {
      final bedIdx = rooms[roomIdx].beds.indexWhere((b) => b.id == tenant.bedId);
      if (bedIdx != -1) {
        rooms[roomIdx].beds[bedIdx].isAvailable = false;
        rooms[roomIdx].beds[bedIdx].tenantId = tenant.id;
      }
    }
    notifyListeners();
    
    try {
      final tempPassword = await ApiService.createTenant({
        'name': tenant.name,
        'phone': tenant.phone,
        'email': tenant.email,
        'emergencyContact': tenant.emergencyContact,
        'bedId': tenant.bedId.isNotEmpty ? tenant.bedId : null,
        'monthlyRent': tenant.rentAmount,
        'securityDeposit': tenant.securityDeposit,
        'dueDay': 5,
        'moveInDate': tenant.moveInDate.toIso8601String(),
      });
      await loadFromAPI();
      return tempPassword;
    } catch (e) {
      debugPrint('Error creating tenant: $e');
      await loadFromAPI();
      rethrow;
    }
  }

  Future<void> recordPayment(String tenantId, double amount, String method, {String paymentType = 'BOTH'}) async {
    final payment = Payment(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      amount: amount,
      date: DateTime.now(),
      method: method,
    );
    payments.add(payment);

    try {
      await ApiService.recordRentPayment({
        'tenantId': tenantId,
        'rentId': 'mock_rent_id',
        'amount': amount,
        'method': method.toUpperCase().replaceAll(' ', '_'),
        'paymentDate': DateTime.now().toIso8601String(),
        'paymentType': paymentType,
      });
      // Reload from API to get the real paymentStatus and pendingRentAmount
      await loadFromAPI();
    } catch (e) {
      debugPrint('Error recording payment: $e');
      rethrow;
    }

    saveToStorage();
    notifyListeners();
  }

  void markCredentialsSent(String tenantId) {
    final index = tenants.indexWhere((t) => t.id == tenantId);
    if (index != -1) {
      tenants[index].credentialsSent = true;
      saveToStorage();
      notifyListeners();
    }
  }

  void markCredentialsSentByPhone(String phone) {
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final index = tenants.indexWhere((t) {
      final tPhone = t.phone.replaceAll(RegExp(r'\D'), '');
      return tPhone.isNotEmpty && cleanPhone.isNotEmpty && (tPhone.endsWith(cleanPhone) || cleanPhone.endsWith(tPhone));
    });
    if (index != -1) {
      tenants[index].credentialsSent = true;
      saveToStorage();
      notifyListeners();
    }
  }

  Future<void> addRoom(Room room) async {
    rooms.add(room);
    notifyListeners();

    try {
      await ApiService.createRoom({
        'roomNumber': room.number,
        'floorNumber': room.floor,
        'capacity': room.capacity,
      });
      await loadFromAPI();
    } catch (e) {
      debugPrint('Error creating room: $e');
      await loadFromAPI();
      rethrow;
    }

    saveToStorage();
    notifyListeners();
  }

  void addBed(String roomId, String bedName) {
    final roomIdx = rooms.indexWhere((r) => r.id == roomId);
    if (roomIdx != -1) {
      var newBed = Bed(
        id: 'b_${DateTime.now().millisecondsSinceEpoch}',
        name: bedName,
      );
      rooms[roomIdx].beds.add(newBed);
      rooms[roomIdx].capacity = rooms[roomIdx].beds.length;
      saveToStorage();
      notifyListeners();
    }
  }

  void removeBed(String roomId, String bedId) {
    final roomIdx = rooms.indexWhere((r) => r.id == roomId);
    if (roomIdx != -1) {
      rooms[roomIdx].beds.removeWhere((b) => b.id == bedId);
      rooms[roomIdx].capacity = rooms[roomIdx].beds.length;
      saveToStorage();
      notifyListeners();
    }
  }

  Future<void> editTenantFinancials(String tenantId, double? rentAmount, double? securityDeposit, int? rentDueDay, String? paymentMode) async {
    try {
      await ApiService.updateTenantFinancials(
        tenantId: tenantId,
        rentAmount: rentAmount,
        securityDeposit: securityDeposit,
        rentDueDay: rentDueDay,
        paymentMode: paymentMode,
      );
      await loadFromAPI();
    } catch (e) {
      debugPrint('Error updating tenant financials: $e');
      rethrow;
    }
  }

  Future<void> editBillAmount(String billId, double newAmount) async {
    try {
      await ApiService.updateBill(billId, newAmount);
      await loadFromAPI();
    } catch (e) {
      debugPrint('Error updating bill: $e');
      rethrow;
    }
  }

  void addBillToTenants(List<String> tenantIds, double splitAmount, String description) {
    // Fire the API call and reload from server when done so bills survive refresh.
    if (tenantIds.isNotEmpty) {
      final tenant = tenants.firstWhere((t) => t.id == tenantIds.first);
      if (tenant.roomId.isNotEmpty) {
        ApiService.generateRoomCurrentBill({
          'roomId': tenant.roomId,
          'totalAmount': splitAmount * tenantIds.length,
          'splitType': 'CUSTOM',
          'customSplits': tenantIds.map((id) => {
            'tenantProfileId': id,
            'value': splitAmount
          }).toList(),
          'description': description,
        }).then((_) {
          // Reload from API so the newly created bills appear correctly
          // (they are now PENDING in the DB and will come back from fetchTenants)
          loadFromAPI();
        }).catchError((e) {
          debugPrint('Error generating bill: $e');
        });
      }
    }

    // Optimistically add charges to local state so the UI updates immediately
    for (var tenantId in tenantIds) {
      final idx = tenants.indexWhere((t) => t.id == tenantId);
      if (idx != -1) {
        tenants[idx].additionalCharges.add(AdditionalCharge(
          id: 'ac_${DateTime.now().millisecondsSinceEpoch}_$tenantId',
          description: description,
          amount: splitAmount,
          date: DateTime.now(),
          billType: 'CURRENT',
        ));
        // NOTE: isPaid is NOT touched — utility bills don't affect rent status.
      }
    }

    saveToStorage();
    notifyListeners();
  }

  Future<void> allocateTenant(String tenantId, String roomId, String bedId, {
    double rentAmount = 0.0,
    double securityDeposit = 0.0,
    DateTime? moveInDate,
  }) async {
    final tenantIdx = tenants.indexWhere((t) => t.id == tenantId);
    if (tenantIdx != -1) {
      final t = tenants[tenantIdx];
      t.roomId = roomId;
      t.bedId = bedId;
      t.rentAmount = rentAmount;
      t.securityDeposit = securityDeposit;
      if (moveInDate != null) t.moveInDate = moveInDate;
    }

    final roomIdx = rooms.indexWhere((r) => r.id == roomId);
    if (roomIdx != -1) {
      final bedIdx = rooms[roomIdx].beds.indexWhere((b) => b.id == bedId);
      if (bedIdx != -1) {
        rooms[roomIdx].beds[bedIdx].isAvailable = false;
        rooms[roomIdx].beds[bedIdx].tenantId = tenantId;
      }
    }
    notifyListeners();

    try {
      await ApiService.allocateTenantToBed(
        tenantId, 
        bedId,
        rentAmount: rentAmount,
        securityDeposit: securityDeposit,
        moveInDate: moveInDate?.toIso8601String(),
      );
      await loadFromAPI();
    } catch (e) {
      debugPrint('Error allocating tenant: $e');
      await loadFromAPI();
      rethrow;
    }

    saveToStorage();
    notifyListeners();
  }

  Future<void> vacateTenant(String tenantId) async {
    var tenantIndex = tenants.indexWhere((t) => t.id == tenantId);
    if (tenantIndex != -1) {
      var tenant = tenants[tenantIndex];
      for (var room in rooms) {
        if (room.id == tenant.roomId) {
          for (var bed in room.beds) {
            if (bed.id == tenant.bedId || bed.tenantId == tenantId) {
              bed.isAvailable = true;
              bed.tenantId = null;
            }
          }
        }
      }
      tenants.removeAt(tenantIndex);
      saveToStorage();
      notifyListeners();
    }
  }
}

