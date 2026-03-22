package io.github.kkyyuu.shuttermute.phonebridge;

import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.provider.Settings;
import android.text.TextUtils;
import android.view.View;
import android.widget.Button;
import android.widget.ScrollView;
import android.widget.TextView;

import androidx.annotation.Nullable;
import androidx.appcompat.app.AppCompatActivity;
import androidx.appcompat.widget.AppCompatEditText;
import androidx.lifecycle.ViewModelProvider;

import com.google.android.material.appbar.MaterialToolbar;
import com.google.android.material.button.MaterialButton;
import com.google.android.material.button.MaterialButtonToggleGroup;
import com.google.android.material.textfield.TextInputLayout;

import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Collections;

public class MainActivity extends AppCompatActivity {
    private static final String PREFS_NAME = "phonebridge";
    private static final String PREF_HOST = "target_host";
    private static final String PREF_PAIRING_PORT = "pairing_port";
    private static final String PREF_CONNECT_PORT = "connect_port";
    private static final String PREF_USE_SELF_MODE = "use_self_mode";

    private TextInputLayout targetHostLayout;
    private TextInputLayout pairingPortLayout;
    private TextInputLayout connectPortLayout;
    private TextInputLayout pairingCodeLayout;
    private AppCompatEditText hostInput;
    private AppCompatEditText pairingPortInput;
    private AppCompatEditText connectPortInput;
    private AppCompatEditText pairingCodeInput;
    private TextView modeSummaryView;
    private TextView selfHostSummaryView;
    private TextView instructionsView;
    private TextView guideStepsView;
    private TextView guideNoteView;
    private TextView connectionHelpView;
    private TextView statusView;
    private TextView logView;
    private ScrollView logScroll;
    private MaterialButtonToggleGroup modeGroup;
    private MaterialButton refreshSelfHostButton;
    private MainViewModel viewModel;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        MaterialToolbar toolbar = findViewById(R.id.toolbar);
        setSupportActionBar(toolbar);

        targetHostLayout = findViewById(R.id.target_host_layout);
        pairingPortLayout = findViewById(R.id.pairing_port_layout);
        connectPortLayout = findViewById(R.id.connect_port_layout);
        pairingCodeLayout = findViewById(R.id.pairing_code_layout);
        hostInput = findViewById(R.id.target_host);
        pairingPortInput = findViewById(R.id.pairing_port);
        connectPortInput = findViewById(R.id.connect_port);
        pairingCodeInput = findViewById(R.id.pairing_code);
        modeSummaryView = findViewById(R.id.mode_summary);
        selfHostSummaryView = findViewById(R.id.self_host_summary);
        instructionsView = findViewById(R.id.instructions_view);
        guideStepsView = findViewById(R.id.guide_steps_view);
        guideNoteView = findViewById(R.id.guide_note_view);
        connectionHelpView = findViewById(R.id.connection_help_view);
        statusView = findViewById(R.id.connection_status);
        logView = findViewById(R.id.log_output);
        logScroll = findViewById(R.id.log_scroll);
        modeGroup = findViewById(R.id.mode_group);
        refreshSelfHostButton = findViewById(R.id.button_refresh_self_host);

