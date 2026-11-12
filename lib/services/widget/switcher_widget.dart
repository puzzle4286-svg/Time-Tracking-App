import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../app/theme/app_theme.dart';
import '../../database/app_database.dart';
import '../../models/activity.dart';
import '../../models/activity_icons.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../repositories/time_entry_repository.dart';
import '../../util/clock.dart';
import '../../widgets/activities/activity_tile.dart';
import '../tracking/tracking_service.dart';

/// The home-screen task switcher (D49): the eight grid tiles, nothing else.
/// Tapping a tile switches to it without opening the app.
///
/// Each tile is drawn here as a PNG (same look as in the app, Neon
/// included) and handed to the Android provider `SwitcherWidgetProvider`
/// through home_widget's storage, together with the activity id. A tap
/// sends `timetracker://switch?id=<id>` to [onSwitcherTap], which runs in
/// a background Dart isolate and uses the normal [TrackingService.switchTo].
abstract final class SwitcherWidget {
  static const androidProvider =
      'io.github.puzzle4286svg.time_tracker.SwitcherWidgetProvider';

  /// Logical size of one tile image, including [padding] on every side.
  ///
  /// The shape of one slot when the widget is 4 x 1 cells (about 71 x 37 dp
  /// on the developer's phone), so the tiles fill the frame.
  static const tileSize = Size(100, 52);

  /// Gap around the tile; the Neon glow must fade out inside it, anything
  /// beyond would be cut off in a hard square.
  static const padding = 4.0;

  // Shown about 71 dp wide (about 213 px on a 3x screen).
  static const pixelRatio = 2.5;

  static String idKey(int position) => 'slot_${position}_id';
  static String imageKey(int position) => 'slot_${position}_image';

  /// Registers the tap handler; call once at app start (Android only).
  static Future<void> register() =>
      HomeWidget.registerInteractivityCallback(onSwitcherTap);

  /// Redraws the widget from the database. Errors are swallowed: the widget
  /// is a convenience and must never break the app.
  static Future<void> sync(DatabaseExecutor db) async {
    if (!Platform.isAndroid) return;
    try {
      final state = await SwitcherState.load(db);
      final scheme = state.colorScheme;
      for (var position = 1; position <= 8; position++) {
        final activity = state.at(position);
        if (activity == null) {
          await HomeWidget.saveWidgetData<String>(idKey(position), null);
          await HomeWidget.saveWidgetData<String>(imageKey(position), null);
          continue;
        }
        final png = await renderTile(
          activity,
          active: activity.id == state.activeId,
          scheme: scheme,
          neon: state.neon,
        );
        await HomeWidget.saveFile(imageKey(position), png, extension: 'png');
        await HomeWidget.saveWidgetData<String>(
          idKey(position),
          '${activity.id}',
        );
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: androidProvider);
    } on Object catch (e) {
      debugPrint('Switcher widget update failed: $e');
    }
  }

  /// One tile as PNG bytes, drawn like [ActivityTile].
  static Future<Uint8List> renderTile(
    Activity activity, {
    required bool active,
    required ColorScheme scheme,
    required bool neon,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(pixelRatio);
    paintTile(canvas, activity, active: active, scheme: scheme, neon: neon);
    final image = await recorder.endRecording().toImage(
      (tileSize.width * pixelRatio).round(),
      (tileSize.height * pixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  /// Paints one tile into a [tileSize] area (logical pixels).
  static void paintTile(
    Canvas canvas,
    Activity activity, {
    required bool active,
    required ColorScheme scheme,
    required bool neon,
  }) {
    const radius = Radius.circular(11);
    final color = Color(activity.color);
    final rect = Offset.zero & tileSize;
    final tile = RRect.fromRectAndRadius(rect.deflate(padding), radius);

    if (active && neon) {
      // Tighter than the app's two-layer glow (Neon.boxGlowFor), so it fits
      // in [padding]: sigma 1.4 fades out within about 4 px.
      canvas.drawRRect(
        tile.inflate(0.5),
        Paint()
          ..color = color.withValues(alpha: 0.85)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }
    canvas.drawRRect(
      tile,
      Paint()
        ..color = ActivityTile.fillFor(scheme, activity, active, neon: neon),
    );
    if (active) {
      canvas.drawRRect(
        tile.deflate(1.5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = scheme.onSurface,
      );
    } else if (neon) {
      canvas.drawRRect(
        tile.deflate(0.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color.withValues(alpha: 0.6),
      );
    }

    final foreground = ActivityTile.foregroundFor(
      scheme,
      activity,
      active,
      neon: neon,
    );
    final icon = activityIcon(activity.icon);
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      text: icon != null
          ? TextSpan(
              text: String.fromCharCode(icon.codePoint),
              style: TextStyle(
                fontFamily: icon.fontFamily,
                package: icon.fontPackage,
                // Larger than in the app: the widget tiles are smaller.
                fontSize: active ? 32 : 30,
                color: foreground,
              ),
            )
          : TextSpan(
              text: activity.name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
    )..layout();
    label.paint(
      canvas,
      rect.center - Offset(label.width / 2, label.height / 2),
    );
    label.dispose();
  }
}

/// What the widget shows, read straight from the database.
class SwitcherState {
  SwitcherState._(this._byPosition, this.activeId, this.colorScheme, this.neon);

  final Map<int, Activity> _byPosition;
  final int? activeId;
  final ColorScheme colorScheme;
  final bool neon;

  Activity? at(int position) => _byPosition[position];

  static Future<SwitcherState> load(DatabaseExecutor db) async {
    final settings = await SettingsRepository(db).load();
    final activities = await ActivityRepository(db).liveActivities();
    final open = await TimeEntryRepository(db).openEntry();
    return SwitcherState._(
      {for (final a in activities) a.position!: a},
      open?.activityId,
      buildTheme(settings.appearance, settings.accent).colorScheme,
      settings.neon,
    );
  }
}

/// The activity id in a tile's `timetracker://switch?id=<id>` link, or null
/// for anything else.
int? switchTargetId(Uri? uri) {
  if (uri == null || uri.scheme != 'timetracker' || uri.host != 'switch') {
    return null;
  }
  return int.tryParse(uri.queryParameters['id'] ?? '');
}

/// Runs in a background isolate when a widget tile is tapped.
@pragma('vm:entry-point')
Future<void> onSwitcherTap(Uri? uri) async {
  final id = switchTargetId(uri);
  if (id == null) return;
  // Own connection: sqflite shares single instances per path across the
  // whole process, so closing a shared one would close the app's database
  // if it is open at the same time.
  final db = await openAppDatabase(
    databaseFactory,
    p.join(await getDatabasesPath(), databaseFileName),
    singleInstance: false,
  );
  try {
    final tracking = TrackingService(db, const SystemClock());
    await tracking.reconcile();
    await tracking.switchTo(id);
    await SwitcherWidget.sync(db);
  } on Object catch (e) {
    // E.g. the activity was deleted since the widget was drawn: redraw.
    debugPrint('Switcher widget tap failed: $e');
    await SwitcherWidget.sync(db);
  } finally {
    await db.close();
  }
}
