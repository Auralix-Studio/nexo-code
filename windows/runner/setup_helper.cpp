#include <windows.h>
#include <shellapi.h>
#include <string>

// GUI executable. CREATE_NO_WINDOW prevents even a transient console.
int WINAPI wWinMain(HINSTANCE, HINSTANCE, PWSTR, int) {
  int argc = 0;
  auto argv = CommandLineToArgvW(GetCommandLineW(), &argc);
  if (!argv || argc < 3 || std::wstring(argv[1]) != L"--powershell") {
    if (argv) LocalFree(argv);
    return ERROR_INVALID_PARAMETER;
  }
  const std::wstring encoded = argv[2];
  const bool detached = argc == 4 && std::wstring(argv[3]) == L"--detach";
  LocalFree(argv);
  if (encoded.find_first_not_of(L"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=") != std::wstring::npos)
    return ERROR_INVALID_PARAMETER;
  wchar_t system[MAX_PATH];
  if (!GetSystemDirectoryW(system, MAX_PATH)) return static_cast<int>(GetLastError());
  const std::wstring exe = std::wstring(system) + L"\\WindowsPowerShell\\v1.0\\powershell.exe";
  std::wstring command = L"\"" + exe + L"\" -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand " + encoded;
  STARTUPINFOW startup{};
  startup.cb = sizeof(startup);
  startup.dwFlags = STARTF_USESHOWWINDOW;
  startup.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION process{};
  if (!CreateProcessW(exe.c_str(), command.data(), nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &startup, &process))
    return static_cast<int>(GetLastError());
  CloseHandle(process.hThread);
  DWORD code = 0;
  if (!detached) {
    const auto waited = WaitForSingleObject(process.hProcess, 120000);
    if (waited != WAIT_OBJECT_0) {
      TerminateProcess(process.hProcess, ERROR_TIMEOUT);
      code = ERROR_TIMEOUT;
    } else if (!GetExitCodeProcess(process.hProcess, &code)) {
      code = GetLastError();
    }
  }
  CloseHandle(process.hProcess);
  return static_cast<int>(code);
}
