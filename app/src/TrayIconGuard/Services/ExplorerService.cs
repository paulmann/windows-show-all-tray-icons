using System.Diagnostics;

namespace TrayIconGuard.Services;

/// <summary>
/// Safe Explorer restart: kill every explorer.exe (the shell normally
/// auto-restarts), wait, and start it manually if Windows did not bring it back.
/// </summary>
public static class ExplorerService
{
    public static async Task<(bool Success, int Killed, long Ms)> RestartAsync(int timeoutSeconds = 8)
    {
        var sw = Stopwatch.StartNew();
        int killed = 0;

        foreach (var process in Process.GetProcessesByName("explorer"))
        {
            try
            {
                process.Kill();
                killed++;
            }
            catch (Exception ex)
            {
                LogService.Instance.Warn($"Could not stop explorer PID {process.Id}: {ex.Message}");
            }
            finally
            {
                process.Dispose();
            }
        }

        LogService.Instance.Info($"Explorer restart: stopped {killed} process(es); waiting for the shell...");

        bool back = await WaitForExplorerAsync(TimeSpan.FromSeconds(timeoutSeconds)).ConfigureAwait(false);
        if (!back)
        {
            try
            {
                Process.Start(new ProcessStartInfo("explorer.exe") { UseShellExecute = true })?.Dispose();
                back = await WaitForExplorerAsync(TimeSpan.FromSeconds(5)).ConfigureAwait(false);
            }
            catch (Exception ex)
            {
                LogService.Instance.Error("Failed to start explorer.exe", ex);
            }
        }

        LogService.Instance.Info($"Explorer restart finished in {sw.ElapsedMilliseconds} ms (success={back}).");
        return (back, killed, sw.ElapsedMilliseconds);
    }

    private static async Task<bool> WaitForExplorerAsync(TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (DateTime.UtcNow < deadline)
        {
            var processes = Process.GetProcessesByName("explorer");
            var any = processes.Length > 0;
            foreach (var process in processes)
            {
                process.Dispose();
            }

            if (any)
            {
                return true;
            }

            await Task.Delay(250).ConfigureAwait(false);
        }

        return false;
    }
}
