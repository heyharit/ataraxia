package com.themadbrogrammers.ataraxia

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import android.opengl.Matrix
import android.util.Log
import android.view.Surface
import android.view.WindowManager
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class SphereRenderer(
    private val context: Context,
    private val imagePath: String
) : GLSurfaceView.Renderer, SensorEventListener {

    private var programId = 0
    private var positionHandle = 0
    private var texCoordHandle = 0
    private var mvpMatrixHandle = 0
    private var textureId = 0

    private val projectionMatrix = FloatArray(16)
    private val viewMatrix = FloatArray(16)
    private val mvpMatrix = FloatArray(16)

    private var targetPitch = 0f
    private var targetYaw = 0f
    private var currentPitch = 0f
    private var currentYaw = 0f

    // 🟢 FIX 1: The "Glitch" Preventer.
    // Forces the camera to instantly snap to the sensor's position on the first frame,
    // completely bypassing the smoothing math so it doesn't "fly" into place.
    private var isFirstSensorUpdate = true

    // 🟢 FIX 2: We need the exact screen rotation, not just landscape/portrait.
    private val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)

    private val rotationMatrix  = FloatArray(16)
    private val remappedMatrix  = FloatArray(16)
    private val orientation     = FloatArray(3)

    private lateinit var vertexBuffer: FloatBuffer
    private var numIndices = 0

    @Volatile private var pendingBitmap: Bitmap? = null
    @Volatile private var bitmapReady = false

    fun onResume() {
        // Reset the flag every time the screen turns back on
        isFirstSensorUpdate = true 
        rotationSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    fun onPause() {
        sensorManager.unregisterListener(this)
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        bitmapReady = false
        textureId = 0

        GLES20.glClearColor(0f, 0f, 0f, 1f)
        GLES20.glEnable(GLES20.GL_DEPTH_TEST)

        generateSphere(radius = 50f, rings = 60, sectors = 60)

        val vertShader = loadShader(GLES20.GL_VERTEX_SHADER, readRawTextFile(context, R.raw.vertex_shader_360))
        val fragShader = loadShader(GLES20.GL_FRAGMENT_SHADER, readRawTextFile(context, R.raw.fragment_shader_360))

        programId = GLES20.glCreateProgram().also { prog ->
            GLES20.glAttachShader(prog, vertShader)
            GLES20.glAttachShader(prog, fragShader)
            GLES20.glLinkProgram(prog)
        }

        positionHandle  = GLES20.glGetAttribLocation(programId,  "a_Position")
        texCoordHandle  = GLES20.glGetAttribLocation(programId,  "a_TexCoord")
        mvpMatrixHandle = GLES20.glGetUniformLocation(programId, "u_MVPMatrix")

        loadBitmapInBackground()
    }

    private fun loadBitmapInBackground() {
        if (imagePath.isEmpty()) return
        Thread {
            try {
                val opts = BitmapFactory.Options().apply { inScaled = false }
                pendingBitmap = BitmapFactory.decodeFile(imagePath, opts)
            } catch (t: Throwable) {
                Log.e("SphereRenderer", "Failed to decode bitmap", t)
            }
        }.start()
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        val ratio = width.toFloat() / height.toFloat()
        Matrix.perspectiveM(projectionMatrix, 0, 60f, ratio, 0.1f, 100f)
    }

    override fun onDrawFrame(gl: GL10?) {
        if (!bitmapReady) uploadPendingTexture()
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
        
        if (!bitmapReady || textureId == 0) return

        GLES20.glUseProgram(programId)

        var yawDiff = targetYaw - currentYaw
        while (yawDiff < -180f) yawDiff += 360f
        while (yawDiff >  180f) yawDiff -= 360f

        // 🟢 FIX 3: Premium Cinematic Stabilization.
        // Dropped from 0.25f to 0.08f. This acts like a heavy Steadicam rig,
        // absorbing micro-jitters from your hands and delivering smooth pans.
        currentYaw   += yawDiff * 0.08f
        currentPitch += (targetPitch - currentPitch) * 0.08f

        Matrix.setIdentityM(viewMatrix, 0)
        Matrix.rotateM(viewMatrix, 0, currentPitch, 1f, 0f, 0f)
        Matrix.rotateM(viewMatrix, 0, currentYaw,   0f, 1f, 0f)

        Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
        GLES20.glUniformMatrix4fv(mvpMatrixHandle, 1, false, mvpMatrix, 0)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glUniform1i(GLES20.glGetUniformLocation(programId, "u_Texture"), 0)

        vertexBuffer.position(0)
        GLES20.glVertexAttribPointer(positionHandle, 3, GLES20.GL_FLOAT, false, 20, vertexBuffer)
        GLES20.glEnableVertexAttribArray(positionHandle)

        vertexBuffer.position(3)
        GLES20.glVertexAttribPointer(texCoordHandle, 2, GLES20.GL_FLOAT, false, 20, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texCoordHandle)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, numIndices)

        GLES20.glDisableVertexAttribArray(positionHandle)
        GLES20.glDisableVertexAttribArray(texCoordHandle)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type != Sensor.TYPE_GAME_ROTATION_VECTOR) return
        SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)

        // 🟢 FIX 2 (Cont.): Flawless World-Locking for all orientations.
        // We get the exact physical rotation of the screen and remap the sensor 
        // to exactly counter-act Android's window rotation. The image stays perfectly anchored.
        var axisX = SensorManager.AXIS_X
        var axisY = SensorManager.AXIS_Z

        when (windowManager.defaultDisplay.rotation) {
            Surface.ROTATION_0 -> { axisX = SensorManager.AXIS_X; axisY = SensorManager.AXIS_Z }
            Surface.ROTATION_90 -> { axisX = SensorManager.AXIS_Z; axisY = SensorManager.AXIS_MINUS_X }
            Surface.ROTATION_180 -> { axisX = SensorManager.AXIS_MINUS_X; axisY = SensorManager.AXIS_MINUS_Z }
            Surface.ROTATION_270 -> { axisX = SensorManager.AXIS_MINUS_Z; axisY = SensorManager.AXIS_X }
        }

        SensorManager.remapCoordinateSystem(rotationMatrix, axisX, axisY, remappedMatrix)
        SensorManager.getOrientation(remappedMatrix, orientation)

        targetYaw = Math.toDegrees(orientation[0].toDouble()).toFloat()
        val rawPitch = Math.toDegrees(orientation[1].toDouble()).toFloat()
        targetPitch  = rawPitch.coerceIn(-89.9f, 89.9f)

        // 🟢 FIX 1 (Cont.): The First-Frame Snap
        if (isFirstSensorUpdate) {
            currentYaw = targetYaw
            currentPitch = targetPitch
            isFirstSensorUpdate = false
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun generateSphere(radius: Float, rings: Int, sectors: Int) {
        numIndices = 0
        val rStep = 1.0 / (rings - 1).toDouble()
        val sStep = 1.0 / (sectors - 1).toDouble()
        val vertices = mutableListOf<Float>()

        for (r in 0 until rings - 1) {
            for (s in 0 until sectors) {
                for (i in 0..1) {
                    val curR = (r + i).toDouble()
                    val y = Math.sin(-Math.PI / 2.0 + Math.PI * curR * rStep).toFloat()
                    val x = (Math.cos(2.0 * Math.PI * s * sStep) * Math.sin(Math.PI * curR * rStep)).toFloat()
                    val z = (Math.sin(2.0 * Math.PI * s * sStep) * Math.sin(Math.PI * curR * rStep)).toFloat()

                    vertices.add(-x * radius)
                    vertices.add( y * radius)
                    vertices.add( z * radius)

                    val u = 1.0f - (s * sStep).toFloat()
                    val v = 1.0f - (curR * rStep).toFloat()
                    vertices.add(u)
                    vertices.add(v)
                    numIndices++
                }
            }
        }

        vertexBuffer = ByteBuffer
            .allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .also { it.put(vertices.toFloatArray()).position(0) }
    }

    private fun uploadPendingTexture() {
        val bmp = pendingBitmap ?: return
        pendingBitmap = null

        val ids = IntArray(1)
        GLES20.glGenTextures(1, ids, 0)
        textureId = ids[0]

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureId)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bmp, 0)
        bmp.recycle()

        bitmapReady = true
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)
        return shader
    }

    private fun readRawTextFile(context: Context, resId: Int): String =
        context.resources.openRawResource(resId).bufferedReader().use { it.readText() }
}