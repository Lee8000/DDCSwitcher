#include "platform.hpp"
#include <shellapi.h>
#include <shlobj.h>
#include <physicalmonitorenumerationapi.h>
#include <lowlevelmonitorconfigurationapi.h>
#include <fstream>
#include <iomanip>
#include <memory>
#include <sstream>

namespace ddc {
struct Handle {
    HANDLE value=nullptr;
    explicit Handle(HANDLE h=nullptr):value(h) {}
    ~Handle(){ if(value && value!=INVALID_HANDLE_VALUE) CloseHandle(value); }
    Handle(const Handle&)=delete;
    Handle& operator=(const Handle&)=delete;
};
std::wstring wide(const std::string& s) {
    if(s.empty()) return {};
    int size=MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s.data(),static_cast<int>(s.size()),nullptr,0);
    if(!size) throw std::runtime_error("文本不是有效 UTF-8。");
    std::wstring out(size,L'\0'); MultiByteToWideChar(CP_UTF8,MB_ERR_INVALID_CHARS,s.data(),static_cast<int>(s.size()),out.data(),size); return out;
}
std::string utf8(const std::wstring& s) {
    if(s.empty()) return {};
    int size=WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,s.data(),static_cast<int>(s.size()),nullptr,0,nullptr,nullptr);
    if(!size) throw std::runtime_error("文本包含无效字符。");
    std::string out(size,'\0'); WideCharToMultiByte(CP_UTF8,WC_ERR_INVALID_CHARS,s.data(),static_cast<int>(s.size()),out.data(),size,nullptr,nullptr); return out;
}
std::string systemError(const std::string& context,DWORD code) {
    wchar_t* message=nullptr;
    FormatMessageW(FORMAT_MESSAGE_ALLOCATE_BUFFER|FORMAT_MESSAGE_FROM_SYSTEM|FORMAT_MESSAGE_IGNORE_INSERTS,nullptr,code,0,reinterpret_cast<LPWSTR>(&message),0,nullptr);
    std::string result=context+" ("+std::to_string(code)+")";
    if(message){ result+=": "+utf8(message); LocalFree(message); }
    return result;
}
std::string newID() {
    GUID id{}; if(FAILED(CoCreateGuid(&id))) throw std::runtime_error("无法创建动作标识。");
    wchar_t buffer[40]{}; StringFromGUID2(id,buffer,40); return utf8(buffer);
}
std::filesystem::path exePath() {
    std::wstring buffer(32768,L'\0'); DWORD size=GetModuleFileNameW(nullptr,buffer.data(),static_cast<DWORD>(buffer.size()));
    if(!size || size>=buffer.size()) throw std::runtime_error("无法获取程序路径。");
    buffer.resize(size); return buffer;
}
std::filesystem::path settingsPath(bool demo) {
    PWSTR folder=nullptr;
    if(FAILED(SHGetKnownFolderPath(FOLDERID_LocalAppData,KF_FLAG_CREATE,nullptr,&folder))) throw std::runtime_error("无法找到本地应用数据目录。");
    std::filesystem::path result(folder); CoTaskMemFree(folder);
    return result/(demo?L"DDCSwitcherDemo":L"DDCSwitcher")/L"settings.txt";
}
static std::string readFile(const std::filesystem::path& path) {
    if(std::filesystem::file_size(path)>1024*1024) throw std::runtime_error("文件超过容量限制。");
    std::ifstream input(path,std::ios::binary);
    if(!input) throw std::runtime_error("无法读取文件。");
    return std::string((std::istreambuf_iterator<char>(input)),{});
}
static void writeFile(const std::filesystem::path& path,const std::string& text) {
    Handle file(CreateFileW(path.c_str(),GENERIC_WRITE,0,nullptr,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,nullptr));
    if(file.value==INVALID_HANDLE_VALUE) throw std::runtime_error(systemError("无法创建文件"));
    DWORD written=0;
    if(!WriteFile(file.value,text.data(),static_cast<DWORD>(text.size()),&written,nullptr) || written!=text.size() || !FlushFileBuffers(file.value))
        throw std::runtime_error(systemError("无法完整写入文件"));
}
Config loadSettings(const std::filesystem::path& path) {
    if(!std::filesystem::exists(path)) return {};
    Config result=decode(readFile(path));
    for(const auto& action:result) { wide(action.name); wide(action.monitor); }
    return result;
}
void saveSettings(const std::filesystem::path& path,const Config& config) {
    std::string text=encode(config);
    std::filesystem::create_directories(path.parent_path());
    auto temp=path; temp+=wide(".tmp-"+newID());
    try {
        writeFile(temp,text);
        if(!MoveFileExW(temp.c_str(),path.c_str(),MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)) throw std::runtime_error(systemError("保存设置失败"));
    } catch(...) { DeleteFileW(temp.c_str()); throw; }
}
std::filesystem::path backupSettings(const std::filesystem::path& path) {
    auto backup=path; backup+=wide(".backup-"+newID());
    if(!MoveFileExW(path.c_str(),backup.c_str(),MOVEFILE_WRITE_THROUGH)) throw std::runtime_error(systemError("备份原设置失败"));
    return backup;
}
void WinRegistrar::add(int id,Shortcut shortcut) {
    if(!RegisterHotKey(window,id,shortcut.modifiers|MOD_NOREPEAT,shortcut.key))
        throw std::runtime_error(systemError("快捷键已被占用或无法注册，请换一个组合"));
}
void WinRegistrar::remove(int id) noexcept { UnregisterHotKey(window,id); }
std::wstring shortcutLabel(Shortcut s) {
    if(!s.key) return L"点击录制快捷键";
    std::wstring value;
    if(s.modifiers&2) value+=L"Ctrl+";
    if(s.modifiers&1) value+=L"Alt+";
    if(s.modifiers&4) value+=L"Shift+";
    if((s.key>='A'&&s.key<='Z')||(s.key>='0'&&s.key<='9')) value+=static_cast<wchar_t>(s.key);
    else if(s.key>=VK_F1&&s.key<=VK_F24) value+=L"F"+std::to_wstring(s.key-VK_F1+1);
    else {
        UINT scan=MapVirtualKeyW(s.key,MAPVK_VK_TO_VSC_EX);
        wchar_t name[100]{};
        GetKeyNameTextW(static_cast<LONG>((scan&255)<<16)|((scan&0xFF00)?1<<24:0),name,100);
        value+=name[0]?name:(L"Key "+std::to_wstring(s.key));
    }
    return value;
}

