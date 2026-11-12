import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/app/theme/app_theme.dart';
import 'package:time_tracker/models/activity.dart';
import 'package:time_tracker/models/app_settings.dart';
import 'package:time_tracker/repositories/settings_repository.dart';
import 'package:time_tracker/services/widget/switcher_widget.dart';
import 'package:time_tracker/widgets/activities/activity_tile.dart';

import '../../support/tracking_fixture.dart';

Activity _activity({String? icon, String name = 'Work'}) => Activity(
  id: 7,
  name: name,
  color: 0xFFFF9800,
  position: 1,
  isSystem: false,
  createdAt: DateTime.utc(2026),
  deletedAt: null,
  icon: icon,
);

/// Decoded RGBA pixels of [png].
Future<(ByteData, int)> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData())!;
  final width = image.width;
  image.dispose();
  return (data, width);
}

Color _at(ByteData data, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return Color.fromARGB(
    data.getUint8(i + 3),
    data.getUint8(i),
    data.getUint8(i + 1),
    data.getUint8(i + 2),
  );
}

/// The pixel at logical [at].
Future<Color> _pixel(Uint8List png, Offset at) async {
  final (data, width) = await _decode(png);
  return _at(
    data,
    width,
    (at.dx * SwitcherWidget.pixelRatio).round(),
    (at.dy * SwitcherWidget.pixelRatio).round(),
  );
}

/// PNG pixels have 8 bits per channel.
bool _close(Color a, Color b) =>
    (a.r - b.r).abs() < 2 / 255 &&
    (a.g - b.g).abs() < 2 / 255 &&
    (a.b - b.b).abs() < 2 / 255 &&
    (a.a - b.a).abs() < 2 / 255;

Matcher _closeTo(Color expected) =>
    predicate<Color>((c) => _close(c, expected), 'close to $expected');

/// Pixels in the central 24 x 24 area that differ from [fill].
Future<int> _drawnInCentre(Uint8List png, Color fill) async {
  final (data, width) = await _decode(png);
  final c =
      SwitcherWidget.tileSize.center(Offset.zero) * SwitcherWidget.pixelRatio;
  const half = 12 * SwitcherWidget.pixelRatio;
  var count = 0;
  for (var y = (c.dy - half).round(); y < c.dy + half; y++) {
    for (var x = (c.dx - half).round(); x < c.dx + half; x++) {
      if (!_close(_at(data, width, x, y), fill)) count++;
    }
  }
  return count;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final scheme = buildTheme(
    AppearanceMode.dark,
    AccentPalette.teal,
  ).colorScheme;

  Future<Uint8List> render(
    Activity a, {
    bool active = false,
    bool neon = false,
  }) =>
      SwitcherWidget.renderTile(a, active: active, scheme: scheme, neon: neon);

  group('tile image', () {
    test('has the widget tile size', () async {
      final png = await render(_activity(icon: 'work'));
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      expect(
        image.width,
        SwitcherWidget.tileSize.width * SwitcherWidget.pixelRatio,
      );
      expect(
        image.height,
        SwitcherWidget.tileSize.height * SwitcherWidget.pixelRatio,
      );
    });

    test('is filled like the app tile: full colour when active, muted '
        'otherwise', () async {
      final a = _activity();
      // A point inside the tile but away from the centred label.
      const probe = Offset(SwitcherWidget.padding + 6, 26);
      expect(
        await _pixel(await render(a, active: true), probe),
        _closeTo(ActivityTile.fillFor(scheme, a, true)),
      );
      expect(
        await _pixel(await render(a), probe),
        _closeTo(ActivityTile.fillFor(scheme, a, false)),
      );
    });

    test('glows outside the tile only with Neon on the active tile', () async {
      final a = _activity(icon: 'work');
      // In the padding, beside the tile edge.
      const outside = Offset(2, 26);
      expect((await _pixel(await render(a, active: true), outside)).a, 0);
      expect((await _pixel(await render(a, neon: true), outside)).a, 0);
      expect(
        (await _pixel(await render(a, active: true, neon: true), outside)).a,
        greaterThan(0),
      );
    });

    test('draws the icon or the first letter in the centre', () async {
      for (final a in [_activity(icon: 'work'), _activity(name: 'reading')]) {
        for (final active in [false, true]) {
          final fill = ActivityTile.fillFor(scheme, a, active);
          expect(
            await _drawnInCentre(await render(a, active: active), fill),
            greaterThan(40),
            reason: '${a.icon ?? a.name}, active: $active',
          );
        }
      }
    });
  });

  group('state from the database', () {
    test('grid by position, the running activity and the look', () async {
      final f = await TrackingFixture.create(DateTime.utc(2026, 11, 12, 8));
      addTearDown(f.db.close);
      await SettingsRepository(
        f.db,
      ).save(const AppSettings(appearance: AppearanceMode.light, neon: true));
      await f.service.reconcile();
      f.clock.advance(const Duration(minutes: 5));
      await f.service.switchTo(f.study);

      final state = await SwitcherState.load(f.db);
      expect(state.at(1)?.id, f.freeTime);
      expect(state.at(2)?.id, f.gaming);
      expect(state.at(3)?.id, f.study);
      expect(state.at(4), isNull);
      expect(state.activeId, f.study);
      expect(state.neon, isTrue);
      expect(state.colorScheme.brightness, Brightness.light);
    });
  });

  test('tap links', () {
    expect(switchTargetId(Uri.parse('timetracker://switch?id=12')), 12);
    expect(switchTargetId(Uri.parse('timetracker://switch?id=x')), isNull);
    expect(switchTargetId(Uri.parse('timetracker://open?id=12')), isNull);
    expect(switchTargetId(Uri.parse('https://switch?id=12')), isNull);
    expect(switchTargetId(null), isNull);
  });
}
