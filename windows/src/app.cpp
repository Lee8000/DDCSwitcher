#include "platform.hpp"
#include <commctrl.h>
#include <shellapi.h>
#include <chrono>
#include <memory>
#include <thread>
#include <cerrno>

namespace {
using namespace ddc;
constexpr UINT DONE=WM_APP+1,TRAY=WM_APP+2;
enum { LIST=100,NAME,MONITOR,PRESET,VALUE,RECORD,CLEAR,ENABLED,ADD,REMOVE,REFRESH,HELP,FOLDER,RESET,SAVE,SWITCH,OPEN=9000,QUIT };
struct Completion { bool listing; WorkerResult result; };
class App {
    HWND window=nullptr,list=nullptr,name=nullptr,monitor=nullptr,preset=nullptr,value=nullptr,record=nullptr,enabled=nullptr,status=nullptr,reset=nullptr;
    std::vector<HWND> fields;
    HFONT font=nullptr,headingFont=nullptr;
    UINT dpi=96,taskbarCreated=0;
    bool demo=false,loading=false,recording=false,busy=false,recovery=false,red=false;
    bool pendingRefresh=false;
    int selected=-1;
    Config saved,draft;
    std::vector<Monitor> monitors;
    std::vector<std::string> options;
    std::filesystem::path file;
    WinRegistrar registrar{nullptr};
    Hotkeys hotkeys{registrar};
    std::string registrationError;
    std::chrono::steady_clock::time_point lastSwitch{};
    NOTIFYICONDATAW tray{};
    const std::vector<std::pair<std::wstring,int>> presets={{L"HDMI 1 · 17",17},{L"HDMI 2 · 18",18},{L"DisplayPort 1 · 15",15},{L"DisplayPort 2 · 16",16},{L"USB-C · 27",27}};
    int px(int n)const{return MulDiv(n,static_cast<int>(dpi),96);}
    static std::wstring text(HWND field) {
        int n=GetWindowTextLengthW(field); std::wstring result(static_cast<size_t>(n)+1,L'\0');
        GetWindowTextW(field,result.data(),n+1); result.resize(n); return result;
    }
    HWND control(const wchar_t* cls,const wchar_t* title,int id,DWORD style,int x,int y,int w,int h) {
        HWND child=CreateWindowExW(cls==std::wstring(L"EDIT")||cls==std::wstring(L"LISTBOX")?WS_EX_CLIENTEDGE:0,cls,title,
            WS_CHILD|WS_VISIBLE|style,px(x),px(y),px(w),px(h),window,reinterpret_cast<HMENU>(static_cast<INT_PTR>(id)),GetModuleHandleW(nullptr),nullptr);
        if(!child) throw std::runtime_error(systemError("无法创建设置控件"));
        SendMessageW(child,WM_SETFONT,reinterpret_cast<WPARAM>(font),TRUE);
        fields.push_back(child); return child;
    }
    void setStatus(const std::string& message,bool error=false) {
        red=error||!registrationError.empty();
        auto shown=wide(registrationError.empty()?message:registrationError);
        SetWindowTextW(status,shown.c_str()); InvalidateRect(status,nullptr,TRUE);
    }
    bool validSelection()const{return selected>=0&&static_cast<size_t>(selected)<draft.size();}
    void collect() {
        if(loading||!validSelection())return;
        auto& a=draft[static_cast<size_t>(selected)];
        a.name=utf8(text(name));
        auto index=static_cast<int>(SendMessageW(monitor,CB_GETCURSEL,0,0));
        a.monitor=index>=0&&static_cast<size_t>(index)<options.size()?options[static_cast<size_t>(index)]:"";
        std::wstring raw=text(value); wchar_t* end=nullptr; errno=0;
        long number=wcstol(raw.c_str(),&end,10);
        a.value=!raw.empty()&&end==raw.c_str()+raw.size()&&errno!=ERANGE&&number>=0&&number<=65535?static_cast<int>(number):-1;
        a.enabled=SendMessageW(enabled,BM_GETCHECK,0,0)==BST_CHECKED;
    }
    void stopRecording() {
        if(!recording)return;
        recording=false;
        if(validSelection()) SetWindowTextW(record,shortcutLabel(draft[static_cast<size_t>(selected)].shortcut).c_str());
        try {hotkeys.resume();}catch(const std::exception& e){registrationError=e.what();setStatus(e.what(),true);}
    }
    void populateMonitors() {
        bool previous=loading; loading=true;
        std::string current=validSelection()?draft[static_cast<size_t>(selected)].monitor:"";
        SendMessageW(monitor,CB_RESETCONTENT,0,0); options.clear(); options.push_back("");
        SendMessageW(monitor,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(monitors.empty()?L"未发现显示器，请连接后刷新":L"请选择显示器…"));
        int choice=0;
        for(const auto& m:monitors) {
            unsigned hash=2166136261u;for(unsigned char c:m.id)hash=(hash^c)*16777619u;
            wchar_t suffix[24]{};swprintf(suffix,24,L" · %08X",hash);
            auto label=wide(m.name)+suffix;
            SendMessageW(monitor,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(label.c_str()));
            options.push_back(m.id);
            if(_stricmp(m.id.c_str(),current.c_str())==0) choice=static_cast<int>(options.size()-1);
        }
        if(!current.empty()&&!choice) {
            SendMessageW(monitor,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(L"已保存的显示器（未连接）"));
            options.push_back(current); choice=static_cast<int>(options.size()-1);
        }
        SendMessageW(monitor,CB_SETCURSEL,choice,0); loading=previous;
    }
    void loadEditor() {
        stopRecording(); loading=true;
        bool active=validSelection();
        for(HWND child:{name,monitor,preset,value,record,enabled}) EnableWindow(child,active);
        if(active) {
            const auto& a=draft[static_cast<size_t>(selected)];
            SetWindowTextW(name,wide(a.name).c_str()); SetWindowTextW(value,std::to_wstring(a.value).c_str());
            SetWindowTextW(record,shortcutLabel(a.shortcut).c_str()); SendMessageW(enabled,BM_SETCHECK,a.enabled?BST_CHECKED:BST_UNCHECKED,0);
            int index=static_cast<int>(presets.size());
            for(size_t i=0;i<presets.size();++i)if(presets[i].second==a.value)index=static_cast<int>(i);
            SendMessageW(preset,CB_SETCURSEL,index,0);
        } else {SetWindowTextW(name,L"");SetWindowTextW(value,L"");SetWindowTextW(record,L"先添加一个动作");}
        populateMonitors(); loading=false;
    }
    void reloadList(int choose) {
        loading=true;SendMessageW(list,LB_RESETCONTENT,0,0);
        for(const auto& a:draft) {
            auto label=wide(a.name)+(a.enabled?L"":L"（已停用）")+L"  "+(a.shortcut.key?shortcutLabel(a.shortcut):L"未设置快捷键");
            SendMessageW(list,LB_ADDSTRING,0,reinterpret_cast<LPARAM>(label.c_str()));
        }
        selected=draft.empty()?-1:std::max(0,std::min(choose,static_cast<int>(draft.size()-1)));
        SendMessageW(list,LB_SETCURSEL,static_cast<WPARAM>(selected),0);loading=false;loadEditor();
    }
    bool save() {
        stopRecording();collect();
        if(recovery){setStatus("原设置无法读取，请先备份并重置，避免覆盖原文件。",true);return false;}
        try {
            hotkeys.replace(draft,[&]{saveSettings(file,draft);});saved=draft;registrationError.clear();
            reloadList(selected);setStatus("设置已保存，快捷键已生效；关闭窗口后仍在系统托盘运行。");return true;
        }catch(const std::exception& e){setStatus(e.what(),true);MessageBeep(MB_ICONWARNING);return false;}
    }
    void start(bool listing,const Action& action={}) {
        if(busy) {if(listing)pendingRefresh=true;return;}
        if(!listing && std::chrono::steady_clock::now()-lastSwitch<std::chrono::milliseconds(800))return;
        if(!listing)lastSwitch=std::chrono::steady_clock::now();
        busy=true;
        setStatus(listing?"正在查找可唯一匹配的外接显示器…":"正在发送输入源切换命令…");
        HWND destination=window;bool simulated=demo;
        std::thread([destination,listing,action,simulated]{
            auto result=std::make_unique<Completion>();result->listing=listing;
            try {
                std::string mode=simulated?(listing?"--worker-demo-list":"--worker-demo-switch"):(listing?"--worker-list":"--worker-switch");
                std::vector<std::string> args{mode};
                if(!listing){validate({action});args.push_back(action.monitor);args.push_back(std::to_string(action.value));}
                result->result=runChild(args);
            }catch(const std::exception& e){result->result={false,e.what(),{}};}
            if(PostMessageW(destination,DONE,0,reinterpret_cast<LPARAM>(result.get())))result.release();
        }).detach();
    }
    void trigger(const std::string& id) {
        if(recording||recovery)return;
        for(const auto& a:saved)if(a.id==id&&a.enabled){start(false,a);return;}
    }
    void complete(Completion& done) {
        busy=false;
        if(done.listing){monitors=done.result.monitors;populateMonitors();}
        if(!done.result.success){setStatus(done.result.message,true);show();}
        else if(done.listing)setStatus(monitors.empty()?"未找到可控制的外接显示器。请启用 DDC/CI、直连并使用扩展显示模式。":"发现 "+std::to_string(monitors.size())+" 台显示器；请选择输入源与快捷键后保存。");
        else setStatus(done.result.message);
        if(pendingRefresh){pendingRefresh=false;start(true);}
    }
    void addTray() {
        tray={};tray.cbSize=sizeof(tray);tray.hWnd=window;tray.uID=1;tray.uFlags=NIF_ICON|NIF_MESSAGE|NIF_TIP;tray.uCallbackMessage=TRAY;
        tray.hIcon=LoadIconW(GetModuleHandleW(nullptr),MAKEINTRESOURCEW(101));if(!tray.hIcon)tray.hIcon=LoadIconW(nullptr,IDI_APPLICATION);
        lstrcpynW(tray.szTip,demo?L"DDC Switcher · 演示模式":L"DDC Switcher · 输入源快捷切换",128);
        Shell_NotifyIconW(NIM_ADD,&tray);
    }
    void trayMenu() {
        stopRecording();HMENU menu=CreatePopupMenu();
        AppendMenuW(menu,MF_STRING|MF_GRAYED,0,demo?L"DDC Switcher · 演示模式":L"DDC 输入源快捷切换");
        std::vector<std::string> ids;
        for(const auto& a:saved)if(a.enabled){ids.push_back(a.id);auto title=wide(a.name)+(a.shortcut.key?L"    "+shortcutLabel(a.shortcut):L"");AppendMenuW(menu,MF_STRING|(busy?MF_GRAYED:0),10000+static_cast<UINT_PTR>(ids.size()-1),title.c_str());}
        AppendMenuW(menu,MF_SEPARATOR,0,nullptr);AppendMenuW(menu,MF_STRING,OPEN,L"打开设置…");AppendMenuW(menu,MF_STRING,REFRESH,L"刷新显示器");AppendMenuW(menu,MF_STRING,QUIT,L"退出");
        POINT point{};GetCursorPos(&point);SetForegroundWindow(window);
        UINT command=TrackPopupMenu(menu,TPM_RETURNCMD|TPM_RIGHTBUTTON,point.x,point.y,0,window,nullptr);
        DestroyMenu(menu);PostMessageW(window,WM_NULL,0,0);
        if(command>=10000&&command-10000<ids.size())trigger(ids[command-10000]);
        else if(command)onCommand(command,0);
    }
    void show(){ShowWindow(window,SW_SHOWNORMAL);SetForegroundWindow(window);}
    void onCommand(unsigned command,unsigned notification) {
        if(loading)return;
        if(command==LIST&&notification==LBN_SELCHANGE){collect();selected=static_cast<int>(SendMessageW(list,LB_GETCURSEL,0,0));loadEditor();return;}
        if(command==NAME||command==VALUE||command==MONITOR||command==ENABLED){collect();return;}
        if(command==PRESET&&notification==CBN_SELCHANGE){auto i=static_cast<size_t>(SendMessageW(preset,CB_GETCURSEL,0,0));if(i<presets.size())SetWindowTextW(value,std::to_wstring(presets[i].second).c_str());collect();return;}
        switch(command) {
        case ADD:{stopRecording();collect();draft.push_back({newID(),"HDMI 1",monitors.empty()?"":monitors[0].id,17,{},true});reloadList(static_cast<int>(draft.size()-1));SetFocus(name);break;}
        case REMOVE:stopRecording();if(validSelection()){draft.erase(draft.begin()+selected);reloadList(selected);}break;
        case SAVE:save();break;
        case SWITCH:if(validSelection()&&save())trigger(draft[static_cast<size_t>(selected)].id);break;
        case REFRESH:start(true);break;
        case RECORD:if(validSelection()){if(recording)stopRecording();else{hotkeys.pause();recording=true;SetFocus(record);SetWindowTextW(record,L"请按组合键… Esc 取消");}}break;
        case CLEAR:stopRecording();if(validSelection()){draft[static_cast<size_t>(selected)].shortcut={};SetWindowTextW(record,L"点击录制快捷键");}break;
        case HELP:MessageBoxW(window,L"1. 在显示器菜单中启用 DDC/CI，连接后刷新。\n2. 添加动作，选择显示器与输入源。\n3. 录制 Ctrl+Alt+1 等组合键，再保存。\n4. 关闭设置窗口后，使用快捷键或托盘菜单切换。\n\n预设代码不保证适用于所有型号，可自定义 0–65535。请使用扩展显示模式；镜像或多物理设备映射存在歧义时不会猜测目标。\n\n切到其他电脑后，原端口可能断开 DDC，届时需用显示器按键或另一台电脑切回。命令成功不代表显示器已确认切换。",L"使用说明",MB_OK|MB_ICONINFORMATION);break;
        case FOLDER:std::filesystem::create_directories(file.parent_path());ShellExecuteW(window,L"open",file.parent_path().c_str(),nullptr,nullptr,SW_SHOWNORMAL);break;
        case RESET:if(recovery&&MessageBoxW(window,L"将保留原设置为备份文件，然后重新配置。继续？",L"备份并重置",MB_YESNO|MB_ICONQUESTION)==IDYES){backupSettings(file);saved.clear();draft.clear();recovery=false;ShowWindow(reset,SW_HIDE);reloadList(0);start(true);}break;
        case OPEN:show();break;
        case QUIT:stopRecording();DestroyWindow(window);break;
        default:break;
        }
    }
    static LRESULT CALLBACK recorderProc(HWND h,UINT m,WPARAM w,LPARAM l,UINT_PTR,DWORD_PTR context) {
        auto* app=reinterpret_cast<App*>(context);
        if(m==WM_KILLFOCUS)app->stopRecording();
        if(m==WM_GETDLGCODE)return DLGC_WANTALLKEYS;
        return DefSubclassProc(h,m,w,l);
    }
    bool capture(MSG& message) {
        if(!recording||(message.message!=WM_KEYDOWN&&message.message!=WM_SYSKEYDOWN))return false;
        unsigned key=static_cast<unsigned>(message.wParam);
        if(key==VK_ESCAPE){stopRecording();return true;}
        if((key>=VK_SHIFT&&key<=VK_MENU)||(key>=VK_LSHIFT&&key<=VK_RMENU))return true;
        unsigned mods=(GetKeyState(VK_CONTROL)&0x8000?2u:0u)|(GetKeyState(VK_MENU)&0x8000?1u:0u)|(GetKeyState(VK_SHIFT)&0x8000?4u:0u);
        try {
            Shortcut candidate{mods,key};validate({{"record","record","demo:record",17,candidate,true}});
            if(validSelection())draft[static_cast<size_t>(selected)].shortcut=candidate;
            stopRecording();setStatus("快捷键已录制，请保存并启用。");
        }catch(const std::exception&){SetWindowTextW(record,L"需包含 Ctrl 或 Alt，请重试…");MessageBeep(MB_ICONWARNING);}
        return true;
    }
    void createUI() {
        dpi=GetDpiForSystem();
        font=CreateFontW(-px(14),0,0,0,FW_NORMAL,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");
        headingFont=CreateFontW(-px(24),0,0,0,FW_SEMIBOLD,FALSE,FALSE,FALSE,DEFAULT_CHARSET,OUT_DEFAULT_PRECIS,CLIP_DEFAULT_PRECIS,CLEARTYPE_QUALITY,DEFAULT_PITCH,L"Segoe UI");
        auto heading=control(L"STATIC",demo?L"输入源快捷切换 · 演示模式（不控制硬件）":L"一个组合键，切换输入源",0,0,24,20,880,36);SendMessageW(heading,WM_SETFONT,reinterpret_cast<WPARAM>(headingFont),TRUE);
        control(L"STATIC",L"为每个输入源配置动作；关闭窗口后，应用继续在系统托盘运行。",0,0,24,64,880,24);
        list=control(L"LISTBOX",L"",LIST,WS_TABSTOP|WS_VSCROLL|LBS_NOTIFY|LBS_NOINTEGRALHEIGHT,24,108,235,340);
        control(L"BUTTON",L"＋ 添加",ADD,WS_TABSTOP,24,464,112,32);control(L"BUTTON",L"− 删除",REMOVE,WS_TABSTOP,146,464,112,32);
        control(L"STATIC",L"动作名称",0,0,285,108,580,20);name=control(L"EDIT",L"",NAME,WS_TABSTOP|ES_AUTOHSCROLL,285,132,600,28);SendMessageW(name,EM_SETLIMITTEXT,80,0);
        control(L"STATIC",L"目标显示器",0,0,285,177,580,20);monitor=control(L"COMBOBOX",L"",MONITOR,WS_TABSTOP|CBS_DROPDOWNLIST|WS_VSCROLL,285,201,600,240);
        control(L"STATIC",L"输入源（标准 DDC/CI）",0,0,285,247,580,20);
        preset=control(L"COMBOBOX",L"",PRESET,WS_TABSTOP|CBS_DROPDOWNLIST|WS_VSCROLL,285,271,390,220);
        for(const auto& p:presets)SendMessageW(preset,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(p.first.c_str()));
        SendMessageW(preset,CB_ADDSTRING,0,reinterpret_cast<LPARAM>(L"自定义十进制代码"));
        value=control(L"EDIT",L"",VALUE,WS_TABSTOP|ES_AUTOHSCROLL,690,271,195,28);SendMessageW(value,EM_SETLIMITTEXT,10,0);
        control(L"STATIC",L"常见预设不保证适用所有型号；支持自定义 0–65535。",0,0,285,307,600,22);
        control(L"STATIC",L"全局组合快捷键",0,0,285,343,600,20);
        record=control(L"BUTTON",L"点击录制快捷键",RECORD,WS_TABSTOP,285,367,460,32);
        SetWindowSubclass(record,recorderProc,1,reinterpret_cast<DWORD_PTR>(this));
        control(L"BUTTON",L"清除",CLEAR,WS_TABSTOP,760,367,125,32);
        control(L"STATIC",L"需包含 Ctrl 或 Alt；建议 Ctrl+Alt+1，Esc 取消录制。",0,0,285,407,600,22);
        enabled=control(L"BUTTON",L"启用此动作",ENABLED,WS_TABSTOP|BS_AUTOCHECKBOX,285,446,600,26);
        control(L"BUTTON",L"刷新显示器",REFRESH,WS_TABSTOP,24,512,130,32);control(L"BUTTON",L"设置文件夹",FOLDER,WS_TABSTOP,168,512,130,32);control(L"BUTTON",L"使用说明",HELP,WS_TABSTOP,312,512,112,32);
        reset=control(L"BUTTON",L"备份并重置损坏设置",RESET,WS_TABSTOP,440,512,220,32);ShowWindow(reset,SW_HIDE);
        status=control(L"STATIC",L"正在查找显示器…",0,SS_LEFT,24,555,860,38);
        control(L"STATIC",L"切到另一台电脑后，原端口可能无法再切回。",0,0,24,610,490,25);
        control(L"BUTTON",L"保存并切换此动作",SWITCH,WS_TABSTOP,540,601,190,34);control(L"BUTTON",L"保存并启用",SAVE,WS_TABSTOP|BS_DEFPUSHBUTTON,748,601,138,34);
    }
    static LRESULT CALLBACK procedure(HWND h,UINT message,WPARAM w,LPARAM l) {
        App* app=reinterpret_cast<App*>(GetWindowLongPtrW(h,GWLP_USERDATA));
        if(message==WM_NCCREATE){app=static_cast<App*>(reinterpret_cast<CREATESTRUCTW*>(l)->lpCreateParams);app->window=h;SetWindowLongPtrW(h,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(app));}
        if(!app)return DefWindowProcW(h,message,w,l);
        try {
            if(app->taskbarCreated&&message==app->taskbarCreated){app->addTray();return 0;}
            switch(message) {
            case WM_COMMAND:app->onCommand(LOWORD(w),HIWORD(w));return 0;
            case WM_HOTKEY:app->trigger(app->hotkeys.actionFor(static_cast<int>(w)));return 0;
            case DONE:{std::unique_ptr<Completion> done(reinterpret_cast<Completion*>(l));app->complete(*done);return 0;}
            case TRAY:if(l==WM_RBUTTONUP||l==WM_CONTEXTMENU)app->trayMenu();else if(l==WM_LBUTTONDBLCLK)app->show();return 0;
            case WM_DISPLAYCHANGE:SetTimer(h,1,700,nullptr);return 0;
            case WM_TIMER:if(w==1){KillTimer(h,1);if(app->status)app->start(true);}return 0;
            case WM_CLOSE:app->stopRecording();ShowWindow(h,SW_HIDE);return 0;
            case WM_ACTIVATE:if(LOWORD(w)==WA_INACTIVE)app->stopRecording();break;
            case WM_CTLCOLORSTATIC:SetBkMode(reinterpret_cast<HDC>(w),TRANSPARENT);if(reinterpret_cast<HWND>(l)==app->status)SetTextColor(reinterpret_cast<HDC>(w),app->red?RGB(180,30,30):GetSysColor(COLOR_WINDOWTEXT));return reinterpret_cast<LRESULT>(GetSysColorBrush(COLOR_WINDOW));
            case WM_DESTROY:app->hotkeys.pause();Shell_NotifyIconW(NIM_DELETE,&app->tray);PostQuitMessage(0);return 0;
            default:break;
            }
        }catch(const std::exception& e){if(app->status)app->setStatus(e.what(),true);else MessageBoxW(h,wide(e.what()).c_str(),L"DDC Switcher",MB_OK|MB_ICONERROR);}
        return DefWindowProcW(h,message,w,l);
    }
public:
    explicit App(bool simulated):demo(simulated),file(settingsPath(simulated)){}
    ~App(){if(font)DeleteObject(font);if(headingFont)DeleteObject(headingFont);}
    int run(bool forceShow) {
        const wchar_t* className=demo?L"DDCSwitcherDemoWindow":L"DDCSwitcherWindow";
        HANDLE mutex=CreateMutexW(nullptr,FALSE,demo?L"Local\\DDCSwitcherDemo":L"Local\\DDCSwitcher");
        if(!mutex)throw std::runtime_error(systemError("无法创建单实例标识"));
        if(GetLastError()==ERROR_ALREADY_EXISTS){HWND previous=FindWindowW(className,nullptr);if(previous){ShowWindow(previous,SW_SHOWNORMAL);SetForegroundWindow(previous);}CloseHandle(mutex);return 0;}
        struct MutexClose{HANDLE h;~MutexClose(){CloseHandle(h);}} mutexClose{mutex};
        INITCOMMONCONTROLSEX controls{sizeof(controls),ICC_STANDARD_CLASSES};InitCommonControlsEx(&controls);
        WNDCLASSW cls{};cls.hInstance=GetModuleHandleW(nullptr);cls.lpszClassName=className;cls.lpfnWndProc=procedure;cls.hCursor=LoadCursorW(nullptr,IDC_ARROW);cls.hbrBackground=GetSysColorBrush(COLOR_WINDOW);cls.hIcon=LoadIconW(cls.hInstance,MAKEINTRESOURCEW(101));RegisterClassW(&cls);
        dpi=GetDpiForSystem();RECT rect{0,0,px(915),px(655)};DWORD style=WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU|WS_MINIMIZEBOX;AdjustWindowRect(&rect,style,FALSE);
        if(!CreateWindowExW(WS_EX_CONTROLPARENT,className,demo?L"DDC Switcher · 演示模式（不控制硬件）":L"DDC Switcher · 输入源快捷切换",style,CW_USEDEFAULT,CW_USEDEFAULT,rect.right-rect.left,rect.bottom-rect.top,nullptr,nullptr,cls.hInstance,this))throw std::runtime_error(systemError("无法创建设置窗口"));
        createUI();registrar.window=window;
        std::string loadError;
        try{saved=loadSettings(file);}catch(const std::exception& e){recovery=true;loadError=std::string("设置无法读取，原文件已保留：")+e.what();}
        if(demo&&saved.empty()&&!recovery)saved={{newID(),"工作电脑 · HDMI 1","demo:monitor-1",17,{3,'1'},true},{newID(),"笔记本 · USB-C","demo:monitor-1",27,{3,'2'},true}};
        draft=saved;reloadList(0);ShowWindow(reset,recovery?SW_SHOW:SW_HIDE);
        try{hotkeys.replace(saved);}catch(const std::exception& e){registrationError=e.what();}
        taskbarCreated=RegisterWindowMessageW(L"TaskbarCreated");addTray();
        if(saved.empty()||demo||recovery||forceShow||!registrationError.empty())show();
        if(recovery)setStatus(loadError,true);else start(true);
        MSG message{};
        while(GetMessageW(&message,nullptr,0,0)>0){if(capture(message))continue;if(!IsDialogMessageW(window,&message)){TranslateMessage(&message);DispatchMessageW(&message);}}
        return static_cast<int>(message.wParam);
    }
};
}
int WINAPI wWinMain(HINSTANCE,HINSTANCE,PWSTR,int) {
    int count=0;LPWSTR* raw=CommandLineToArgvW(GetCommandLineW(),&count);
    if(!raw)return 1;
    std::vector<std::wstring> args;for(int i=1;i<count;++i)args.emplace_back(raw[i]);LocalFree(raw);
    try {
        if(!args.empty()&&args[0].rfind(L"--worker-",0)==0)return ddc::workerEntry(args);
        if(args.size()==2&&args[0]==L"--self-test")return ddc::selfTest(args[1]);
        bool demo=false,settings=false;
        for(const auto& arg:args){if(arg==L"--demo")demo=true;else if(arg==L"--settings")settings=true;else throw std::runtime_error("未知启动参数。");}
        SetProcessDPIAware();App app(demo);return app.run(settings);
    }catch(const std::exception& e){MessageBoxW(nullptr,ddc::wide(e.what()).c_str(),L"DDC Switcher 无法启动",MB_OK|MB_ICONERROR);return 1;}
}
