import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../providers/auth_provider.dart';
import 'panel_card.dart';
import 'shop_onboarding_dialog.dart';
import 'sidebar_navigation.dart';

/// Displays the Instagram/Craft-style account switching sheet,
/// constrained strictly to the navbar/sidebar width and anchored to the bottom-left.
void showShopSwitchModalSheet(BuildContext context, {double? width}) {
  final appProvider = Provider.of<AppProvider>(context, listen: false);
  final authProvider = Provider.of<AuthProvider?>(context, listen: false);
  var shops = appProvider.availableShops;
  final activeSlug = appProvider.activeTenantId ?? appProvider.shop?['slug'] as String?;
  final isOwner = authProvider?.role == 'owner';

  if (shops.isEmpty && appProvider.shop != null) {
    shops = [appProvider.shop!];
  }

  final mediaQuery = MediaQuery.of(context);
  final screenWidth = mediaQuery.size.width;
  // Bounded strictly to navbar width (240px by default, or the passed width)
  final double sheetWidth = math.min(
    width ?? SidebarNavigation.expandedWidth,
    screenWidth,
  );

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Switch Account',
    barrierColor: Colors.black.withOpacity(0.25),
    transitionDuration: const Duration(milliseconds: 180),
    transitionBuilder: (dialogContext, anim1, anim2, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic)),
        child: FadeTransition(opacity: anim1, child: child),
      );
    },
    pageBuilder: (dialogContext, _, __) {
      return Align(
        alignment: Alignment.bottomLeft,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: sheetWidth,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(2, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header: "Switch Account"
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12, top: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Switch Account',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(),
                            borderRadius: BorderRadius.circular(12),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Shop / Account items
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: shops.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, index) {
                          final s = shops[index];
                          final slug = s['slug'] as String? ?? s['id']?.toString() ?? '';
                          final name = s['name'] as String? ?? 'Shop';
                          final role = (s['role'] as String? ?? '').toUpperCase();
                          final email = s['email'] as String? ?? authProvider?.userEmail ?? '';
                          final subtitle = email.isNotEmpty ? email : (role.isNotEmpty ? role : slug);
                          final isSelected = slug == activeSlug;

                          return InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(dialogContext).pop();
                              if (slug != activeSlug) {
                                appProvider.switchShop(slug);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: isSelected
                                    ? Border.all(color: const Color(0xFF2563EB), width: 1.5)
                                    : Border.all(color: Colors.transparent, width: 1.5),
                              ),
                              child: Row(
                                children: [
                                  // Avatar with presence indicator dot
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 17,
                                        backgroundColor: isSelected
                                            ? const Color(0xFFDBEAFE)
                                            : const Color(0xFFF1EFEA),
                                        child: Text(
                                          initialsFor(name),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? const Color(0xFF2563EB)
                                                : const Color(0xFF182C4F),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: -1,
                                        top: -1,
                                        child: Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),

                                  // Name and Subtitle
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF141A24),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          subtitle,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Active checkmark
                                  if (isSelected)
                                    const Padding(
                                      padding: EdgeInsets.only(left: 4),
                                      child: Icon(
                                        Icons.check_rounded,
                                        size: 18,
                                        color: Color(0xFF2563EB),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),
                    const Divider(height: 1, color: Color(0xFFF1EFEA)),
                    const SizedBox(height: 6),

                    // "Add Account" action
                    if (isOwner)
                      InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          Navigator.of(dialogContext).pop();
                          showDialog<void>(
                            context: context,
                            barrierDismissible: true,
                            builder: (_) => const ShopOnboardingDialog(),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          child: Row(
                            children: [
                              Icon(Icons.person_add_alt_outlined, size: 19, color: Color(0xFF475569)),
                              SizedBox(width: 10),
                              Text(
                                'Add Account',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),


                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
