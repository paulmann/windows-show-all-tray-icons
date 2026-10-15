#include "ui/kit/widget.h"

#include <cmath>

#include <commctrl.h>

#include "core/win_compat.h"
#include "ui/theme.h"

namespace tig::ui {

namespace {
constexpr float kRadiusBtn = 4.f;
constexpr float kRadiusCard = 8.f;
constexpr int kBtnH = 32;

}  // namespace

// ================= Button =================
int Button::PreferredWidth(HWND hwnd) const {
    float w = 36.f;  // padding (tolerant to fallback font metrics)
    if (glyph) w += 22.f;
    w += gfx::TextWidth(hwnd, label, 14.f, FontStyle::Medium);
    return static_cast<int>(w);
}

void Button::Paint(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    Gdiplus::RectF r = gfx::RectFOf(rc);
    Gdiplus::Color bg, fg, border(0, 0, 0, 0);
    float borderW = 0.f;
    switch (style) {
        case Style::Accent:
            bg = gfx::C(P.accent);
            if (hotAnim > 0) bg = gfx::C(theme::Mix(P.accent, P.accentHover, hotAnim));
            if (pressAnim > 0) bg = gfx::C(theme::Mix(gfx::Ref(bg), P.accentPressed, pressAnim));
            fg = gfx::C(P.accentText);
            break;
        case Style::Outline:
            bg = hotAnim > 0 ? gfx::C(theme::Mix(P.controlBg, P.controlHover, hotAnim * 0.7f))
                             : gfx::C(P.controlBg);
            fg = gfx::C(P.textPrimary);
            border = gfx::C(P.controlBorder);
            borderW = 1.f;
            break;
        case Style::Danger:
            bg = hotAnim > 0 ? gfx::C(theme::Mix(P.cardBg, P.dangerSoft, 0.5f * hotAnim))
                             : gfx::C(P.cardBg);
            fg = gfx::C(P.danger);
            border = gfx::C(theme::Mix(P.cardBorder, P.danger, 0.35));
            borderW = 1.f;
            break;
        default:  // Subtle
            bg = gfx::C(P.controlHover);
            if (!hot && !pressed) bg = gfx::C(theme::Mix(P.windowBg, P.controlHover, 0.35f));
            fg = gfx::C(P.textPrimary);
            break;
    }
    if (!enabled) {
        bg = gfx::C(theme::Mix(gfx::Ref(bg), P.windowBg, 0.5));
        fg = gfx::C(P.textDisabled);
    }
    gfx::FillRoundRect(pc.g, r, kRadiusBtn, bg);
    if (borderW > 0) gfx::StrokeRoundRect(pc.g, r, kRadiusBtn, border, borderW);
    if (focused) {
        gfx::StrokeRoundRect(pc.g, Gdiplus::RectF(r.X - 2, r.Y - 2, r.Width + 4, r.Height + 4),
                             kRadiusBtn + 2, gfx::C(P.accent, 220), 1.6f);
    }
    // content
    float x = r.X + 12.f;
    const float cy = r.Y + r.Height * 0.5f;
    if (glyph) {
        Gdiplus::RectF gr(x, cy - 9.f, 18.f, 18.f);
        gfx::DrawGlyph(pc.g, glyph, gfx::GlyphFont(pc.hwnd, 15.f), gr, fg);
        x += 22.f;
    }
    Gdiplus::RectF tr(x, r.Y, r.GetRight() - x - 12.f, r.Height);
    gfx::DrawString(pc.g, label, gfx::Font(pc.hwnd, 14.f, FontStyle::Medium), tr, fg);
}

bool Button::OnMouse(ME e, POINT p) {
    Widget::OnMouse(e, p);
    return true;
}

bool Button::Tick(float dt) {
    const bool a = Approach(hotAnim, hot && enabled ? 1.f : 0.f, dt);
    const bool b = Approach(pressAnim, pressed ? 1.f : 0.f, dt, 90.f);
    return a || b;
}

// ================= IconButton =================
void IconButton::Paint(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    Gdiplus::RectF r = gfx::RectFOf(rc);
    Gdiplus::Color bg(0, 0, 0, 0);
    if (pressAnim > 0)
        bg = gfx::C(theme::Mix(P.windowBg, P.pressOverlay, pressAnim), (BYTE)(160 * pressAnim));
    else if (hotAnim > 0)
        bg = gfx::C(theme::Mix(P.windowBg, P.hoverOverlay, hotAnim), (BYTE)(160 * hotAnim));
    if (bg.GetAlpha()) gfx::FillRoundRect(pc.g, r, kRadiusBtn, bg);
    if (focused) gfx::StrokeRoundRect(pc.g, r, kRadiusBtn, gfx::C(P.accent, 220), 1.6f);
    gfx::DrawGlyph(pc.g, glyph, gfx::GlyphFont(pc.hwnd, 16.f), r, gfx::C(P.textPrimary));
}

bool IconButton::OnMouse(ME e, POINT p) {
    Widget::OnMouse(e, p);
    return true;
}

bool IconButton::Tick(float dt) {
    const bool a = Approach(hotAnim, hot ? 1.f : 0.f, dt);
    const bool b = Approach(pressAnim, pressed ? 1.f : 0.f, dt, 90.f);
    return a || b;
}

// ================= Toggle =================
void Toggle::Paint(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    const float s = static_cast<float>(GetDpiForWindow(pc.hwnd)) / 96.f;
    const float W = 40.f * s, H = 20.f * s;
    const float x = static_cast<float>(rc.right) - W - 0.f;
    const float y = static_cast<float>(rc.top) + (Height() - H) * 0.5f;
    Gdiplus::RectF track(x, y, W, H);
    const Gdiplus::Color onCol = gfx::C(P.accent);
    const Gdiplus::Color offCol = gfx::C(P.toggleOff);
    const Gdiplus::Color col = Gdiplus::Color(
        255, static_cast<BYTE>(offCol.GetR() + (onCol.GetR() - offCol.GetR()) * anim),
        static_cast<BYTE>(offCol.GetG() + (onCol.GetG() - offCol.GetG()) * anim),
        static_cast<BYTE>(offCol.GetB() + (onCol.GetB() - offCol.GetB()) * anim));
    // OFF state = ON state rotated 180deg: same pill, dark-orange track, white knob
    // at the left; no outline stroke in either state.
    gfx::FillRoundRect(pc.g, track, H * 0.5f, enabled ? col : gfx::C(P.toggleOff));
    // knob
    const float knobIdle = 12.f * s, knobActive = 14.f * s;
    const float grow = (hot || pressed || focused) ? 1.f : 0.f;
    const float kd = knobIdle + (knobActive - knobIdle) * grow * 0.5f +
                     (knobActive - knobIdle) * anim * 0.5f;
    const float travel = W - kd - 3.f * s - 3.f * s;
    const float kx = x + 3.f * s + travel * anim;
    const float ky = y + (H - kd) * 0.5f;
    Gdiplus::RectF knob(kx, ky, kd, kd);
    const Gdiplus::Color knobCol =
        anim > 0.5f ? gfx::C(P.accentText) : gfx::C(enabled ? P.knobOff : P.knobOff);
    gfx::FillRoundRect(pc.g, knob, kd * 0.5f, knobCol);
    if (focused)
        gfx::StrokeRoundRect(pc.g, Gdiplus::RectF(x - 3, y - 3, W + 6, H + 6), H * 0.5f + 3,
                             gfx::C(P.accent, 200), 1.5f);
}

bool Toggle::OnMouse(ME e, POINT p) {
    if (e == ME::Click && enabled) {
        Set(!on);
        return true;
    }
    return Widget::OnMouse(e, p);
}

bool Toggle::OnKey(UINT vk, bool down) {
    if (!down || !enabled) return false;
    if (vk == VK_SPACE || vk == VK_RETURN) {
        Set(!on);
        return true;
    }
    return false;
}

bool Toggle::Tick(float dt) { return Approach(anim, on ? 1.f : 0.f, dt, 160.f); }

// ================= Segmented =================
int Segmented::PreferredWidth(HWND hwnd) const {
    float w = 8.f;
    for (const auto& it : items) {
        w += 20.f + gfx::TextWidth(hwnd, it.label, 13.f, FontStyle::Medium);
        if (it.glyph) w += 18.f;
    }
    return static_cast<int>(w);
}

void Segmented::Layout(const RECT& area) {
    Widget::Layout(area);
    selAnim = static_cast<float>(selected);
}

void Segmented::Select(int idx, bool fire) {
    if (idx < 0 || idx >= static_cast<int>(items.size()) || idx == selected) return;
    selected = idx;
    if (fire && onChange) onChange(idx);
}

void Segmented::Paint(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    Gdiplus::RectF r = gfx::RectFOf(rc);
    gfx::FillRoundRect(pc.g, r, 6.f, gfx::C(theme::Mix(P.windowBg, P.controlHover, 0.6f)));
    const float segW = r.Width / static_cast<float>(items.size());
    // sliding pill
    const float px = r.X + 2.f + selAnim * segW;
    Gdiplus::RectF pill(px, r.Y + 2.f, segW - 4.f, r.Height - 4.f);
    gfx::FillRoundRect(pc.g, pill, 5.f, gfx::C(P.cardBg));
    gfx::StrokeRoundRect(pc.g, pill, 5.f, gfx::C(P.cardBorder), 1.f);
    if (focused) gfx::StrokeRoundRect(pc.g, r, 6.f, gfx::C(P.accent, 200), 1.5f);
    for (size_t i = 0; i < items.size(); ++i) {
        Gdiplus::RectF seg(r.X + i * segW, r.Y, segW, r.Height);
        const bool sel = static_cast<int>(i) == selected;
        const Gdiplus::Color fg = gfx::C(sel ? P.textPrimary : P.textSecondary);
        float cx = seg.X + seg.Width * 0.5f;
        const float textW = gfx::TextWidth(pc.hwnd, items[i].label, 13.f, FontStyle::Medium);
        float total = textW;
        if (items[i].glyph) total += 18.f;
        float x = cx - total * 0.5f;
        if (items[i].glyph) {
            Gdiplus::RectF gr(x, seg.Y, 18.f, seg.Height);
            gfx::DrawGlyph(pc.g, items[i].glyph, gfx::GlyphFont(pc.hwnd, 13.f), gr, fg,
                           Gdiplus::StringAlignmentNear);
            x += 18.f;
        }
        Gdiplus::RectF tr(x, seg.Y, seg.GetRight() - x, seg.Height);
        gfx::DrawString(pc.g, items[i].label, gfx::Font(pc.hwnd, 13.f, FontStyle::Medium), tr,
                        fg, Gdiplus::StringAlignmentNear);
    }
}

bool Segmented::OnMouse(ME e, POINT p) {
    if (e == ME::Click && enabled) {
        const float segW = Width() / static_cast<float>(items.size());
        const int idx = static_cast<int>((p.x - rc.left) / segW);
        Select(idx);
        return true;
    }
    return Widget::OnMouse(e, p);
}

bool Segmented::OnKey(UINT vk, bool down) {
    if (!down) return false;
    if (vk == VK_LEFT) { Select(selected - 1); return true; }
    if (vk == VK_RIGHT) { Select(selected + 1); return true; }
    return Widget::OnKey(vk, down);
}

bool Segmented::Tick(float dt) {
    return Approach(selAnim, static_cast<float>(selected), dt, 180.f);
}

// ================= SearchBox =================
namespace {
LRESULT CALLBACK SearchEditProc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp, UINT_PTR, DWORD_PTR) {
    switch (msg) {
        case WM_GETDLGCODE:
            return DLGC_WANTALLKEYS;
        case WM_KEYDOWN:
            if (wp == VK_ESCAPE) {
                HWND parent = GetParent(hwnd);
                if (parent) SendMessageW(parent, WM_APP + 40, 0, 0);
                return 0;
            }
            break;
        default:
            break;
    }
    return DefSubclassProc(hwnd, msg, wp, lp);
}
}  // namespace

