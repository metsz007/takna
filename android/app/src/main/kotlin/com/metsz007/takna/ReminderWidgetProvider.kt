package com.metsz007.takna

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/// Home-screen widget: paints the single next upcoming reminder (title + when)
/// from the key/values the Dart side saves at the tail of every reconcile.
/// Tapping the widget opens the app.
class ReminderWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.reminder_widget).apply {
                setTextViewText(R.id.widget_label, widgetData.getString("label", "TAKNA"))
                setTextViewText(
                    R.id.widget_title,
                    widgetData.getString("title", "Nothing scheduled"),
                )
                setTextViewText(R.id.widget_time, widgetData.getString("time", ""))
                setTextViewText(
                    R.id.widget_day,
                    widgetData.getString("day", "Tap to add a reminder"),
                )
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
