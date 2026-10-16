#include "core.hpp"
#include <iostream>
#include <sstream>
using namespace ddc;
static int failures = 0, checks = 0;
void check(bool condition,const char* message) { ++checks; if(!condition) { ++failures; std::cerr<<"FAIL: "<<message<<"\n"; } }
template<class F> void rejects(F operation,const char* message) { bool failed=false; try { operation(); } catch(const std::exception&) { failed=true; } check(failed,message); }
struct FakeRegistrar: Registrar {
    std::map<int,Shortcut> keys;
    std::set<Shortcut> blocked;
    void add(int id,Shortcut key) override {
        if(blocked.count(key)) throw std::runtime_error("external conflict");
        for(auto& pair:keys) if(pair.second==key) throw std::runtime_error("duplicate registration");
        keys.emplace(id,key);
    }
    void remove(int id) noexcept override { keys.erase(id); }
};
int main() {
    const std::string monitor=R"(\\?\DISPLAY#DEL0001#FAKE#{1234})";
    Action a{"a","工作电脑 · HDMI 1",monitor,17,{3,'1'},true};
    check(stableID(monitor),"stable monitor path accepted");
    check(!stableID(R"(\\.\DISPLAY1)"),"temporary display number rejected");
    check(uniqueSources({{"DISPLAY1",monitor,"Monitor",true,false}}).size()==1,"unique external source accepted");
    check(uniqueSources({{"DISPLAY1",monitor,"Monitor",true,false},{"DISPLAY1",monitor+"2","Other",true,false}}).empty(),"cloned external targets refused");
    check(uniqueSources({{"DISPLAY1",monitor,"Monitor",true,false},{"DISPLAY1","","Internal",true,true}}).empty(),"cloned internal target still counts toward ambiguity");
    rejects([&]{uniqueSources({{"DISPLAY1",monitor,"Monitor",true,false},{"","","",false,false}});},"partial topology cannot prove unique mapping");
    for(int value:{-1,65536}) { auto bad=a; bad.value=value; rejects([&]{validate({bad});},"input out of range rejected"); }
    try { validate({a}); } catch(...) { check(false,"valid action accepted"); }
    for(auto badKey:{Shortcut{4,'1'},Shortcut{0,'1'},Shortcut{3,0x7B},Shortcut{3,0x11}}) {
        auto bad=a; bad.shortcut=badKey; rejects([&]{validate({bad});},"invalid/reserved shortcut rejected");
    }
    auto b=a; b.id="b";
    rejects([&]{validate({a,b});},"duplicate enabled shortcut rejected");
    b.enabled=false;
    try { validate({a,b}); } catch(...) { check(false,"disabled duplicate does not reserve shortcut"); }
    b.id=a.id; rejects([&]{validate({a,b});},"duplicate action identity rejected");
    auto special=a; special.name="名称 \\\" = # ;";
    try {
        auto decoded=decode(encode({special}));
        check(decoded.size()==1,"settings action survives roundtrip");
        if(decoded.size()==1) check(decoded[0].name==special.name && decoded[0].monitor==monitor,"Unicode and quote/backslash roundtrip");
    } catch(...) { check(false,"settings roundtrip works"); }
    for(const auto& bad:{std::string("garbage"),std::string("DDCSWITCHER 2\n"),std::string("DDCSWITCHER 1\ninvalid\n")})
        rejects([&]{decode(bad);},"invalid settings rejected");
    rejects([&]{decode(encode({a})+"junk\n");},"trailing corrupt record rejected");
    check(quoteArg("a b")=="\"a b\"","Windows argv spaces quoted");
    check(quoteArg("C:\\tail\\")=="\"C:\\tail\\\\\"","Windows argv terminal backslash escaped");
    check(quoteArg("a\"b")=="\"a\\\"b\"","Windows argv quote escaped");
    FakeRegistrar registrar;
    {
        Hotkeys keys(registrar);
        bool committed=false;
        keys.replace({a},[&]{committed=true;});
        check(committed && registrar.keys.size()==1,"register and commit");
        check(keys.actionFor(1)==a.id,"dispatch mapping");
        auto other=a; other.shortcut.key='2';
        rejects([&]{keys.replace({other},[]{throw std::runtime_error("disk full");});},"save failure reported");
        check(keys.actionFor(1)==a.id && registrar.keys.size()==1,"save failure preserves old registration");
        registrar.blocked.insert(other.shortcut);
        rejects([&]{keys.replace({other});},"system conflict reported");
        check(registrar.keys.size()==1 && keys.actionFor(1)==a.id,"system conflict preserves old registration");
        registrar.blocked.clear(); other.id="b";
        keys.replace({a,other});
        std::swap(a.shortcut,other.shortcut);
        keys.replace({a,other});
        check(keys.actionFor(1)=="b" && registrar.keys.size()==2,"swapping combinations reuses registrations");
        keys.pause(); check(registrar.keys.empty() && keys.actionFor(1).empty(),"recording suspends registration");
        keys.resume(); check(registrar.keys.size()==2,"recording restores saved registration");
    }
    check(registrar.keys.empty(),"destruction releases shortcuts");
    std::cout<<checks<<" checks, "<<failures<<" failures\n";
    return failures?1:0;
}