        viewModel = new ViewModelProvider(this).get(MainViewModel.class);
        restoreForm();
        bindButtons();
        bindObservers();
        updateModeUi();
    }

    private void bindButtons() {
        Button pairButton = findViewById(R.id.button_pair);
        Button connectButton = findViewById(R.id.button_connect);
        Button disconnectButton = findViewById(R.id.button_disconnect);
        Button muteButton = findViewById(R.id.button_mute);
        Button unmuteButton = findViewById(R.id.button_unmute);
        Button clearLogButton = findViewById(R.id.button_clear_log);
        Button securitySettingsButton = findViewById(R.id.button_open_security_settings);
        Button phoneInfoButton = findViewById(R.id.button_open_phone_info);
        Button developerOptionsButton = findViewById(R.id.button_open_developer_options);
        Button wifiSettingsButton = findViewById(R.id.button_open_wifi_settings);

        modeGroup.addOnButtonCheckedListener((group, checkedId, isChecked) -> {
            if (!isChecked) {
                return;
            }
            saveForm();
            updateModeUi();
        });

        refreshSelfHostButton.setOnClickListener(v -> refreshSelfHostSummary());
        securitySettingsButton.setOnClickListener(v -> openSystemScreen(Settings.ACTION_SECURITY_SETTINGS));
        phoneInfoButton.setOnClickListener(v -> openSystemScreen(Settings.ACTION_DEVICE_INFO_SETTINGS));
        developerOptionsButton.setOnClickListener(v -> openSystemScreen(Settings.ACTION_APPLICATION_DEVELOPMENT_SETTINGS));
        wifiSettingsButton.setOnClickListener(v -> openSystemScreen(Settings.ACTION_WIFI_SETTINGS));

        pairButton.setOnClickListener(v -> {
            clearFieldErrors();
            String host = resolveHost();
            if (!validateHost(host)) {
                return;
            }
            Integer pairingPort = parsePort(pairingPortInput);
            Integer connectPort = parsePort(connectPortInput);
            String pairingCode = requireText(pairingCodeInput);
            boolean hasError = false;
            if (pairingPort == null) {
                pairingPortLayout.setError(getString(R.string.error_pairing_port_required));
                hasError = true;
            }
            if (connectPort == null) {
                connectPortLayout.setError(getString(R.string.error_connect_port_required));
                hasError = true;
            }
            if (pairingCode == null || pairingCode.length() != 6) {
                pairingCodeLayout.setError(getString(R.string.error_pairing_code_required));
                hasError = true;
            }
            if (hasError) {
                statusView.setText(R.string.invalid_pairing_fields);
                return;
            }
            saveForm();
            viewModel.pair(host, pairingPort, pairingCode, connectPort);
        });

        connectButton.setOnClickListener(v -> {
            clearFieldErrors();
            String host = resolveHost();
            if (!validateHost(host)) {
                return;
            }
            Integer connectPort = parsePort(connectPortInput);
            if (connectPort == null) {
                connectPortLayout.setError(getString(R.string.error_connect_port_required));
                statusView.setText(R.string.invalid_connect_fields);
                return;
            }
            saveForm();
            viewModel.connect(host, connectPort);
        });

        disconnectButton.setOnClickListener(v -> viewModel.disconnect());

        muteButton.setOnClickListener(v -> {
            clearFieldErrors();
            String host = resolveHost();
            if (!validateHost(host)) {
                return;
            }
            Integer connectPort = parsePort(connectPortInput);
            if (connectPort == null) {
                connectPortLayout.setError(getString(R.string.error_connect_port_required));
                statusView.setText(R.string.invalid_connect_fields);
                return;
            }
            saveForm();
            viewModel.mute(host, connectPort);
        });

        unmuteButton.setOnClickListener(v -> {
            clearFieldErrors();
            String host = resolveHost();
            if (!validateHost(host)) {
                return;
            }
            Integer connectPort = parsePort(connectPortInput);
            if (connectPort == null) {
                connectPortLayout.setError(getString(R.string.error_connect_port_required));
                statusView.setText(R.string.invalid_connect_fields);
                return;
            }
            saveForm();
            viewModel.unmute(host, connectPort);
        });

        clearLogButton.setOnClickListener(v -> viewModel.clearLog());
    }

    private void bindObservers() {
        viewModel.watchConnected().observe(this, connected -> clearFieldErrors());
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
        connectPortInput.setText(prefs.getString(PREF_CONNECT_PORT, ""));
        modeGroup.check(prefs.getBoolean(PREF_USE_SELF_MODE, true) ? R.id.mode_self : R.id.mode_other);
    }

    private void saveForm() {
        getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
                .edit()
                .putString(PREF_HOST, stringValue(hostInput))
                .putString(PREF_PAIRING_PORT, stringValue(pairingPortInput))
                .putString(PREF_CONNECT_PORT, stringValue(connectPortInput))
                .putBoolean(PREF_USE_SELF_MODE, isSelfMode())
                .apply();
    }

    private void updateModeUi() {
        boolean selfMode = isSelfMode();
        targetHostLayout.setVisibility(selfMode ? View.GONE : View.VISIBLE);
        selfHostSummaryView.setVisibility(selfMode ? View.VISIBLE : View.GONE);
        refreshSelfHostButton.setVisibility(selfMode ? View.VISIBLE : View.GONE);

        modeSummaryView.setText(selfMode ? R.string.mode_summary_self : R.string.mode_summary_other);
        instructionsView.setText(selfMode ? R.string.instructions_self_phone : R.string.instructions_other_phone);
        guideStepsView.setText(selfMode ? R.string.guide_steps_self_phone : R.string.guide_steps_other_phone);
        guideNoteView.setText(selfMode ? R.string.guide_note_self_phone : R.string.guide_note_other_phone);
        connectionHelpView.setText(selfMode ? R.string.connection_help_self_phone : R.string.connection_help_other_phone);
        clearFieldErrors();

        if (selfMode) {
            refreshSelfHostSummary();
        }
    }

    @Nullable
    private String resolveHost() {
        if (!isSelfMode()) {
            return requireText(hostInput);
        }

        String host = detectLocalIpv4Address();
        if (host == null) {
            refreshSelfHostSummary();
            statusView.setText(R.string.invalid_self_host);
        }
        return host;
    }

    private void refreshSelfHostSummary() {
        String host = detectLocalIpv4Address();
        if (host == null) {
            selfHostSummaryView.setText(R.string.self_host_unavailable);
        } else {
            selfHostSummaryView.setText(getString(R.string.self_host_detected, host));
        }
    }

    private boolean validateHost(@Nullable String host) {
        if (host != null) {
            return true;
        }

        if (!isSelfMode()) {
            targetHostLayout.setError(getString(R.string.error_target_host_required));
        }
        return false;
    }

    private void clearFieldErrors() {
        targetHostLayout.setError(null);
        pairingPortLayout.setError(null);
        connectPortLayout.setError(null);
        pairingCodeLayout.setError(null);
    }

    private void openSystemScreen(String action) {
        if (startActivitySafely(action)) {
            return;
        }
        if (startActivitySafely(Settings.ACTION_SETTINGS)) {
            statusView.setText(R.string.settings_shortcut_fallback);
        } else {
            statusView.setText(R.string.settings_shortcut_unavailable);
        }
    }

    private boolean startActivitySafely(String action) {
        try {
            Intent intent = new Intent(action);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            startActivity(intent);
            return true;
        } catch (ActivityNotFoundException exception) {
            return false;
        }
    }

    private boolean isSelfMode() {
        return modeGroup.getCheckedButtonId() == R.id.mode_self;
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

    @Nullable
    private static String detectLocalIpv4Address() {
        try {
            String fallback = null;
            for (NetworkInterface networkInterface : Collections.list(NetworkInterface.getNetworkInterfaces())) {
                if (!networkInterface.isUp() || networkInterface.isLoopback() || networkInterface.isVirtual()) {
                    continue;
                }

                for (InetAddress address : Collections.list(networkInterface.getInetAddresses())) {
                    if (!(address instanceof Inet4Address) || address.isLoopbackAddress()) {
                        continue;
                    }

                    String hostAddress = address.getHostAddress();
                    if (address.isSiteLocalAddress()) {
                        String interfaceName = networkInterface.getName();
                        if (interfaceName != null && (interfaceName.startsWith("wlan")
                                || interfaceName.startsWith("eth")
                                || interfaceName.startsWith("swlan")
                                || interfaceName.startsWith("ap"))) {
                            return hostAddress;
                        }
                        if (fallback == null) {
                            fallback = hostAddress;
                        }
                    } else if (fallback == null) {
                        fallback = hostAddress;
                    }
                }
            }
            return fallback;
        } catch (SocketException exception) {
            return null;
        }
    }
}