SearchBox::~SearchBox() {
    if (edit && IsWindow(edit)) {
        RemoveWindowSubclass(edit, SearchEditProc, 1);
        DestroyWindow(edit);
    }
}

void SearchBox::Create(HWND parent) {
    edit = CreateWindowExW(0, L"EDIT", L"", WS_CHILD | ES_AUTOHSCROLL, 0, 0, 0, 0, parent,
                           nullptr, GetModuleHandleW(nullptr), nullptr);
    if (!edit) return;
    SetWindowSubclass(edit, SearchEditProc, 1, 0);
    SendMessageW(edit, EM_SETCUEBANNER, TRUE, 0);  // placeholder set via SetText? no: see Refresh
    Refresh();
}

void SearchBox::Layout(const RECT& area) {
    Widget::Layout(area);
    if (edit) {
        const RECT inner = {rc.left + 34, rc.top + 1, rc.right - 34, rc.bottom - 1};
        MoveWindow(edit, inner.left, inner.top, inner.right - inner.left,
                   inner.bottom - inner.top, TRUE);
    }
}

RECT SearchBox::ClearRect() const {
    return {rc.right - 30, rc.top, rc.right - 4, rc.bottom};
}

void SearchBox::Paint(PaintCtx& pc) {
    const Palette& P = theme::Pal();
    Gdiplus::RectF r = gfx::RectFOf(rc);
    gfx::FillRoundRect(pc.g, r, 4.f, gfx::C(P.searchBg));
    const Gdiplus::Color border = focused ? gfx::C(P.accent) : gfx::C(P.searchBorder);
    gfx::StrokeRoundRect(pc.g, r, 4.f, border, focused ? 1.6f : 1.f);
    Gdiplus::RectF gr(r.X + 10.f, r.Y, 18.f, r.Height);
    gfx::DrawGlyph(pc.g, 0xE721, gfx::GlyphFont(pc.hwnd, 14.f), gr, gfx::C(P.textSecondary),
                   Gdiplus::StringAlignmentNear);
    if (!Text().empty()) {
        const RECT cr = ClearRect();
        Gdiplus::RectF crf = gfx::RectFOf(cr);
        if (hot) gfx::FillRoundRect(pc.g, crf, 4.f, gfx::C(P.hoverOverlay));
        gfx::DrawGlyph(pc.g, 0xE711, gfx::GlyphFont(pc.hwnd, 11.f), crf,
                       gfx::C(P.textSecondary));
    }
}

