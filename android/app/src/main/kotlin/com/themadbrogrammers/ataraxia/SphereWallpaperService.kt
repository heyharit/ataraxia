package com.themadbrogrammers.ataraxia

import android.content.Context
import android.opengl.GLSurfaceView
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.SurfaceHolder

class SphereWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = GLWallpaperEngine()

    // ─────────────────────────────────────────────
    //  Engine
    // ─────────────────────────────────────────────

    inner class GLWallpaperEngine : Engine() {

        private lateinit var glSurfaceView: WallpaperGLSurfaceView
        private lateinit var renderer: SphereRenderer
        private var rendererSet = false

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)

            // Read the 360 image path that Flutter stored via set360Wallpaper.
            val prefs = getSharedPreferences("ataraxia_prefs", Context.MODE_PRIVATE)
            val imagePath = prefs.getString("360_path", "") ?: ""

            // FIX: Log clearly if no path is set instead of silently showing black.
            if (imagePath.isEmpty()) {
                Log.w("SphereWallpaperService", "No 360 image path found in SharedPreferences. " +
                        "Set 'ataraxia_prefs/360_path' before launching this service.")
            }

            glSurfaceView = WallpaperGLSurfaceView(this@SphereWallpaperService)
            glSurfaceView.setEGLContextClientVersion(2)

            renderer = SphereRenderer(applicationContext, imagePath)
            glSurfaceView.setRenderer(renderer)

            // RENDERMODE_CONTINUOUSLY: the sensor drives the camera every frame.
            // If you switch to RENDERMODE_WHEN_DIRTY, call glSurfaceView.requestRender()
            // inside onSensorChanged to avoid dropping frames.
            glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY

            rendererSet = true
        }

        override fun onVisibilityChanged(visible: Boolean) {
            super.onVisibilityChanged(visible)
            if (!rendererSet) return

            if (visible) {
                glSurfaceView.onResume()
                renderer.onResume()
            } else {
                // Unregister sensors when wallpaper is off-screen → saves battery.
                renderer.onPause()
                glSurfaceView.onPause()
            }
        }

        override fun onDestroy() {
            super.onDestroy()
            if (rendererSet) {
                renderer.onPause()
                glSurfaceView.onPause()
            }
        }

        // ─────────────────────────────────────────────
        //  WallpaperGLSurfaceView
        // ─────────────────────────────────────────────

        /**
         * Bridges GLSurfaceView into the WallpaperService surface.
         * Must override getHolder() to return the Engine's SurfaceHolder — otherwise
         * the GL surface renders into a detached window and nothing appears.
         */
        inner class WallpaperGLSurfaceView(context: Context) : GLSurfaceView(context) {

            override fun getHolder(): SurfaceHolder =
                this@GLWallpaperEngine.surfaceHolder

            /** Called when the engine is destroyed. Detaches from the window cleanly. */
            fun destroy() = super.onDetachedFromWindow()
        }
    }
}