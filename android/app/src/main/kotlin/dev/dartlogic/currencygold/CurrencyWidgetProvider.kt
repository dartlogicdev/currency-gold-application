package dev.dartlogic.currencygold

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class CurrencyWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (widgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, widgetId)
        }
    }

    companion object {
        // home_widget 0.6.x speichert Daten in "HomeWidgetPreferences"
        private fun getPrefs(context: Context) =
            context.getSharedPreferences(
                "HomeWidgetPreferences",
                Context.MODE_PRIVATE
            )

        fun updateWidget(context: Context, appWidgetManager: AppWidgetManager, widgetId: Int) {
            val prefs = getPrefs(context)

            val pair1Label = prefs.getString("pair1_label", "EUR/USD") ?: "EUR/USD"
            val pair1Value = prefs.getString("pair1_value", "-") ?: "-"
            val pair2Label = prefs.getString("pair2_label", "EUR/TRY") ?: "EUR/TRY"
            val pair2Value = prefs.getString("pair2_value", "-") ?: "-"
            val pair3Label = prefs.getString("pair3_label", "EUR/GBP") ?: "EUR/GBP"
            val pair3Value = prefs.getString("pair3_value", "-") ?: "-"
            val goldLabel  = prefs.getString("gold_label", "🥇 Gold/g") ?: "🥇 Gold/g"
            val goldValue  = prefs.getString("gold_value", "-") ?: "-"
            val date       = prefs.getString("widget_date", "") ?: ""

            val views = RemoteViews(context.packageName, R.layout.currency_widget)
            views.setTextViewText(R.id.pair1_label, pair1Label)
            views.setTextViewText(R.id.pair1_value, pair1Value)
            views.setTextViewText(R.id.pair2_label, pair2Label)
            views.setTextViewText(R.id.pair2_value, pair2Value)
            views.setTextViewText(R.id.pair3_label, pair3Label)
            views.setTextViewText(R.id.pair3_value, pair3Value)
            views.setTextViewText(R.id.gold_label, goldLabel)
            views.setTextViewText(R.id.gold_value, goldValue)
            views.setTextViewText(R.id.widget_date, date)

            // Tap auf Kurse öffnet die App
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context, 0, launchIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                            android.app.PendingIntent.FLAG_IMMUTABLE
                )
                views.setOnClickPendingIntent(R.id.pair1_value, pendingIntent)
                views.setOnClickPendingIntent(R.id.pair2_value, pendingIntent)
                views.setOnClickPendingIntent(R.id.pair3_value, pendingIntent)
            }

            // Rechner-Button öffnet Popup
            val popupIntent = android.content.Intent(context, ConverterPopupActivity::class.java).apply {
                flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK or
                        android.content.Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val popupPending = android.app.PendingIntent.getActivity(
                context, 1, popupIntent,
                android.app.PendingIntent.FLAG_UPDATE_CURRENT or
                        android.app.PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btn_calculator, popupPending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}

