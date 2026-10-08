import 'package:flutter/material.dart';
import '../core/services/push_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_text.dart';
import '../core/theme/app_theme.dart';
import '../features/home/screens/home_screen.dart';
import '../features/shops/screens/shops_screen.dart';
import '../features/booking/screens/book_service_screen.dart';
import '../features/payments/screens/payments_screen.dart';
import '../features/profile/screens/profile_screen.dart';

/// The single source of truth for the customer app navigation.
///
/// Wraps every screen with a consistent AppBar + bottom navigation, so the
/// bottom nav and chrome stay identical across the entire app.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Authenticated - register this phone for push notifications.
    PushService.init(app: 'customer');
  }

  static const _pages = <Widget>[
    HomeScreen(),
    ShopsScreen(),
    SizedBox.shrink(),
    PaymentsScreen(),
    ProfileScreen(),
  ];

  static const _items = <BottomNavItem>[
    BottomNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home'),
    BottomNavItem(
        icon: Icons.storefront_outlined,
        activeIcon: Icons.storefront_rounded,
        label: 'Providers'),
    BottomNavItem(
        icon: Icons.add_circle_outline,
        activeIcon: Icons.add_circle_rounded,
        label: 'Book',
        isCenter: true),
    BottomNavItem(
        icon: Icons.payments_outlined,
        activeIcon: Icons.payments_rounded,
        label: 'Payments'),
    BottomNavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  void _onTap(int i) {
    if (i == 2) {
      // Center button = Find Provider (immediate booking core flow).
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const BookServiceScreen()),
      );
      return;
    }
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SogoColors.surfaceMuted,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: SogoBottomNav(
        items: _items,
        currentIndex: _index,
        onTap: _onTap,
      ),
    );
  }
}

class BottomNavItem {
  const BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isCenter = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCenter;
}

class SogoBottomNav extends StatelessWidget {
  const SogoBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<BottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: SogoColors.surface,
          boxShadow: [SogoShadows.card],
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(SogoRadius.lg),
            topRight: Radius.circular(SogoRadius.lg),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: SizedBox(
          height: 68,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == currentIndex;
              if (item.isCenter) {
                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(i),
                    child: Center(
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [
                            SogoColors.primary,
                            SogoColors.primaryDark
                          ]),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Color(0x660a6e3f),
                                blurRadius: 12,
                                offset: Offset(0, 4))
                          ],
                        ),
                        child: const Icon(Icons.add_circle_rounded,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                );
              }
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(SogoRadius.md),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          color: selected
                              ? SogoColors.primary
                              : SogoColors.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontFamily: SogoText.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? SogoColors.primary
                                : SogoColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
