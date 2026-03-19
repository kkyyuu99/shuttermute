using System.Net.Http;

internal sealed partial class ShutterMuteApp
{
    private async Task SetupSetEditAsync(string adbPath, string serial)
    {
        var apkPath = await ResolveSetEditApkPathAsync();
        WriteMessage("SetEditInstalling");
        await InstallApkAsync(
            adbPath,
            serial,
            SetEditPackageName,
            apkPath,
            bypassLowTargetSdkBlock: true,
            installErrorKey: "SetEditInstallFailed");
        WriteMessage("SetEditInstalled");

        var writeSettingsResult = await RunAdbAsync(
            adbPath,
            serial,
            "shell",
            "appops",
            "set",
            SetEditPackageName,
            "WRITE_SETTINGS",
            "allow");
        EnsureSuccess(writeSettingsResult, "SetEditWriteSettingsFailed");
        WriteMessage("SetEditWriteSettingsGranted");

        var secureSettingsResult = await RunAdbAsync(
            adbPath,
            serial,
            "shell",
            "pm",
            "grant",
            SetEditPackageName,
            "android.permission.WRITE_SECURE_SETTINGS");
        if (secureSettingsResult.ExitCode == 0)
        {
            WriteMessage("SetEditSecureGranted");
        }
        else
        {
            var extra = string.IsNullOrWhiteSpace(secureSettingsResult.Output)
                ? string.Empty
                : $" {secureSettingsResult.Output}";
            WriteLog($"{GetText("SetEditSecureSkipped")}{extra}");
        }

        if (openSetEditAfterSetup)
        {
            await OpenSetEditAsync(adbPath, serial);
        }

        WriteMessage("SetEditSetupDone");
        Console.WriteLine();
        foreach (var line in GetTextLines("SetEditGuide"))
        {
            Console.WriteLine(line);
        }
    }

    private async Task OpenSetEditAsync(string adbPath, string serial)
    {
        var result = await RunAdbAsync(
            adbPath,
            serial,
            "shell",
            "monkey",
            "-p",
            SetEditPackageName,
            "-c",
            "android.intent.category.LAUNCHER",
            "1");
        EnsureSuccess(result, "SetEditOpenFailed");
        WriteMessage("SetEditOpened");
    }

    private async Task<string> ResolveSetEditApkPathAsync()
    {
        if (!string.IsNullOrWhiteSpace(setEditApkPath))
        {
            var localPath = Path.GetFullPath(setEditApkPath);
            if (!File.Exists(localPath))
            {
                throw new InvalidOperationException(Format("SetEditApkNotFound", localPath));
            }

            WriteLog(Format("SetEditUsingLocalApk", localPath));
            return localPath;
        }

        var downloadRoot = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "ShutterMute",
            "downloads");
        Directory.CreateDirectory(downloadRoot);

        var cachedPath = Path.Combine(downloadRoot, SetEditDefaultFileName);
        if (File.Exists(cachedPath) && new FileInfo(cachedPath).Length > 0)
        {
            WriteLog(Format("SetEditUsingCachedApk", cachedPath));
            return cachedPath;
        }

        WriteLog(Format("SetEditDownloading", setEditDownloadUrl));
        await DownloadFileAsync(setEditDownloadUrl, cachedPath);
        WriteLog(Format("SetEditDownloadDone", cachedPath));
        return cachedPath;
    }

    private static async Task DownloadFileAsync(string url, string destinationPath)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(destinationPath)!);

        using var client = new HttpClient();
        client.DefaultRequestHeaders.UserAgent.ParseAdd("ShutterMute/1.0");

        using var response = await client.GetAsync(url, HttpCompletionOption.ResponseHeadersRead);
        response.EnsureSuccessStatusCode();

        await using var sourceStream = await response.Content.ReadAsStreamAsync();
        await using var destinationStream = new FileStream(destinationPath, FileMode.Create, FileAccess.Write, FileShare.Read);
        await sourceStream.CopyToAsync(destinationStream);
    }

    private async Task InstallApkAsync(
        string adbPath,
        string serial,
        string packageName,
        string apkPath,
        bool bypassLowTargetSdkBlock,
        string installErrorKey)
    {
        var installArguments = new List<string> { "install", "-r" };
        if (bypassLowTargetSdkBlock)
        {
            installArguments.Add("--bypass-low-target-sdk-block");
        }

        installArguments.Add(apkPath);
        var installResult = await RunAdbAsync(adbPath, serial, installArguments.ToArray());
        if (installResult.ExitCode == 0)
        {
            return;
        }

        if (NeedsReinstall(installResult.Output))
        {
            WriteLog(Format("InstallRetryingAfterUninstall", packageName));
            await RunAdbAsync(adbPath, serial, "uninstall", packageName);

            var retryArguments = new List<string> { "install", "-r" };
            if (bypassLowTargetSdkBlock)
            {
                retryArguments.Add("--bypass-low-target-sdk-block");
            }

            retryArguments.Add(apkPath);
            var retryResult = await RunAdbAsync(adbPath, serial, retryArguments.ToArray());
            EnsureSuccess(retryResult, installErrorKey);
            return;
        }

        EnsureSuccess(installResult, installErrorKey);
    }

    private static bool NeedsReinstall(string output)
    {
        return output.Contains("INSTALL_FAILED_UPDATE_INCOMPATIBLE", StringComparison.OrdinalIgnoreCase) ||
               output.Contains("INSTALL_PARSE_FAILED_INCONSISTENT_CERTIFICATES", StringComparison.OrdinalIgnoreCase) ||
               output.Contains("INSTALL_FAILED_VERSION_DOWNGRADE", StringComparison.OrdinalIgnoreCase);
    }

    private static void PrintHelp()
    {
        Console.WriteLine("ShutterMute");
        Console.WriteLine();
        Console.WriteLine("Options:");
        Console.WriteLine("  --language ko|ja");
        Console.WriteLine("  --action mute|unmute|setedit-setup|setedit-open");
        Console.WriteLine("  --skip-vibrate");
        Console.WriteLine("  --setedit-apk <path>");
        Console.WriteLine("  --setedit-url <url>");
        Console.WriteLine("  --no-open-setedit");
        Console.WriteLine("  --no-pause");
        Console.WriteLine("  --help");
    }
}
