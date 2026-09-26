#ifndef UNICODE
#define UNICODE
#endif
#include <windows.h>
#include <shlobj.h>
#include <objbase.h>
#include <string>
#include <vector>



// --- utilidades -------------------------------------------------------------

static std::wstring SelfPath() {
  std::wstring buf(MAX_PATH, L'\0');
  DWORD n = GetModuleFileNameW(nullptr, &buf[0], (DWORD)buf.size());
  buf.resize(n);
  return buf;
}

static std::wstring LocalAppData() {
  PWSTR p = nullptr;
  std::wstring out;
  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_LocalAppData, 0, nullptr, &p))) {
    out = p;
  }
  if (p) CoTaskMemFree(p);
  return out;
}

static std::wstring SystemTar() {
  std::wstring dir(MAX_PATH, L'\0');
  UINT n = GetSystemDirectoryW(&dir[0], (UINT)dir.size());
  dir.resize(n);
  return dir + L"\\tar.exe";
}

static void Fatal(const std::wstring& msg) {
  MessageBoxW(nullptr, msg.c_str(), L"Nexo UPLA — Instalador",
              MB_ICONERROR | MB_OK);
}

// Ejecuta un proceso oculto y espera; devuelve el exit code (o -1 si falla).
static int RunHiddenWait(const std::wstring& cmdLine) {
  std::wstring mutableCmd = cmdLine;  // CreateProcessW puede modificar el buffer
  STARTUPINFOW si{};
  si.cb = sizeof(si);
  si.dwFlags = STARTF_USESHOWWINDOW;
  si.wShowWindow = SW_HIDE;
  PROCESS_INFORMATION pi{};
  if (!CreateProcessW(nullptr, &mutableCmd[0], nullptr, nullptr, FALSE,
                      CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
    return -1;
  }
  if (WaitForSingleObject(pi.hProcess, 120000) != WAIT_OBJECT_0) {
    TerminateProcess(pi.hProcess, ERROR_TIMEOUT);
    CloseHandle(pi.hThread); CloseHandle(pi.hProcess); return ERROR_TIMEOUT;
  }
  DWORD code = 1;
  GetExitCodeProcess(pi.hProcess, &code);
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return (int)code;
}

static bool LaunchDetached(const std::wstring& exePath,
                           const std::wstring& workDir) {
  std::wstring cmd = L"\"" + exePath + L"\" --setup";
  STARTUPINFOW si{};
  si.cb = sizeof(si);
  PROCESS_INFORMATION pi{};
  if (!CreateProcessW(nullptr, &cmd[0], nullptr, nullptr, FALSE, 0, nullptr,
                      workDir.c_str(), &si, &pi)) {
    return false;
  }
  CloseHandle(pi.hThread);
  CloseHandle(pi.hProcess);
  return true;
}

// Embed the archive as a PE resource, compatible with Authenticode signing.
static bool ExtractOverlayToFile(const std::wstring& destZip) {
  auto resource = FindResourceW(nullptr, MAKEINTRESOURCEW(101), RT_RCDATA);
  if (!resource) return false;
  const DWORD size = SizeofResource(nullptr, resource);
  auto loaded = LoadResource(nullptr, resource);
  auto data = LockResource(loaded);
  if (!data || !size) return false;
  HANDLE file = CreateFileW(destZip.c_str(), GENERIC_WRITE, 0, nullptr,
                           CREATE_NEW, FILE_ATTRIBUTE_NORMAL, nullptr);
  if (file == INVALID_HANDLE_VALUE) return false;
  DWORD written = 0;
  const bool ok = WriteFile(file, data, size, &written, nullptr) && written == size;
  CloseHandle(file);
  return ok;
}

// --- splash mínima ("Preparando Nexo UPLA…") --------------------------------

static LRESULT CALLBACK SplashProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
  if (msg == WM_PAINT) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);
    RECT rc;
    GetClientRect(hwnd, &rc);
    HBRUSH bg = CreateSolidBrush(RGB(0x0E, 0x0F, 0x1A));  // fondo oscuro Nexo
    FillRect(hdc, &rc, bg);
    DeleteObject(bg);
    SetBkMode(hdc, TRANSPARENT);
    SetTextColor(hdc, RGB(0xE8, 0xEA, 0xF2));
    HFONT font = CreateFontW(-20, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
                             DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                             CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                             DEFAULT_PITCH | FF_DONTCARE, L"Segoe UI");
    HGDIOBJ old = SelectObject(hdc, font);
    DrawTextW(hdc, L"Preparando Nexo UPLA…", -1, &rc,
              DT_CENTER | DT_VCENTER | DT_SINGLELINE);
    SelectObject(hdc, old);
    DeleteObject(font);
    EndPaint(hwnd, &ps);
    return 0;
  }
  return DefWindowProcW(hwnd, msg, wp, lp);
}

