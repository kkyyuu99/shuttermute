package io.github.kkyyuu.shuttermute.phonebridge;

import android.app.Application;

import androidx.annotation.NonNull;
import androidx.lifecycle.AndroidViewModel;
import androidx.lifecycle.LiveData;
import androidx.lifecycle.MutableLiveData;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.github.muntashirakon.adb.AbsAdbConnectionManager;
import io.github.muntashirakon.adb.AdbStream;

public class MainViewModel extends AndroidViewModel {
    private static final String CAMERA_SETTING_KEY = "csc_pref_camera_forced_shuttersound_key";

    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    private final MutableLiveData<Boolean> connected = new MutableLiveData<>(false);
    private final MutableLiveData<String> statusText = new MutableLiveData<>("");
    private final MutableLiveData<String> logText = new MutableLiveData<>("");

    private String connectedHost;
    private int connectedPort = -1;

    public MainViewModel(@NonNull Application application) {
        super(application);
    }

    public LiveData<Boolean> watchConnected() {
        return connected;
    }

    public LiveData<String> watchStatusText() {
        return statusText;
    }

    public LiveData<String> watchLogText() {
        return logText;
    }

    @Override
    protected void onCleared() {
        super.onCleared();
        executor.submit(() -> {
            try {
                BridgeConnectionManager.getInstance(getApplication()).close();
            } catch (Exception ignore) {
            }
        });
        executor.shutdown();
    }

    public void pair(String host, int pairingPort, String pairingCode, int connectPort) {
        executor.submit(() -> {
            try {
                appendLog("Pairing with " + host + ":" + pairingPort);
                AbsAdbConnectionManager manager = BridgeConnectionManager.getInstance(getApplication());
                boolean paired = manager.pair(host, pairingPort, pairingCode);
                if (!paired) {
                    statusText.postValue("Pairing failed.");
                    appendLog("Pairing failed.");
                    return;
                }
                statusText.postValue("Pairing successful.");
                appendLog("Pairing successful.");
                connectInternal(host, connectPort, true);
            } catch (Throwable throwable) {
                statusText.postValue("Pairing failed.");
                appendLog("Pairing failed: " + throwable.getMessage());
            }
        });
    }

    public void connect(String host, int connectPort) {
        executor.submit(() -> connectInternal(host, connectPort, false));
    }

    public void disconnect() {
        executor.submit(() -> {
            try {
                AbsAdbConnectionManager manager = BridgeConnectionManager.getInstance(getApplication());
                manager.disconnect();
                connectedHost = null;
                connectedPort = -1;
                connected.postValue(false);
                statusText.postValue("Disconnected.");
                appendLog("Disconnected.");
            } catch (Throwable throwable) {
                appendLog("Disconnect failed: " + throwable.getMessage());
            }
        });
    }

    public void mute(String host, int connectPort) {
        runCommand(host, connectPort, "settings put system " + CAMERA_SETTING_KEY + " 0");
    }

    public void unmute(String host, int connectPort) {
        runCommand(host, connectPort, "settings put system " + CAMERA_SETTING_KEY + " 1");
    }

    public void clearLog() {
        logText.postValue("");
    }

    private void runCommand(String host, int connectPort, String command) {
        executor.submit(() -> {
            try {
                if (!ensureConnected(host, connectPort)) {
                    statusText.postValue("Unable to connect to target phone.");
                    return;
                }

                appendLog("Running: " + command);
                String output = executeShellCommand(command);
                statusText.postValue("Command completed.");
                if (!output.isBlank()) {
                    appendLog(output.trim());
                } else {
                    appendLog("Done.");
                }
            } catch (Throwable throwable) {
                statusText.postValue("Command failed.");
                appendLog("Command failed: " + throwable.getMessage());
            }
        });
    }

    private void connectInternal(String host, int connectPort, boolean fromPairing) {
        try {
            boolean result = ensureConnected(host, connectPort);
            connected.postValue(result);
            if (result) {
                statusText.postValue(fromPairing ? "Paired and connected." : "Connected.");
            } else {
                statusText.postValue("Connection failed.");
                appendLog("Connection failed.");
            }
        } catch (Throwable throwable) {
            connected.postValue(false);
            statusText.postValue("Connection failed.");
            appendLog("Connection failed: " + throwable.getMessage());
        }
    }

    private boolean ensureConnected(String host, int connectPort) throws Exception {
        AbsAdbConnectionManager manager = BridgeConnectionManager.getInstance(getApplication());
        if (manager.isConnected() && host.equals(connectedHost) && connectPort == connectedPort) {
            return true;
        }

        if (manager.isConnected()) {
            manager.disconnect();
        }

        appendLog("Connecting to " + host + ":" + connectPort);
        boolean result = manager.connect(host, connectPort);
        if (result) {
            connectedHost = host;
            connectedPort = connectPort;
            appendLog("Connected to target phone.");
        }
        return result;
    }

    private String executeShellCommand(String command) throws Exception {
        AbsAdbConnectionManager manager = BridgeConnectionManager.getInstance(getApplication());
        try (AdbStream stream = manager.openStream("shell:" + command);
             InputStream inputStream = stream.openInputStream();
             ByteArrayOutputStream outputStream = new ByteArrayOutputStream()) {
            byte[] buffer = new byte[4096];
            int count;
            while ((count = inputStream.read(buffer)) != -1) {
                outputStream.write(buffer, 0, count);
            }
            return outputStream.toString(StandardCharsets.UTF_8);
        }
    }

    private void appendLog(String line) {
        String current = logText.getValue();
        String next = (current == null || current.isBlank()) ? line : current + "\n" + line;
        logText.postValue(next);
    }
}
