// TrayIconGuard v8 — widget base + Fluent control kit (agent A2).
#pragma once
#include <cmath>
#include <functional>
#include <memory>
#include <string>
#include <vector>
#include <windows.h>

#include "ui/gfx.h"
#include "ui/lang/strings.h"

namespace tig::ui {
using tig::gfx::FontStyle;

enum class ME { Enter, Leave, Move, Down, Up, Click, DblClick };

struct PaintCtx {
    Gdiplus::Graphics& g;
    HWND hwnd;
};

class Widget {
public:
    virtual ~Widget() = default;
    RECT rc{};
    bool visible = true;
    bool enabled = true;
    bool focusable = false;
    bool focused = false;
    bool hot = false;
    bool pressed = false;
    std::wstring tooltip;
    std::function<void()> onClick;

    virtual void Layout(const RECT& area) { rc = area; }
    virtual void Paint(PaintCtx& pc) = 0;
    virtual bool HitTest(POINT p) const { return visible && PtInRect(&rc, p) != FALSE; }
    virtual bool OnMouse(ME e, POINT) {
        switch (e) {
            case ME::Enter: hot = true; break;
            case ME::Leave: hot = false; pressed = false; break;
            case ME::Down: pressed = enabled; break;
            case ME::Up: pressed = false; break;
            case ME::Click:
                if (enabled && onClick) onClick();
                break;
            default: break;
        }
        return true;
    }
    virtual bool OnKey(UINT vk, bool down) {
        if (!down || !enabled) return false;
        if (vk == VK_SPACE || vk == VK_RETURN) {
            if (onClick) onClick();
            return true;
        }
        return false;
    }
    virtual bool Tick(float dtMs) {
        (void)dtMs;
        return false;
    }
    virtual HWND NativeHwnd() const { return nullptr; }
    virtual void Refresh() {}
    int Width() const { return rc.right - rc.left; }
    int Height() const { return rc.bottom - rc.top; }

    // exponential approach animation helper; returns true while moving
    static bool Approach(float& cur, float target, float dtMs, float timeMs = 140.f) {
        if (cur == target) return false;
        const float t = dtMs / timeMs;
        const float k = t >= 1.f ? 1.f : 1.f - std::exp(-3.f * t);
        cur += (target - cur) * k;
        if (std::fabs(target - cur) < 0.002f) cur = target;
        return cur != target;
    }
};
using WidgetPtr = std::unique_ptr<Widget>;

// ---------- Button ----------
class Button : public Widget {
public:
    enum class Style { Accent, Subtle, Outline, Danger };
    Style style = Style::Subtle;
    std::wstring label;
    wchar_t glyph = 0;
    float hotAnim = 0.f, pressAnim = 0.f;

    Button() { focusable = true; }
    int PreferredWidth(HWND hwnd) const;
    void Paint(PaintCtx& pc) override;
    bool OnMouse(ME e, POINT p) override;
    bool Tick(float dt) override;
};

class IconButton : public Widget {
public:
    wchar_t glyph = 0;
    float hotAnim = 0.f, pressAnim = 0.f;
    IconButton() { focusable = true; }
    void Paint(PaintCtx& pc) override;
    bool OnMouse(ME e, POINT p) override;
    bool Tick(float dt) override;
};

// ---------- Toggle switch ----------
class Toggle : public Widget {
public:
    bool on = false;
    std::function<void(bool)> onChange;
    float anim = 0.f;  // 0 off .. 1 on
    Toggle() { focusable = true; }
    void Paint(PaintCtx& pc) override;
    bool OnMouse(ME e, POINT p) override;
    bool OnKey(UINT vk, bool down) override;
    bool Tick(float dt) override;
    void Set(bool v) {
        if (on == v) return;
        on = v;
        if (onChange) onChange(v);
    }
};

// ---------- Segmented control ----------
class Segmented : public Widget {
public:
    struct Item {
        std::wstring label;
        wchar_t glyph = 0;
    };
    std::vector<Item> items;
    int selected = 0;
    float selAnim = 0.f;  // animated x position of the pill (segment index space)
    std::function<void(int)> onChange;
    Segmented() { focusable = true; }
    int PreferredWidth(HWND hwnd) const;
    void Layout(const RECT& area) override;
    void Paint(PaintCtx& pc) override;
    bool OnMouse(ME e, POINT p) override;
    bool OnKey(UINT vk, bool down) override;
    bool Tick(float dt) override;
    void Select(int idx, bool fire = true);
};

// ---------- Search box (real EDIT child, fully themed) ----------
class SearchBox : public Widget {
public:
    std::function<void(const std::wstring&)> onChange;
    std::function<void()> onEscape;
    SearchBox() { focusable = true; }
    ~SearchBox() override;
    void Create(HWND parent);
    void Layout(const RECT& area) override;
    void Paint(PaintCtx& pc) override;
    bool OnMouse(ME e, POINT p) override;
    bool OnKey(UINT vk, bool down) override;
    HWND NativeHwnd() const override { return edit; }
    void Refresh() override;
    std::wstring Text() const;
    void SetText(const std::wstring& s);
    RECT ClearRect() const;

private:
    HWND edit = nullptr;
};

// ---------- Vertical overlay scrollbar ----------
class ScrollBar : public Widget {
public:
    int contentH = 0, viewH = 0, pos = 0;
    std::function<void(int)> onScroll;
    void Paint(PaintCtx& pc) override;
    bool HitTest(POINT p) const override;
    bool OnMouse(ME e, POINT p) override;
    void SetRange(int content, int view);
    void ScrollBy(int delta);
    RECT ThumbRect() const;
    bool Needed() const { return contentH > viewH; }

private:
    bool dragging = false;
    int dragStartY = 0, dragStartPos = 0;
};

// ---------- shared drawing helpers for pages ----------
void DrawCard(PaintCtx& pc, const RECT& r, const std::wstring& title = std::wstring());
RECT CardContentRect(HWND hwnd, const RECT& card);
// settings row: label + description on the left, control area on the right (returned)
RECT DrawSettingRow(PaintCtx& pc, const RECT& row, const std::wstring& label,
                    const std::wstring& desc, bool last = false);
void DrawStatusChip(PaintCtx& pc, const RECT& r, const std::wstring& text, COLORREF fg,
                    COLORREF bg);

}  // namespace tig::ui
