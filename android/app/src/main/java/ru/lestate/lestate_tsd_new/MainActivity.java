package ru.lestate.lestate_tsd_new;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.os.Bundle;
import android.os.Build;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;

public class MainActivity extends FlutterActivity {
    private static String SCAN_ACTION;
    private static String BARCODE_DATA;
    private static final String CHANNEL = "scan_channel";
    private BroadcastReceiver scanReceiver;
    private EventChannel.EventSink eventSink;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // Определяем марку ТСД
        String manufacturer = Build.MANUFACTURER.toLowerCase();
        if (manufacturer.contains("ubx") || manufacturer.contains("urovo")) {
            SCAN_ACTION = "android.intent.ACTION_DECODE_DATA";
            BARCODE_DATA = "barcode_string";
        } else if (manufacturer.contains("atol")) {
            SCAN_ACTION = "com.xcheng.scanner.action.BARCODE_DECODING_BROADCAST";
            BARCODE_DATA = "EXTRA_BARCODE_DECODING_DATA";
        }

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL).setStreamHandler(
                new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        eventSink = events;
                        scanReceiver = new BroadcastReceiver() {
                            @Override
                            public void onReceive(Context context, Intent intent) {
                                String scanData = intent.getStringExtra(BARCODE_DATA);
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
