package com.themadbrogrammers.ataraxia

import android.content.Context
import android.opengl.GLSurfaceView
import android.service.wallpaper.WallpaperService
import android.view.SurfaceHolder

class SacredWallpaperService : WallpaperService() {

    override fun onCreateEngine(): Engine = GLWallpaperEngine()

    inner class GLWallpaperEngine : Engine() {
        private lateinit var glSurfaceView: WallpaperGLSurfaceView
        private lateinit var renderer: Ataraxia3DRenderer
        private var rendererSet = false

        override fun onCreate(surfaceHolder: SurfaceHolder?) {
            super.onCreate(surfaceHolder)
            
            // Read the file paths saved from Flutter
            val prefs = getSharedPreferences("ataraxia_prefs", Context.MODE_PRIVATE)
            val colorPath = prefs.getString("color_path", "") ?: ""
            val depthPath = prefs.getString("depth_path", "") ?: ""

            glSurfaceView = WallpaperGLSurfaceView(this@SacredWallpaperService)
            glSurfaceView.setEGLContextClientVersion(2) // Use OpenGL ES 2.0
            glSurfaceView.setPreserveEGLContextOnPause(true)

            renderer = Ataraxia3DRenderer(applicationContext, colorPath, depthPath)
            glSurfaceView.setRenderer(renderer)
            glSurfaceView.renderMode = GLSurfaceView.RENDERMODE_CONTINUOUSLY
            rendererSet = true
        }

        override fun onVisibilityChanged(visible: Boolean) {
            super.onVisibilityChanged(visible)
            if (rendererSet) {
                if (visible) {
                    glSurfaceView.onResume()
                    renderer.onResume()
                } else {
                    glSurfaceView.onPause()
                    renderer.onPause()
                }
            }
        }

        override fun onDestroy() {
            super.onDestroy()
            glSurfaceView.onPause()
            renderer.onPause()
        }

        // The Hack: Route GLSurfaceView to the Wallpaper Engine's Surface
        inner class WallpaperGLSurfaceView(context: Context) : GLSurfaceView(context) {
            override fun getHolder(): SurfaceHolder = this@GLWallpaperEngine.surfaceHolder
            fun onDestroy() = super.onDetachedFromWindow()
        }
    }
}