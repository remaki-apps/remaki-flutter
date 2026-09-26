import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Base shimmer effect wrapper with customizable colors.
class AppShimmer extends StatelessWidget {
  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  const AppShimmer({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: baseColor ?? const Color(0xFFE2E8F0),
      highlightColor: highlightColor ?? const Color(0xFFF8FAFC),
      child: child,
    );
  }
}

/// Shimmer placeholder container with optional rounded corners.
class ShimmerBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final EdgeInsetsGeometry? margin;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 12.0,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Shimmer circular placeholder for icons & avatars.
class ShimmerCircle extends StatelessWidget {
  final double radius;
  final EdgeInsetsGeometry? margin;

  const ShimmerCircle({
    super.key,
    required this.radius,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      margin: margin,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

// =============================================================================
// PRE-BUILT SKELETON LAYOUTS FOR ADMIN & TENANT FLOWS
// =============================================================================

/// Skeleton layout for Admin Dashboard Screen
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top PG Identity Card
            const ShimmerBox(height: 85, borderRadius: 20),
            const SizedBox(height: 16),

            // Pending Approvals Banner
            const ShimmerBox(height: 60, borderRadius: 16),
            const SizedBox(height: 20),

            // Section Header
            const ShimmerBox(width: 140, height: 20, borderRadius: 6),
            const SizedBox(height: 12),

            // Stats Grid (4 cards in 2x2 grid)
            Row(
              children: const [
                Expanded(child: ShimmerBox(height: 100, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(height: 100, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: ShimmerBox(height: 100, borderRadius: 16)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(height: 100, borderRadius: 16)),
              ],
            ),
            const SizedBox(height: 20),

            // Occupancy Summary Card
            const ShimmerBox(height: 140, borderRadius: 20),
            const SizedBox(height: 20),

            // Quick Actions Bar
            const ShimmerBox(width: 120, height: 20, borderRadius: 6),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                4,
                (index) => const Column(
                  children: [
                    ShimmerCircle(radius: 28),
                    SizedBox(height: 8),
                    ShimmerBox(width: 50, height: 12, borderRadius: 4),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Recent Transactions Section Header
            const ShimmerBox(width: 160, height: 20, borderRadius: 6),
            const SizedBox(height: 12),

            // Recent Payment Item List
            ...List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: ShimmerBox(height: 72, borderRadius: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Tenants List Screen
class TenantsListSkeleton extends StatelessWidget {
  const TenantsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Header Summary Shimmer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 24, borderRadius: 6),
                  SizedBox(height: 6),
                  ShimmerBox(width: 180, height: 14, borderRadius: 4),
                ],
              ),
              ShimmerBox(width: 110, height: 36, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 16),

          // Search Bar
          const ShimmerBox(height: 48, borderRadius: 14),
          const SizedBox(height: 12),

          // Filter Chips
          Row(
            children: const [
              ShimmerBox(width: 70, height: 32, borderRadius: 20),
              SizedBox(width: 8),
              ShimmerBox(width: 70, height: 32, borderRadius: 20),
              SizedBox(width: 8),
              ShimmerBox(width: 80, height: 32, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 16),

          // Tenant List Cards
          ...List.generate(
            5,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: ShimmerBox(height: 110, borderRadius: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Rooms List Screen
class RoomsGridSkeleton extends StatelessWidget {
  const RoomsGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Header & Stats bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              ShimmerBox(width: 120, height: 24, borderRadius: 6),
              ShimmerBox(width: 100, height: 36, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 14),

          // Search & Filter
          const ShimmerBox(height: 48, borderRadius: 14),
          const SizedBox(height: 14),

          // Stats Chips
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 40, borderRadius: 12)),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(height: 40, borderRadius: 12)),
              SizedBox(width: 8),
              Expanded(child: ShimmerBox(height: 40, borderRadius: 12)),
            ],
          ),
          const SizedBox(height: 20),

          // Floor Header
          const ShimmerBox(width: 130, height: 20, borderRadius: 6),
          const SizedBox(height: 12),

          // Room Cards Grid (2 columns)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 4,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemBuilder: (context, index) => const ShimmerBox(height: 140, borderRadius: 16),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Rent Overview Screen
class RentOverviewSkeleton extends StatelessWidget {
  const RentOverviewSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Rent/Bill Toggle Segment
          const ShimmerBox(height: 48, borderRadius: 14),
          const SizedBox(height: 16),

          // Primary Collection Card
          const ShimmerBox(height: 160, borderRadius: 22),
          const SizedBox(height: 16),

          // Stat Breakdown Grid (2x2)
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 80, borderRadius: 16)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 80, borderRadius: 16)),
            ],
          ),
          const SizedBox(height: 20),

          // Tenant List Header
          const ShimmerBox(width: 150, height: 20, borderRadius: 6),
          const SizedBox(height: 12),

          // List Items
          ...List.generate(
            4,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: ShimmerBox(height: 85, borderRadius: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Payment History Screen
class PaymentHistorySkeleton extends StatelessWidget {
  const PaymentHistorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Total Collection Header Banner
          const ShimmerBox(height: 110, borderRadius: 20),
          const SizedBox(height: 16),

          // Filter & Search bar
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 46, borderRadius: 12)),
              SizedBox(width: 10),
              ShimmerBox(width: 46, height: 46, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 16),

          // List of payments
          ...List.generate(
            5,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: ShimmerBox(height: 80, borderRadius: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Pending Approvals Screen
class PendingApprovalsSkeleton extends StatelessWidget {
  const PendingApprovalsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Top info bar
          const ShimmerBox(height: 50, borderRadius: 12),
          const SizedBox(height: 16),

          // Request cards
          ...List.generate(
            4,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 14.0),
              child: ShimmerBox(height: 150, borderRadius: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Announcements Screen
class AnnouncementsSkeleton extends StatelessWidget {
  const AnnouncementsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // New Announcement Action Card
          const ShimmerBox(height: 70, borderRadius: 16),
          const SizedBox(height: 20),

          const ShimmerBox(width: 160, height: 20, borderRadius: 6),
          const SizedBox(height: 12),

          ...List.generate(
            3,
            (index) => const Padding(
              padding: EdgeInsets.only(bottom: 14.0),
              child: ShimmerBox(height: 130, borderRadius: 18),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton for Unpaid Tenants & Available Beds Screens
class SimpleListSkeleton extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SimpleListSkeleton({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 90,
  });

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          const ShimmerBox(height: 70, borderRadius: 16),
          const SizedBox(height: 16),
          ...List.generate(
            itemCount,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: ShimmerBox(height: itemHeight, borderRadius: 16),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton layout for Tenant Flow Dashboard Tab
class TenantHomeSkeleton extends StatelessWidget {
  const TenantHomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tenant Welcome Header Card
            const ShimmerBox(height: 90, borderRadius: 22),
            const SizedBox(height: 16),

            // Due Amount / Rent Status Hero Banner
            const ShimmerBox(height: 180, borderRadius: 24),
            const SizedBox(height: 20),

            // Quick Actions Section Header
            const ShimmerBox(width: 130, height: 18, borderRadius: 6),
            const SizedBox(height: 12),

            // Quick Actions 4 Grid
            Row(
              children: const [
                Expanded(child: ShimmerBox(height: 85, borderRadius: 18)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(height: 85, borderRadius: 18)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: const [
                Expanded(child: ShimmerBox(height: 85, borderRadius: 18)),
                SizedBox(width: 12),
                Expanded(child: ShimmerBox(height: 85, borderRadius: 18)),
              ],
            ),
            const SizedBox(height: 24),

            // Recent Payment History Header
            const ShimmerBox(width: 160, height: 18, borderRadius: 6),
            const SizedBox(height: 12),

            ...List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12.0),
                child: ShimmerBox(height: 75, borderRadius: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton for Tenant Profile Screen
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return AppShimmer(
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Profile Header Card with Avatar
          Center(
            child: Column(
              children: const [
                ShimmerCircle(radius: 45),
                SizedBox(height: 12),
                ShimmerBox(width: 150, height: 22, borderRadius: 6),
                SizedBox(height: 6),
                ShimmerBox(width: 100, height: 14, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Detail Cards
          const ShimmerBox(height: 140, borderRadius: 18),
          const SizedBox(height: 14),
          const ShimmerBox(height: 120, borderRadius: 18),
          const SizedBox(height: 14),
          const ShimmerBox(height: 100, borderRadius: 18),
        ],
      ),
    );
  }
}
