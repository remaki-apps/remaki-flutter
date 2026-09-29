import 'dart:math';
import 'package:intl/intl.dart';

String generateEasyPassword() {
  final random = Random();
  final prefixes = ['rem', 'pg', 'sun', 'stay', 'rm'];
  final prefix = prefixes[random.nextInt(prefixes.length)];
  final number = 100 + random.nextInt(900);
  return '$prefix$number';
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
        date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
        billType: json['billType'] as String? ?? 'OTHER',
        status: json['status'] as String? ?? 'PENDING',
        billDueDate: json['billDueDate'] != null ? DateTime.tryParse(json['billDueDate'] as String) : null,
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

  PropertyItem({
    required this.id,
    required this.name,
    this.address = '',
    this.city = '',
    this.state = '',
    this.pincode = '',
    this.description,
    this.totalFloors = 0,
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
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'pincode': pincode,
        'description': description,
        'totalFloors': totalFloors,
      };
}

class Room {
  String id;
  String number;
  String floor;
  int capacity;
  List<Bed> beds;
  String propertyId;

  Room({
    required this.id,
    required this.number,
    this.floor = 'Ground Floor',
    required this.capacity,
    required this.beds,
    this.propertyId = '',
  });

  int get availableBeds => beds.where((b) => b.isAvailable).length;
  bool get isFull => availableBeds == 0;
  bool get isEmpty => availableBeds == capacity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'floor': floor,
        'capacity': capacity,
        'beds': beds.map((b) => b.toJson()).toList(),
        'propertyId': propertyId,
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id']?.toString() ?? '',
        number: json['number']?.toString() ?? '',
        floor: json['floor']?.toString() ?? 'Ground Floor',
        capacity: (json['capacity'] as num?)?.toInt() ?? 0,
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
  bool get isUnpaid => !isPaid && !isPartiallyPaid;
  bool get isPartiallyPaid => paymentStatus == 'PARTIAL' || (pendingRentAmount > 0 && pendingRentAmount < rentAmount);
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
        ? 'Room $roomNumber${floorName.isNotEmpty ? ' ($floorName)' : ''}'
        : 'Assigned Room';

    return Uri.encodeComponent(
      '🧾 *RENT & BILL STATEMENT* 🧾\n'
      '🏢 *${pgName.isNotEmpty ? pgName : 'Your PG'}*\n'
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
      '*${pgName.isNotEmpty ? pgName : 'Your PG'} Management*'
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
        moveInDate: DateTime.tryParse(json['moveInDate']?.toString() ?? '') ?? DateTime.now(),
        rentAmount: (json['rentAmount'] as num?)?.toDouble() ?? 0.0,
        securityDeposit: (json['securityDeposit'] as num?)?.toDouble() ?? 0.0,
        isPaid: json['isPaid'] as bool? ?? false,
        paymentStatus: json['paymentStatus']?.toString() ?? (json['isPaid'] == true ? 'PAID' : 'UNPAID'),
        platformFee: (json['platformFee'] as num?)?.toDouble() ?? 9.0,
        propertyId: json['propertyId'] as String? ?? (json['room'] != null && json['room']['propertyId'] != null ? json['room']['propertyId'].toString() : ''),
        rentDueDate: DateTime.tryParse(json['rentDueDate']?.toString() ?? '') ?? DateTime.now(),
        pendingRentAmount: (json['pendingRentAmount'] as num?)?.toDouble() ?? 0,
        additionalCharges: (json['additionalCharges'] as List<dynamic>?)?.map((e) => AdditionalCharge.fromJson(e as Map<String, dynamic>)).toList() ?? [],
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
      };

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String? ?? '',
        tenantId: json['tenantId'] as String? ?? '',
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        date: json['date'] != null ? DateTime.tryParse(json['date'] as String) ?? DateTime.now() : DateTime.now(),
        method: json['method'] as String? ?? 'UPI',
        tenantName: json['tenantName'] as String?,
        roomNumber: json['roomNumber'] as String?,
        notes: json['notes'] as String?,
        propertyId: json['propertyId'] as String?,
      );
}

