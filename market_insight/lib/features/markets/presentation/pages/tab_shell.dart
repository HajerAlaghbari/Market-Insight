import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/localization/app_localizations.dart';
import '../../../../app/localization/locale_provider.dart';

class TabShell extends ConsumerWidget {
  final Widget child;
  const TabShell({super.key, required this.child});

  static const tabs = ['/metals', '/fx', '/news', '/crypto', '/stocks'];

  int _indexFromLocation(String location) {
    final i = tabs.indexWhere((t) => location.startsWith(t));
    return i < 0 ? 2 : i;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _indexFromLocation(location);
    final l10n = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    return Scaffold(

      /// 🔹 AppBar مع شعار التطبيق
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              "assets/images/logo.png",
              height: 28,
            ),
            const SizedBox(width: 10),
            Text(l10n.appTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.fact_check_outlined),
            tooltip: l10n.signalReview,
            onPressed: () => context.push('/signal-review'),
          ),
          IconButton(
            icon: const Icon(Icons.language),
            tooltip: l10n.language,
            onPressed: () {
              ref.read(localeProvider.notifier).toggleLocale();
            },
          ),
        ],
      ),

      body: child,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => context.go(tabs[i]),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.savings),
            label: l10n.navMetals,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.swap_horiz),
            label: l10n.navFx,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.newspaper),
            label: l10n.navNews,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.currency_bitcoin),
            label: l10n.navCrypto,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.candlestick_chart),
            label: l10n.navStocks,
          ),
        ],
      ),
    );
  }
}