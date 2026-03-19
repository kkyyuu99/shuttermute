using System.Diagnostics;
using System.Globalization;
using System.Net.Http;
using System.Reflection;
using System.Text;

Console.InputEncoding = new UTF8Encoding(false);
Console.OutputEncoding = new UTF8Encoding(false);

var app = new ShutterMuteApp(args);
return await app.RunAsync();

internal enum AppAction
{
    Mute,
    Unmute,
    SetEditSetup,
    SetEditOpen
}

internal enum LanguageCode
{
    Ko,
    Ja
}

internal sealed record DeviceInfo(string Serial, string State);

internal sealed record CommandResult(int ExitCode, string Output);

internal sealed partial class ShutterMuteApp
{
    private const string CameraSettingKey = "csc_pref_camera_forced_shuttersound_key";
    private const string SetEditPackageName = "io.github.muntashirakon.setedit";
    private const string SetEditDefaultFileName = "SetEdit-v3.0-rc01.apk";
    private const string SetEditDefaultDownloadUrl =
        "https://github.com/MuntashirAkon/SetEdit/releases/download/v3.0-rc01/SetEdit-v3.0-rc01.apk";
    private readonly string[] args;
    private readonly bool interactiveMode;
    private readonly bool trySetVibrateMode;
    private readonly bool pauseOnExit;
    private bool openSetEditAfterSetup;
    private bool showHelp;
    private AppAction? action;
    private LanguageCode language;
    private string? setEditApkPath;
    private string setEditDownloadUrl = SetEditDefaultDownloadUrl;
    private Dictionary<string, string> text = null!;
    private Dictionary<string, string[]> textLines = null!;

    public ShutterMuteApp(string[] args)
    {
        this.args = args;
        interactiveMode = args.Length == 0;
        trySetVibrateMode = !args.Contains("--skip-vibrate", StringComparer.OrdinalIgnoreCase);
        pauseOnExit = interactiveMode && !args.Contains("--no-pause", StringComparer.OrdinalIgnoreCase);
        openSetEditAfterSetup = !args.Contains("--no-open-setedit", StringComparer.OrdinalIgnoreCase);
        language = ResolveDefaultLanguage();
        ParseArguments();
        ApplyLanguage(language);
    }

    public async Task<int> RunAsync()
    {
        try
        {
            if (showHelp)
            {
                PrintHelp();
                return 0;
            }

            if (!TryResolveLanguageFromPrompt())
            {
                return 1;
            }

            if (!TryResolveActionFromPrompt())
            {
                return 1;
            }

            var adbPath = await FindAdbPathAsync();
            var device = await WaitForReadyDeviceAsync(adbPath);
            if (device is null)
            {
                WriteMessage("ConnectionCancelled");
                return 1;
            }

            WriteLog(Format("UsingDevice", device.Serial));

            switch (action)
            {
                case AppAction.Mute:
                    await MuteAsync(adbPath, device.Serial);
                    break;
                case AppAction.Unmute:
                    await UnmuteAsync(adbPath, device.Serial);
                    break;
                case AppAction.SetEditSetup:
                    await SetupSetEditAsync(adbPath, device.Serial);
                    break;
                case AppAction.SetEditOpen:
                    await OpenSetEditAsync(adbPath, device.Serial);
                    break;
                default:
                    throw new InvalidOperationException("Action was not resolved.");
            }

            WriteMessage("Finished");
            return 0;
        }
        catch (Exception ex)
        {
            WriteLog($"{GetText("ErrorPrefix")} {ex.Message}");
            return 1;
        }
        finally
        {
            if (pauseOnExit)
            {
                Console.WriteLine();
                Console.Write($"{GetText("ClosePrompt")}: ");
                Console.ReadLine();
            }
        }
    }

