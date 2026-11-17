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
  final String address;
  final String city;
  final String state;
  final String pincode;
  final int totalFloors;
  final String adminId;
  final String adminName;
  final String adminCode;
  final int totalRooms;
  final int totalBeds;
  final int occupiedBeds;
  final int availableBeds;
  final int totalTenants;

  OrganizationPropertyItem({
    required this.id,
    required this.name,
    required this.address,
    required this.city,
    required this.state,
    required this.pincode,
    required this.totalFloors,
    required this.adminId,
    required this.adminName,
    required this.adminCode,
    required this.totalRooms,
    required this.totalBeds,
    required this.occupiedBeds,
    required this.availableBeds,
    required this.totalTenants,
  });

  factory OrganizationPropertyItem.fromJson(Map<String, dynamic> json) {
    return OrganizationPropertyItem(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      address: json['address'] as String? ?? '',
      city: json['city'] as String? ?? '',
      state: json['state'] as String? ?? '',
      pincode: json['pincode'] as String? ?? '',
      totalFloors: (json['totalFloors'] as num?)?.toInt() ?? 0,
      adminId: json['adminId'] as String? ?? '',
      adminName: json['adminName'] as String? ?? '',
      adminCode: json['adminCode'] as String? ?? '',
      totalRooms: (json['totalRooms'] as num?)?.toInt() ?? 0,
      totalBeds: (json['totalBeds'] as num?)?.toInt() ?? 0,
      occupiedBeds: (json['occupiedBeds'] as num?)?.toInt() ?? 0,
      availableBeds: (json['availableBeds'] as num?)?.toInt() ?? 0,
      totalTenants: (json['totalTenants'] as num?)?.toInt() ?? 0,
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

