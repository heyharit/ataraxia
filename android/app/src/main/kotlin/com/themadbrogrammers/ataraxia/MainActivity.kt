package com.themadbrogrammers.ataraxia

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.annotation.NonNull
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileInputStream
import java.io.IOException

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.ataraxia/wallpaper"

    override fun onCreate(savedInstanceState: Bundle?) {
        // Prevent screenshots / screen recording
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setWallpaper" -> {
                        val path = call.argument<String>("path")
                        val mode = call.argument<String>("mode") ?: "both"

                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Path cannot be null or empty", null)
                            return@setMethodCallHandler
                        }

                        val file = File(path)
                        if (!file.exists() || !file.isFile) {
                            result.error("FILE_NOT_FOUND", "File does not exist or is invalid", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val manager = WallpaperManager.getInstance(applicationContext)

                            // THE VIBRANCY FIX: 
                            // Using setStream bypasses Android's aggressive Bitmap compression 
                            // and preserves the exact ICC color profile (Display P3 / sRGB) of the image.
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                                when (mode.lowercase()) {
                                    "home" -> {
                                        FileInputStream(file).use { 
                                            manager.setStream(it, null, true, WallpaperManager.FLAG_SYSTEM) 
                                        }
                                    }
                                    "lock" -> {
                                        FileInputStream(file).use { 
                                            manager.setStream(it, null, true, WallpaperManager.FLAG_LOCK) 
                                        }
                                    }
                                    "both" -> {
                                        // Set both individually to ensure maximum quality on both screens
                                        FileInputStream(file).use { 
                                            manager.setStream(it, null, true, WallpaperManager.FLAG_SYSTEM) 
                                        }
                                        FileInputStream(file).use { 
                                            manager.setStream(it, null, true, WallpaperManager.FLAG_LOCK) 
                                        }
                                    }
                                    else -> FileInputStream(file).use { manager.setStream(it) }
                                }
                            } else {
                                FileInputStream(file).use { manager.setStream(it) }
                            }
                            
                            result.success(true)
                        } catch (e: SecurityException) {
                            result.error("SECURITY_ERROR", e.message, null)
                        } catch (e: IOException) {
                            result.error("IO_ERROR", e.message, null)
                        } catch (e: Exception) {
                            result.error("WALLPAPER_ERROR", e.message, null)
                        }
                    }

                    // ─── THE NEW 4D MATRIX ENGINE BRIDGE ───
                    "setParallaxWallpaper" -> {
                        val bgPath = call.argument<String>("bg")
                        val forePath = call.argument<String>("fore")

                        if (bgPath.isNullOrBlank() || forePath.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Background and foreground paths are required", null)
                            return@setMethodCallHandler
                        }

                        // 1. Save paths for the 4D renderer to read
                        val prefs = getSharedPreferences("ataraxia_prefs", Context.MODE_PRIVATE)
                        val success = prefs.edit().apply {
                            putString("bg_path", bgPath)
                            putString("fore_path", forePath)
                            putLong("last_updated", System.currentTimeMillis())
                        }.commit() 

                        if (success) {
                            try {
                                val manager = WallpaperManager.getInstance(context)
                                val info = manager.wallpaperInfo
                                
                                // Check if our NEW 4D service is already running
                                if (info != null && info.packageName == packageName && info.serviceName == ParallaxWallpaperService::class.java.name) {
                                    result.success(true)
                                } else {
                                    // Launch the Live Wallpaper Picker
                                    val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                                        putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, 
                                            ComponentName(context, ParallaxWallpaperService::class.java))
                                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                    }
                                    startActivity(intent)
                                    result.success(true)
                                }
                            } catch (e: Exception) {
                                result.error("INTENT_ERROR", e.message, null)
                            }
                        } else {
                            result.error("PREFS_ERROR", "Failed to save wallpaper paths", null)
                        }
                    }
                    
                    "set360Wallpaper" -> {
                        val imagePath = call.argument<String>("image")

                        if (imagePath.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Image path is required", null)
                            return@setMethodCallHandler
                        }

                        val prefs = getSharedPreferences("ataraxia_prefs", Context.MODE_PRIVATE)
                        prefs.edit().putString("360_path", imagePath).commit() 

                        try {
                            val manager = WallpaperManager.getInstance(context)
                            val info = manager.wallpaperInfo
                            
                            if (info != null && info.packageName == packageName && info.serviceName == SphereWallpaperService::class.java.name) {
                                result.success(true)
                            } else {
                                val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
                                    putExtra(WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT, 
                                        ComponentName(context, SphereWallpaperService::class.java))
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success(true)
                            }
                        } catch (e: Exception) {
                            result.error("INTENT_ERROR", e.message, null)
                        }
                    }

                    "openWriteIntent" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("INVALID_PATH", "Path cannot be null or empty", null)
                            return@setMethodCallHandler
                        }

                        try {
                            val file = File(path)
                            val uri = FileProvider.getUriForFile(this, "${packageName}.fileprovider", file)
                            val intent = Intent(Intent.ACTION_ATTACH_DATA).apply {
                                addCategory(Intent.CATEGORY_DEFAULT)
                                setDataAndType(uri, "image/*")
                                putExtra("mimeType", "image/*")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "Set Wallpaper Via System"))
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INTENT_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}