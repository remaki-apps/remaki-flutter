import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String generateEasyPassword() {
  final random = Random();
  final prefixes = ['rem', 'pg', 'sun', 'stay', 'rm'];
  final prefix = prefixes[random.nextInt(prefixes.length)];
  final number = 100 + random.nextInt(900);
  return '$prefix$number';
}

/// Formats room string without duplicate "Room" prefix (e.g. "Room 101", never "Room Room 101")
String formatRoomName(String? room) {
  if (room == null || room.trim().isEmpty) return '';
  var trimmed = room.trim();
  while (RegExp(r'^room\s*[:\-]?\s*', caseSensitive: false).hasMatch(trimmed)) {
    trimmed = trimmed.replaceFirst(RegExp(r'^room\s*[:\-]?\s*', caseSensitive: false), '').trim();
  }
  return trimmed.isEmpty ? 'Room' : 'Room $trimmed';
}

/// Formats bed string without duplicate "Bed" prefix (e.g. "Bed 1", never "Bed Bed 1")
String formatBedName(String? bed) {
  if (bed == null || bed.trim().isEmpty) return '';
  var trimmed = bed.trim();
  while (RegExp(r'^bed\s*[:\-]?\s*', caseSensitive: false).hasMatch(trimmed)) {
    trimmed = trimmed.replaceFirst(RegExp(r'^bed\s*[:\-]?\s*', caseSensitive: false), '').trim();
  }
  return trimmed.isEmpty ? 'Bed' : 'Bed $trimmed';
}

/// Formats combined Room and Bed string cleanly (e.g. "Room 101 • Bed 1")
String formatRoomAndBed(String? room, String? bed, {String separator = ' • '}) {
  final r = formatRoomName(room);
  final b = formatBedName(bed);
  if (r.isNotEmpty && b.isNotEmpty) return '$r$separator$b';
  if (r.isNotEmpty) return r;
  return b;
}

class Bed {
  String id;
  String name;
  bool isAvailable;
  String? tenantId;

  Bed({required this.id, required this.name, this.isAvailable = true, this.tenantId});

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isAvailable': isAvailable,
        'tenantId': tenantId,
      };

  factory Bed.fromJson(Map<String, dynamic> json) => Bed(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Bed',
        isAvailable: json['isAvailable'] as bool? ?? true,
        tenantId: json['tenantId']?.toString(),
      );
}

class AdditionalCharge {
  String id;
  String description;
  double amount;
  DateTime date;
  String billType;        // 'RENT', 'CURRENT', 'OTHER'
  String status;          // 'PENDING', 'PAID'
  DateTime? billDueDate;  // the bill's own due date (distinct from rent due date)

  AdditionalCharge({
    required this.id,
    required this.description,
    required this.amount,
    required this.date,
    this.billType = 'OTHER',
    this.status = 'PENDING',
    this.billDueDate,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
        'billType': billType,
        'status': status,
        'billDueDate': billDueDate?.toIso8601String(),
      };

  factory AdditionalCharge.fromJson(Map<String, dynamic> json) => AdditionalCharge(
        id: json['id']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        date: (DateTime.tryParse(json['date']?.toString() ?? json['createdAt']?.toString() ?? '') ?? DateTime.now()).toLocal(),
        billType: (json['billType'] ?? json['type']) as String? ?? 'OTHER',
        status: json['status'] as String? ?? 'PENDING',
        billDueDate: (json['billDueDate'] ?? json['dueDate']) != null ? DateTime.tryParse((json['billDueDate'] ?? json['dueDate']).toString())?.toLocal() : null,
      );
}

class PropertyItem {
  final String id;
  final String name;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final String? description;
  final int totalFloors;
  final double platformFee;
  final String? upiId;
  final String? upiPayeeName;

  PropertyItem({
    required this.id,
    required this.name,
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.description,
    this.totalFloors = 0,
    this.platformFee = 9.0,
    this.upiId,
    this.upiPayeeName,
  });

  factory PropertyItem.fromJson(Map<String, dynamic> json) => PropertyItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        city: json['city']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        pincode: json['pincode']?.toString() ?? '',
        description: json['description']?.toString(),
        totalFloors: (json['totalFloors'] as num?)?.toInt() ?? 0,
        platformFee: (json['platformFee'] as num?)?.toDouble() ?? 9.0,
        upiId: json['upiId']?.toString(),
        upiPayeeName: json['upiPayeeName']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'description': description,
        'platformFee': platformFee,
        'totalFloors': totalFloors,
        'upiId': upiId,
        'upiPayeeName': upiPayeeName,
      };
}

