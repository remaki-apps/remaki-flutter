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
        id: json['id'] as String,
        name: json['name'] as String,
        isAvailable: json['isAvailable'] as bool? ?? true,
        tenantId: json['tenantId'] as String?,
      );
}

class AdditionalCharge {
  String id;
  String description;
  double amount;
  DateTime date;

  AdditionalCharge({required this.id, required this.description, required this.amount, required this.date});

  Map<String, dynamic> toJson() => {
        'id': id,
        'description': description,
        'amount': amount,
        'date': date.toIso8601String(),
      };

  factory AdditionalCharge.fromJson(Map<String, dynamic> json) => AdditionalCharge(
        id: json['id'] as String,
        description: json['description'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
      );
}

class Room {
  String id;
  String number;
  String floor;
  int capacity;
  List<Bed> beds;

  Room({required this.id, required this.number, this.floor = 'Ground Floor', required this.capacity, required this.beds});

  int get availableBeds => beds.where((b) => b.isAvailable).length;
  bool get isFull => availableBeds == 0;
  bool get isEmpty => availableBeds == capacity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'floor': floor,
        'capacity': capacity,
        'beds': beds.map((b) => b.toJson()).toList(),
      };

  factory Room.fromJson(Map<String, dynamic> json) => Room(
        id: json['id'] as String,
        number: json['number'] as String,
        floor: json['floor'] as String? ?? 'Ground Floor',
        capacity: json['capacity'] as int,
        beds: (json['beds'] as List<dynamic>?)?.map((e) => Bed.fromJson(e as Map<String, dynamic>)).toList() ?? [],
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
  bool get isUnpaid => !isPaid;
  DateTime rentDueDate;
  List<AdditionalCharge> additionalCharges;

  double get totalDue => rentAmount + additionalCharges.fold(0.0, (sum, c) => sum + c.amount);

  Tenant({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    this.emergencyContact,
    required this.roomId,
    required this.bedId,
    required this.moveInDate,
    required this.rentAmount,
    required this.securityDeposit,
    this.isPaid = false,
    required this.rentDueDate,
    List<AdditionalCharge>? additionalCharges,
  }) : additionalCharges = additionalCharges ?? [];

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
        'rentDueDate': rentDueDate.toIso8601String(),
        'additionalCharges': additionalCharges.map((c) => c.toJson()).toList(),
      };

  factory Tenant.fromJson(Map<String, dynamic> json) => Tenant(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        email: json['email'] as String? ?? '',
        emergencyContact: json['emergencyContact'] as String?,
        roomId: json['roomId'] as String,
        bedId: json['bedId'] as String,
        moveInDate: DateTime.parse(json['moveInDate'] as String),
        rentAmount: (json['rentAmount'] as num).toDouble(),
        securityDeposit: (json['securityDeposit'] as num).toDouble(),
        isPaid: json['isPaid'] as bool? ?? false,
        rentDueDate: DateTime.parse(json['rentDueDate'] as String),
        additionalCharges: (json['additionalCharges'] as List<dynamic>?)?.map((e) => AdditionalCharge.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      );
}

class Payment {
  String id;
  String tenantId;
  double amount;
  DateTime date;
  String method;

  Payment({required this.id, required this.tenantId, required this.amount, required this.date, required this.method});

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'amount': amount,
        'date': date.toIso8601String(),
        'method': method,
      };

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        id: json['id'] as String,
        tenantId: json['tenantId'] as String,
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date'] as String),
        method: json['method'] as String,
      );
}

