import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/app/app_platform.dart';
import 'package:sakuramedia/l10n/app_localizations.dart';
import 'package:sakuramedia/routes/app_navigation.dart';
import 'package:sakuramedia/routes/app_route.dart';
import 'package:sakuramedia/routes/app_route_registry.dart';
import 'package:sakuramedia/routes/app_route_target.dart';
import 'package:sakuramedia/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;
  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('zh'));
  });

  test('registry contains exactly the current route surface', () {
    expect(appRoutes.definitions.length, 109);
    expect(appRoutes.forPlatform(AppPlatform.desktop).length, 51);
    expect(appRoutes.forPlatform(AppPlatform.mobile).length, 58);

    expect(
      appRoutes.scoped(AppPlatform.desktop, AppRouteScope.outsideShell).length,
      6,
    );
    expect(
      appRoutes.scoped(AppPlatform.desktop, AppRouteScope.branchRoot).length,
      19,
    );
    expect(
      appRoutes.scoped(AppPlatform.desktop, AppRouteScope.shellLevel).length,
      26,
    );
    expect(
      appRoutes.scoped(AppPlatform.mobile, AppRouteScope.outsideShell).length,
      45,
    );
    expect(
      appRoutes.scoped(AppPlatform.mobile, AppRouteScope.branchRoot).length,
      5,
    );
    expect(
      appRoutes.scoped(AppPlatform.mobile, AppRouteScope.branchChild).length,
      8,
    );
    // 移动路由树只挂载 outsideShell 与分支，shellLevel 的移动路由不可达。
    expect(
      appRoutes.scoped(AppPlatform.mobile, AppRouteScope.shellLevel).length,
      0,
    );
    final ids = appRoutes.definitions
        .map((definition) => definition.id)
        .toSet();
    expect(ids.length, appRoutes.definitions.length);
    expect(desktopPrimaryBranchOrder.length, 19);
    expect(mobilePrimaryBranchOrder.length, 5);
    expect(mobileOverviewBranchIndex, 0);
  });

  test('definitions expose the expected navigation metadata', () {
    for (final definition in appRoutes.definitions) {
      expect(
        definition.title(l10n).trim(),
        isNotEmpty,
        reason: '${definition.id} must have a non-empty title',
      );
    }

    final desktopItems = desktopNavItems(l10n);
    expect(desktopItems.length, 22);
    expect(
      desktopItems.map((item) => item.name).toSet().length,
      desktopItems.length,
    );
    expect(desktopItems.first.sectionLabel, isNull);
    expect(
      desktopItems.skip(1).every((item) => item.sectionLabel != null),
      isTrue,
    );
    expect(desktopItems.map((item) => item.routeId).toList(), <AppRouteId>[
      AppRouteId.desktopOverview,
      AppRouteId.desktopDiscover,
      AppRouteId.desktopMovies,
      AppRouteId.desktopActors,
      AppRouteId.desktopTags,
      AppRouteId.desktopMoments,
      AppRouteId.desktopClips,
      AppRouteId.desktopPlaylists,
      AppRouteId.desktopFavorites,
      AppRouteId.desktopRecentlyPlayed,
      AppRouteId.desktopRecentViews,
      AppRouteId.desktopRatedMovies,
      AppRouteId.desktopVideos,
      AppRouteId.desktopRankings,
      AppRouteId.desktopMedia,
      AppRouteId.desktopMediaImport,
      AppRouteId.desktopDownloadTasks,
      AppRouteId.desktopActivity,
      AppRouteId.desktopMovieSubscriptions,
      AppRouteId.desktopNotifications,
      AppRouteId.desktopAgentConnect,
      AppRouteId.desktopConfiguration,
    ]);

    final mobileItems = mobileNavItems(l10n);
    expect(mobileItems.length, 5);
    expect(mobileItems.map((item) => item.routeId).toList(), <AppRouteId>[
      AppRouteId.mobileOverview,
      AppRouteId.mobileMovies,
      AppRouteId.mobileActors,
      AppRouteId.mobileRankings,
      AppRouteId.mobilePornbox,
    ]);

    var clientProxyTaps = 0;
    final drawerSections = mobileDrawerSections(
      l10n,
      onClientProxyTap: () => clientProxyTaps++,
    );
    expect(drawerSections.length, 5);
    final drawerEntries = drawerSections
        .expand((section) => section.entries)
        .toList(growable: false);
    expect(drawerEntries.length, 25);
    expect(
      drawerEntries.map((entry) => entry.key).toSet().length,
      drawerEntries.length,
    );
    for (final entry in drawerEntries) {
      if (entry.routeId case final routeId?) {
        expect(() => appRoutes.byId(routeId), returnsNormally);
      }
    }

    final clientProxyEntry = drawerEntries.singleWhere(
      (entry) => entry.key == 'client-proxy',
    );
    clientProxyEntry.onTap!();
    expect(clientProxyTaps, 1);

    final subpages = appRoutes.definitions
        .where((definition) => definition.subpageChrome != null)
        .toList(growable: false);
    expect(subpages.length, 47);
    expect(
      subpages
          .where((definition) => definition.subpageChrome!.glassChrome)
          .length,
      28,
    );
    expect(
      subpages
          .where((definition) => definition.subpageChrome!.immersive)
          .length,
      1,
    );
    expect(
      subpages
          .where((definition) => !definition.subpageChrome!.autoHideAppBar)
          .length,
      1,
    );
    expect(
      appRoutes.definitions
          .where((definition) => !definition.showTopBar)
          .length,
      1,
    );
    expect(
      appRoutes.definitions
          .where((definition) => definition.layout == AppShellLayout.immersive)
          .length,
      1,
    );
  });

  test('every route target round-trips its path template', () {
    for (final definition in appRoutes.definitions) {
      final pathParameters = <String, String>{};
      final expectedPath = definition.path.replaceAllMapped(
        RegExp(r':([A-Za-z0-9_]+)'),
        (match) {
          final name = match.group(1)!;
          pathParameters[name] = 'x';
          return 'x';
        },
      );
      final target = AppRouteTarget(
        id: definition.id,
        pathParameters: pathParameters,
      );
      expect(
        target.path,
        expectedPath,
        reason: '${definition.id} did not round-trip its path',
      );
    }
  });

  test('outbound query parameters use canonical camelCase names', () {
    for (final definition in appRoutes.definitions) {
      if (definition.queryParameters.isEmpty) {
        continue;
      }
      final queryParameters = <String, String?>{};
      for (final parameter in definition.queryParameters) {
        queryParameters[parameter.name] = switch (parameter.type) {
          AppQueryType.string =>
            parameter.defaultValue == 'all' ? 'sample' : 'sample',
          AppQueryType.integer => '1',
          AppQueryType.boolean => 'true',
        };
      }
      final pathParameters = <String, String>{};
      definition.path.replaceAllMapped(RegExp(r':([A-Za-z0-9_]+)'), (match) {
        pathParameters[match.group(1)!] = 'x';
        return 'x';
      });
      final target = AppRouteTarget(
        id: definition.id,
        pathParameters: pathParameters,
        queryParameters: queryParameters,
      );
      final parsed = Uri.parse(target.location).queryParameters;
      for (final parameter in definition.queryParameters) {
        expect(
          parsed[parameter.name],
          queryParameters[parameter.name],
          reason: '${definition.id} must emit ${parameter.name} in camelCase',
        );
        final alias = parameter.alias;
        if (alias != null) {
          expect(parsed.containsKey(alias), isFalse);
        }
      }
    }
  });

  test('canonical query values are used by public route factories', () {
    expect(
      DesktopRoutes.downloadTasks(movieNumber: 'ABC-1').location,
      contains('downloadMovieNumber=ABC-1'),
    );
    expect(
      MobileRoutes.downloadTasks(movieNumber: 'ABC-1').location,
      contains('downloadMovieNumber=ABC-1'),
    );
    expect(
      DesktopRoutes.moviePlayer(
        movieNumber: 'ABC-1',
        mediaId: 9,
        positionSeconds: 12,
      ).location,
      allOf(contains('mediaId=9'), contains('positionSeconds=12')),
    );
    expect(
      DesktopRoutes.search(query: 'hello', useOnlineSearch: true).location,
      contains('useOnlineSearch=true'),
    );
  });
}
