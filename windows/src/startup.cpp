#include "startup.hpp"

namespace ddc {
namespace {
constexpr auto valueName=L"DDCSwitcher";
struct Key { HKEY value=nullptr; ~Key(){if(value)RegCloseKey(value);} };
void requireSuccess(LSTATUS code) {
    if(code!=ERROR_SUCCESS)throw std::runtime_error(systemError("无法访问登录启动项",static_cast<DWORD>(code)));
}
std::wstring startupCommand(const std::filesystem::path& executable) {
    const auto& path=executable.native();
    if(!executable.is_absolute() || path.find_first_of(L"\"\r\n")!=std::wstring::npos || path.find(L'\0')!=std::wstring::npos)
        throw std::runtime_error("自启动需要有效的程序绝对路径。");
    auto command=L"\""+path+L"\"";
    if(command.size()>260)throw std::runtime_error("程序路径过长，无法注册登录启动项；请将程序移至较短的固定路径。");
    return command;
}
}
std::wstring StartupRegistration::command() const {
    Key opened;
    auto result=RegOpenKeyExW(root,key.c_str(),0,KEY_QUERY_VALUE,&opened.value);
    if(result==ERROR_FILE_NOT_FOUND)return {};
    requireSuccess(result);
    DWORD type=0,bytes=0;
    result=RegQueryValueExW(opened.value,valueName,nullptr,&type,nullptr,&bytes);
    if(result==ERROR_FILE_NOT_FOUND)return {};
    requireSuccess(result);
    if(type!=REG_SZ || bytes<sizeof(wchar_t) || bytes>65536 || bytes%sizeof(wchar_t))
        throw std::runtime_error("登录启动项格式异常，请在系统启动应用设置中检查。");
    std::wstring data(bytes/sizeof(wchar_t),L'\0');
    auto capacity=bytes;
    requireSuccess(RegQueryValueExW(opened.value,valueName,nullptr,&type,reinterpret_cast<BYTE*>(data.data()),&bytes));
    if(type!=REG_SZ || bytes>capacity || bytes<sizeof(wchar_t) || bytes%sizeof(wchar_t))
        throw std::runtime_error("登录启动项已变化，请重试。");
    data.resize(bytes/sizeof(wchar_t));
    if(data.back()!=L'\0')throw std::runtime_error("登录启动项缺少字符串结束符。");
    data.pop_back();
    if(data.find(L'\0')!=std::wstring::npos)throw std::runtime_error("登录启动项含有无效字符。");
    return data;
}
StartupState StartupRegistration::state(const std::filesystem::path& executable) const {
    auto saved=command();
    if(saved.empty())return {};
    // Reading an existing entry must still work when the new executable path is too long.
    auto expected=L"\""+executable.native()+L"\"";
    return {true,_wcsicmp(saved.c_str(),expected.c_str())==0};
}
void StartupRegistration::setEnabled(bool enabled,const std::filesystem::path& executable) const {
    Key opened;
    if(enabled) {
        auto data=startupCommand(executable); // Validate before touching the registry.
        requireSuccess(RegCreateKeyExW(root,key.c_str(),0,nullptr,0,KEY_SET_VALUE,nullptr,&opened.value,nullptr));
        requireSuccess(RegSetValueExW(opened.value,valueName,0,REG_SZ,reinterpret_cast<const BYTE*>(data.c_str()),static_cast<DWORD>((data.size()+1)*sizeof(wchar_t))));
    } else {
        auto result=RegOpenKeyExW(root,key.c_str(),0,KEY_SET_VALUE,&opened.value);
        if(result==ERROR_FILE_NOT_FOUND)return;
        requireSuccess(result);
        result=RegDeleteValueW(opened.value,valueName);
        if(result!=ERROR_FILE_NOT_FOUND)requireSuccess(result);
    }
}
}
