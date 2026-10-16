#include "core.hpp"
#include <algorithm>
#include <iomanip>
#include <sstream>
namespace ddc {
std::map<std::string,Monitor> uniqueSources(const std::vector<DisplayPath>& paths) {
    std::map<std::string,std::vector<Monitor>> groups;
    for(const auto& path:paths) {
        if(!path.metadataKnown || path.source.empty()) throw std::runtime_error("显示配置不完整，无法安全匹配目标，请刷新后重试。");
        groups[path.source].push_back({path.internal?"":path.id,path.name});
    }
    std::map<std::string,Monitor> result;
    for(const auto& pair:groups)if(pair.second.size()==1&&stableID(pair.second[0].id))result.emplace(pair.first,pair.second[0]);
    return result;
}
static bool clean(const std::string& value,size_t limit) {
    return !value.empty() && value.size()<=limit && value.find_first_of("\r\n\t") == std::string::npos &&
        value.find('\0')==std::string::npos && value.find_first_not_of(' ')!=std::string::npos;
}
bool stableID(const std::string& id) {
    std::string upper=id;
    std::transform(upper.begin(),upper.end(),upper.begin(),[](unsigned char c){ return c>='a'&&c<='z'?char(c-32):char(c); });
    return clean(id,4096) && (upper.rfind(R"(\\?\DISPLAY#)",0)==0 || id.rfind("demo:",0)==0);
}
void validate(const Config& config) {
    if(config.size()>256) throw std::runtime_error("最多支持 256 个切换动作。");
    std::set<std::string> ids;
    std::set<Shortcut> shortcuts;
    for(const auto& a:config) {
        if(!clean(a.id,80) || !ids.insert(a.id).second) throw std::runtime_error("动作标识无效或重复。");
        if(!clean(a.name,320)) throw std::runtime_error("请填写有效动作名称（不能包含换行）。");
        if(!stableID(a.monitor)) throw std::runtime_error("请为每个动作选择显示器，不能使用临时编号。");
        if(a.value<0 || a.value>65535) throw std::runtime_error("输入源代码必须是 0–65535 的整数。");
        auto k=a.shortcut;
        if(k.key || k.modifiers) {
            if(!(k.modifiers&3) || (k.modifiers&~7u) || k.key<8 || k.key>254 || k.key==0x7B ||
               (k.key>=0x10 && k.key<=0x12) || (k.key>=0xA0 && k.key<=0xA5) || k.key==0x5B || k.key==0x5C)
                throw std::runtime_error("快捷键需包含 Ctrl 或 Alt；不能使用单独修饰键或保留的 F12。");
            if(a.enabled && !shortcuts.insert(k).second) throw std::runtime_error("已启用动作的快捷键重复，请使用不同组合。");
        }
    }
}
std::string encode(const Config& config) {
    validate(config);
    std::ostringstream stream;
    stream<<"DDCSWITCHER 1 "<<config.size()<<"\n";
    for(const auto& a:config) stream<<std::quoted(a.id)<<' '<<std::quoted(a.name)<<' '<<std::quoted(a.monitor)<<' '
        <<a.value<<' '<<a.shortcut.modifiers<<' '<<a.shortcut.key<<' '<<(a.enabled?1:0)<<"\n";
    return stream.str();
}
Config decode(const std::string& text) {
    if(text.size()>1024*1024) throw std::runtime_error("设置文件过大。");
    std::istringstream input(text);
    std::string line,magic,extra;
    if(!std::getline(input,line)) throw std::runtime_error("设置文件为空。");
    std::istringstream header(line);
    unsigned version=0,count=0;
    if(!(header>>magic>>version>>count) || magic!="DDCSWITCHER" || version!=1 || count>256 || (header>>extra))
        throw std::runtime_error("设置文件格式或版本不受支持，原文件已保留。");
    Config result;
    for(unsigned i=0;i<count;++i) {
        if(!std::getline(input,line) || line.size()>16384) throw std::runtime_error("设置文件记录不完整。");
        std::istringstream record(line);
        Action a; unsigned enabled=0;
        auto quoted=[&](std::string& value) {
            record>>std::ws;
            if(record.peek()!='"' || !(record>>std::quoted(value))) throw std::runtime_error("设置文本字段损坏。");
        };
        quoted(a.id); quoted(a.name); quoted(a.monitor);
        if(!(record>>a.value>>a.shortcut.modifiers>>a.shortcut.key>>enabled) || enabled>1 || (record>>extra))
            throw std::runtime_error("设置文件记录损坏。");
        a.enabled=enabled!=0; result.push_back(a);
    }
    if(input>>extra) throw std::runtime_error("设置文件包含未识别的内容。");
    validate(result); return result;
}
std::string quoteArg(const std::string& argument) {
    std::string result="\"";
    size_t slashes=0;
    for(char c:argument) {
        if(c=='\\') { ++slashes; continue; }
        result.append(c=='"'?slashes*2+1:slashes,'\\');
        result+=c; slashes=0;
    }
    result.append(slashes*2,'\\'); result+='"'; return result;
}
Hotkeys::~Hotkeys() { pause(); }
void Hotkeys::replace(const Config& config,const std::function<void()>& commit) {
    validate(config);
    if(suspended) throw std::runtime_error("请先结束快捷键录制。");
    std::map<Shortcut,Entry> staged,wanted;
    std::set<int> used;
    for(const auto& pair:active) used.insert(pair.second.token);
    try {
        for(const auto& a:config) {
            if(!a.enabled || !a.shortcut.key) continue;
            auto found=active.find(a.shortcut);
            int token=0;
            if(found!=active.end()) token=found->second.token;
            else {
                for(int i=0;i<0xBFFF;++i) {
                    if(next>0xBFFF) next=1;
                    int candidate=next++;
                    if(!used.count(candidate)) { token=candidate; used.insert(candidate); break; }
                }
                if(!token) throw std::runtime_error("快捷键标识已耗尽，请重启应用。");
                registrar.add(token,a.shortcut);
                staged.emplace(a.shortcut,Entry{token,a.id});
            }
            wanted.emplace(a.shortcut,Entry{token,a.id});
        }
        commit();
    } catch(...) {
        for(const auto& pair:staged) registrar.remove(pair.second.token);
        throw;
    }
    for(const auto& pair:active) if(!wanted.count(pair.first)) registrar.remove(pair.second.token);
    active=std::move(wanted); desired=config;
}
void Hotkeys::pause() {
    suspended=true;
    for(const auto& pair:active) registrar.remove(pair.second.token);
    active.clear();
}
void Hotkeys::resume() { if(suspended) { suspended=false; replace(desired); } }
std::string Hotkeys::actionFor(int token) const {
    for(const auto& pair:active) if(pair.second.token==token) return pair.second.action;
    return {};
}
}
