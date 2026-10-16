#pragma once
#ifndef NOMINMAX
#define NOMINMAX
#endif
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <filesystem>
#include "core.hpp"

namespace ddc {
std::wstring wide(const std::string& value);
std::string utf8(const std::wstring& value);
std::string systemError(const std::string& context,DWORD code=GetLastError());
std::string newID();
std::filesystem::path exePath();
std::filesystem::path settingsPath(bool demo);
Config loadSettings(const std::filesystem::path& path);
void saveSettings(const std::filesystem::path& path,const Config& config);
std::filesystem::path backupSettings(const std::filesystem::path& path);
std::wstring shortcutLabel(Shortcut shortcut);
struct WinRegistrar: Registrar {
    HWND window;
    explicit WinRegistrar(HWND hwnd): window(hwnd) {}
    void add(int id,Shortcut shortcut) override;
    void remove(int id) noexcept override;
};
struct WorkerResult {
    bool success=false;
    std::string message;
    std::vector<Monitor> monitors;
};
WorkerResult runChild(const std::vector<std::string>& arguments,DWORD timeout=8000);
int workerEntry(const std::vector<std::wstring>& arguments);
int selfTest(const std::filesystem::path& report);
}
