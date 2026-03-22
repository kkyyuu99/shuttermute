package io.github.kkyyuu.shuttermute.phonebridge;

import android.content.SharedPreferences;
import android.os.Bundle;
import android.text.TextUtils;
import android.widget.Button;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.AppCompatEditText;
import androidx.lifecycle.ViewModelProvider;

import com.google.android.material.appbar.MaterialToolbar;

public class MainActivity extends AppCompatActivity {
    private static final String PREFS_NAME = "phonebridge";
    private static final String PREF_HOST = "target_host";
    private static final String PREF_PAIRING_PORT = "pairing_port";
    private static final String PREF_CONNECT_PORT = "connect_port";

    private AppCompatEditText hostInput;
    private AppCompatEditText pairingPortInput;
    private AppCompatEditText connectPortInput;
    private AppCompatEditText pairingCodeInput;
    private TextView statusView;
    private TextView logView;
    private ScrollView logScroll;
    private MainViewModel viewModel;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        MaterialToolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        hostInput = findViewById(R.id.target_host);
        pairingPortInput = findViewById(R.id.pairing_port);
        connectPortInput = findViewById(R.id.connect_port);
        pairingCodeInput = findViewById(R.id.pairing_code);
        statusView = findViewById(R.id.connection_status);
        logView = findViewById(R.id.log_output);
        logScroll = findViewById(R.id.log_scroll);

        viewModel = new ViewModelProvider(this).get(MainViewModel.class);
        bindButtons();
        bindObservers();
        restoreForm();
    }

    private void bindButtons() {
        Button pairButton = findViewById(R.id.button_pair);
        Button connectButton = findViewById(R.id.button_connect);
        Button disconnectButton = findViewById(R.id.button_disconnect);
        Button muteButton = findViewById(R.id.button_mute);
        Button unmuteButton = findViewById(R.id.button_unmute);
        Button clearLogButton = findViewById(R.id.button_clear_log);

        pairButton.setOnClickListener(v -> {
            String host = requireText(hostInput);
            Integer pairingPort = parsePort(pairingPortInput);
            Integer connectPort = parsePort(connectPortInput);
            String pairingCode = requireText(pairingCodeInput);
            if (host == null || pairingPort == null || connectPort == null || pairingCode == null || pairingCode.length() != 6) {
                statusView.setText(R.string.invalid_pairing_fields);
                return;
            }
            saveForm();
            viewModel.pair(host, pairingPort, pairingCode, connectPort);
        });

        connectButton.setOnClickListener(v -> {
            String host = requireText(hostInput);
            Integer connectPort = parsePort(connectPortInput);
            if (host == null || connectPort == null) {
                statusView.setText(R.string.invalid_connect_fields);
                return;
            }
            saveForm();
            viewModel.connect(host, connectPort);
        });

        disconnectButton.setOnClickListener(v -> viewModel.disconnect());

        muteButton.setOnClickListener(v -> {
            String host = requireText(hostInput);
            Integer connectPort = parsePort(connectPortInput);
            if (host == null || connectPort == null) {
                statusView.setText(R.string.invalid_connect_fields);
                return;
            }
            saveForm();
            viewModel.mute(host, connectPort);
        });

        unmuteButton.setOnClickListener(v -> {
            String host = requireText(hostInput);
            Integer connectPort = parsePort(connectPortInput);
            if (host == null || connectPort == null) {
                statusView.setText(R.string.invalid_connect_fields);
                return;
            }
            saveForm();
            viewModel.unmute(host, connectPort);
        });

        clearLogButton.setOnClickListener(v -> viewModel.clearLog());
    }

    private void bindObservers() {
        viewModel.watchConnected().observe(this, connected -> {
            if (Boolean.TRUE.equals(connected)) {
                statusView.setText(R.string.connected_status);
            }
        });
        viewModel.watchStatusText().observe(this, status -> {
            if (!TextUtils.isEmpty(status)) {
                statusView.setText(status);
            }
        });
        viewModel.watchLogText().observe(this, log -> {
            logView.setText(log == null ? "" : log);
            logScroll.post(() -> logScroll.fullScroll(ScrollView.FOCUS_DOWN));
        });
    }

    private void restoreForm() {
        SharedPreferences prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE);
        hostInput.setText(prefs.getString(PREF_HOST, ""));
        pairingPortInput.setText(prefs.getString(PREF_PAIRING_PORT, ""));
        connectPortInput.setText(prefs.getString(PREF_CONNECT_PORT, "37099"));
    }

    private void saveForm() {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .edit()
                .putString(PREF_HOST, stringValue(hostInput))
                .putString(PREF_PAIRING_PORT, stringValue(pairingPortInput))
                .putString(PREF_CONNECT_PORT, stringValue(connectPortInput))
                .apply();
    }

    @Nullable
    private static String requireText(AppCompatEditText editText) {
        String value = stringValue(editText);
        return value.isBlank() ? null : value;
    }

    @Nullable
    private static Integer parsePort(AppCompatEditText editText) {
        String value = stringValue(editText);
        if (value.isBlank() || !TextUtils.isDigitsOnly(value)) {
            return null;
        }
        return Integer.parseInt(value);
    }

    private static String stringValue(AppCompatEditText editText) {
        return editText.getText() == null ? "" : editText.getText().toString().trim();
    }
}
