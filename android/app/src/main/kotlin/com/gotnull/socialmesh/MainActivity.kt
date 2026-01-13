package com.gotnull.socialmesh

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Register GlyphMatrix plugin for Nothing Phone 3
        flutterEngine.plugins.add(GlyphMatrixPlugin())
    }
}
