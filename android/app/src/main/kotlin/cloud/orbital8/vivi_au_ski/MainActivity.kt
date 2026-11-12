package cloud.orbital8.vivi_au_ski

import android.content.Context
import android.content.pm.ActivityInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity(), SensorEventListener {
    companion object {
        private const val ACCELEROMETER_CHANNEL = "cloud.orbital8.vivi_au_ski/accelerometer"
        private const val DEVICE_CHANNEL = "cloud.orbital8.vivi_au_ski/device"
    }

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var lastAx: Double = 0.0
    private var lastAy: Double = 0.0
    private var lastAz: Double = 9.81

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCELEROMETER_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
                registerAccelerometer()
            }

            override fun onCancel(arguments: Any?) {
                unregisterAccelerometer()
                eventSink = null
            }
        })

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DEVICE_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAccelerometer" -> {
                    result.success(accelerometer != null)
                }
                "getDeviceInfo" -> {
                    result.success(
                        mapOf(
                            "platform" to "android",
                            "model" to Build.MODEL,
                            "manufacturer" to Build.MANUFACTURER,
                            "sdkInt" to Build.VERSION.SDK_INT,
                            "hasAccelerometer" to (accelerometer != null),
                            "sensorName" to (accelerometer?.name ?: "none")
                        )
                    )
                }
                "getCurrentAcceleration" -> {
                    result.success(
                        mapOf(
                            "x" to lastAx,
                            "y" to lastAy,
                            "z" to lastAz
                        )
                    )
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun registerAccelerometer() {
        val mgr = sensorManager ?: return
        val sensor = accelerometer ?: return
        mgr.registerListener(this, sensor, SensorManager.SENSOR_DELAY_GAME)
    }

    private fun unregisterAccelerometer() {
        sensorManager?.unregisterListener(this)
    }

    override fun onResume() {
        super.onResume()
        if (eventSink != null) {
            registerAccelerometer()
        }
    }

    override fun onPause() {
        super.onPause()
        unregisterAccelerometer()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type != Sensor.TYPE_ACCELEROMETER) return
        val ax = event.values[0].toDouble()
        val ay = event.values[1].toDouble()
        val az = event.values[2].toDouble()
        lastAx = ax
        lastAy = ay
        lastAz = az
        eventSink?.success(
            mapOf(
                "x" to ax,
                "y" to ay,
                "z" to az
            )
        )
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