struct Physical {
    std::vector<PHYSICAL_MONITOR> values;
    explicit Physical(HMONITOR monitor) {
        DWORD count=0;
        if(!GetNumberOfPhysicalMonitorsFromHMONITOR(monitor,&count) || !count || count>32) throw std::runtime_error("此显示器没有可访问的物理 DDC 设备。");
        values.resize(count);
        if(!GetPhysicalMonitorsFromHMONITOR(monitor,count,values.data())) { values.clear(); throw std::runtime_error(systemError("无法打开显示器控制通路")); }
    }
    ~Physical(){ if(!values.empty()) DestroyPhysicalMonitors(static_cast<DWORD>(values.size()),values.data()); }
    Physical(const Physical&)=delete;
};
struct Device { Monitor info; HMONITOR handle; };
static std::vector<Device> discover() {
    UINT32 pathCount=0,modeCount=0;
    std::vector<DISPLAYCONFIG_PATH_INFO> paths;
    std::vector<DISPLAYCONFIG_MODE_INFO> modes;
    LONG result=ERROR_INSUFFICIENT_BUFFER;
    for(int attempt=0;attempt<4 && result==ERROR_INSUFFICIENT_BUFFER;++attempt) {
        result=GetDisplayConfigBufferSizes(QDC_ONLY_ACTIVE_PATHS,&pathCount,&modeCount);
        if(result!=ERROR_SUCCESS) break;
        paths.resize(pathCount); modes.resize(modeCount);
        result=QueryDisplayConfig(QDC_ONLY_ACTIVE_PATHS,&pathCount,paths.data(),&modeCount,modes.data(),nullptr);
    }
    if(result!=ERROR_SUCCESS) throw std::runtime_error(systemError("无法读取显示配置（请在本地桌面会话运行）",static_cast<DWORD>(result)));
    paths.resize(pathCount);
    std::vector<DisplayPath> records;
    for(const auto& path:paths) {
        DISPLAYCONFIG_SOURCE_DEVICE_NAME source{};
        source.header={DISPLAYCONFIG_DEVICE_INFO_GET_SOURCE_NAME,sizeof(source),path.sourceInfo.adapterId,path.sourceInfo.id};
        DISPLAYCONFIG_TARGET_DEVICE_NAME target{};
        target.header={DISPLAYCONFIG_DEVICE_INFO_GET_TARGET_NAME,sizeof(target),path.targetInfo.adapterId,path.targetInfo.id};
        if(DisplayConfigGetDeviceInfo(&source.header)!=ERROR_SUCCESS || DisplayConfigGetDeviceInfo(&target.header)!=ERROR_SUCCESS) {
            records.push_back({"","","",false,false});
            continue;
        }
        auto technology=path.targetInfo.outputTechnology;
        // Keep every target in the source group, including internal targets, so
        // clone/mirror configurations cannot accidentally match a different monitor.
        bool internal=technology==DISPLAYCONFIG_OUTPUT_TECHNOLOGY_INTERNAL || technology==DISPLAYCONFIG_OUTPUT_TECHNOLOGY_LVDS || technology==DISPLAYCONFIG_OUTPUT_TECHNOLOGY_DISPLAYPORT_EMBEDDED || technology==DISPLAYCONFIG_OUTPUT_TECHNOLOGY_UDI_EMBEDDED;
        records.push_back({utf8(source.viewGdiDeviceName),utf8(target.monitorDevicePath),utf8(target.monitorFriendlyDeviceName),true,internal});
    }
    auto sources=uniqueSources(records);
    struct Context { std::map<std::string,Monitor>* sources; std::vector<Device> result; std::exception_ptr error; } context{&sources,{},nullptr};
    EnumDisplayMonitors(nullptr,nullptr,[](HMONITOR h,HDC,LPRECT,LPARAM param)->BOOL {
        auto& c=*reinterpret_cast<Context*>(param);
        try {
            MONITORINFOEXW info{}; info.cbSize=sizeof(info);
            if(!GetMonitorInfoW(h,&info)) return TRUE;
            auto found=c.sources->find(utf8(info.szDevice));
            if(found==c.sources->end()) return TRUE;
            try {
                Physical physical(h);
                if(physical.values.size()!=1) return TRUE;
                auto monitor=found->second;
                if(monitor.name.empty()) monitor.name=utf8(physical.values[0].szPhysicalMonitorDescription);
                if(monitor.name.empty()) monitor.name="External monitor";
                c.result.push_back({monitor,h});
            } catch(const std::exception&) { /* inaccessible devices are not safe targets */ }
        } catch(...) { c.error=std::current_exception(); return FALSE; }
        return TRUE;
    },reinterpret_cast<LPARAM>(&context));
    if(context.error) std::rethrow_exception(context.error);
    std::set<std::string> ids;
    for(auto& d:context.result) if(!ids.insert(d.info.id).second) throw std::runtime_error("显示器身份有歧义，无法安全选择目标。");
    return context.result;
}
static WorkerResult perform(bool list,bool demo,const std::string& id,int value) {
    if(!list && (value<0 || value>65535)) throw std::runtime_error("输入源代码超出范围。");
    if(demo) {
        if(list) return {true,"演示显示器",{{"demo:monitor-1","Demo Monitor（不控制硬件）"}}};
        if(id!="demo:monitor-1") throw std::runtime_error("模拟目标已断开。");
        return {true,"模拟命令已发送（未控制真实显示器）。",{}};
    }
    auto devices=discover();
    if(list) { WorkerResult out{true,"",{}}; for(const auto& d:devices) out.monitors.push_back(d.info); return out; }
    std::vector<Device> matches;
    for(const auto& device:devices) if(_wcsicmp(wide(device.info.id).c_str(),wide(id).c_str())==0) matches.push_back(device);
    if(matches.size()!=1) throw std::runtime_error("未找到唯一匹配的显示器。请连接后刷新；非当前输入端口可能已断开。");
    Physical physical(matches[0].handle);
    if(physical.values.size()!=1) throw std::runtime_error("显示器映射存在歧义，请使用扩展显示模式。");
    if(!SetVCPFeature(physical.values[0].hPhysicalMonitor,0x60,static_cast<DWORD>(value))) throw std::runtime_error(systemError("DDC 输入切换失败，请检查连接、DDC/CI 与输入代码"));
    return {true,"切换命令已发送，请观察显示器是否响应。",{}};
}
int workerEntry(const std::vector<std::wstring>& args) {
    if(args[0]==L"--worker-hang") { Sleep(INFINITE); return 1; }
    if(args.size()<2) return 2;
    WorkerResult result;
    try {
        bool demo=args[0]==L"--worker-demo-list" || args[0]==L"--worker-demo-switch";
        bool list=args[0]==L"--worker-list" || args[0]==L"--worker-demo-list";
        if(!list && args[0]!=L"--worker-switch" && args[0]!=L"--worker-demo-switch") throw std::runtime_error("未知控制命令。");
        int value=0; std::string id;
        if(!list) {
            if(args.size()!=4) throw std::runtime_error("控制参数不完整。");
            size_t consumed=0; value=std::stoi(args[3],&consumed);
            if(consumed!=args[3].size()) throw std::runtime_error("无效输入源代码。");
            id=utf8(args[2]);
        }
        result=perform(list,demo,id,value);
    } catch(const std::exception& e){ result={false,e.what(),{}}; }
    try {
        std::ostringstream out;
        out<<(result.success?"OK":"ERROR")<<' '<<std::quoted(result.message)<<' '<<result.monitors.size()<<"\n";
        for(const auto& m:result.monitors) out<<std::quoted(m.id)<<' '<<std::quoted(m.name)<<"\n";
        writeFile(args[1],out.str());
    } catch(...) { return 3; }
    return 0; // The protocol carries hardware failures; nonzero means a transport failure.
}
WorkerResult runChild(const std::vector<std::string>& arguments,DWORD timeout) {
    if(arguments.empty()) throw std::runtime_error("缺少控制命令。");
    auto output=std::filesystem::temp_directory_path()/wide("DDCSwitcher-worker-"+newID()+".txt");
    struct Cleanup { std::filesystem::path file; ~Cleanup(){ DeleteFileW(file.c_str()); } } cleanup{output};
    std::string command=quoteArg(utf8(exePath().wstring()))+" "+quoteArg(arguments[0])+" "+quoteArg(utf8(output.wstring()));
    for(size_t i=1;i<arguments.size();++i) command+=" "+quoteArg(arguments[i]);
    auto line=wide(command);
    Handle job(CreateJobObjectW(nullptr,nullptr));
    if(!job.value) throw std::runtime_error(systemError("无法创建控制任务"));
    JOBOBJECT_EXTENDED_LIMIT_INFORMATION limits{}; limits.BasicLimitInformation.LimitFlags=JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
    if(!SetInformationJobObject(job.value,JobObjectExtendedLimitInformation,&limits,sizeof(limits))) throw std::runtime_error(systemError("无法限制控制任务"));
    STARTUPINFOW startup{}; startup.cb=sizeof(startup); PROCESS_INFORMATION process{};
    if(!CreateProcessW(exePath().c_str(),line.data(),nullptr,nullptr,FALSE,CREATE_SUSPENDED|CREATE_NO_WINDOW,nullptr,nullptr,&startup,&process)) throw std::runtime_error(systemError("无法启动显示器控制进程"));
    Handle child(process.hProcess),thread(process.hThread);
    if(!AssignProcessToJobObject(job.value,child.value)){ auto error=GetLastError(); TerminateProcess(child.value,1); throw std::runtime_error(systemError("无法约束控制进程",error)); }
    if(ResumeThread(thread.value)==static_cast<DWORD>(-1)) throw std::runtime_error(systemError("无法运行控制进程"));
    DWORD wait=WaitForSingleObject(child.value,timeout);
    if(wait!=WAIT_OBJECT_0) { TerminateJobObject(job.value,1); WaitForSingleObject(child.value,1000); throw std::runtime_error("显示器控制超时，请检查线材、扩展坞和 DDC/CI 设置。"); }
    DWORD status=1; GetExitCodeProcess(child.value,&status);
    if(status) throw std::runtime_error("控制进程异常退出（"+std::to_string(status)+"）。");
    std::istringstream input(readFile(output));
    std::string state,extra; WorkerResult result; size_t count=0;
    if(!(input>>state>>std::quoted(result.message)>>count) || (state!="OK"&&state!="ERROR") || count>64) throw std::runtime_error("控制进程返回无效结果。");
    result.success=state=="OK";
    for(size_t i=0;i<count;++i){ Monitor m; if(!(input>>std::quoted(m.id)>>std::quoted(m.name)) || !stableID(m.id)) throw std::runtime_error("控制进程返回无效显示器标识。"); result.monitors.push_back(m); }
    if(input>>extra) throw std::runtime_error("控制进程返回多余内容。");
    return result;
}
}
