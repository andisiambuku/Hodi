import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/app_bottom_nav.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/patients/presentation/patients_screen.dart';
import '../features/patients/presentation/register_patient_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/sync/hub/presentation/sync_hub_screen.dart';
import '../features/sync/history/presentation/sync_history_screen.dart';
import '../features/sync/pending_changes/presentation/pending_changes_screen.dart';
import '../features/visits/presentation/record_visit_screen.dart';
import '../features/visits/presentation/visit_detail_screen.dart';
import '../features/visits/presentation/visits_screen.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Home is the top of the Visits branch (`/visits`); the day's list lives at
/// `/visits/today`. See README for the rationale.
GoRouter buildRouter() {
  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/visits',
    routes: [
      GoRoute(path: '/', redirect: (_, _) => '/visits'),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/visits',
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'today',
                    builder: (context, _) =>
                        VisitsScreen(onBack: () => context.pop()),
                  ),
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const RecordVisitScreen(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) =>
                        VisitDetailScreen(visitId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/patients',
                builder: (_, _) => const PatientsScreen(),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => const RegisterPatientScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/sync',
                builder: (_, _) => const SyncHubScreen(),
                routes: [
                  GoRoute(
                    path: 'pending',
                    builder: (_, _) => const PendingChangesScreen(),
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (_, _) => const SyncHistoryScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: AppBottomNav(
        currentIndex: shell.currentIndex,
        // Re-tapping the active tab pops back to its root.
        onTap: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
