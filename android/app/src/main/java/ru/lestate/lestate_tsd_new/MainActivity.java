package ru.lestate.lestate_tsd_new;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;

public class MainActivity extends FlutterActivity {
    private static final String SCAN_ACTION = "com.xcheng.scanner.action.BARCODE_DECODING_BROADCAST";
    private static final String CHANNEL = "scan_channel";
    private BroadcastReceiver scanReceiver;
    private EventChannel.EventSink eventSink;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL).setStreamHandler(
                new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        eventSink = events;
                        scanReceiver = new BroadcastReceiver() {
                            @Override
                            public void onReceive(Context context, Intent intent) {
                                String scanData = intent.getStringExtra("EXTRA_BARCODE_DECODING_DATA");
                                if (scanData != null && eventSink != null) {
                                    eventSink.success(scanData);
                                }
                            }
                        };
                        registerReceiver(scanReceiver, new IntentFilter(SCAN_ACTION));
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        eventSink = null;
                        unregisterReceiver(scanReceiver);
                    }
                }
        );
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        if (scanReceiver != null) {
            unregisterReceiver(scanReceiver);
        }
    }
}