    private void ParseArguments()
    {
        for (var i = 0; i < args.Length; i++)
        {
            var current = args[i];
            if (current.Equals("--help", StringComparison.OrdinalIgnoreCase) ||
                current.Equals("-h", StringComparison.OrdinalIgnoreCase))
            {
                showHelp = true;
                continue;
            }

            if (current.Equals("--language", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                language = ParseLanguage(args[++i]);
                continue;
            }

            if (current.StartsWith("--language=", StringComparison.OrdinalIgnoreCase))
            {
                language = ParseLanguage(current.Split('=', 2)[1]);
                continue;
            }

            if (current.Equals("--action", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                action = ParseAction(args[++i]);
                continue;
            }

            if (current.StartsWith("--action=", StringComparison.OrdinalIgnoreCase))
            {
                action = ParseAction(current.Split('=', 2)[1]);
                continue;
            }

            if (current.Equals("--setedit-apk", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                setEditApkPath = args[++i];
                continue;
            }

            if (current.StartsWith("--setedit-apk=", StringComparison.OrdinalIgnoreCase))
            {
                setEditApkPath = current.Split('=', 2)[1];
                continue;
            }

            if (current.Equals("--setedit-url", StringComparison.OrdinalIgnoreCase) && i + 1 < args.Length)
            {
                setEditDownloadUrl = args[++i];
                continue;
            }

            if (current.StartsWith("--setedit-url=", StringComparison.OrdinalIgnoreCase))
            {
                setEditDownloadUrl = current.Split('=', 2)[1];
            }
        }
    }

    private bool TryResolveLanguageFromPrompt()
    {
        if (args.Any(arg => arg.StartsWith("--language", StringComparison.OrdinalIgnoreCase)) || !interactiveMode)
        {
            ApplyLanguage(language);
            return true;
        }

        Console.WriteLine();
        Console.WriteLine("Choose language / 言語を選んでください");
        Console.WriteLine(language == LanguageCode.Ko ? "1. 한국어 (기본값)" : "1. 한국어");
        Console.WriteLine(language == LanguageCode.Ja ? "2. 日本語 (既定値)" : "2. 日本語");
        Console.Write("Number / 番号: ");

        var input = Console.ReadLine()?.Trim();
        if (string.IsNullOrEmpty(input))
        {
            ApplyLanguage(language);
            return true;
        }

        language = input switch
        {
            "1" => LanguageCode.Ko,
            "2" => LanguageCode.Ja,
            _ => language
        };

        ApplyLanguage(language);
        return true;
    }

    private bool TryResolveActionFromPrompt()
    {
        if (action is not null)
        {
            return true;
        }

        Console.WriteLine();
        Console.WriteLine(GetText("ChooseAction"));
        Console.WriteLine($"1. {GetText("MuteAction")}");
        Console.WriteLine($"2. {GetText("UnmuteAction")}");
        Console.WriteLine($"3. {GetText("SetEditSetupAction")}");
        Console.WriteLine($"4. {GetText("SetEditOpenAction")}");
        Console.WriteLine($"0. {GetText("ExitAction")}");
        Console.Write($"{GetText("ActionPrompt")}: ");

        var input = Console.ReadLine()?.Trim();
        action = input switch
        {
            "1" => AppAction.Mute,
            "2" => AppAction.Unmute,
            "3" => AppAction.SetEditSetup,
            "4" => AppAction.SetEditOpen,
            "0" => null,
            _ => AppAction.Mute
        };

        return action is not null;
    }

    private async Task<string> FindAdbPathAsync()
    {
        var bundledAdbPath = TryExtractBundledAdb();
        if (!string.IsNullOrWhiteSpace(bundledAdbPath))
        {
            WriteLog(Format("UsingBundledAdb", bundledAdbPath));
            return bundledAdbPath;
        }

        var fromPath = await TryRunProcessAsync("where", ["adb"], echoOutput: false);
        if (fromPath.ExitCode == 0)
        {
            var firstPath = fromPath.Output
                .Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries)
                .Select(line => line.Trim())
                .FirstOrDefault(File.Exists);
            if (!string.IsNullOrWhiteSpace(firstPath))
            {
                WriteLog(Format("UsingSystemAdb", firstPath));
                return firstPath;
            }
        }

        var candidates = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "Android", "Sdk", "platform-tools", "adb.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile), "AppData", "Local", "Android", "Sdk", "platform-tools", "adb.exe")
        };

        foreach (var candidate in candidates)
        {
            if (File.Exists(candidate))
            {
                WriteLog(Format("UsingSystemAdb", candidate));
                return candidate;
            }
        }

        throw new InvalidOperationException(GetText("AdbNotFound"));
    }

    private static string? TryExtractBundledAdb()
    {
        var assembly = Assembly.GetExecutingAssembly();
        var bundle = new Dictionary<string, string>
        {
            ["adb.exe"] = "PlatformTools.adb.exe",
            ["AdbWinApi.dll"] = "PlatformTools.AdbWinApi.dll",
            ["AdbWinUsbApi.dll"] = "PlatformTools.AdbWinUsbApi.dll",
            ["libwinpthread-1.dll"] = "PlatformTools.libwinpthread-1.dll"
        };

        if (assembly.GetManifestResourceStream(bundle["adb.exe"]) is null)
        {
            return null;
        }

        var rootPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ShutterMute",
            "platform-tools");
        Directory.CreateDirectory(rootPath);

        foreach (var item in bundle)
        {
            var destinationPath = Path.Combine(rootPath, item.Key);
            if (File.Exists(destinationPath))
            {
                continue;
            }

            using var stream = assembly.GetManifestResourceStream(item.Value);
            if (stream is null)
            {
                return null;
            }

            using var fileStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.Read);
            stream.CopyTo(fileStream);
        }

