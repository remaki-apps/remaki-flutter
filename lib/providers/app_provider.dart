import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class AppProvider with ChangeNotifier {
  List<Room> rooms = [];
  List<Tenant> tenants = [];
  List<Payment> payments = [];

  static const String _roomsKey = 'sunshine_pg_rooms';
  static const String _tenantsKey = 'sunshine_pg_tenants';
  static const String _paymentsKey = 'sunshine_pg_payments';

  AppProvider() {
    loadFromStorage();
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

  double get expectedRent => tenants.fold(0.0, (sum, t) => sum + t.totalDue);
  double get collectedRent => tenants.where((t) => t.isPaid).fold(0.0, (sum, t) => sum + t.totalDue);
  double get pendingRent => expectedRent - collectedRent;

  List<Tenant> get newTenantsThisMonth => tenants.where((t) => t.moveInDate.month == DateTime.now().month).toList();
  List<Tenant> get unpaidTenants => tenants.where((t) => !t.isPaid).toList();

  void addTenant(Tenant tenant) {
    tenants.add(tenant);
    // update bed status
    var room = rooms.firstWhere((r) => r.id == tenant.roomId);
    var bed = room.beds.firstWhere((b) => b.id == tenant.bedId);
    bed.isAvailable = false;
    bed.tenantId = tenant.id;
    saveToStorage();
    notifyListeners();
  }

  void recordPayment(String tenantId, double amount, String method) {
    var payment = Payment(
      id: 'p_${DateTime.now().millisecondsSinceEpoch}',
      tenantId: tenantId,
      amount: amount,
      date: DateTime.now(),
      method: method,
    );
    payments.add(payment);
    var tenantIndex = tenants.indexWhere((t) => t.id == tenantId);
    if (tenantIndex != -1) {
      tenants[tenantIndex].isPaid = true;
    }
    saveToStorage();
    notifyListeners();
  }

  void addRoom(Room room) {
    rooms.add(room);
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

  void addBillToTenants(List<String> tenantIds, double splitAmount, String description) {
    for (var tenantId in tenantIds) {
      var tenant = tenants.firstWhere((t) => t.id == tenantId);
      tenant.additionalCharges.add(AdditionalCharge(
        id: 'ac_${DateTime.now().millisecondsSinceEpoch}_$tenantId',
        description: description,
        amount: splitAmount,
        date: DateTime.now(),
      ));
    }
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

