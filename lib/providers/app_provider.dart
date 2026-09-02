import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';

class AppProvider with ChangeNotifier {
  List<Room> rooms = [];
  List<Tenant> tenants = [];
  List<Payment> payments = [];

  static const String _roomsKey = 'sunshine_pg_rooms';
  static const String _tenantsKey = 'sunshine_pg_tenants';
  static const String _paymentsKey = 'sunshine_pg_payments';

  AppProvider() {
    loadFromAPI();
  }

  Future<void> loadFromAPI() async {
    try {
      final tenantsData = await ApiService.fetchTenants();
      final roomsData = await ApiService.fetchRooms();
      final paymentsData = await ApiService.fetchPayments();
      
      rooms = roomsData.map((e) {
        return Room(
          id: e['id'],
          number: e['roomNumber'],
          floor: e['floorNumber'] ?? 'Ground Floor',
          capacity: e['capacity'],
          beds: (e['beds'] as List).map((b) => Bed(
            id: b['id'],
            name: b['bedLabel'],
            isAvailable: b['status'] == 'AVAILABLE' || b['status'] == 'VACANT',
          )).toList(),
        );
      }).toList();

      tenants = tenantsData.map((e) {
        return Tenant(
          id: e['id'],
          name: e['name'],
          phone: e['phone'] ?? '',
          email: e['email'] ?? '',
          roomId: e['room'] != null ? e['room']['id'] : '',
          bedId: e['bed'] != null ? e['bed']['id'] : '',
          moveInDate: e['moveInDate'] != null ? DateTime.tryParse(e['moveInDate']) ?? DateTime.now() : DateTime.now(),
          rentAmount: (e['monthlyRent'] ?? 0).toDouble(),
          securityDeposit: (e['securityDeposit'] ?? 0).toDouble(),
          isPaid: e['paymentStatus'] == 'PAID',
          rentDueDate: e['rentDueDate'] != null ? DateTime.tryParse(e['rentDueDate']) ?? DateTime.now() : DateTime.now(),
          pendingRentAmount: (e['pendingRentAmount'] as num?)?.toDouble() ?? (e['monthlyRent'] ?? 0).toDouble(),
          additionalCharges: (e['bills'] as List<dynamic>?)?.map((b) => AdditionalCharge(
            id: b['id'],
            description: b['description'] ?? 'Bill',
            amount: (b['amount'] as num).toDouble(),
            date: b['createdAt'] != null ? DateTime.tryParse(b['createdAt']) ?? DateTime.now() : DateTime.now(),
            billType: b['type'] as String? ?? 'OTHER',
            status: b['status'] as String? ?? 'PENDING',
            billDueDate: b['dueDate'] != null ? DateTime.tryParse(b['dueDate'] as String) : null,
          )).toList() ?? [],
        );
      }).toList();

      payments = paymentsData.map((e) {
        return Payment(
          id: e['id'],
          tenantId: e['tenantId'],
          amount: (e['amount'] as num).toDouble(),
          method: e['method'],
          date: e['date'] != null ? DateTime.tryParse(e['date']) ?? DateTime.now() : DateTime.now(),
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

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading from API: $e');
      await loadFromStorage();
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
    // update bed status
    var room = rooms.firstWhere((r) => r.id == tenant.roomId);
    var bed = room.beds.firstWhere((b) => b.id == tenant.bedId);
    bed.isAvailable = false;
    bed.tenantId = tenant.id;
    notifyListeners();
    
    try {
      final tempPassword = await ApiService.createTenant({
        'name': tenant.name,
        'phone': tenant.phone,
        'email': tenant.email,
        'emergencyContact': tenant.emergencyContact,
        'bedId': tenant.bedId,
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
      return null;
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

  void addRoom(Room room) {
    rooms.add(room);
    
    ApiService.createRoom({
      'roomNumber': room.number,
      'floorNumber': room.floor,
      'capacity': room.capacity,
    }).catchError((e) => debugPrint('Error creating room: \$e'));

    saveToStorage();
    notifyListeners();
  }

  void addBed(String roomId, String bedName) {
    var room = rooms.firstWhere((r) => r.id == roomId);
    var newBed = Bed(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      name: bedName,
    );
    room.beds.add(newBed);
    room.capacity = room.beds.length;
    saveToStorage();
    notifyListeners();
  }

  void removeBed(String roomId, String bedId) {
    var room = rooms.firstWhere((r) => r.id == roomId);
    room.beds.removeWhere((b) => b.id == bedId);
    room.capacity = room.beds.length;
    saveToStorage();
    notifyListeners();
  }

  void _syncTotals() {
    // Already recalculating dynamically on getter. We can leave this.
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
        }).catchError((e) => debugPrint('Error generating bill: $e'));
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

  void allocateTenant(String tenantId, String roomId, String bedId, {
    double rentAmount = 0.0,
    double securityDeposit = 0.0,
    DateTime? moveInDate,
  }) {
    var tenant = tenants.firstWhere((t) => t.id == tenantId);
    tenant.roomId = roomId;
    tenant.bedId = bedId;
    tenant.rentAmount = rentAmount;
    tenant.securityDeposit = securityDeposit;
    if (moveInDate != null) tenant.moveInDate = moveInDate;

    var room = rooms.firstWhere((r) => r.id == roomId);
    var bed = room.beds.firstWhere((b) => b.id == bedId);
    bed.isAvailable = false;
    bed.tenantId = tenantId;

    ApiService.allocateTenantToBed(
      tenantId, 
      bedId,
      rentAmount: rentAmount,
      securityDeposit: securityDeposit,
      moveInDate: moveInDate?.toIso8601String(),
    ).catchError((e) => debugPrint('Error allocating tenant: \$e'));

    saveToStorage();
    notifyListeners();
  }

  void vacateTenant(String tenantId) {
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