bool SearchBox::OnMouse(ME e, POINT p) {
    if (e == ME::Click) {
        const RECT cr = ClearRect();
        if (!Text().empty() && PtInRect(&cr, p)) {
            SetText(L"");
            if (onChange) onChange(L"");
            return true;
        }
        if (edit) SetFocus(edit);
        return true;
    }
    return Widget::OnMouse(e, p);
}

bool SearchBox::OnKey(UINT vk, bool down) {
    (void)vk;
    (void)down;
    return false;
}

void SearchBox::Refresh() {
    if (!edit) return;
    SendMessageW(edit, EM_SETCUEBANNER, TRUE,
                 reinterpret_cast<LPARAM>(l10n::t(l10n::S::SearchHint)));
}

std::wstring SearchBox::Text() const {
    if (!edit) return {};
    const int n = GetWindowTextLengthW(edit);
    std::wstring s(static_cast<size_t>(n) + 1, L'\0');
    GetWindowTextW(edit, s.data(), n + 1);
    s.resize(static_cast<size_t>(n));
    return s;
}

void SearchBox::SetText(const std::wstring& s) {
    if (edit) SetWindowTextW(edit, s.c_str());
}

// ================= ScrollBar =================
void ScrollBar::SetRange(int content, int view) {
    contentH = content;
    viewH = view;
    if (pos > contentH - viewH) pos = contentH > viewH ? contentH - viewH : 0;
    if (pos < 0) pos = 0;
}

