package pe.upla.nexo.nexo

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class PaymentWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { id ->
            val views = RemoteViews(context.packageName, R.layout.widget_payment).apply {
                setTextViewText(R.id.pay_amount, widgetData.getString("pay_amount", ""))
                setTextViewText(
                    R.id.pay_desc,
                    widgetData.getString("pay_desc", "Sin deudas")
                )
                setTextViewText(R.id.pay_due, widgetData.getString("pay_due", ""))
                val intent = HomeWidgetLaunchIntent.getActivity(
                    context, MainActivity::class.java
                )
                setOnClickPendingIntent(R.id.widget_root, intent)
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
