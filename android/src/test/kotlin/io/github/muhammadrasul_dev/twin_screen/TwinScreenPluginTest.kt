package io.github.muhammadrasul_dev.twin_screen

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.mockito.Mockito
import kotlin.test.Test
import kotlin.test.assertEquals

/*
 * Run with `./gradlew testDebugUnitTest` in `example/android/`.
 */
internal class TwinScreenPluginTest {
    @Test
    fun postureFor_usesTheSameThresholdsAsTheDartSimulator() {
        assertEquals("closed", TwinScreenPlugin.postureFor(0.0))
        assertEquals("closed", TwinScreenPlugin.postureFor(29.9))
        assertEquals("halfOpened", TwinScreenPlugin.postureFor(30.0))
        assertEquals("halfOpened", TwinScreenPlugin.postureFor(110.0))
        assertEquals("halfOpened", TwinScreenPlugin.postureFor(150.0))
        assertEquals("flat", TwinScreenPlugin.postureFor(150.1))
        assertEquals("flat", TwinScreenPlugin.postureFor(180.0))
    }

    @Test
    fun onMethodCall_unknownMethod_isNotImplemented() {
        val plugin = TwinScreenPlugin()
        val mockResult: MethodChannel.Result = Mockito.mock(MethodChannel.Result::class.java)
        plugin.onMethodCall(MethodCall("getPlatformVersion", null), mockResult)
        Mockito.verify(mockResult).notImplemented()
    }
}
