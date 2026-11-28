class Organization {
  final String id;
  final String name;
  final String code;
  final String? email;
  final String? phoneNumber;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? logoUrl;
  final bool isActive;
  final String createdAt;
  final String updatedAt;

  Organization({
    required this.id,
    required this.name,
    required this.code,
    this.email,
    this.phoneNumber,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.logoUrl,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      email: json['email'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      logoUrl: json['logoUrl'] as String?,
      isActive: json['isActive'] == true,
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

class OrganizationDashboardMetrics {
  final int totalAdmins;
  final int activeAdmins;
  final int inactiveAdmins;
  final int totalProperties;
  final int totalRooms;
  final int totalOccupiedBeds;
  final int totalAvailableBeds;
  final int totalTenants;
  final double totalRentExpected;
  final double totalRentCollected;
  final double totalRentPending;

  OrganizationDashboardMetrics({
    required this.totalAdmins,
    required this.activeAdmins,
    required this.inactiveAdmins,
    required this.totalProperties,
    required this.totalRooms,
    required this.totalOccupiedBeds,
    required this.totalAvailableBeds,
    required this.totalTenants,
    required this.totalRentExpected,
    required this.totalRentCollected,
    required this.totalRentPending,
  });

  int get totalBeds => totalOccupiedBeds + totalAvailableBeds;
  double get occupancyRate => totalBeds > 0 ? (totalOccupiedBeds / totalBeds) : 0.0;

  factory OrganizationDashboardMetrics.empty() {
    return OrganizationDashboardMetrics(
      totalAdmins: 0,
      activeAdmins: 0,
      inactiveAdmins: 0,
      totalProperties: 0,
      totalRooms: 0,
      totalOccupiedBeds: 0,
      totalAvailableBeds: 0,
      totalTenants: 0,
      totalRentExpected: 0.0,
      totalRentCollected: 0.0,
      totalRentPending: 0.0,
    );
  }

  factory OrganizationDashboardMetrics.fromJson(Map<String, dynamic> json) {
    return OrganizationDashboardMetrics(
      totalAdmins: (json['totalAdmins'] as num?)?.toInt() ?? 0,
      activeAdmins: (json['activeAdmins'] as num?)?.toInt() ?? 0,
      inactiveAdmins: (json['inactiveAdmins'] as num?)?.toInt() ?? 0,
      totalProperties: (json['totalProperties'] as num?)?.toInt() ?? 0,
      totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
      totalOccupiedBeds: (json['totalOccupiedBeds'] as num?)?.toInt() ?? 0,
      totalAvailableBeds: (json['totalAvailableBeds'] as num?)?.toInt() ?? 0,
      totalTenants: (json['totalTenants'] as num?)?.toInt() ?? 0,
      totalRentExpected: (json['totalRentExpected'] as num?)?.toDouble() ?? 0.0,
      totalRentCollected: (json['totalRentCollected'] as num?)?.toDouble() ?? 0.0,
      totalRentPending: (json['totalRentPending'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrganizationAdminSummary {
  final String id;
  final String displayName;
  final String phoneNumber;
  final String? email;
  final String adminCode;
  final bool isActive;
  final String createdAt;
  final String? lastLoginAt;
  final int propertyCount;
  final List<String> propertyNames;
  final int totalRooms;
  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int totalTenants;
  final double rentCollected;
  final double rentPending;

  OrganizationAdminSummary({
    required this.id,
    required this.displayName,
    required this.phoneNumber,
    this.email,
    required this.adminCode,
    required this.isActive,
    required this.createdAt,
    this.lastLoginAt,
    required this.propertyCount,
    required this.propertyNames,
    required this.totalRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.totalTenants,
    required this.rentCollected,
    required this.rentPending,
  });

  double get occupancyRate => totalBeds > 0 ? (occupiedBeds / totalBeds) : 0.0;

  factory OrganizationAdminSummary.fromJson(Map<String, dynamic> json) {
    return OrganizationAdminSummary(
      id: json['id'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String?,
      adminCode: json['adminCode'] as String? ?? '',
      isActive: json['isActive'] == true,
      createdAt: json['createdAt'] as String? ?? '',
      lastLoginAt: json['lastLoginAt'] as String?,
      propertyCount: (json['propertyCount'] as num?)?.toInt() ?? 0,
      propertyNames: (json['propertyNames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
      totalBeds: (json['totalBeds'] as num?)?.toInt() ?? 0,
      occupiedBeds: (json['occupiedBeds'] as num?)?.toInt() ?? 0,
      availableBeds: (json['availableBeds'] as num?)?.toInt() ?? 0,
      totalTenants: (json['totalTenants'] as num?)?.toInt() ?? 0,
      rentCollected: (json['rentCollected'] as num?)?.toDouble() ?? 0.0,
      rentPending: (json['rentPending'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class AdminCreatedPayload {
  final OrganizationAdminSummary admin;
  final String tempPassword;

  AdminCreatedPayload({
    required this.admin,
    required this.tempPassword,
  });

  factory AdminCreatedPayload.fromJson(Map<String, dynamic> json) {
    return AdminCreatedPayload(
      admin: OrganizationAdminSummary.fromJson(json['admin'] as Map<String, dynamic>),
      tempPassword: json['tempPassword'] as String? ?? '',
    );
  }
}

class OrganizationPropertyItem {
  final String id;
  final String name;
  final String? description;
  final String address;
  final String city;
  final String state;
  final String pincode;
  final int totalFloors;
  final bool isActive;
  final String adminId;
  final String adminName;
  final String adminCode;
  final String? upiId;
  final String? upiPayeeName;
  final double platformFee;
  final String? platformFeeUpiId;
  final String? platformFeePayeeName;
  final double monthlyPlatformFeeCollected;
  final double platformFeePaid;
  final String? platformFeeBillingMonth;
  final int totalRooms;
  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int totalTenants;
  final int coOwnersCount;
  final bool electricityCalculatorEnabled;
  final double electricityCostPerUnit;
  final String genderPolicy;

  OrganizationPropertyItem({
    required this.id,
    required this.name,
    this.description,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.totalFloors,
    this.isActive = true,
    required this.adminId,
    required this.adminName,
    required this.adminCode,
    this.upiId,
    this.upiPayeeName,
    this.platformFee = 9.0,
    this.platformFeeUpiId,
    this.platformFeePayeeName,
    this.monthlyPlatformFeeCollected = 0.0,
    this.platformFeePaid = 0.0,
    this.platformFeeBillingMonth,
    required this.totalRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.totalTenants,
    this.coOwnersCount = 0,
    this.electricityCalculatorEnabled = false,
    this.electricityCostPerUnit = 0.0,
    this.genderPolicy = 'BOTH',
  });

  factory OrganizationPropertyItem.fromJson(Map<String, dynamic> json) {
    return OrganizationPropertyItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      totalFloors: (json['totalFloors'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] != false,
      adminId: json['adminId'] as String? ?? '',
      adminName: json['adminName'] as String? ?? '',
      adminCode: json['adminCode'] as String? ?? '',
      upiId: json['upiId'] as String?,
      upiPayeeName: json['upiPayeeName'] as String?,
      platformFee: (json['platformFee'] as num?)?.toDouble() ?? 9.0,
      platformFeeUpiId: json['platformFeeUpiId'] as String?,
      platformFeePayeeName: json['platformFeePayeeName'] as String?,
      monthlyPlatformFeeCollected: (json['monthlyPlatformFeeCollected'] as num?)?.toDouble() ?? 0.0,
      platformFeePaid: (json['platformFeePaid'] as num?)?.toDouble() ?? 0.0,
      platformFeeBillingMonth: json['platformFeeBillingMonth'] as String?,
      totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
      totalBeds: (json['totalBeds'] as num?)?.toInt() ?? 0,
      occupiedBeds: (json['occupiedBeds'] as num?)?.toInt() ?? 0,
      availableBeds: (json['availableBeds'] as num?)?.toInt() ?? 0,
      totalTenants: (json['totalTenants'] as num?)?.toInt() ?? 0,
      coOwnersCount: (json['coOwnersCount'] as num?)?.toInt() ?? 0,
      electricityCalculatorEnabled: json['electricityCalculatorEnabled'] == true,
      electricityCostPerUnit: (json['electricityCostPerUnit'] as num?)?.toDouble() ?? 0.0,
      genderPolicy: json['genderPolicy'] as String? ?? 'BOTH',
    );
  }
}

class OrganizationPropertyOwnerItem {
  final String id;
  final String userId;
  final String propertyId;
  final String name;
  final String phoneNumber;
  final String? email;
  final String role;
  final bool isPrimary;
  final bool isActive;

  OrganizationPropertyOwnerItem({
    required this.id,
    required this.userId,
    required this.propertyId,
    required this.name,
    required this.phoneNumber,
    this.email,
    required this.role,
    required this.isPrimary,
    required this.isActive,
  });

  factory OrganizationPropertyOwnerItem.fromJson(Map<String, dynamic> json) {
    return OrganizationPropertyOwnerItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      propertyId: json['propertyId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phoneNumber: json['phoneNumber'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'CO_OWNER',
      isPrimary: json['isPrimary'] == true,
      isActive: json['isActive'] != false,
    );
  }
}

class OrganizationBedItem {
  final String id;
  final String roomId;
  final String bedLabel;
  final String status;
  final String? tenantName;

  OrganizationBedItem({
    required this.id,
    required this.roomId,
    required this.bedLabel,
    required this.status,
    this.tenantName,
  });

  factory OrganizationBedItem.fromJson(Map<String, dynamic> json) {
    return OrganizationBedItem(
      id: json['id'] as String? ?? '',
      roomId: json['roomId'] as String? ?? '',
      bedLabel: json['bedLabel'] as String? ?? '',
      status: json['status'] as String? ?? 'AVAILABLE',
      tenantName: json['tenantName'] as String?,
    );
  }
}

class OrganizationRoomItem {
  final String id;
  final String propertyId;
  final String roomNumber;
  final String floorNumber;
  final int capacity;
  final String roomType;
  final String foodOption;
  final double monthlyRentWithFood;
  final double monthlyRentWithoutFood;
  final String status;
  final int occupiedBeds;
  final int availableBeds;
  final List<OrganizationBedItem> beds;

  OrganizationRoomItem({
    required this.id,
    required this.propertyId,
    required this.roomNumber,
    required this.floorNumber,
    required this.capacity,
    required this.roomType,
    required this.foodOption,
    required this.monthlyRentWithFood,
    required this.monthlyRentWithoutFood,
    required this.status,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.beds,
  });

  factory OrganizationRoomItem.fromJson(Map<String, dynamic> json) {
    return OrganizationRoomItem(
      id: json['id'] as String? ?? '',
      propertyId: json['propertyId'] as String? ?? '',
      roomNumber: json['roomNumber'] as String? ?? '',
      floorNumber: json['floorNumber'] as String? ?? '',
      capacity: (json['capacity'] as num?)?.toInt() ?? 0,
      roomType: json['roomType'] as String? ?? 'NON_AC',
      foodOption: json['foodOption'] as String? ?? 'WITH_AND_WITHOUT_FOOD',
      monthlyRentWithFood: (json['monthlyRentWithFood'] as num?)?.toDouble() ?? 0.0,
      monthlyRentWithoutFood: (json['monthlyRentWithoutFood'] as num?)?.toDouble() ?? 0.0,
      status: json['status'] as String? ?? 'EMPTY',
      occupiedBeds: (json['occupiedBeds'] as num?)?.toInt() ?? 0,
      availableBeds: (json['availableBeds'] as num?)?.toInt() ?? 0,
      beds: (json['beds'] as List<dynamic>?)
              ?.map((b) => OrganizationBedItem.fromJson(b as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class DeletionPreview {
  final int propertiesCount;
  final int roomsCount;
  final int bedsCount;
  final int tenantsCount;
  final int coOwnersCount;
  final int paymentsCount;

  DeletionPreview({
    required this.propertiesCount,
    required this.roomsCount,
    required this.bedsCount,
    required this.tenantsCount,
    required this.coOwnersCount,
    required this.paymentsCount,
  });

  factory DeletionPreview.fromJson(Map<String, dynamic> json) {
    return DeletionPreview(
      propertiesCount: (json['propertiesCount'] as num?)?.toInt() ?? 0,
      roomsCount: (json['roomsCount'] as num?)?.toInt() ?? 0,
      bedsCount: (json['bedsCount'] as num?)?.toInt() ?? 0,
      tenantsCount: (json['tenantsCount'] as num?)?.toInt() ?? 0,
      coOwnersCount: (json['coOwnersCount'] as num?)?.toInt() ?? 0,
      paymentsCount: (json['paymentsCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class OrgPlatformFeeSettlementItem {
  final String id;
  final String propertyId;
  final String adminId;
  final String billingMonth;
  final double amountPaid;
  final String paymentMode;
  final String? referenceId;
  final String? notes;
  final String paidAt;
  final String? recordedBy;

  OrgPlatformFeeSettlementItem({
    required this.id,
    required this.propertyId,
    required this.adminId,
    required this.billingMonth,
    required this.amountPaid,
    required this.paymentMode,
    this.referenceId,
    this.notes,
    required this.paidAt,
    this.recordedBy,
  });

  factory OrgPlatformFeeSettlementItem.fromJson(Map<String, dynamic> json) {
    return OrgPlatformFeeSettlementItem(
      id: json['id'] as String? ?? '',
      propertyId: json['propertyId'] as String? ?? '',
      adminId: json['adminId'] as String? ?? '',
      billingMonth: json['billingMonth'] as String? ?? '',
      amountPaid: (json['amountPaid'] as num?)?.toDouble() ?? 0.0,
      paymentMode: json['paymentMode'] as String? ?? 'UPI',
      referenceId: json['referenceId'] as String?,
      notes: json['notes'] as String?,
      paidAt: json['paidAt'] as String? ?? '',
      recordedBy: json['recordedBy'] as String?,
    );
  }
}

class OrganizationPropertyPlatformFeeSummary {
  final String propertyId;
  final String propertyName;
  final String adminId;
  final String adminName;
  final String adminCode;
  final String billingMonth;
  final double feePerTenant;
  final String? platformFeeUpiId;
  final String? platformFeePayeeName;
  final double totalCollected;
  final double totalSettled;
  final double pendingAmount;
  final int tenantsContributed;
  final List<String> availableMonths;
  final List<OrgPlatformFeeSettlementItem> settlements;

  OrganizationPropertyPlatformFeeSummary({
    required this.propertyId,
    required this.propertyName,
    required this.adminId,
    required this.adminName,
    required this.adminCode,
    required this.billingMonth,
    required this.feePerTenant,
    this.platformFeeUpiId,
    this.platformFeePayeeName,
    required this.totalCollected,
    required this.totalSettled,
    required this.pendingAmount,
    required this.tenantsContributed,
    this.availableMonths = const [],
    required this.settlements,
  });

  factory OrganizationPropertyPlatformFeeSummary.fromJson(Map<String, dynamic> json) {
    return OrganizationPropertyPlatformFeeSummary(
      propertyId: json['propertyId'] as String? ?? '',
      propertyName: json['propertyName'] as String? ?? '',
      adminId: json['adminId'] as String? ?? '',
      adminName: json['adminName'] as String? ?? '',
      adminCode: json['adminCode'] as String? ?? '',
      billingMonth: json['billingMonth'] as String? ?? '',
      feePerTenant: (json['feePerTenant'] as num?)?.toDouble() ?? 9.0,
      platformFeeUpiId: json['platformFeeUpiId'] as String?,
      platformFeePayeeName: json['platformFeePayeeName'] as String?,
      totalCollected: (json['totalCollected'] as num?)?.toDouble() ?? 0.0,
      totalSettled: (json['totalSettled'] as num?)?.toDouble() ?? 0.0,
      pendingAmount: (json['pendingAmount'] as num?)?.toDouble() ?? 0.0,
      tenantsContributed: (json['tenantsContributed'] as num?)?.toInt() ?? 0,
      availableMonths: (json['availableMonths'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      settlements: (json['settlements'] as List<dynamic>?)
              ?.map((s) => OrgPlatformFeeSettlementItem.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Builds the onboarding WhatsApp credentials message for an Admin in plain text.
String buildAdminCredentialsMessage({
  required String orgName,
  required String adminName,
  required String adminCode,
  required String phone,
  required String password,
  String propertyName = '',
}) {
  final propLine = propertyName.trim().isNotEmpty
      ? '• Assigned Property: ${propertyName.trim()}\n\n'
      : '';

  final orgDisplay = orgName.trim().isNotEmpty ? orgName.trim() : 'Organization';

  return Uri.encodeComponent(
    'Welcome to $orgDisplay!\n\n'
    'Dear $adminName,\n\n'
    'Your Admin account has been created on Remaki by $orgDisplay management. You can now log in to the Remaki Admin Portal to manage your PG properties, rooms, beds, and tenants.\n\n'
    'Login Credentials\n'
    '• Admin Code: $adminCode\n'
    '• Registered Mobile: $phone\n'
    '• Password: $password\n\n'
    '$propLine'
    'Download the Remaki App\n'
    'Android: https://play.google.com/store/apps/details?id=com.remaki.app\n'
    'iOS / Web: https://remaki-flutter.vercel.app\n\n'
    'How to Get Started\n'
    '1. Open the Remaki app.\n'
    '2. Log in using your registered mobile number and password above.\n'
    '3. You may change your password anytime under the More tab.\n\n'
    'Please keep your credentials secure.\n\n'
    'Regards,\n'
    '$orgDisplay Management'
  );
}

