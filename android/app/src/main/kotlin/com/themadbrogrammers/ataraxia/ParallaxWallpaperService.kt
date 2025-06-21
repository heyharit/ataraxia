package com.themadbrogrammers.ataraxia

import android.content.Context
import android.graphics.*
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.service.wallpaper.WallpaperService
import android.view.Choreographer
import android.view.SurfaceHolder
import java.io.File
import kotlin.math.max

class ParallaxWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = Engine4D()

    inner class Engine4D : Engine(), SensorEventListener, Choreographer.FrameCallback {

        private val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        // 1. ABSOLUTE GRAVITY: Tracks physical reality, no rubber-banding.
        private val rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)

        @Volatile private var bgBitmap: Bitmap? = null
        @Volatile private var foreBitmap: Bitmap? = null

        private val rotationMatrix = FloatArray(9)
        private val orientation = FloatArray(3)

        private var targetTiltX = 0f
        private var targetTiltY = 0f
        private var currentTiltX = 0f
        private var currentTiltY = 0f

        // 2. THE 3D CAMERA: Physically skews flat layers for true perspective
        private val camera3D = android.graphics.Camera()
        private val matrix3D = Matrix()
        
        private val paint = Paint().apply {
            isAntiAlias = true
            isFilterBitmap = true
            isDither = true
        }

        private var isRendering = false

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            loadLayers()
        }

        override fun onVisibilityChanged(visible: Boolean) {
            if (visible) {
                rotationSensor?.let {
                    sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
                }
                if (!isRendering) {
                    isRendering = true
                    Choreographer.getInstance().postFrameCallback(this)
                }
            } else {
                sensorManager.unregisterListener(this)
                isRendering = false
            }
        }

        override fun doFrame(frameTimeNanos: Long) {
            if (!isRendering) return

            // 3. FLUID PHYSICS: Heavy, premium interpolation.
            currentTiltX += (targetTiltX - currentTiltX) * 0.1f
            currentTiltY += (targetTiltY - currentTiltY) * 0.1f

            drawFrame()
            Choreographer.getInstance().postFrameCallback(this)
        }

        private fun drawFrame() {
            val holder = surfaceHolder ?: return
            if (!holder.surface.isValid) return

            var canvas: Canvas? = null
            try {
                canvas = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    holder.lockHardwareCanvas()
                } else {
                    holder.lockCanvas()
                }

                canvas?.let { c ->
                    c.drawColor(Color.BLACK)

                    val centerX = c.width / 2f
                    val centerY = c.height / 2f

                    synchronized(this) {
                        // Background: Sinks backward (-30 shift) and tilts slightly
                        bgBitmap?.let { drawLayer(c, it, centerX, centerY, -30f, 0.5f) }
                        
                        // Foreground: Pops out towards the user (+60 shift) and tilts aggressively
                        foreBitmap?.let { drawLayer(c, it, centerX, centerY, 60f, 1.3f) }
                    }
                }
            } finally {
                canvas?.let { holder.unlockCanvasAndPost(it) }
            }
        }

        private fun drawLayer(
            canvas: Canvas, 
            bitmap: Bitmap, 
            centerX: Float, 
            centerY: Float, 
            parallaxShift: Float, 
            tiltMultiplier: Float
        ) {
            if (bitmap.isRecycled) return

            canvas.save()

            // Overscan by 15% to hide the edges when the 3D shift happens
            val scale = max(canvas.width.toFloat() / bitmap.width, canvas.height.toFloat() / bitmap.height) * 1.15f
            
            // Apply 3D Perspective Tilt
            camera3D.save()
            camera3D.rotateX(currentTiltY * 15f * tiltMultiplier)
            camera3D.rotateY(-currentTiltX * 15f * tiltMultiplier)
            camera3D.getMatrix(matrix3D)
            camera3D.restore()

            // Center the 3D rotation properly
            matrix3D.preTranslate(-centerX, -centerY)
            matrix3D.postTranslate(centerX, centerY)
            canvas.concat(matrix3D)

            // Apply 2D Slide (The physical left/right separation)
            val slideX = currentTiltX * parallaxShift
            val slideY = currentTiltY * parallaxShift
            canvas.translate(slideX, slideY)

            // Center and scale the bitmap
            val tx = centerX - (bitmap.width * scale) / 2f
            val ty = centerY - (bitmap.height * scale) / 2f
            
            val drawMatrix = Matrix()
            drawMatrix.postScale(scale, scale)
            drawMatrix.postTranslate(tx, ty)

            canvas.drawBitmap(bitmap, drawMatrix, paint)
            canvas.restore()
        }

        override fun onSensorChanged(event: SensorEvent) {
            if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
                SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
                SensorManager.getOrientation(rotationMatrix, orientation)

                // Map rotation to a safe coordinate range
                targetTiltX = (orientation[2]).coerceIn(-0.4f, 0.4f)
                targetTiltY = (-orientation[1]).coerceIn(-0.4f, 0.4f)
            }
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        override fun onDestroy() {
            super.onDestroy()
            sensorManager.unregisterListener(this)
            isRendering = false
            Choreographer.getInstance().removeFrameCallback(this)
        }

        private fun loadLayers() {
            val prefs = getSharedPreferences("ataraxia_prefs", Context.MODE_PRIVATE)
            val screenW = resources.displayMetrics.widthPixels
            val screenH = resources.displayMetrics.heightPixels

            val newBg = decodeSafe(prefs.getString("bg_path", null), screenW, screenH)
            val newFore = decodeSafe(prefs.getString("fore_path", null), screenW, screenH)

            synchronized(this) {
                val oldBg = bgBitmap
                val oldFore = foreBitmap

                bgBitmap = newBg
                foreBitmap = newFore
                
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    oldBg?.let { if (!it.isRecycled) it.recycle() }
                    oldFore?.let { if (!it.isRecycled) it.recycle() }
                }, 100)
            }
        }

        private fun decodeSafe(path: String?, reqW: Int, reqH: Int): Bitmap? {
            if (path.isNullOrEmpty()) return null
            return try {
                val file = File(path)
                if (!file.exists()) return null

                val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeFile(path, options)

                var sample = 1
                if (options.outHeight > reqH || options.outWidth > reqW) {
                    val halfH = options.outHeight / 2
                    val halfW = options.outWidth / 2
                    while (halfH / sample >= reqH && halfW / sample >= reqW) {
                        sample *= 2
                    }
                }

                options.inSampleSize = sample
                options.inJustDecodeBounds = false
                
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    options.inPreferredConfig = Bitmap.Config.HARDWARE
                    options.inPreferredColorSpace = ColorSpace.get(ColorSpace.Named.DISPLAY_P3)
                } else {
                    options.inPreferredConfig = Bitmap.Config.ARGB_8888
                }

                BitmapFactory.decodeFile(path, options)
            } catch (e: Exception) { null }
        }
    }
}