class Room {
  String id;
  String number;
  String floor;
  int capacity;
  String roomType; // 'AC' or 'NON_AC'
  List<Bed> beds;
  String propertyId;

  Room({
    required this.id,
    required this.number,
    this.floor = 'Ground Floor',
    required this.capacity,
    this.roomType = 'NON_AC',
    required this.beds,
    this.propertyId = '',
  });

  bool get isAc => roomType.toUpperCase() == 'AC';
  int get availableBeds => beds.where((b) => b.isAvailable).length;
  bool get isFull => availableBeds == 0;
  bool get isEmpty => availableBeds == capacity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'floor': floor,
        'capacity': capacity,
        'roomType': roomType,
        'beds': beds.map((b) => b.toJson()).toList(),
        'propertyId': propertyId,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        floor: json['floor']?.toString() ?? 'Ground Floor',
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
        roomType: json['roomType']?.toString() ?? 'NON_AC',
        propertyId: json['propertyId']?.toString() ?? '',
        beds: (json['beds'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((e) => Bed.fromJson(e))
            .toList() ?? [],
      );
}

class Tenant {
  String id;
  String name;
  String phone;
  String email;
  String? emergencyContact;
  String roomId;
  String bedId;
  DateTime moveInDate;
  double rentAmount;
  double securityDeposit;
  bool isPaid;
  String paymentStatus;
  double platformFee;
  String propertyId;
  bool get isPending => paymentStatus == 'PENDING';
  bool get isPartiallyPaid => paymentStatus == 'PARTIAL' || (pendingRentAmount > 0 && pendingRentAmount < rentAmount);

  bool get isUpcoming {
    if (paymentStatus == 'PAID' && isPaid) return false;
    if (isPending || isPartiallyPaid) return false;
    if (paymentStatus == 'UPCOMING') return true;
    if (paymentStatus == 'OVERDUE') return false;
    final dueStart = DateTime(rentDueDate.year, rentDueDate.month, rentDueDate.day);
    return DateTime.now().isBefore(dueStart);
  }

  bool get isOverdue {
    if (isPaid || isPending || isPartiallyPaid || isUpcoming) return false;
    if (paymentStatus == 'OVERDUE') return true;
    final graceDate = DateTime(rentDueDate.year, rentDueDate.month, rentDueDate.day).add(const Duration(days: 3));
    return DateTime.now().isAfter(graceDate);
  }

  bool get isUnpaid {
    if (isPaid || isPending || isPartiallyPaid || isUpcoming || isOverdue) return false;
    return true;
  }

  String get statusBadgeLabel {
    if (isPaid || paymentStatus == 'PAID') return 'PAID';
    if (isPending) return 'PENDING';
    if (isPartiallyPaid || (isPaid && totalPendingBills > 0)) return 'PARTIAL';
    if (isUpcoming) return 'UPCOMING';
    if (isOverdue) return 'OVERDUE';
    if (totalDue == 0 && rentAmount == 0) return 'NO DUES';
    return 'UNPAID';
  }

  Color get statusColor {
    switch (statusBadgeLabel) {
      case 'PAID':
        return const Color(0xFF16A34A);
      case 'PENDING':
        return const Color(0xFFD97706);
      case 'PARTIAL':
        return const Color(0xFFEAB308);
      case 'UPCOMING':
        return const Color(0xFF2563EB);
      case 'OVERDUE':
        return const Color(0xFFEF4444);
      case 'UNPAID':
      default:
        return const Color(0xFFEA580C);
    }
  }

  Color get statusBgColor {
    switch (statusBadgeLabel) {
      case 'PAID':
        return const Color(0xFFDCFCE7);
      case 'PENDING':
        return const Color(0xFFFEF3C7);
      case 'PARTIAL':
        return const Color(0xFFFEF9C3);
      case 'UPCOMING':
        return const Color(0xFFEFF6FF);
      case 'OVERDUE':
        return const Color(0xFFFEE2E2);
      case 'UNPAID':
      default:
        return const Color(0xFFFFEDD5);
    }
  }

  Color get statusBorderColor {
    switch (statusBadgeLabel) {
      case 'PAID':
        return const Color(0xFFBBF7D0);
      case 'PENDING':
        return const Color(0xFFFDE68A);
      case 'PARTIAL':
        return const Color(0xFFFDE047);
      case 'UPCOMING':
        return const Color(0xFFBFDBFE);
      case 'OVERDUE':
        return const Color(0xFFFCA5A5);
      case 'UNPAID':
      default:
        return const Color(0xFFFED7AA);
    }
  }
  DateTime rentDueDate;
  // Amount still owed on rent this cycle (0 if fully paid, partial if partially paid)
  double pendingRentAmount;
  List<AdditionalCharge> additionalCharges;
  String? imageUrl;
  bool credentialsSent;
  String password;
  String? defaultPaymentMode;

