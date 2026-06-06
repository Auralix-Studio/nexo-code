package pe.upla.nexo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class TodayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_today).apply {
                setTextViewText(
                    R.id.today_list,
                    widgetData.getString("today_list", "Sin clases hoy")
                )
                setTextViewText(R.id.today_day, widgetData.getString("today_day", ""))
                val intent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, intent)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
