package pe.upla.nexo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class NextClassWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_next_class).apply {
                setTextViewText(
                    R.id.next_title,
                    widgetData.getString("next_title", "Sin clases próximas")
                )
                setTextViewText(R.id.next_sub, widgetData.getString("next_sub", ""))
                setTextViewText(R.id.next_when, widgetData.getString("next_when", ""))
                val intent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, intent)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
