package io.github.puzzle4286svg.lifestring

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen task switcher (D49): the eight grid tiles. The tile images and
 * activity ids are written by the Dart side (SwitcherWidget.sync); a tap
 * sends timetracker://switch?id=<id> to the Dart tap handler in the
 * background, so switching never opens the app.
 */
class SwitcherWidgetProvider : HomeWidgetProvider() {
    private val tiles = intArrayOf(
        R.id.tile1, R.id.tile2, R.id.tile3, R.id.tile4,
        R.id.tile5, R.id.tile6, R.id.tile7, R.id.tile8,
    )

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val views = RemoteViews(context.packageName, R.layout.switcher_widget)
        tiles.forEachIndexed { index, viewId ->
            val position = index + 1
            val id = widgetData.getString("slot_${position}_id", null)
            val bitmap = widgetData.getString("slot_${position}_image", null)
                ?.let { BitmapFactory.decodeFile(it) }
            if (id == null || bitmap == null) {
                views.setViewVisibility(viewId, View.INVISIBLE)
                return@forEachIndexed
            }
            views.setViewVisibility(viewId, View.VISIBLE)
            views.setImageViewBitmap(viewId, bitmap)
            views.setOnClickPendingIntent(
                viewId,
                HomeWidgetBackgroundIntent.getBroadcast(
                    context,
                    Uri.parse("timetracker://switch?id=$id"),
                ),
            )
        }
        appWidgetManager.updateAppWidget(appWidgetIds, views)
    }
}
