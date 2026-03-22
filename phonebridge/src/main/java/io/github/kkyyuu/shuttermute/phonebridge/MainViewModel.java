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
                    statusText.postValue(getString(R.string.status_pairing_failed));
                    appendLog(getString(R.string.log_pairing_failed));
                    return;
                }
                statusText.postValue(getString(R.string.status_pairing_successful));
                appendLog("Pairing successful.");
                connectInternal(host, connectPort, true);
            } catch (Throwable throwable) {
                if (isConnectionRefused(throwable)) {
                    statusText.postValue(getString(R.string.status_pairing_port_refused));
                    appendLog(getString(R.string.log_pairing_port_refused));
                } else {
                    statusText.postValue(getString(R.string.status_pairing_failed));
                }
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
                statusText.postValue(getString(R.string.status_disconnected));
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
                    statusText.postValue(getString(R.string.status_unable_to_connect));
                    return;
                }

                appendLog("Running: " + command);
                String output = executeShellCommand(command);
                statusText.postValue(getString(R.string.status_command_completed));
                if (!output.isBlank()) {
                    appendLog(output.trim());
                } else {
                    appendLog("Done.");
                }
            } catch (Throwable throwable) {
                statusText.postValue(getString(R.string.status_command_failed));
                appendLog("Command failed: " + throwable.getMessage());
            }
        });
    }

    private void connectInternal(String host, int connectPort, boolean fromPairing) {
        try {
            boolean result = ensureConnected(host, connectPort);
            connected.postValue(result);
            if (result) {
                statusText.postValue(getString(fromPairing
                        ? R.string.status_paired_and_connected
                        : R.string.status_connected));
            } else {
                statusText.postValue(getString(R.string.status_connection_failed));
                appendLog(getString(R.string.log_connection_failed));
            }
        } catch (Throwable throwable) {
            connected.postValue(false);
            if (isPairingRequired(throwable)) {
                statusText.postValue(getString(R.string.status_pairing_required));
                appendLog(getString(R.string.log_pairing_required));
            } else {
                statusText.postValue(getString(R.string.status_connection_failed));
            }
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

    private String getString(int resId) {
        return getApplication().getString(resId);
    }

    private static boolean isConnectionRefused(Throwable throwable) {
        String message = throwable.getMessage();
        return message != null && message.contains("ECONNREFUSED");
    }

    private static boolean isPairingRequired(Throwable throwable) {
        String message = throwable.getMessage();
        return message != null && message.contains("ADB pairing is required");
    }
}