static HWND ShowSplash(HINSTANCE hInst) {
  WNDCLASSW wc{};
  wc.lpfnWndProc = SplashProc;
  wc.hInstance = hInst;
  wc.hCursor = LoadCursor(nullptr, IDC_APPSTARTING);
  wc.lpszClassName = L"NexoSetupSplash";
  RegisterClassW(&wc);

  const int w = 380, h = 130;
  int sx = GetSystemMetrics(SM_CXSCREEN), sy = GetSystemMetrics(SM_CYSCREEN);
  HWND hwnd = CreateWindowExW(
      WS_EX_TOPMOST | WS_EX_TOOLWINDOW, wc.lpszClassName, L"Nexo UPLA",
      WS_POPUP | WS_BORDER, (sx - w) / 2, (sy - h) / 2, w, h, nullptr, nullptr,
      hInst, nullptr);
  if (hwnd) {
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
  }
  return hwnd;
}

// --- entry point ------------------------------------------------------------

int WINAPI wWinMain(HINSTANCE hInst, HINSTANCE, LPWSTR, int) {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  const std::wstring lad = LocalAppData();
  if (lad.empty()) {
    Fatal(L"No se pudo determinar la carpeta de datos del usuario.");
    return 1;
  }
  HANDLE mutex = CreateMutexW(nullptr, TRUE, L"Local\\NexoSetup");
  if (!mutex || GetLastError() == ERROR_ALREADY_EXISTS) {
    Fatal(L"Ya hay un instalador de Nexo abierto."); return 1;
  }
  const std::wstring root = lad + L"\\Nexo";
  const std::wstring stagingRoot = root + L"\\_stage";
  for (const auto& path : {root, stagingRoot}) {
    const DWORD attributes = GetFileAttributesW(path.c_str());
    if (attributes != INVALID_FILE_ATTRIBUTES && (attributes & FILE_ATTRIBUTE_REPARSE_POINT)) {
      Fatal(L"La ruta de instalación está redirigida."); return 1;
    }
  }
  GUID guid{}; CoCreateGuid(&guid);
  wchar_t unique[40]; StringFromGUID2(guid, unique, 40);
  const std::wstring stage = stagingRoot + L"\\" + unique;
  const std::wstring zipPath = stage + L"\\payload.zip";
  const std::wstring exePath = stage + L"\\nexo.exe";

  HWND splash = ShowSplash(hInst);

  // 1) Preparar carpeta de staging limpia.
  if (SHCreateDirectoryExW(nullptr, stage.c_str(), nullptr) != ERROR_SUCCESS) {
    Fatal(L"No se pudo crear una carpeta temporal privada."); return 1;
  }

  // 2) Extraer el overlay (payload.zip) del propio .exe.
  if (!ExtractOverlayToFile(zipPath)) {
    if (splash) DestroyWindow(splash);
    Fatal(L"El instalador está dañado o incompleto (no se encontró el "
          L"contenido de la aplicación). Descárgalo de nuevo.");
    return 2;
  }

  // 3) Descomprimir con el tar.exe de Windows (firmado por Microsoft).
  const std::wstring tar = SystemTar();
  if (GetFileAttributesW(tar.c_str()) == INVALID_FILE_ATTRIBUTES) {
    if (splash) DestroyWindow(splash);
    Fatal(L"Este equipo no incluye tar.exe (requiere Windows 10 1809 o "
          L"posterior). Usa el paquete ZIP como alternativa.");
    return 3;
  }
  std::wstring cmd = L"\"" + tar + L"\" -xf \"" + zipPath + L"\" -C \"" +
                     stage + L"\"";
  int rc = RunHiddenWait(cmd);
  if (rc != 0) {
    if (splash) DestroyWindow(splash);
    Fatal(L"No se pudo descomprimir la aplicación (código " +
          std::to_wstring(rc) + L").");
    return 4;
  }

  // 4) Limpiar el zip temporal.
  DeleteFileW(zipPath.c_str());

  // 5) Lanzar la app; su SetupWizard toma el control desde aquí.
  if (GetFileAttributesW(exePath.c_str()) == INVALID_FILE_ATTRIBUTES) {
    if (splash) DestroyWindow(splash);
    Fatal(L"No se encontró nexo.exe tras la extracción.");
    return 5;
  }
  bool launched = LaunchDetached(exePath, stage);

  if (splash) DestroyWindow(splash);
  CoUninitialize();

  if (!launched) {
    Fatal(L"No se pudo iniciar Nexo tras la instalación.");
    return 6;
  }
  return 0;
}
