#pragma once
#include "platform.hpp"

namespace ddc {
struct StartupState { bool registered=false; bool currentPath=false; };
// Alternate roots/keys permit isolated tests; the UI always uses the default Run key.
class StartupRegistration {
    HKEY root;
    std::wstring key;
public:
    explicit StartupRegistration(HKEY rootKey=HKEY_CURRENT_USER,
        std::wstring subkey=L"Software\\Microsoft\\Windows\\CurrentVersion\\Run")
        : root(rootKey),key(std::move(subkey)) {}
    std::wstring command() const;
    StartupState state(const std::filesystem::path& executable) const;
    void setEnabled(bool enabled,const std::filesystem::path& executable) const;
};
}
