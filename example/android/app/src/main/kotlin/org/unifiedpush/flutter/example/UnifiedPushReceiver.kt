package org.unifiedpush.flutter.example

import android.content.Context
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import org.unifiedpush.flutter.connector.UnifiedPushReceiver

class UnifiedPushReceiver : UnifiedPushReceiver() {
    override fun getEngine(context: Context): FlutterEngine {
        var engine = MainActivity.engine
        if (engine == null) {
            engine = MainActivity.provideEngine(context)
            engine.getLocalizationPlugin().sendLocalesToFlutter(
                context.getResources().getConfiguration())
            engine.getDartExecutor().executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault())
        }
        return engine
    }
}