  String? occupation;
  String? dateOfBirth;
  String? maritalStatus;
  String? fatherName;
  String? permanentAddress;
  String? villageOrTown;
  String? houseNo;
  String? wardNo;
  String? district;
  String? state;
  String? nationality;
  String? pinCode;
  double pendingConvenienceFee;

  // totalDue = unpaid utility/other bills only (not rent, as rent is tracked via pendingRentAmount)
  double get totalPendingBills => additionalCharges
      .where((c) => c.billType != 'RENT' && (c.status == 'PENDING' || c.status == 'UNPAID'))
      .fold(0.0, (sum, c) => sum + c.amount);

  // totalPaidBills = paid utility/other bills only
  double get totalPaidBills => additionalCharges
      .where((c) => c.billType != 'RENT' && c.status == 'PAID')
      .fold(0.0, (sum, c) => sum + c.amount);

  // totalExpectedBills = sum of pending + paid
  double get totalExpectedBills => totalPendingBills + totalPaidBills;

  // Grand total owed: pending rent balance + pending utility bills
  double get totalDue => pendingRentAmount + totalPendingBills;

  String buildDetailedRentBillMessage({String roomNumber = '', String floorName = '', String pgName = ''}) {
    final dueDateStr = DateFormat('dd MMM yyyy').format(rentDueDate);
    final List<String> itemLines = [];

    // 1. Rent Amount
    final rentVal = pendingRentAmount > 0 ? pendingRentAmount : rentAmount;
    if (rentVal > 0) {
      itemLines.add('• *Monthly Rent:* ₹${rentVal.toStringAsFixed(0)}');
    }

    // 2. Additional Charges & Bills (Electricity, Water, Maintenance, EB etc.)
    for (var charge in additionalCharges) {
      if (charge.billType != 'RENT' && charge.amount > 0 && (charge.status == 'PENDING' || charge.status == 'UNPAID')) {
        String label = charge.description.trim();
        if (label.isEmpty) {
          label = charge.billType == 'CURRENT' ? 'Electricity / EB Bill' : 'Utility Charge';
        }
        itemLines.add('• *$label:* ₹${charge.amount.toStringAsFixed(0)}');
      }
    }

    if (itemLines.isEmpty) {
      itemLines.add('• *Total Rent Balance:* ₹${totalDue.toStringAsFixed(0)}');
    }

    final itemsText = itemLines.join('\n');
    final totalStr = (totalDue > 0 ? totalDue : rentAmount).toStringAsFixed(0);

    final roomDetailStr = roomNumber.isNotEmpty
        ? '${formatRoomName(roomNumber)}${floorName.isNotEmpty ? ' ($floorName)' : ''}'
        : 'Assigned Room';

    return Uri.encodeComponent(
      '🧾 *RENT & BILL STATEMENT* 🧾\n'
      '🏢 *${pgName.isNotEmpty ? pgName : 'PG'}*\n'
      '────────────────────────────\n'
      '👤 *Tenant Name:* $name\n'
      '📱 *Mobile Number:* $phone\n'
      '🏠 *Room Details:* $roomDetailStr\n'
      '📅 *Due Date:* $dueDateStr\n'
      '────────────────────────────\n'
      '📋 *Detailed Bill Breakdown:*\n'
      '$itemsText\n'
      '────────────────────────────\n'
      '💰 *Total Amount Payable:* *₹$totalStr*\n'
      '────────────────────────────\n\n'
      '📲 Track payments & receipts anytime on the *Remaki* app.\n'
      'Kindly clear your pending bill balance on or before the due date.\n\n'
      'Best regards,\n'
      '*${pgName.isNotEmpty ? '$pgName Management' : 'Property Management'}*'
    );
  }

  Tenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.emergencyContact,
    required this.roomId,
    