void ScrollBar::ScrollBy(int delta) {
    const int maxPos = contentH - viewH;
    int np = pos + delta;
    if (np < 0) np = 0;
    if (np > maxPos) np = maxPos;
    if (np != pos) {
        pos = np;
        if (onScroll) onScroll(pos);
    }
}

RECT ScrollBar::ThumbRect() const {
    if (!Needed()) return {};
    const int trackH = rc.bottom - rc.top;
    const float ratio = static_cast<float>(viewH) / static_cast<float>(contentH);
    int thumbH = static_cast<int>(trackH * ratio);
    if (thumbH < 28) thumbH = 28;
    const int maxPos = contentH - viewH;
    const int travel = trackH - thumbH;
    const int y = rc.top + (maxPos > 0 ? static_cast<int>(1.f * pos / maxPos * travel) : 0);
    return {rc.right - 8, y, rc.right - 2, y + thumbH};
}

bool ScrollBar::HitTest(POINT p) const {
    if (!visible || !Needed()) return false;
    RECT wide = rc;
    wide.left -= 4;
    return PtInRect(&wide, p) != FALSE;
}

void ScrollBar::Paint(PaintCtx& pc) {
    if (!Needed()) return;
    const Palette& P = theme::Pal();
    const RECT th = ThumbRect();
    Gdiplus::RectF r = gfx::RectFOf(th);
    gfx::FillRoundRect(pc.g, r, 3.f, gfx::C(hot || dragging ? P.scrollbarHot : P.scrollbar, 200));
}

