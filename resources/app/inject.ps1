param(
    [Parameter(Mandatory=$true)][int]$TargetPID,
    [Parameter(Mandatory=$true)][string]$DLLPath
)

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using System.Text;

public class DLLInjector {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr OpenProcess(uint access, bool inherit, int pid);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr VirtualAllocEx(IntPtr hProcess, IntPtr addr, uint size, uint type, uint protect);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr addr, byte[] buf, uint size, out int written);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr CreateRemoteThread(IntPtr hProcess, IntPtr attr, uint stackSize, IntPtr startAddr, IntPtr param, uint flags, out int threadId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint WaitForSingleObject(IntPtr handle, uint ms);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetExitCodeThread(IntPtr hThread, out uint exitCode);

    [DllImport("kernel32.dll")]
    public static extern bool CloseHandle(IntPtr handle);

    [DllImport("kernel32.dll")]
    public static extern bool VirtualFreeEx(IntPtr hProcess, IntPtr addr, uint size, uint type);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode)]
    public static extern IntPtr GetModuleHandle(string name);

    [DllImport("kernel32.dll", CharSet = CharSet.Ansi, ExactSpelling = true)]
    public static extern IntPtr GetProcAddress(IntPtr hModule, string name);

    public static string Inject(int pid, string dllPath) {
        uint access = 0x0002 | 0x0008 | 0x0010 | 0x0020 | 0x0400;
        IntPtr hProc = OpenProcess(access, false, pid);
        if (hProc == IntPtr.Zero)
            return "ERROR:Failed to open process. Run EthyrialHub as Administrator.";

        byte[] pathBytes = Encoding.Unicode.GetBytes(dllPath + "\0");
        uint pathLen = (uint)pathBytes.Length;

        IntPtr memAddr = VirtualAllocEx(hProc, IntPtr.Zero, pathLen, 0x3000, 0x04);
        if (memAddr == IntPtr.Zero) {
            CloseHandle(hProc);
            return "ERROR:Failed to allocate memory in target process.";
        }

        int written;
        if (!WriteProcessMemory(hProc, memAddr, pathBytes, pathLen, out written)) {
            VirtualFreeEx(hProc, memAddr, 0, 0x8000);
            CloseHandle(hProc);
            return "ERROR:Failed to write DLL path to target process.";
        }

        IntPtr k32 = GetModuleHandle("kernel32.dll");
        IntPtr loadLib = GetProcAddress(k32, "LoadLibraryW");
        if (loadLib == IntPtr.Zero) {
            VirtualFreeEx(hProc, memAddr, 0, 0x8000);
            CloseHandle(hProc);
            return "ERROR:Failed to resolve LoadLibraryW.";
        }

        int threadId;
        IntPtr hThread = CreateRemoteThread(hProc, IntPtr.Zero, 0, loadLib, memAddr, 0, out threadId);
        if (hThread == IntPtr.Zero) {
            VirtualFreeEx(hProc, memAddr, 0, 0x8000);
            CloseHandle(hProc);
            return "ERROR:Failed to create remote thread. Run EthyrialHub as Administrator.";
        }

        uint waitResult = WaitForSingleObject(hThread, 15000);

        uint exitCode;
        GetExitCodeThread(hThread, out exitCode);

        CloseHandle(hThread);
        VirtualFreeEx(hProc, memAddr, 0, 0x8000);
        CloseHandle(hProc);

        if (waitResult != 0)
            return "ERROR:Remote thread timed out after 15 seconds.";

        if (exitCode == 0)
            return "ERROR:LoadLibraryW returned 0. DLL failed to load in target process.";

        return "OK";
    }
}
"@ -Language CSharp

$result = [DLLInjector]::Inject($TargetPID, $DLLPath)
Write-Output $result
