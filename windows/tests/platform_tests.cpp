#include "platform.hpp"
#include "startup.hpp"
#include <shellapi.h>
#include <fstream>
#include <chrono>
#include <sstream>
namespace ddc {
int selfTest(const std::filesystem::path& report) {
    std::ostringstream log;
    int checks=0,failures=0;
    auto check=[&](bool ok,const char* label){ ++checks; if(!ok) ++failures; log<<(ok?"PASS: ":"FAIL: ")<<label<<"\n"; };
    auto folder=std::filesystem::temp_directory_path()/wide("DDCSwitcher-test-"+newID());
    try {
        std::filesystem::create_directories(folder);
        // Dedicated per-run HKCU key: never touch the user's real Run entry.
        auto testKey=wide("Software\\DDCSwitcherTests\\"+newID());
        struct RegistryCleanup { std::wstring key; ~RegistryCleanup(){RegDeleteTreeW(HKEY_CURRENT_USER,key.c_str());} } registryCleanup{testKey};
        StartupRegistration startup(HKEY_CURRENT_USER,testKey);
        auto startupExe=std::filesystem::path(L"C:\\测试 空格\\DDCSwitcher.exe");
        check(!startup.state(startupExe).registered,"startup defaults off");
        startup.setEnabled(true,startupExe);
        check(startup.state(startupExe).registered && startup.state(startupExe).currentPath,"startup enables current Unicode path");
        int argc=0;auto argv=CommandLineToArgvW(startup.command().c_str(),&argc);
        check(argv && argc==1 && argv[0]==startupExe.native(),"startup command preserves exact executable argument");
        if(argv)LocalFree(argv);
        check(!startup.state(L"C:\\moved\\DDCSwitcher.exe").currentPath,"moved executable is detected");
        bool invalidStartup=false;
        try{startup.setEnabled(true,std::filesystem::path(L"C:\\"+std::wstring(260,L'a')+L".exe"));}catch(...){invalidStartup=true;}
        check(invalidStartup && startup.state(startupExe).currentPath,"overlong startup command preserves old registration");
        HKEY sibling=nullptr;RegOpenKeyExW(HKEY_CURRENT_USER,testKey.c_str(),0,KEY_SET_VALUE,&sibling);
        DWORD marker=42;RegSetValueExW(sibling,L"OtherApp",0,REG_DWORD,reinterpret_cast<const BYTE*>(&marker),sizeof(marker));RegCloseKey(sibling);
        startup.setEnabled(false,startupExe);startup.setEnabled(false,startupExe);
        check(!startup.state(startupExe).registered,"startup disables idempotently");
        DWORD after=0,size=sizeof(after);RegGetValueW(HKEY_CURRENT_USER,testKey.c_str(),L"OtherApp",RRF_RT_REG_DWORD,nullptr,&after,&size);
        check(after==42,"disable preserves unrelated registry values");
        bool accessFailure=false;
        try{StartupRegistration denied(nullptr,L"invalid-root");denied.setEnabled(true,startupExe);}catch(...){accessFailure=true;}
        check(accessFailure,"startup write failure is reported");
        auto file=folder/L"settings.txt";
        Action a{"a","测试输入源","demo:monitor-1",17,{7,0x79},true};
        check(loadSettings(file).empty(),"missing settings starts empty");
        saveSettings(file,{a});
        check(loadSettings(file).at(0).name==a.name,"atomic Unicode settings roundtrip");
        { std::ofstream out(file,std::ios::binary); out<<"corrupt settings"; }
        bool rejected=false; try { loadSettings(file); } catch(...) { rejected=true; }
        check(rejected,"corrupt settings rejected");
        { std::ifstream input(file,std::ios::binary); std::string text((std::istreambuf_iterator<char>(input)),{}); check(text=="corrupt settings","corrupt file preserved"); }
        auto backup=backupSettings(file);
        check(std::filesystem::exists(backup) && !std::filesystem::exists(file),"explicit backup preserves original");
        saveSettings(file,{a});
        auto bad=a; bad.value=-1; rejected=false;
        try { saveSettings(file,{bad}); } catch(...) { rejected=true; }
        check(rejected && loadSettings(file).at(0).value==17,"invalid save preserves previous file");
        auto monitors=runChild({"--worker-demo-list"});
        check(monitors.success && monitors.monitors.size()==1 && monitors.monitors[0].id==a.monitor,"bounded fake monitor discovery");
        auto sent=runChild({"--worker-demo-switch",a.monitor,"17"});
        check(sent.success,"fake switch request returns receipt");
        auto failed=runChild({"--worker-demo-switch","demo:missing","17"});
        check(!failed.success,"disconnected fake device rejected");
        auto start=std::chrono::steady_clock::now(); rejected=false;
        try { runChild({"--worker-hang"},150); } catch(...) { rejected=true; }
        check(rejected && std::chrono::steady_clock::now()-start<std::chrono::seconds(3),"worker timeout terminates job");
        WNDCLASSW cls{}; cls.lpszClassName=L"DDCSwitcherSelfTest"; cls.hInstance=GetModuleHandleW(nullptr);
        cls.lpfnWndProc=[](HWND w,UINT m,WPARAM p,LPARAM l)->LRESULT {
            if(m==WM_HOTKEY) { auto value=reinterpret_cast<int*>(GetWindowLongPtrW(w,GWLP_USERDATA)); if(value) *value=static_cast<int>(p); return 0; }
            return DefWindowProcW(w,m,p,l);
        };
        RegisterClassW(&cls);
        HWND window=CreateWindowW(cls.lpszClassName,L"",0,0,0,0,0,nullptr,nullptr,cls.hInstance,nullptr);
        if(!window) throw std::runtime_error(systemError("test window"));
        int received=0; SetWindowLongPtrW(window,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(&received));
        {
            WinRegistrar registry(window); Hotkeys hotkeys(registry);
            hotkeys.replace({a});
            check(hotkeys.actionFor(1)==a.id,"RegisterHotKey mapping installed");
            PostMessageW(window,WM_HOTKEY,1,MAKELPARAM(a.shortcut.modifiers,a.shortcut.key));
            MSG message{}; while(PeekMessageW(&message,nullptr,0,0,PM_REMOVE)) DispatchMessageW(&message);
            check(received==1,"WM_HOTKEY dispatch reaches registered window");
            hotkeys.pause(); check(hotkeys.actionFor(1).empty(),"recording removes active mappings");
            hotkeys.resume();
        }
        DestroyWindow(window);
        check(true,"native hotkey cleanup completed");
    } catch(const std::exception& error) { ++failures; log<<"FAIL: exception: "<<error.what()<<"\n"; }
    std::error_code ignored; std::filesystem::remove_all(folder,ignored);
    log<<checks<<" native checks, "<<failures<<" failures. No real DDC writes or physical keyboard synthesis.\n";
    std::ofstream output(report,std::ios::binary); output<<log.str();
    return failures?1:0;
}
}
