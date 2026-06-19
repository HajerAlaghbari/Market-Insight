import 'package:go_router/go_router.dart';

import '../features/markets/presentation/pages/tab_shell.dart';
import '../features/markets/presentation/pages/symbols_list_page.dart';
import '../features/markets/presentation/pages/symbol_details_page.dart';
import '../features/news/presentation/news_page.dart';
import '../features/signal_review/presentation/signal_review_page.dart';
import '../features/settings/presentation/settings_page.dart';

import '../features/markets/domain/entities/symbol.dart';

import '../features/auth/presentation/controllers/auth_listenable.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/verify_email_page.dart';

final _auth = AuthListenable();

final appRouter = GoRouter(
  initialLocation: '/crypto',

  refreshListenable: _auth,

  redirect: (context, state) {
    final user = _auth.user;
    final loggedIn = user != null;
    final verified = user?.emailVerified ?? false;

    final loc = state.uri.toString();

    final goingToAuth =
        loc.startsWith('/login') || loc.startsWith('/register');

    final goingToVerify = loc.startsWith('/verify-email');

    /// not logged in
    if (!loggedIn && !goingToAuth) {
      return '/login';
    }

    /// logged in but email NOT verified
    if (loggedIn && !verified && !goingToVerify) {
      return '/verify-email';
    }

    /// email verified but user still in verify page
    if (loggedIn && verified && goingToVerify) {
      return '/crypto';
    }

    /// already logged in
    if (loggedIn && goingToAuth) {
      return '/crypto';
    }

    return null;
  },

  routes: [

    /// =========================
    /// AUTH ROUTES
    /// =========================
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),

    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterPage(),
    ),

    GoRoute(
      path: '/verify-email',
      builder: (context, state) => const VerifyEmailPage(),
    ),

    /// =========================
    /// SETTINGS PAGE
    /// =========================
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsPage(),
    ),

    /// =========================
    /// MAIN APP SHELL
    /// =========================
    ShellRoute(
      builder: (context, state, child) => TabShell(child: child),
      routes: [

        GoRoute(
          path: '/crypto',
          builder: (context, state) =>
          const SymbolsListPage(category: MarketCategory.crypto),
        ),

        GoRoute(
          path: '/news',
          builder: (context, state) => const NewsPage(),
        ),

        GoRoute(
          path: '/metals',
          builder: (context, state) =>
          const SymbolsListPage(category: MarketCategory.metals),
        ),

        GoRoute(
          path: '/fx',
          builder: (context, state) =>
          const SymbolsListPage(category: MarketCategory.fx),
        ),

        GoRoute(
          path: '/stocks',
          builder: (context, state) =>
          const SymbolsListPage(category: MarketCategory.stocks),
        ),
      ],
    ),

    /// =========================
    /// SIGNAL REVIEW PAGE
    /// =========================
    GoRoute(
      path: '/signal-review',
      builder: (context, state) => const SignalReviewPage(),
    ),

    /// =========================
    /// SYMBOL DETAILS
    /// =========================
    GoRoute(
      path: '/symbol/:code',
      builder: (context, state) {
        final code = state.pathParameters['code']!;
        final name = (state.extra as Map?)?['name'] as String? ?? code;

        return SymbolDetailsPage(
          code: code,
          name: name,
        );
      },
    ),
  ],
);