    this.occupation,
    this.dateOfBirth,
    this.maritalStatus,
    this.fatherName,
    this.permanentAddress,
    this.villageOrTown,
    this.houseNo,
    this.wardNo,
    this.district,
    this.state,
    this.nationality,
    this.pinCode,
    required this.bedId,
    required this.moveInDate,
    required this.rentAmount,
    required this.securityDeposit,
    this.isPaid = false,
    this.paymentStatus = 'UNPAID',
    this.platformFee = 9.0,
    this.propertyId = '',
    required this.rentDueDate,
    this.pendingRentAmount = 0,
    List<AdditionalCharge>? additionalCharges,
    this.imageUrl,
    this.credentialsSent = false,
    String? password,
    this.defaultPaymentMode,
    this.pendingConvenienceFee = 0.0,
  })  : additionalCharges = additionalCharges ?? [],
        password = password ?? generateEasyPassword();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'emergencyContact': emergencyContact,
        'roomId': roomId,
        'bedId': bedId,
        'moveInDate': moveInDate.toIso8601String(),
        'rentAmount': rentAmount,
        'securityDeposit': securityDeposit,
        'isPaid': isPaid,
        'paymentStatus': paymentStatus,
        'platformFee': platformFee,
        'propertyId': propertyId,
        'rentDueDate': rentDueDate.toIso8601String(),
        'pendingRentAmount': pendingRentAmount,
        'additionalCharges': additionalCharges.map((c) => c.toJson()).toList(),
        'imageUrl': imageUrl,
        'credentialsSent': credentialsSent,
        'password': password,
        'defaultPaymentMode': defaultPaymentMode,
        'occupation': occupation,
        'dateOfBirth': dateOfBirth,
        'maritalStatus': maritalStatus,
        'fatherName': fatherName,
        'permanentAddress': permanentAddress,
        'villageOrTown': villageOrTown,
        'houseNo': houseNo,
        'wardNo': wardNo,
        'district': district,
        'state': state,
        'nationality': nationality,
        'pinCode': pinCode,
        'pendingConvenienceFee': pendingConvenienceFee,
      };

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Tenant',
        phone: json['phone']?.toString() ?? '',
        email: json['email'] as String? ?? '',
        emergencyContact: json['emergencyContact'] as String?,
        roomId: json['roomId']?.toString() ?? '',
        bedId: json['bedId']?.toString() ?? '',
        moveInDate: (DateTime.tryParse(json['moveInDate']?.toString() ?? '') ?? DateTime.now()).toLocal(),
        rentAmount: (json['rentAmount'] as num?)?.toDouble() ?? 0.0,
        securityDeposit: (json['securityDeposit'] as num?)?.toDouble() ?? 0.0,
        isPaid: json['isPaid'] as bool? ?? false,
        paymentStatus: (json['hasPendingRequest'] == true || json['paymentStatus'] == 'PENDING')
            ? 'PENDING'
            : (json['paymentStatus']?.toString() ?? (json['isPaid'] == true ? 'PAID' : 'UNPAID')),
        platformFee: (json['platformFee'] as num?)?.toDouble() ?? 9.0,
        propertyId: json['propertyId'] as String? ?? (json['room'] != null && json['room']['propertyId'] != null ? json['room']['propertyId'].toString() : ''),
        rentDueDate: (DateTime.tryParse(json['rentDueDate']?.toString() ?? '') ?? DateTime.now()).toLocal(),
        pendingRentAmount: (json['pendingRentAmount'] as num?)?.toDouble() ?? 0,
        additionalCharges: (json['additionalCharges'] as List<dynamic>?)?.map((e) => AdditionalCharge.fromJson(e as Map<String, dynamic>)).toList() ??
            (json['bills'] as List<dynamic>?)?.map((e) => AdditionalCharge.fromJson(e as Map<String, dynamic>)).toList() ??
            [],
        imageUrl: json['imageUrl'] as String?,
        credentialsSent: json['credentialsSent'] as bool? ?? false,
        password: (json['tempPassword'] ?? json['password']) as String? ?? generateEasyPassword(),
        defaultPaymentMode: json['defaultPaymentMode'] as String?,
        occupation: json['occupation'] as String?,
        dateOfBirth: json['dateOfBirth'] as String?,
        maritalStatus: json['maritalStatus'] as String?,
        fatherName: json['fatherName'] as String?,
        permanentAddress: json['permanentAddress'] as String?,
        villageOrTown: json['villageOrTown'] as String?,
        houseNo: json['houseNo'] as String?,
        wardNo: json['wardNo'] as String?,
        district: json['district'] as String?,
        state: json['state'] as String?,
        nationality: json['nationality'] as String?,
        pinCode: json['pinCode'] as String?,
        pendingConvenienceFee: (json['pendingConvenienceFee'] as num?)?.toDouble() ?? 0.0,
      );
}

class Payment {
  String id;
  String tenantId;
  double amount;
  DateTime date;
  String method;
  String? tenantName;
  String? roomNumber;
  String? notes;
  String? propertyId;
  String? billingMonth;
  double platformFee;
  double rentAmount;

