#pragma once
#include <cstdint>
#include <functional>
#include <map>
#include <set>
#include <string>
#include <vector>
#include <stdexcept>
#include <tuple>

namespace ddc {
struct Shortcut {
    unsigned modifiers = 0, key = 0;
    bool operator<(const Shortcut& other) const { return std::tie(modifiers,key)<std::tie(other.modifiers,other.key); }
    bool operator==(const Shortcut& other) const { return modifiers==other.modifiers && key==other.key; }
};
struct Action {
    std::string id, name, monitor;
    int value = 17;
    Shortcut shortcut;
    bool enabled = true;
};
using Config = std::vector<Action>;
struct Monitor { std::string id, name; };
struct DisplayPath { std::string source, id, name; bool metadataKnown=true, internal=false; };
std::map<std::string,Monitor> uniqueSources(const std::vector<DisplayPath>& paths);
void validate(const Config& config);
std::string encode(const Config& config);
Config decode(const std::string& text);
std::string quoteArg(const std::string& argument);
bool stableID(const std::string& id);
struct Registrar {
    virtual ~Registrar() = default;
    virtual void add(int id, Shortcut shortcut) = 0;
    virtual void remove(int id) noexcept = 0;
};
class Hotkeys {
    struct Entry { int token; std::string action; };
    Registrar& registrar;
    std::map<Shortcut,Entry> active;
    Config desired;
    int next = 1;
    bool suspended = false;
public:
    explicit Hotkeys(Registrar& r): registrar(r) {}
    ~Hotkeys();
    void replace(const Config& config, const std::function<void()>& commit = []{});
    void pause();
    void resume();
    std::string actionFor(int token) const;
};
}
