using Microsoft.Win32;
using TrayIconGuard.Interop;

namespace TrayIconGuard.Services;

/// <summary>
/// Event-driven registry change monitor built on RegNotifyChangeKeyValue.
/// Fires <see cref="Changed"/> after every subtree modification (debounced)
/// and periodically as a consistency heartbeat. Falls back to pure polling
/// when the notification cannot be armed (e.g. key transiently deleted).
/// </summary>
public sealed class RegistryMonitor : IDisposable
{
    private readonly string _subKeyPath;

    private CancellationTokenSource? _cts;
    private Task? _loopTask;
    private bool _disposed;

    public RegistryMonitor(string subKeyPath) => _subKeyPath = subKeyPath;

    /// <summary>Raised on the monitor thread after each change/heartbeat cycle.</summary>
    public event Action? Changed;

    public bool UseEvents { get; set; } = true;
    public int PollIntervalSeconds { get; set; } = 3;
    public int DebounceMilliseconds { get; set; } = 400;
    public bool IsRunning => _loopTask is { IsCompleted: false };

    public void Start()
    {
        ObjectDisposedException.ThrowIf(_disposed, this);
        if (IsRunning)
        {
            return;
        }

        _cts = new CancellationTokenSource();
        var ct = _cts.Token;
        _loopTask = Task.Run(() => LoopAsync(ct), CancellationToken.None);
    }

    public void Stop()
    {
        try
        {
            _cts?.Cancel();
            _loopTask?.Wait(TimeSpan.FromSeconds(3));
        }
        catch (AggregateException)
        {
            // Cancellation races are expected during shutdown.
        }
        catch (OperationCanceledException)
        {
            // Expected during shutdown.
        }
        finally
        {
            _cts?.Dispose();
            _cts = null;
            _loopTask = null;
        }
    }

    public void Dispose()
    {
        if (_disposed)
        {
            return;
        }

        Stop();
        _disposed = true;
    }

    private async Task LoopAsync(CancellationToken ct)
    {
        LogService.Instance.Info(
            $"Registry monitor started (events={UseEvents}, poll={PollIntervalSeconds}s, debounce={DebounceMilliseconds}ms).");

        try
        {
            while (!ct.IsCancellationRequested)
            {
                if (UseEvents)
                {
                    var (armed, signaled) = await WaitForChangeAsync(ct).ConfigureAwait(false);
                    if (armed && signaled)
                    {
                        // Real change: let the burst settle, then scan.
                        await Task.Delay(DebounceMilliseconds, ct).ConfigureAwait(false);
                    }
                    else if (!armed)
                    {
                        // Could not arm the notification this cycle: pure polling.
                        await Task.Delay(PollIntervalSeconds * 1000, ct).ConfigureAwait(false);
                    }
                    // armed && !signaled == periodic re-arm timeout: heartbeat scan below.
                }
                else
                {
                    await Task.Delay(PollIntervalSeconds * 1000, ct).ConfigureAwait(false);
                }

                try
                {
                    Changed?.Invoke();
                }
                catch (Exception ex)
                {
                    LogService.Instance.Error("Registry monitor subscriber failed", ex);
                }
            }
        }
        catch (OperationCanceledException)
        {
            // Normal shutdown path.
        }

        LogService.Instance.Info("Registry monitor stopped.");
    }

    private async Task<(bool Armed, bool Signaled)> WaitForChangeAsync(CancellationToken ct)
    {
        RegistryKey? root = null;
        ManualResetEvent? changedEvent = null;
        try
        {
            root = Registry.CurrentUser.OpenSubKey(_subKeyPath, writable: false)
                   ?? Registry.CurrentUser.CreateSubKey(_subKeyPath);
            if (root is null)
            {
                return (false, false);
            }

            changedEvent = new ManualResetEvent(initialState: false);
            const int filter = NativeMethods.REG_NOTIFY_CHANGE_NAME | NativeMethods.REG_NOTIFY_CHANGE_LAST_SET;

            int rc = NativeMethods.RegNotifyChangeKeyValue(
                root.Handle, bWatchSubtree: true, filter, changedEvent.SafeWaitHandle, fAsynchronous: true);

            if (rc != 0)
            {
                LogService.Instance.Warn(
                    rc == NativeMethods.ERROR_KEY_DELETED
                        ? "Watched key was deleted; reopening next cycle."
                        : $"RegNotifyChangeKeyValue failed ({rc}); polling this cycle.");
                return (false, false);
            }

            int index = await Task.Run(
                () => WaitHandle.WaitAny([changedEvent, ct.WaitHandle], PollIntervalSeconds * 1000),
                CancellationToken.None).ConfigureAwait(false);

            ct.ThrowIfCancellationRequested();
            return (true, index == 0);
        }
        catch (OperationCanceledException)
        {
            throw;
        }
        catch (Exception ex)
        {
            LogService.Instance.Error("Failed to arm registry notification", ex);
            return (false, false);
        }
        finally
        {
            changedEvent?.Dispose();
            root?.Dispose();
        }
    }
}
