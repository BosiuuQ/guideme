package com.example.guide_me

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding

// This is a lightweight scaffold that exposes two channels:
//  - MethodChannel "com.example.guide_me/navigation" with method "startNavigation" that accepts a Map with origin/destination
//  - EventChannel "com.example.guide_me/navigation_events" that will stream simple navigation events (text + distance)
// The heavy-lifting with Mapbox Navigation SDK should be implemented inside startNavigation (native) using Mapbox SDK.
// For now this scaffold sends periodic mocked events to Flutter to verify the plumbing.
class NavigationPlugin: FlutterPlugin, MethodCallHandler, ActivityAware {
    private lateinit var methodChannel : MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private val handler = Handler(Looper.getMainLooper())
    private var mockCounter = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methodChannel = MethodChannel(binding.binaryMessenger, "com.example.guide_me/navigation")
        eventChannel = EventChannel(binding.binaryMessenger, "com.example.guide_me/navigation_events")
        methodChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object: EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }
            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() { activity = null }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) { activity = binding.activity }
    override fun onDetachedFromActivity() { activity = null }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when(call.method) {
            "startNavigation" -> {
                // Expect arguments: { "route": [[lat,lon],[lat,lon],... ] }
                val args = call.arguments as? Map<*,*>
                // TODO: Replace this mock implementation with real Mapbox Navigation SDK usage:
                //  1. Initialize MapboxNavigation with credentials
                //  2. Build route and start navigation session
                //  3. Subscribe to route progress and send events to eventSink
                // For now, send back success and start sending mocked events
                result.success(true)
                startMockEvents()
            }
            "stopNavigation" -> {
                stopMockEvents()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private val mockRunnable = object: Runnable {
        override fun run() {
            mockCounter++
            val instr = when (mockCounter % 5) {
                0 -> mapOf("instruction" to "Turn left", "distance" to 120)
                1 -> mapOf("instruction" to "Turn right", "distance" to 80)
                2 -> mapOf("instruction" to "Continue", "distance" to 400)
                3 -> mapOf("instruction" to "Arrive at destination", "distance" to 10)
                else -> mapOf("instruction" to "Continue", "distance" to 200)
            }
            eventSink?.success(instr)
            handler.postDelayed(this, 3000)
        }
    }

    private fun startMockEvents() {
        handler.post(mockRunnable)
    }

    private fun stopMockEvents() {
        handler.removeCallbacks(mockRunnable)
    }
}
