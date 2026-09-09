using Microsoft.Win32;

namespace Flux.Services;

public sealed class StartupRegistrationService
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const string ValueName = "Flux";

    public bool IsRegistered
    {
        get
        {
            try
            {
                using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, false);
                return key?.GetValue(ValueName) is not null;
            }
            catch
            {
                return false;
            }
        }
    }

    public bool Register()
    {
        try
        {
            var exePath = $"\"{Environment.ProcessPath}\"";
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true);
            if (key is null) return false;
            key.SetValue(ValueName, exePath, RegistryValueKind.String);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public bool Unregister()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, true);
            if (key is null) return true;
            key.DeleteValue(ValueName, false);
            return true;
        }
        catch
        {
            return false;
        }
    }
}