bool ScrollBar::OnMouse(ME e, POINT p) {
    switch (e) {
        case ME::Down: {
            const RECT th = ThumbRect();
            if (PtInRect(&th, p)) {
                dragging = true;
                dragStartY = p.y;
                dragStartPos = pos;
            } else {
                // page jump
                ScrollBy(p.y < th.top ? -viewH : viewH);
            }
            return true;
        }
        case ME::Move:
            if (dragging) {
                const int trackH = rc.bottom - rc.top;
                const RECT th = ThumbRect();
                const int travel = trackH - (th.bottom - th.top);
                const int maxPos = contentH - viewH;
                if (travel > 0 && maxPos > 0) {
                    const int np = dragStartPos +
                                   static_cast<int>(1.0 * (p.y - dragStartY) / travel * maxPos);
                    const int old = pos;
                    pos = np;
                    if (pos < 0) pos = 0;
                    if (pos > maxPos) pos = maxPos;
                    if (pos != old && onScroll) onScroll(pos);
                }
            }
            return true;
        case ME::Up:
            dragging = false;
            return true;
        default:
            return Widget::OnMouse(e, p);
    }
}

// ================= shared page drawing =================
void DrawCard(PaintCtx& pc, const RECT& r, const std::wstring& title) {
    const Palette& P = theme::Pal();
    Gdiplus::RectF rf = gfx::RectFOf(r);
    gfx::FillRoundRect(pc.g, rf, kRadiusCard, gfx::C(P.cardBg));
    gfx::StrokeRoundRect(pc.g, rf, kRadiusCard, gfx::C(P.cardBorder), 1.f);
    if (!title.empty()) {
        Gdiplus::RectF tr(rf.X + 16.f, rf.Y + 12.f, rf.Width - 32.f, 20.f);
        gfx::DrawString(pc.g, title, gfx::Font(pc.hwnd, 14.f, FontStyle::SemiBold), tr,
                        gfx::C(P.textPrimary));
    }
}

RECT CardContentRect(HWND hwnd, const RECT& card) {
    (void)hwnd;
    return {card.left + 16, card.top + 40, card.right - 16, card.bottom - 12};
}

RECT DrawSettingRow(PaintCtx& pc, const RECT& row, const std::wstring& label,
                    const std::wstring& desc, bool last) {
    const Palette& P = theme::Pal();
    Gdiplus::RectF rf = gfx::RectFOf(row);
    Gdiplus::RectF lr(rf.X + 16.f, rf.Y, rf.Width * 0.62f, desc.empty() ? rf.Height : 22.f);
    if (!desc.empty()) lr.Y += 4.f;
    gfx::DrawString(pc.g, label, gfx::Font(pc.hwnd, 14.f, FontStyle::Medium), lr,
                    gfx::C(P.textPrimary));
    if (!desc.empty()) {
        Gdiplus::RectF dr(rf.X + 16.f, lr.GetBottom() - 2.f, rf.Width * 0.60f, 26.f);
        gfx::DrawString(pc.g, desc, gfx::Font(pc.hwnd, 11.5f), dr, gfx::C(P.textSecondary));
    }
    if (!last) {
        Gdiplus::RectF sep(rf.X + 16.f, rf.GetBottom() - 1.f, rf.Width - 32.f, 1.f);
        gfx::FillRect(pc.g, sep, gfx::C(P.separator, 160));
    }
    // control zone on the right
    RECT ctl{row.left + static_cast<int>(rf.Width * 0.62f) + 16, row.top, row.right - 12,
             row.bottom};
    return ctl;
}

void DrawStatusChip(PaintCtx& pc, const RECT& r, const std::wstring& text, COLORREF fg,
                    COLORREF bg) {
    Gdiplus::RectF rf = gfx::RectFOf(r);
    gfx::FillRoundRect(pc.g, rf, rf.Height * 0.5f, gfx::C(bg));
    Gdiplus::RectF tr(rf.X + 10.f, rf.Y, rf.Width - 20.f, rf.Height);
    gfx::DrawString(pc.g, text, gfx::Font(pc.hwnd, 11.f, FontStyle::Medium), tr, gfx::C(fg),
                    Gdiplus::StringAlignmentCenter);
}

}  // namespace tig::ui
