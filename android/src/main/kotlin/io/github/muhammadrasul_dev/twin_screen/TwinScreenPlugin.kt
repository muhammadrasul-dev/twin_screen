package io.github.muhammadrasul_dev.twin_screen

import android.app.Activity
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.view.Display
import android.view.WindowManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Reports what Flutter does not: whether the device has a hinge, the hinge
 * angle and posture (which reveals the closed state on the cover screen), the
 * display rotation, and whether it is a book foldable or a flip phone.
 *
 * Fold bounds are left to Flutter, which already fills
 * `MediaQuery.displayFeatures` on Android through Jetpack WindowManager.
 */
class TwinScreenPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    SensorEventListener,
    DisplayManager.DisplayListener {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var prefs: SharedPreferences
    private var sensorManager: SensorManager? = null
    private var displayManager: DisplayManager? = null
    private var hingeSensor: Sensor? = null
    private var activity: Activity? = null
    private var events: EventChannel.EventSink? = null
    private val mainHandler by lazy { Handler(Looper.getMainLooper()) }

    private var hingeAngle: Double? = null
    private var openGuess: String? = null
    private var lastSent: Map<String, Any?>? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        displayManager = context.getSystemService(Context.DISPLAY_SERVICE) as? DisplayManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            hingeSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_HINGE_ANGLE)
        }
        methodChannel = MethodChannel(binding.binaryMessenger, "twin_screen")
        methodChannel.setMethodCallHandler(this)
        eventChannel = EventChannel(binding.binaryMessenger, "twin_screen/state")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        stopListening()
    }

    // ActivityAware: the activity gives the real window bounds and rotation.

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        emitIfChanged()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        emitIfChanged()
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // MethodChannel

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getState" -> result.success(state())
            "rememberDeviceType" -> {
                val type = call.arguments as? String
                if (type != null && type in REMEMBERED_TYPES) {
                    prefs.edit()
                        .putString(KEY_DEVICE_TYPE, type)
                        .putString(KEY_DEVICE_MODEL, deviceModel())
                        .apply()
                    emitIfChanged()
                }
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    // EventChannel: listen to the hinge sensor and the display only while
    // Dart is listening.

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
        lastSent = null
        hingeSensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_UI)
        }
        displayManager?.registerDisplayListener(this, mainHandler)
        emitIfChanged()
    }

    override fun onCancel(arguments: Any?) {
        stopListening()
    }

    private fun stopListening() {
        events = null
        sensorManager?.unregisterListener(this)
        displayManager?.unregisterDisplayListener(this)
    }

    // Hinge angle sensor

    override fun onSensorChanged(event: SensorEvent) {
        val angle = event.values.firstOrNull()?.toDouble() ?: return
        val previous = hingeAngle
        hingeAngle = angle
        // The sensor can be chatty; skip changes below one degree unless
        // they cross a posture boundary.
        if (previous != null && abs(previous - angle) < 1.0 &&
            postureFor(previous) == postureFor(angle)
        ) {
            return
        }
        emitIfChanged()
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    // Display changes: rotation, and the switch between the cover and the
    // inner screen.

    override fun onDisplayAdded(displayId: Int) = Unit

    override fun onDisplayRemoved(displayId: Int) = Unit

    override fun onDisplayChanged(displayId: Int) {
        emitIfChanged()
    }

    private fun emitIfChanged() {
        val sink = events ?: return
        val state = state()
        if (state == lastSent) return
        lastSent = state
        sink.success(state)
    }

    private fun state(): Map<String, Any?> {
        val posture = hingeAngle?.let { postureFor(it) } ?: "unknown"
        val deviceType = deviceType(posture)
        val rotation = rotation()
        return mapOf(
            "deviceType" to deviceType,
            "posture" to posture,
            "hingeAngle" to hingeAngle,
            "rotation" to rotation,
            "features" to listOfNotNull(centreFold(deviceType, posture, rotation)),
        )
    }

    /**
     * Some Android builds (the generic foldable emulators among them) report
     * no fold while the device lies flat, so an app filling the open screen
     * would look like it sits on one side. When the hinge sensor says the
     * device is open and the app fills the whole inner display, this returns
     * the fold at the centre of the display, along the hinge's natural axis.
     *
     * Dart drops it whenever Flutter reports a fold itself.
     */
    private fun centreFold(deviceType: String, posture: String, rotation: Int): Map<String, Any>? {
        if (posture != "flat" && posture != "halfOpened") return null
        if (deviceType != "foldable" && deviceType != "flip") return null
        val current = activity ?: return null
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return null
        val window = current.windowManager.currentWindowMetrics.bounds
        val display = current.windowManager.maximumWindowMetrics.bounds
        if (window != display || window.isEmpty) return null
        val density = context.resources.displayMetrics.density.toDouble()
        val width = window.width() / density
        val height = window.height() / density
        // Make sure this is the inner screen: wide for a book foldable, tall
        // and narrow for a flip phone (whose cover screen is nearly square).
        val isInner = if (deviceType == "foldable") {
            min(width, height) > MAX_COVER_SHORTEST_DP
        } else {
            max(width, height) / min(width, height) >= INNER_FLIP_RATIO
        }
        if (!isInner) return null

        // Book foldables fold vertically in their natural orientation, flip
        // phones horizontally; a quarter turn swaps the two.
        val naturalVertical = deviceType == "foldable"
        val vertical = if (rotation % 2 == 0) naturalVertical else !naturalVertical
        val (left, top, right, bottom) = if (vertical) {
            listOf(width / 2, 0.0, width / 2, height)
        } else {
            listOf(0.0, height / 2, width, height / 2)
        }
        return mapOf(
            "left" to left,
            "top" to top,
            "right" to right,
            "bottom" to bottom,
            "type" to "fold",
            "state" to posture,
        )
    }

    private fun hasHinge(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        return hingeSensor != null ||
            context.packageManager.hasSystemFeature(PackageManager.FEATURE_SENSOR_HINGE_ANGLE)
    }

    /**
     * The hardware type. A type learned from a fold (sent by Dart through
     * `rememberDeviceType`) wins. Before that, a device with a hinge sensor is
     * told apart by the shape of its screen: flip phones open into a very
     * tall screen and close onto a small, nearly square one. The guess from
     * the open screen is the reliable one, so it is kept for the closed state
     * (the window still shows the inner screen while the device closes).
     */
    private fun deviceType(posture: String): String {
        if (Build.MANUFACTURER.equals("Microsoft", ignoreCase = true) &&
            Build.MODEL.startsWith("Surface Duo", ignoreCase = true)
        ) {
            return "dualScreen"
        }
        rememberedType()?.let { return it }
        if (!hasHinge()) return "standard"
        val (shortest, longest) = screenSizeDp() ?: return openGuess ?: "foldable"
        val ratio = longest / shortest
        if (posture != "closed") {
            val guess = if (ratio >= INNER_FLIP_RATIO) "flip" else "foldable"
            openGuess = guess
            return guess
        }
        openGuess?.let { return it }
        // Closed and never seen open: judge the cover screen, if this is it.
        if (shortest > MAX_COVER_SHORTEST_DP) return "foldable"
        return if (ratio < COVER_FLIP_RATIO) "flip" else "foldable"
    }

    /**
     * The type Dart learned from a fold on this very device. The value is tied
     * to the device model, because Android Auto Backup restores
     * SharedPreferences onto a new phone.
     */
    private fun rememberedType(): String? {
        if (prefs.getString(KEY_DEVICE_MODEL, null) != deviceModel()) return null
        return prefs.getString(KEY_DEVICE_TYPE, null)
    }

    private fun deviceModel(): String = "${Build.MANUFACTURER}/${Build.MODEL}"

    /** The whole screen the app is on, in dp: (shortest side, longest side). */
    private fun screenSizeDp(): Pair<Double, Double>? {
        val density = context.resources.displayMetrics.density.toDouble()
        val width: Int
        val height: Int
        val current = activity
        if (current != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = current.windowManager.maximumWindowMetrics.bounds
            width = bounds.width()
            height = bounds.height()
        } else {
            val metrics = context.resources.displayMetrics
            width = metrics.widthPixels
            height = metrics.heightPixels
        }
        if (width <= 0 || height <= 0) return null
        return Pair(min(width, height) / density, max(width, height) / density)
    }

    /** Clockwise quarter turns from the display's natural orientation. */
    private fun rotation(): Int {
        val display: Display? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            activity?.display ?: displayManager?.getDisplay(Display.DEFAULT_DISPLAY)
        } else {
            @Suppress("DEPRECATION")
            (activity?.getSystemService(Context.WINDOW_SERVICE) as? WindowManager)?.defaultDisplay
                ?: displayManager?.getDisplay(Display.DEFAULT_DISPLAY)
        }
        // Surface.ROTATION_0..270 are 0..3.
        return display?.rotation ?: 0
    }

    companion object {
        private const val PREFS = "io.github.muhammadrasul_dev.twin_screen"
        private const val KEY_DEVICE_TYPE = "deviceType"
        private const val KEY_DEVICE_MODEL = "deviceModel"
        private val REMEMBERED_TYPES = setOf("foldable", "flip", "dualScreen")

        /** Hinge angles below this count as closed, matching the Dart simulator. */
        const val CLOSED_BELOW = 30.0

        /** Hinge angles above this count as flat. */
        const val FLAT_ABOVE = 150.0

        /** Closed flip phones show a cover screen close to square. */
        const val COVER_FLIP_RATIO = 1.5

        /** Open flip phones are about 22:9; book foldables open close to square. */
        const val INNER_FLIP_RATIO = 1.8

        /** Cover screens are phone-sized; a wider screen is the inner one. */
        const val MAX_COVER_SHORTEST_DP = 500.0

        fun postureFor(angle: Double): String = when {
            angle < CLOSED_BELOW -> "closed"
            angle > FLAT_ABOVE -> "flat"
            else -> "halfOpened"
        }
    }
}
