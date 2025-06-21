package com.themadbrogrammers.ataraxia

import android.content.Context
import android.graphics.BitmapFactory
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.opengl.GLES20
import android.opengl.GLSurfaceView
import android.opengl.GLUtils
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.nio.FloatBuffer
import javax.microedition.khronos.egl.EGLConfig
import javax.microedition.khronos.opengles.GL10

class Ataraxia3DRenderer(
    private val context: Context,
    private val colorPath: String,
    private val depthPath: String
) : GLSurfaceView.Renderer, SensorEventListener {

    private var programId = 0
    private var positionHandle = 0
    private var texCoordHandle = 0
    private var tiltLocation = 0
    private var uvScaleLocation = 0

    private var colorTextureId = 0
    private var depthTextureId = 0

    private var imageWidth = 0f
    private var imageHeight = 0f
    private var screenWidth = 0f
    private var screenHeight = 0f

    // --- NEW: ABSOLUTE GRAVITY PHYSICS ---
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rotationSensor = sensorManager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
    private val rotationMatrix = FloatArray(9)
    private val orientation = FloatArray(3)

    private var targetTiltX = 0f
    private var targetTiltY = 0f
    private var currentTiltX = 0f
    private var currentTiltY = 0f

    private val vertices = floatArrayOf(
        -1.0f, -1.0f,   0.0f, 1.0f,
         1.0f, -1.0f,   1.0f, 1.0f,
        -1.0f,  1.0f,   0.0f, 0.0f,
         1.0f,  1.0f,   1.0f, 0.0f  
    )
    private lateinit var vertexBuffer: FloatBuffer

    fun onResume() {
        // Register the new Rotation Vector sensor
        rotationSensor?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    fun onPause() {
        sensorManager.unregisterListener(this)
    }

    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        GLES20.glClearColor(0.0f, 0.0f, 0.0f, 1.0f)

        vertexBuffer = ByteBuffer.allocateDirect(vertices.size * 4)
            .order(ByteOrder.nativeOrder())
            .asFloatBuffer()
            .put(vertices)
        vertexBuffer.position(0)

        val vertexShader = loadShader(GLES20.GL_VERTEX_SHADER, readRawTextFile(context, R.raw.vertex_shader))
        val fragmentShader = loadShader(GLES20.GL_FRAGMENT_SHADER, readRawTextFile(context, R.raw.fragment_shader))

        programId = GLES20.glCreateProgram()
        GLES20.glAttachShader(programId, vertexShader)
        GLES20.glAttachShader(programId, fragmentShader)
        GLES20.glLinkProgram(programId)

        positionHandle = GLES20.glGetAttribLocation(programId, "a_Position")
        texCoordHandle = GLES20.glGetAttribLocation(programId, "a_TexCoord")
        
        tiltLocation = GLES20.glGetUniformLocation(programId, "u_Tilt")
        uvScaleLocation = GLES20.glGetUniformLocation(programId, "u_UvScale")
        val colorUniform = GLES20.glGetUniformLocation(programId, "u_ColorTexture")
        val depthUniform = GLES20.glGetUniformLocation(programId, "u_DepthTexture")

        colorTextureId = loadTexture(colorPath)
        depthTextureId = loadTexture(depthPath)

        GLES20.glUseProgram(programId)
        GLES20.glUniform1i(colorUniform, 0)
        GLES20.glUniform1i(depthUniform, 1)
    }

    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        GLES20.glUseProgram(programId)

        var scaleX = 1.0f
        var scaleY = 1.0f
        if (screenWidth > 0 && screenHeight > 0 && imageWidth > 0 && imageHeight > 0) {
            val screenRatio = screenWidth / screenHeight
            val imageRatio = imageWidth / imageHeight
            
            if (screenRatio > imageRatio) {
                scaleY = imageRatio / screenRatio
            } else {
                scaleX = screenRatio / imageRatio
            }
            
            // THE CRISP QUALITY FIX: 
            // Only zoom in by 8% (0.92f) instead of 22%. Keeps the image sharp
            // while providing exactly enough edge-bleed for the new shader.
            scaleX *= 0.92f
            scaleY *= 0.92f
        }
        GLES20.glUniform2f(uvScaleLocation, scaleX, scaleY)

        // Liquid smooth interpolation (Heavy, expensive feel)
        currentTiltX += (targetTiltX - currentTiltX) * 0.08f
        currentTiltY += (targetTiltY - currentTiltY) * 0.08f
        GLES20.glUniform2f(tiltLocation, currentTiltX, currentTiltY)

        GLES20.glActiveTexture(GLES20.GL_TEXTURE0)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, colorTextureId)
        
        GLES20.glActiveTexture(GLES20.GL_TEXTURE1)
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, depthTextureId)

        vertexBuffer.position(0)
        GLES20.glVertexAttribPointer(positionHandle, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(positionHandle)

        vertexBuffer.position(2)
        GLES20.glVertexAttribPointer(texCoordHandle, 2, GLES20.GL_FLOAT, false, 16, vertexBuffer)
        GLES20.glEnableVertexAttribArray(texCoordHandle)

        GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)

        GLES20.glDisableVertexAttribArray(positionHandle)
        GLES20.glDisableVertexAttribArray(texCoordHandle)
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (event.sensor.type == Sensor.TYPE_ROTATION_VECTOR) {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
            SensorManager.getOrientation(rotationMatrix, orientation)
            
            // SENSOR MULTIPLIER FIX:
            // Multiplied by 1.2f to make it incredibly sensitive to your hand.
            // Allowed to go all the way to -1.0 / 1.0 so the shader gets the full range.
            targetTiltX = (orientation[2] * 1.2f).coerceIn(-1.0f, 1.0f)
            targetTiltY = (-orientation[1] * 1.2f).coerceIn(-1.0f, 1.0f)
        }
    }

    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        screenWidth = width.toFloat()
        screenHeight = height.toFloat()
    }
    
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun loadTexture(filePath: String): Int {
        val textureIds = IntArray(1)
        GLES20.glGenTextures(1, textureIds, 0)
        if (textureIds[0] == 0) return 0

        val options = BitmapFactory.Options().apply { inScaled = false }
        val bitmap = BitmapFactory.decodeFile(filePath, options) ?: return 0

        if (imageWidth == 0f) {
            imageWidth = bitmap.width.toFloat()
            imageHeight = bitmap.height.toFloat()
        }

        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureIds[0])
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)

        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        bitmap.recycle()

        return textureIds[0]
    }

    private fun loadShader(type: Int, shaderCode: String): Int {
        val shader = GLES20.glCreateShader(type)
        GLES20.glShaderSource(shader, shaderCode)
        GLES20.glCompileShader(shader)
        return shader
    }

    private fun readRawTextFile(context: Context, resId: Int): String {
        return context.resources.openRawResource(resId).bufferedReader().use { it.readText() }
    }
}