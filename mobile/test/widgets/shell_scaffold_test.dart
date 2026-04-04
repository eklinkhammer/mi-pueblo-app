import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:fence/l10n/app_localizations.dart';
import 'package:fence/providers/auth_provider.dart';
import 'package:fence/widgets/shell_scaffold.dart';
import '../helpers/mocks.dart';


void main() {
  GoRouter createRouter({String initialLocation = '/map'}) {
    return GoRouter(
      initialLocation: initialLocation,
      routes: [
        ShellRoute(
          builder: (_, __, child) => ShellScaffold(child: child),
          routes: [
            GoRoute(
              path: '/map',
              builder: (_, __) => const Text('Map Page'),
            ),
            GoRoute(
              path: '/groups',
              builder: (_, __) => const Text('Groups Page'),
            ),
            GoRoute(
              path: '/settings',
              builder: (_, __) => const Text('Settings Page'),
            ),
          ],
        ),
      ],
    );
  }

  late MockApiClient mockApi;

  setUp(() {
    mockApi = MockApiClient();
    when(() => mockApi.getAccessToken()).thenAnswer((_) async => 'valid-token');
    when(() => mockApi.getMe()).thenAnswer((_) async {
      return Response(
        data: {
          'user': {
            'id': 'uid',
            'email': 'a@b.com',
            'display_name': 'A',
            'inserted_at': '2025-01-01T00:00:00Z',
          }
        },
        statusCode: 200,
        requestOptions: RequestOptions(path: '/fake'),
      );
    });
  });

  group('ShellScaffold', () {
    testWidgets('shows 3 navigation destinations when authenticated',
        (tester) async {
      final router = createRouter();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi, MockLocalNotificationService())),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationDestination), findsNWidgets(3));
      expect(find.text('Map'), findsOneWidget);
      expect(find.text('Groups'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('correct tab selected for /map route', (tester) async {
      final router = createRouter(initialLocation: '/map');
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi, MockLocalNotificationService())),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);
    });

    testWidgets('correct tab selected for /groups route', (tester) async {
      final router = createRouter(initialLocation: '/groups');
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi, MockLocalNotificationService())),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 1);
    });

    testWidgets('correct tab selected for /settings route', (tester) async {
      final router = createRouter(initialLocation: '/settings');
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(mockApi, MockLocalNotificationService())),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      final navBar =
          tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 2);
    });

    testWidgets('no bottom nav for unauthenticated users', (tester) async {
      final unauthApi = MockApiClient();
      // ignore: unnecessary_lambdas
      when(() => unauthApi.getAccessToken()).thenAnswer((_) async => null);

      final router = createRouter();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => AuthNotifier(unauthApi, MockLocalNotificationService())),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
    });
  });
}