        return Path.Combine(rootPath, "adb.exe");
    }

    private async Task<DeviceInfo?> WaitForReadyDeviceAsync(string adbPath)
    {
        while (true)
        {
            await RunAdbAsync(adbPath, null, "start-server");
            var devices = await GetDevicesAsync(adbPath);
            var readyDevices = devices.Where(device => device.State.Equals("device", StringComparison.OrdinalIgnoreCase)).ToList();

            if (readyDevices.Count == 1)
            {
                return readyDevices[0];
            }

            if (readyDevices.Count > 1)
            {
                throw new InvalidOperationException(Format("MoreThanOneDevice", string.Join(", ", readyDevices.Select(device => device.Serial))));
            }

            var guidanceLines = new List<string>(GetTextLines("NeedUsbDebugBody"));
            if (devices.Count > 0)
            {
                guidanceLines.Add(string.Empty);
                guidanceLines.Add(GetText("DetectedState"));
                guidanceLines.AddRange(devices.Select(device => $"{device.Serial} ({device.State})"));
            }

            if (devices.Any(device => device.State.Equals("unauthorized", StringComparison.OrdinalIgnoreCase)))
            {
                guidanceLines.Add(string.Empty);
                guidanceLines.Add(GetText("Unauthorized1"));
                guidanceLines.Add(GetText("Unauthorized2"));
            }

            Console.WriteLine();
            foreach (var line in guidanceLines)
            {
                Console.WriteLine(line);
            }

            Console.WriteLine();
            Console.Write($"{GetText("RetryPrompt")} ");
            if (Console.ReadLine() is null)
            {
                return null;
            }
        }
    }

    private async Task<List<DeviceInfo>> GetDevicesAsync(string adbPath)
    {
        var result = await RunAdbAsync(adbPath, null, "devices", "-l");
        if (result.ExitCode != 0)
        {
            throw new InvalidOperationException(GetText("ConnectionStillNotReady"));
        }

        var devices = new List<DeviceInfo>();
        var lines = result.Output.Split(new[] { "\r\n", "\n" }, StringSplitOptions.RemoveEmptyEntries);
        foreach (var line in lines.Skip(1))
        {
            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length < 2)
            {
                continue;
            }

            devices.Add(new DeviceInfo(parts[0], parts[1]));
        }

        return devices;
    }

    private async Task MuteAsync(string adbPath, string serial)
    {
        var settingsResult = await RunAdbAsync(adbPath, serial, "shell", "settings", "put", "system", CameraSettingKey, "0");
        EnsureSuccess(settingsResult, "MuteFailed");

        if (trySetVibrateMode)
        {
            var vibrateResult = await RunAdbAsync(adbPath, serial, "shell", "cmd", "audio", "set-ringer-mode", "VIBRATE");
            if (vibrateResult.ExitCode == 0)
            {
                WriteMessage("VibrateSuccess");
            }
            else
            {
                WriteMessage("VibrateUnsupported");
            }
        }
        else
        {
            WriteMessage("RingerUnchanged");
        }

        WriteMessage("MuteDone");
    }

    private async Task UnmuteAsync(string adbPath, string serial)
    {
        var result = await RunAdbAsync(adbPath, serial, "shell", "settings", "put", "system", CameraSettingKey, "1");
        EnsureSuccess(result, "UnmuteFailed");
        WriteMessage("UnmuteDone");
    }

    private void EnsureSuccess(CommandResult result, string errorKey)
    {
        if (result.ExitCode == 0)
        {
            return;
        }

        throw new InvalidOperationException($"{GetText(errorKey)} {result.Output}".Trim());
    }

    private async Task<CommandResult> RunAdbAsync(string adbPath, string? serial, params string[] arguments)
    {
        var allArguments = new List<string>();
        if (!string.IsNullOrWhiteSpace(serial))
        {
            allArguments.Add("-s");
            allArguments.Add(serial);
        }

        allArguments.AddRange(arguments);
        WriteLog($"Running: {adbPath} {string.Join(" ", allArguments.Select(QuoteIfNeeded))}");
        return await TryRunProcessAsync(adbPath, allArguments);
    }

    private static async Task<CommandResult> TryRunProcessAsync(string fileName, IReadOnlyList<string> arguments, bool echoOutput = true)
    {
        var process = new Process
        {
            StartInfo = new ProcessStartInfo
            {
                FileName = fileName,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
                CreateNoWindow = true
            }
        };

        foreach (var argument in arguments)
        {
            process.StartInfo.ArgumentList.Add(argument);
        }

        var outputBuilder = new StringBuilder();
        process.OutputDataReceived += (_, eventArgs) =>
        {
            if (eventArgs.Data is not null)
            {
                outputBuilder.AppendLine(eventArgs.Data);
                if (echoOutput)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {eventArgs.Data}");
                }
            }
        };
        process.ErrorDataReceived += (_, eventArgs) =>
        {
            if (eventArgs.Data is not null)
            {
                outputBuilder.AppendLine(eventArgs.Data);
                if (echoOutput)
                {
                    Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {eventArgs.Data}");
                }
            }
        };

        process.Start();
        process.BeginOutputReadLine();
        process.BeginErrorReadLine();
        await process.WaitForExitAsync();
        return new CommandResult(process.ExitCode, outputBuilder.ToString().Trim());
    }

    private void WriteLog(string message) => Console.WriteLine($"[{DateTime.Now:HH:mm:ss}] {message}");

    private void WriteMessage(string key) => Console.WriteLine(GetText(key));

    private string GetText(string key)
    {
        if (!text.TryGetValue(key, out var value))
        {
            throw new KeyNotFoundException($"Missing text key: {key}");
        }

        return value;
    }

    private string[] GetTextLines(string key)
    {
        if (!textLines.TryGetValue(key, out var value))
        {
            throw new KeyNotFoundException($"Missing text line key: {key}");
        }

        return value;
    }

    private string Format(string key, params object[] args) => string.Format(CultureInfo.InvariantCulture, GetText(key), args);

    private void ApplyLanguage(LanguageCode currentLanguage)
    {
        (text, textLines) = currentLanguage switch
        {
            LanguageCode.Ja => BuildJapaneseText(),
            _ => BuildKoreanText()
        };
    }

    private static LanguageCode ResolveDefaultLanguage()
    {
        return CultureInfo.CurrentUICulture.Name.StartsWith("ja", StringComparison.OrdinalIgnoreCase)
            ? LanguageCode.Ja
            : LanguageCode.Ko;
    }

    private static LanguageCode ParseLanguage(string value)
    {
        return value.ToLowerInvariant() switch
        {
            "ko" => LanguageCode.Ko,
            "ja" => LanguageCode.Ja,
            _ => throw new InvalidOperationException("Supported languages: ko, ja")
        };
    }

    private static AppAction ParseAction(string value)
    {
        return value.ToLowerInvariant() switch
        {
            "mute" => AppAction.Mute,
            "unmute" => AppAction.Unmute,
            "setedit" => AppAction.SetEditSetup,
            "setedit-setup" => AppAction.SetEditSetup,
            "setup-setedit" => AppAction.SetEditSetup,
            "setedit-open" => AppAction.SetEditOpen,
            "open-setedit" => AppAction.SetEditOpen,
            _ => throw new InvalidOperationException("Supported actions: mute, unmute, setedit-setup, setedit-open")
        };
    }

    private static string QuoteIfNeeded(string value) => value.Contains(' ') ? $"\"{value}\"" : value;

    private static (Dictionary<string, string>, Dictionary<string, string[]>) BuildKoreanText()
    {
        return (
            new Dictionary<string, string>
            {
                ["ChooseAction"] = "실행할 작업을 선택하세요",
                ["MuteAction"] = "카메라 무음 적용",
                ["UnmuteAction"] = "카메라 소리 복구",
                ["SetEditSetupAction"] = "SetEdit 설치와 권한 부여",
                ["SetEditOpenAction"] = "SetEdit 열기",
                ["ExitAction"] = "종료",
                ["ActionPrompt"] = "번호",
                ["ClosePrompt"] = "닫으려면 Enter를 누르세요",
                ["DetectedState"] = "현재 감지된 상태:",
                ["Unauthorized1"] = "휴대폰은 연결됐지만 RSA 승인 전 상태입니다.",
                ["Unauthorized2"] = "휴대폰 화면에서 USB 디버깅 허용 팝업을 승인하면 계속 진행됩니다.",
                ["RetryPrompt"] = "준비가 끝났으면 Enter를 눌러 다시 확인합니다. 취소하려면 창을 닫으세요.",
                ["AdbNotFound"] = "adb.exe를 찾지 못했습니다. Android platform-tools 또는 Android Studio를 먼저 설치해 주세요.",
                ["UsingBundledAdb"] = "내장된 ADB를 사용합니다: {0}",
                ["UsingSystemAdb"] = "시스템 ADB를 사용합니다: {0}",
                ["MoreThanOneDevice"] = "여러 기기가 연결되어 있습니다: {0}. 한 대만 연결해 주세요.",
                ["ConnectionCancelled"] = "작업을 취소했습니다.",
                ["ConnectionStillNotReady"] = "ADB 연결이 아직 준비되지 않았습니다.",
                ["VibrateSuccess"] = "진동 모드 전환이 성공했습니다.",
                ["VibrateUnsupported"] = "자동 진동 전환은 이 기기에서 지원되지 않았습니다. 필요하면 휴대폰을 직접 진동 또는 무음으로 바꿔 주세요.",
                ["RingerUnchanged"] = "휴대폰 소리 모드는 바꾸지 않았습니다.",
                ["MuteDone"] = "카메라 무음 적용이 완료되었습니다.",
                ["UnmuteDone"] = "카메라 셔터음을 다시 켰습니다.",
                ["UsingDevice"] = "사용 기기: {0}",
                ["Finished"] = "원클릭 작업이 완료되었습니다.",
                ["ErrorPrefix"] = "오류:",
                ["MuteFailed"] = "카메라 무음 적용에 실패했습니다.",
                ["UnmuteFailed"] = "카메라 소리 복구에 실패했습니다.",
                ["SetEditUsingLocalApk"] = "지정한 SetEdit APK를 사용합니다: {0}",
                ["SetEditUsingCachedApk"] = "기존 SetEdit APK를 사용합니다: {0}",
                ["SetEditDownloading"] = "SetEdit APK를 다운로드합니다: {0}",
                ["SetEditDownloadDone"] = "SetEdit APK 다운로드가 완료되었습니다: {0}",
                ["SetEditApkNotFound"] = "SetEdit APK를 찾지 못했습니다: {0}",
                ["SetEditInstalling"] = "SetEdit를 설치합니다.",
                ["SetEditInstalled"] = "SetEdit 설치가 완료되었습니다.",
                ["SetEditWriteSettingsGranted"] = "SetEdit WRITE_SETTINGS 권한을 허용했습니다.",
                ["SetEditWriteSettingsFailed"] = "SetEdit WRITE_SETTINGS 권한 허용에 실패했습니다.",
                ["SetEditSecureGranted"] = "SetEdit WRITE_SECURE_SETTINGS 권한을 부여했습니다.",
                ["SetEditSecureSkipped"] = "SetEdit WRITE_SECURE_SETTINGS 권한 부여는 건너뛰었습니다.",
                ["SetEditInstallFailed"] = "SetEdit 설치에 실패했습니다.",
                ["SetEditOpenFailed"] = "SetEdit 실행에 실패했습니다.",
                ["SetEditOpened"] = "SetEdit를 열었습니다.",
                ["SetEditSetupDone"] = "SetEdit 준비가 완료되었습니다.",
                ["InstallRetryingAfterUninstall"] = "{0} 기존 설치와 충돌해서 삭제 후 다시 설치합니다."
            },
            new Dictionary<string, string[]>
            {
                ["NeedUsbDebugBody"] =
                [
                    "ADB 연결 준비가 필요합니다.",
                    "",
                    "삼성폰에서 USB 디버깅 켜는 방법:",
                    "1. 휴대폰 잠금을 해제합니다.",
                    "2. 설정 > 휴대전화 정보 > 소프트웨어 정보로 이동합니다.",
                    "3. 빌드번호를 7번 눌러 개발자 옵션을 켭니다.",
                    "4. 설정 메인으로 돌아가 개발자 옵션을 엽니다.",
                    "5. USB 디버깅을 켭니다.",
                    "6. USB 케이블을 다시 연결하고 가능하면 USB 사용 모드를 파일 전송으로 바꿉니다.",
                    "7. 휴대폰 화면의 USB 디버깅 허용 팝업에서 항상 이 컴퓨터를 허용을 체크하고 허용을 누릅니다."
                ],
                ["SetEditGuide"] =
                [
                    "SetEdit에서 바꿀 값 안내:",
                    "1. Database를 System으로 둡니다.",
                    $"2. key {CameraSettingKey} 를 찾습니다.",
                    "3. 값을 0으로 바꾸면 무음, 1로 바꾸면 소리 복구입니다.",
                    "4. 이 값이 막히면 SetEdit 방식도 함께 막힐 수 있습니다."
                ]
            }
        );
    }

    private static (Dictionary<string, string>, Dictionary<string, string[]>) BuildJapaneseText()
    {
        return (
            new Dictionary<string, string>
            {
                ["ChooseAction"] = "実行する操作を選んでください",
                ["MuteAction"] = "カメラ無音を適用",
                ["UnmuteAction"] = "カメラ音を元に戻す",
                ["SetEditSetupAction"] = "SetEdit をインストールして権限を付与",
                ["SetEditOpenAction"] = "SetEdit を開く",
                ["ExitAction"] = "終了",
                ["ActionPrompt"] = "番号",
                ["ClosePrompt"] = "閉じるには Enter を押してください",
                ["DetectedState"] = "現在の検出状態:",
                ["Unauthorized1"] = "端末は接続されていますが、RSA 承認待ちです。",
                ["Unauthorized2"] = "端末側で USB デバッグ許可ポップアップを承認すると続行します。",
                ["RetryPrompt"] = "準備ができたら Enter を押して再確認します。やめる場合はウィンドウを閉じてください。",
                ["AdbNotFound"] = "adb.exe が見つかりません。Android platform-tools または Android Studio を先にインストールしてください。",
                ["UsingBundledAdb"] = "内蔵 ADB を使用します: {0}",
                ["UsingSystemAdb"] = "システム ADB を使用します: {0}",
                ["MoreThanOneDevice"] = "複数の端末が接続されています: {0}。1 台だけ接続してください。",
                ["ConnectionCancelled"] = "処理をキャンセルしました。",
                ["ConnectionStillNotReady"] = "ADB 接続がまだ準備できていません。",
                ["VibrateSuccess"] = "バイブモードへの切り替えに成功しました。",
                ["VibrateUnsupported"] = "この端末では自動バイブ切り替えに対応していません。必要なら端末を手動でバイブまたはサイレントにしてください。",
                ["RingerUnchanged"] = "着信モードは変更していません。",
                ["MuteDone"] = "カメラ無音の適用が完了しました。",
                ["UnmuteDone"] = "カメラのシャッター音を元に戻しました。",
                ["UsingDevice"] = "使用端末: {0}",
                ["Finished"] = "ワンクリック処理が完了しました。",
                ["ErrorPrefix"] = "エラー:",
                ["MuteFailed"] = "カメラ無音の適用に失敗しました。",
                ["UnmuteFailed"] = "カメラ音の復元に失敗しました。",
                ["SetEditUsingLocalApk"] = "指定した SetEdit APK を使用します: {0}",
                ["SetEditUsingCachedApk"] = "既存の SetEdit APK を使用します: {0}",
                ["SetEditDownloading"] = "SetEdit APK をダウンロードします: {0}",
                ["SetEditDownloadDone"] = "SetEdit APK のダウンロードが完了しました: {0}",
                ["SetEditApkNotFound"] = "SetEdit APK が見つかりません: {0}",
                ["SetEditInstalling"] = "SetEdit をインストールします。",
                ["SetEditInstalled"] = "SetEdit のインストールが完了しました。",
                ["SetEditWriteSettingsGranted"] = "SetEdit に WRITE_SETTINGS 権限を許可しました。",
                ["SetEditWriteSettingsFailed"] = "SetEdit への WRITE_SETTINGS 権限付与に失敗しました。",
                ["SetEditSecureGranted"] = "SetEdit に WRITE_SECURE_SETTINGS 権限を付与しました。",
                ["SetEditSecureSkipped"] = "SetEdit への WRITE_SECURE_SETTINGS 権限付与はスキップしました。",
                ["SetEditInstallFailed"] = "SetEdit のインストールに失敗しました。",
                ["SetEditOpenFailed"] = "SetEdit の起動に失敗しました。",
                ["SetEditOpened"] = "SetEdit を開きました。",
                ["SetEditSetupDone"] = "SetEdit の準備が完了しました。",
                ["InstallRetryingAfterUninstall"] = "{0} の既存インストールと競合したため、削除して再インストールします。"
            },
            new Dictionary<string, string[]>
            {
                ["NeedUsbDebugBody"] =
                [
                    "ADB 接続の準備が必要です。",
                    "",
                    "Samsung 端末で USB デバッグを有効にする方法:",
                    "1. 端末のロックを解除します。",
                    "2. 設定 > 端末情報 > ソフトウェア情報 を開きます。",
                    "3. ビルド番号を 7 回タップして開発者向けオプションを有効にします。",
                    "4. 設定に戻って開発者向けオプションを開きます。",
                    "5. USB デバッグをオンにします。",
                    "6. USB ケーブルを挿し直し、可能なら USB モードをファイル転送に変更します。",
                    "7. 端末に表示される USB デバッグ許可ポップアップで、このパソコンを常に許可をチェックして許可します。"
                ],
                ["SetEditGuide"] =
                [
                    "SetEdit で変更する値:",
                    "1. Database を System にします。",
                    $"2. key {CameraSettingKey} を探します。",
                    "3. 値を 0 にすると無音、1 にすると音を戻せます。",
                    "4. Samsung 側でこのキーが無効化されると SetEdit 方式も使えなくなる可能性があります。"
                ]
            }
        );
    }
}
