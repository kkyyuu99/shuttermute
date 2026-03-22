package io.github.kkyyuu.shuttermute.phonebridge;

import android.app.Application;

import io.github.muntashirakon.adb.PRNGFixes;

public class BridgeApp extends Application {
    @Override
    public void onCreate() {
        super.onCreate();
        PRNGFixes.apply();
    }
}
