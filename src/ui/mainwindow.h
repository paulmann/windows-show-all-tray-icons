// TrayIconGuard v8 — main window shell: nav rail, top bar, pages host,
// status bar, theming, input routing, animations, DPI (agent A2).
#pragma once
#include <memory>
#include <string>
#include <vector>
#include <windows.h>

#include "ui/kit/widget.h"

namespace tig::ui {

enum class PageId { Dashboard = 0, Icons, Guard, Appearance, Backups, Activity, About };
constexpr int kPageCount = 7;

class Page : public Widget {
public:
    PageId id = PageId::Dashboard;
    std::vector<WidgetPtr> widgets;
    ScrollBar sbar;
    int scroll = 0;
    bool built = false;

    virtual l10n::S TitleId() const = 0;
    virtual l10n::S SubId() const = 0;
    virtual wchar_t Glyph() const = 0;
    virtual void Build(HWND hwnd) = 0;
    // Lays out widgets in WINDOW coords using current scroll; sets contentH.
    virtual void LayoutContent(HWND hwnd, int width) = 0;
    virtual void OnShow(HWND) {}
    virtual void OnDataChanged() {}   // guard events / rescan
    virtual void OnSecondTick() {}
    virtual bool OnContextMenu(POINT) { return false; }
    virtual bool OnBackgroundClick(POINT) { return false; }
    virtual void OnPageMouseMove(POINT) {}
    virtual void OnUpdateMessage(WPARAM, LPARAM) {}
    virtual void OnFeedMessage(LPARAM) {}
    virtual void OnDownloadError(LPARAM) {}
    int ContentH() const { return contentH; }
    // page-local rect -> window coords (for page-drawn geometry)
    RECT ToWindow(RECT r) const {
        OffsetRect(&r, rc.left, rc.top);
        return r;
    }
    HWND hwndRef = nullptr;
    void EnsureBuilt(HWND hwnd) {
        hwndRef = hwnd;
        if (!built) {
            built = true;
            Build(hwnd);
        }
    }
    void Layout(const RECT& area) override;
    void Paint(PaintCtx& pc) override;
    // Cards/labels drawn UNDER widgets.
    virtual void PaintBackground(PaintCtx&) {}
    bool HitTest(POINT p) const override;
    Widget* WidgetAt(POINT contentPt);
    virtual bool Wheel(HWND hwnd, int delta);
    bool Tick(float dt) override;
    void Refresh() override;
    void SetScroll(int v);

protected:
    int contentH = 0;
};

class MainWindow {
public:
    MainWindow();
    static MainWindow& Instance();

    bool Create(HINSTANCE hinst, bool startMinimized, const std::wstring& uiTestPage,
                int uiTestMs);
    HWND Hwnd() const { return hwnd; }
    void Show(int cmdShow);
    Page* CurrentPage();
    Page* PageById(PageId id);
    void GoTo(PageId id);
    void RefreshEverything();             // theme / language / data
    void NotifyDataChanged();             // store rescan happened
    void PostGuardEvent(int kind, const std::wstring& detail);  // thread-safe
    void PromoteAllNow();
    void RestartExplorerNow();
    void SetFocusWidget(Widget* w);
    Widget* FocusWidget() const { return focusW; }
    void BlurFocus();
    void CaptureSelfPng(const std::wstring& path);  // QA self-screenshot

private:
    static LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
    LRESULT Handle(UINT msg, WPARAM wp, LPARAM lp);
    void OnSize();
    void OnPaint();
    void OnMouseMove(POINT p);
    void OnLDown(POINT p);
    void OnLUp(POINT p);
    void OnWheel(int delta, POINT p);
    bool OnKeyDown(UINT vk);
    void LayoutAll();
    void DrawNav(PaintCtx& pc);
    void DrawTopBar(PaintCtx& pc);
    void DrawStatus(PaintCtx& pc);
    bool InContent(POINT p) const {
        const RECT r = ContentRect();
        return PtInRect(&r, p) != FALSE;
    }
    bool InTopBar(POINT p) const {
        const RECT r = TopBarRect();
        return PtInRect(&r, p) != FALSE;
    }
    RECT NavRect() const;
    RECT TopBarRect() const;
    RECT ContentRect() const;
    RECT StatusRect() const;
    int NavWidth() const;
    int NavItemAt(POINT p) const;
    void ApplyDwmAttributes();
    void StartAnimTimer();
    void StopAnimTimerIfNeeded();
    void SetHot(Widget* w);
    void UpdateCursor(POINT p);

    HWND hwnd = nullptr;
    HINSTANCE hinst = nullptr;
    std::vector<std::unique_ptr<Page>> pages;
    PageId current = PageId::Dashboard;
    HDC memDc = nullptr;
    HBITMAP memBmp = nullptr;
    int memW = 0, memH = 0;
    Widget* hotWidget = nullptr;
    Widget* pressedWidget = nullptr;
    Widget* focusW = nullptr;
    bool captured = false;
    int navHover = -1;
    IconButton themeQuick;
    IconButton refreshQuick;
    UINT_PTR animTimer = 0;
    UINT_PTR secTimer = 0;
    bool uiTest = false;
    int uiTestMs = 0;
    std::wstring uiTestPageName;
    bool closeHintShown = false;
    ULONGLONG startTick = 0;
};

}  // namespace tig::ui
