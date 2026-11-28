import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../theme/tenant_theme.dart';
import '../widgets/app_shimmer.dart';

class TenantNoticesScreen extends StatefulWidget {
  const TenantNoticesScreen({super.key});

  @override
  State<TenantNoticesScreen> createState() => _TenantNoticesScreenState();
}

class _TenantNoticesScreenState extends State<TenantNoticesScreen> {
  bool _isLoading = true;
  List<dynamic> _notices = [];

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    final data = await ApiService.fetchAnnouncements(false);
    if (!mounted) return;
    setState(() {
      _notices = data;
      _isLoading = false;
    });
  }

  String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TenantTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: TenantTheme.textPrimary, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/tenant_home');
            }
          },
        ),
        title: Text(
          'Notices & Announcements',
          style: GoogleFonts.lato(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: TenantTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: AnnouncementsSkeleton(),
              )
            : _notices.isEmpty
                ? RefreshIndicator(
                    onRefresh: _loadNotices,
                    child: ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.55,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.campaign_outlined, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  'No Active Notices',
                                  style: GoogleFonts.lato(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: TenantTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Notices from PG management will appear here.',
                                  style: GoogleFonts.lato(
                                    fontSize: 13,
                                    color: TenantTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotices,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notices.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = _notices[index] as Map<String, dynamic>;
                        final heading = item['heading']?.toString() ?? 'Notice';
                        final desc = item['description']?.toString() ?? '';
                        final imageUrl = item['imageUrl']?.toString();
                        final createdStr = _formatDate(item['createdAt']?.toString());

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF2FF),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(Icons.campaign_rounded, color: Color(0xFF4F46E5), size: 18),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          heading,
                                          style: GoogleFonts.lato(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: TenantTheme.textPrimary,
                                          ),
                                        ),
                                        if (createdStr.isNotEmpty)
                                          Text(
                                            createdStr,
                                            style: GoogleFonts.lato(
                                              fontSize: 11,
                                              color: TenantTheme.textSecondary,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Text(
                                  desc,
                                  style: GoogleFonts.lato(
                                    fontSize: 13.5,
                                    height: 1.45,
                                    color: const Color(0xFF334155),
                                  ),
                                ),
                              ],
                              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
