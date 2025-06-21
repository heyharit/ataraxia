package com.themadbrogrammers.ataraxia

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.*
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File

class AtaraxiaWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            try {
                val views = RemoteViews(context.packageName, R.layout.widget_layout)

                // ─── TEXT ───────────────────────────────────────────
                val title = widgetData.getString("quote_title", "Breathe.")
                val author = widgetData.getString("quote_author", "ATARAXIA")

                views.setTextViewText(R.id.quote_title, title)
                views.setTextViewText(R.id.quote_author, author)

                // ─── IMAGE (ROUNDED + SAFE + P3 COLOR) ──────────────
                val imgPath = widgetData.getString("widget_image_path", null)

                val bitmap = imgPath?.let { File(it) }
                    ?.takeIf { it.exists() }
                    ?.let { safeDecode(it.absolutePath) }
                    ?.let {
                        roundBitmap(
                            it,
                            28f * context.resources.displayMetrics.density
                        )
                    }

                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_image, bitmap)
                } else {
                    views.setImageViewResource(
                        R.id.widget_image,
                        android.R.color.black
                    )
                }

                // ─── TAP ACTION (DEEP LINK PORTAL) ─────────────────
                val momentId = widgetData.getString("moment_id", null)
                
                val intent = Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    // Pass the exact image ID to Flutter when tapped
                    if (momentId != null) {
                        data = android.net.Uri.parse("ataraxia://moment/$momentId")
                    }
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }

                val pendingIntent = PendingIntent.getActivity(
                    context,
                    widgetId,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )
                
                views.setOnClickPendingIntent(R.id.widget_container, pendingIntent)

                appWidgetManager.updateAppWidget(widgetId, views)

            } catch (_: Exception) {
                // Prevent widget death
            }
        }
    }

    // ─── BITMAP HELPERS ───────────────────────────────────────

    private fun safeDecode(path: String): Bitmap? {
        return try {
            val options = BitmapFactory.Options().apply {
                inJustDecodeBounds = true
            }
            BitmapFactory.decodeFile(path, options)

            options.inSampleSize = calculateInSampleSize(options, 800, 800) 
            options.inJustDecodeBounds = false
            options.inPreferredConfig = Bitmap.Config.ARGB_8888 

            // Force Wide Color Gamut hardware decoding
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                options.inPreferredColorSpace = ColorSpace.get(ColorSpace.Named.DISPLAY_P3)
            }

            BitmapFactory.decodeFile(path, options)
        } catch (_: Exception) {
            null
        }
    }

    private fun calculateInSampleSize(
        opt: BitmapFactory.Options,
        reqW: Int,
        reqH: Int
    ): Int {
        val (h, w) = opt.outHeight to opt.outWidth
        var sample = 1
        if (h > reqH || w > reqW) {
            var halfH = h / 2
            var halfW = w / 2
            while (halfH / sample >= reqH && halfW / sample >= reqW) {
                sample *= 2
            }
        }
        return sample
    }

    private fun roundBitmap(bitmap: Bitmap, radius: Float): Bitmap {
        // 🚀 THE VIBRANCY FIX: Preserve the original P3 Color Space when creating the canvas!
        val output = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O && bitmap.colorSpace != null) {
            Bitmap.createBitmap(
                bitmap.width,
                bitmap.height,
                Bitmap.Config.ARGB_8888,
                true, // hasAlpha
                bitmap.colorSpace!! // Maintain the rich color profile
            )
        } else {
            Bitmap.createBitmap(bitmap.width, bitmap.height, Bitmap.Config.ARGB_8888)
        }

        val canvas = Canvas(output)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            isFilterBitmap = true // Smooths image downscaling
            isDither = true
        }

        val rect = Rect(0, 0, bitmap.width, bitmap.height)
        val rectF = RectF(rect)

        canvas.drawRoundRect(rectF, radius * 1.2f, radius * 1.2f, paint)

        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(bitmap, rect, rect, paint)

        return output
    }
}