  Payment({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.date,
    required this.method,
    this.tenantName,
    this.roomNumber,
    this.notes,
    this.propertyId,
    this.billingMonth,
    this.platformFee = 0.0,
    this.rentAmount = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'amount': amount,
        'date': date.toIso8601String(),
        'method': method,
        'tenantName': tenantName,
        'roomNumber': roomNumber,
        'notes': notes,
        'propertyId': propertyId,
        'billingMonth': billingMonth,
        'platformFee': platformFee,
        'rentAmount': rentAmount,
      };

  factory Payment.fromJson(Map<String, dynamic> json) {
    final amt = (json['amount'] as num?)?.toDouble() ?? 0.0;
    final fee = (json['platformFee'] as num?)?.toDouble() ?? 0.0;
    final rent = (json['rentAmount'] as num?)?.toDouble() ?? amt;
    return Payment(
      id: json['id'] as String? ?? '',
      tenantId: json['tenantId'] as String? ?? '',
      amount: amt,
      date: json['date'] != null
          ? (DateTime.tryParse(json['date'] as String)?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      method: json['method'] as String? ?? 'UPI',
      tenantName: json['tenantName'] as String?,
      roomNumber: json['roomNumber'] as String?,
      notes: json['notes'] as String?,
      propertyId: json['propertyId'] as String?,
      billingMonth: json['billingMonth'] as String?,
      platformFee: fee,
      rentAmount: rent,
    );
  }

  /// Returns total amount paid including rent, utility bills, and platform fee
  double calculateTotalPaid(Tenant? tenant) {
    if (tenant == null) return amount;
    final fee = platformFee > 0 ? platformFee : tenant.platformFee;
    final rent = rentAmount > 0 ? rentAmount : tenant.rentAmount;
    final paidBills = tenant.additionalCharges
        .where((c) => c.billType != 'RENT' && c.status == 'PAID')
        .fold(0.0, (sum, c) => sum + c.amount);
    final combined = rent + paidBills + fee;
    return max(amount, combined);
  }
}

class PropertyOwnerItem {
  final String id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String role;
  final bool isPrimary;
  final DateTime createdAt;

  PropertyOwnerItem({
    required this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    required this.role,
    required this.isPrimary,
    required this.createdAt,
  });

  factory PropertyOwnerItem.fromJson(Map<String, dynamic> json) => PropertyOwnerItem(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Owner',
        phoneNumber: json['phoneNumber']?.toString() ?? '',
        role: json['role']?.toString() ?? 'CO_OWNER',
        isPrimary: json['isPrimary'] == true,
        createdAt: json['createdAt'] != null
            ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
            : DateTime.now(),
      );
}

class Complaint {
  final String id;
  final String tenantProfileId;
  final String adminId;
  final String category;
  final String title;
  final String description;
  final String? mediaUrl;
  final String status; // 'PENDING', 'IN_PROGRESS', 'RESOLVED'
  final String? adminReply;
  final DateTime? repliedAt;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String tenantName;
  final String tenantPhone;
  final String? roomNumber;
  final String? bedLabel;

  Complaint({
    required this.id,
    required this.tenantProfileId,
    required this.adminId,
    required this.category,
    required this.title,
    required this.description,
    this.mediaUrl,
    required this.status,
    this.adminReply,
    this.repliedAt,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.tenantName,
    required this.tenantPhone,
    this.roomNumber,
    this.bedLabel,
  });

  bool get isPending => status == 'PENDING';
  bool get isInProgress => status == 'IN_PROGRESS';
  bool get isResolved => status == 'RESOLVED';

  factory Complaint.fromJson(Map<String, dynamic> json) {
    final tenantJson = json['tenant'] as Map<String, dynamic>? ?? {};
    return Complaint(
      id: json['id']?.toString() ?? '',
      tenantProfileId: json['tenantProfileId']?.toString() ?? '',
      adminId: json['adminId']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      mediaUrl: json['mediaUrl']?.toString(),
      status: json['status']?.toString() ?? 'PENDING',
      adminReply: json['adminReply']?.toString(),
      repliedAt: json['repliedAt'] != null
          ? DateTime.tryParse(json['repliedAt'].toString())?.toLocal()
          : null,
      resolvedAt: json['resolvedAt'] != null
          ? DateTime.tryParse(json['resolvedAt'].toString())?.toLocal()
          : null,
      createdAt: json['createdAt'] != null
          ? (DateTime.tryParse(json['createdAt'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? (DateTime.tryParse(json['updatedAt'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      tenantName: tenantJson['name']?.toString() ?? 'Tenant',
      tenantPhone: tenantJson['phoneNumber']?.toString() ?? '',
      roomNumber: tenantJson['roomNumber']?.toString(),
      bedLabel: tenantJson['bedLabel']?.toString(),
    );
  }
}


