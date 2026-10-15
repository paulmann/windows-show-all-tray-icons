#include "ui/gfx.h"

#include <map>

namespace tig::gfx {

namespace {
ULONG_PTR g_token = 0;

struct FontKey {
    float px;
    int style;
    int dpi;
    bool glyph;
    bool mono;
    bool operator<(const FontKey& o) const {
        if (px != o.px) return px < o.px;
        if (style != o.style) return style < o.style;
        if (dpi != o.dpi) return dpi < o.dpi;
        if (glyph != o.glyph) return glyph < o.glyph;
        return mono < o.mono;
    }
};
std::map<FontKey, Gdiplus::Font*> g_fonts;
std::map<int, Gdiplus::Bitmap*> g_appIcons;

const wchar_t* UiFamilyName() {
    static int checked = 0;
    static wchar_t name[64] = L"Segoe UI";
    if (!checked) {
        checked = 1;
        // Segoe UI Variable Text exists on Windows 11; fall back to Segoe UI.
        HDC dc = GetDC(nullptr);
        HFONT probe = CreateFontW(12, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0,
                                  CLEARTYPE_QUALITY, 0, L"Segoe UI Variable Text");
        HFONT old = static_cast<HFONT>(SelectObject(dc, probe));
        wchar_t face[64] = {};
        GetTextFaceW(dc, 64, face);
        SelectObject(dc, old);
        DeleteObject(probe);
        ReleaseDC(nullptr, dc);
        if (wcscmp(face, L"Segoe UI Variable Text") == 0) wcscpy_s(name, L"Segoe UI Variable Text");
    }
    return name;
}

const wchar_t* GlyphFamilyName() {
    static int checked = 0;
    static wchar_t name[64] = L"Segoe MDL2 Assets";
    if (!checked) {
        checked = 1;
        HDC dc = GetDC(nullptr);
        HFONT probe = CreateFontW(12, 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET, 0, 0,
                                  CLEARTYPE_QUALITY, 0, L"Segoe Fluent Icons");
        HFONT old = static_cast<HFONT>(SelectObject(dc, probe));
        wchar_t face[64] = {};
        GetTextFaceW(dc, 64, face);
        SelectObject(dc, old);
        DeleteObject(probe);
        ReleaseDC(nullptr, dc);
        if (wcscmp(face, L"Segoe Fluent Icons") == 0) wcscpy_s(name, L"Segoe Fluent Icons");
    }
    return name;
}
}  // namespace

bool Init() {
    Gdiplus::GdiplusStartupInput input;
    return Gdiplus::GdiplusStartup(&g_token, &input, nullptr) == Gdiplus::Ok;
}

void Shutdown() {
    for (auto& kv : g_fonts) delete kv.second;
    g_fonts.clear();
    for (auto& kv : g_appIcons) delete kv.second;
    g_appIcons.clear();
    if (g_token) {
        Gdiplus::GdiplusShutdown(g_token);
        g_token = 0;
    }
}

Gdiplus::Color C(COLORREF ref, BYTE alpha) {
    return Gdiplus::Color(alpha, GetRValue(ref), GetGValue(ref), GetBValue(ref));
}

COLORREF Ref(const Gdiplus::Color& c) { return RGB(c.GetR(), c.GetG(), c.GetB()); }

void RoundRectPath(Gdiplus::GraphicsPath& path, const Gdiplus::RectF& r, float radius) {
    const float d = radius * 2.f;
    path.Reset();
    if (d <= 0.5f || r.Width < d || r.Height < d) {
        path.AddRectangle(r);
        return;
    }
    path.AddArc(r.X, r.Y, d, d, 180, 90);
    path.AddArc(r.GetRight() - d, r.Y, d, d, 270, 90);
    path.AddArc(r.GetRight() - d, r.GetBottom() - d, d, d, 0, 90);
    path.AddArc(r.X, r.GetBottom() - d, d, d, 90, 90);
    path.CloseFigure();
}

void FillRoundRect(Gdiplus::Graphics& g, const Gdiplus::RectF& r, float radius,
                   Gdiplus::Color color) {
    Gdiplus::SolidBrush brush(color);
    Gdiplus::GraphicsPath path;
    RoundRectPath(path, r, radius);
    g.FillPath(&brush, &path);
}

void StrokeRoundRect(Gdiplus::Graphics& g, const Gdiplus::RectF& r, float radius,
                     Gdiplus::Color color, float width) {
    Gdiplus::Pen pen(color, width);
    Gdiplus::GraphicsPath path;
    // inset by half stroke so borders stay inside the layout box
    Gdiplus::RectF ir(r.X + width * 0.5f, r.Y + width * 0.5f, r.Width - width, r.Height - width);
    RoundRectPath(path, ir, radius);
    g.DrawPath(&pen, &path);
}

void FillRect(Gdiplus::Graphics& g, const Gdiplus::RectF& r, Gdiplus::Color color) {
    Gdiplus::SolidBrush brush(color);
    g.FillRectangle(&brush, r);
}

void SetupText(Gdiplus::Graphics& g) {
    g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);
    g.SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);
    g.SetPixelOffsetMode(Gdiplus::PixelOffsetModeHalf);
    g.SetInterpolationMode(Gdiplus::InterpolationModeHighQualityBilinear);
}

Gdiplus::Font* Font(HWND hwnd, float px96, FontStyle style) {
    const int dpi = hwnd ? GetDpiForWindow(hwnd) : 96;
    if (!dpi) return nullptr;
    const float px = px96 * dpi / 96.f;
    const FontKey key{px, static_cast<int>(style), dpi, false, false};
    const auto it = g_fonts.find(key);
    if (it != g_fonts.end()) return it->second;
    int weight = FW_REGULAR;
    switch (style) {
        case FontStyle::Medium: weight = FW_MEDIUM; break;
        case FontStyle::SemiBold: weight = FW_SEMIBOLD; break;
        case FontStyle::Bold: weight = FW_BOLD; break;
        default: break;
    }
    HFONT hf = CreateFontW(static_cast<int>(-px), 0, 0, 0, weight, 0, 0, 0, DEFAULT_CHARSET,
                           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH, UiFamilyName());
    HDC dc = GetDC(nullptr);
    HFONT old = static_cast<HFONT>(SelectObject(dc, hf));
    auto* f = new Gdiplus::Font(dc, hf);
    SelectObject(dc, old);
    ReleaseDC(nullptr, dc);
    DeleteObject(hf);
    g_fonts[key] = f;
    return f;
}

Gdiplus::Font* GlyphFont(HWND hwnd, float px96) {
    const int dpi = hwnd ? GetDpiForWindow(hwnd) : 96;
    const float px = px96 * dpi / 96.f;
    const FontKey key{px, 0, dpi, true, false};
    const auto it = g_fonts.find(key);
    if (it != g_fonts.end()) return it->second;
    HFONT hf = CreateFontW(static_cast<int>(-px), 0, 0, 0, FW_NORMAL, 0, 0, 0, DEFAULT_CHARSET,
                           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           DEFAULT_PITCH, GlyphFamilyName());
    HDC dc = GetDC(nullptr);
    HFONT old = static_cast<HFONT>(SelectObject(dc, hf));
    auto* f = new Gdiplus::Font(dc, hf);
    SelectObject(dc, old);
    ReleaseDC(nullptr, dc);
    DeleteObject(hf);
    g_fonts[key] = f;
    return f;
}

Gdiplus::Font* MonoFont(HWND hwnd, float px96) {
    const int dpi = hwnd ? GetDpiForWindow(hwnd) : 96;
    const float px = px96 * dpi / 96.f;
    const FontKey key{px, 0, dpi, false, true};
    const auto it = g_fonts.find(key);
    if (it != g_fonts.end()) return it->second;
    HFONT hf = CreateFontW(static_cast<int>(-px), 0, 0, 0, FW_REGULAR, 0, 0, 0, DEFAULT_CHARSET,
                           OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY,
                           FIXED_PITCH, L"Cascadia Mono");
    // verify face; fallback Consolas
    HDC dc = GetDC(nullptr);
    HFONT old = static_cast<HFONT>(SelectObject(dc, hf));
    wchar_t face[64] = {};
    GetTextFaceW(dc, 64, face);
    SelectObject(dc, old);
    ReleaseDC(nullptr, dc);
    if (wcscmp(face, L"Cascadia Mono") != 0) {
        DeleteObject(hf);
        hf = CreateFontW(static_cast<int>(-px), 0, 0, 0, FW_REGULAR, 0, 0, 0, DEFAULT_CHARSET,
                         OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, FIXED_PITCH,
                         L"Consolas");
    }
    HDC dc2 = GetDC(nullptr);
    HFONT old2 = static_cast<HFONT>(SelectObject(dc2, hf));
    auto* f = new Gdiplus::Font(dc2, hf);
    SelectObject(dc2, old2);
    ReleaseDC(nullptr, dc2);
    DeleteObject(hf);
    g_fonts[key] = f;
    return f;
}

namespace {
Gdiplus::StringFormat* Sf(bool ellipsis, Gdiplus::StringAlignment align) {
    static Gdiplus::StringFormat* cache[2][3] = {};
    const int e = ellipsis ? 1 : 0;
    const int a = align == Gdiplus::StringAlignmentNear ? 0
                : align == Gdiplus::StringAlignmentCenter ? 1 : 2;
    if (!cache[e][a]) {
        auto* sf = new Gdiplus::StringFormat();
        sf->SetFormatFlags(Gdiplus::StringFormatFlagsNoWrap);
        sf->SetAlignment(static_cast<Gdiplus::StringAlignment>(a));
        sf->SetLineAlignment(Gdiplus::StringAlignmentCenter);
        sf->SetTrimming(ellipsis ? Gdiplus::StringTrimmingEllipsisCharacter
                                 : Gdiplus::StringTrimmingNone);
        cache[e][a] = sf;
    }
    return cache[e][a];
}
}  // namespace

float DrawString(Gdiplus::Graphics& g, const std::wstring& s, Gdiplus::Font* font,
                 const Gdiplus::RectF& layout, Gdiplus::Color color,
                 Gdiplus::StringAlignment align, bool ellipsis) {
    if (s.empty() || !font) return 0.f;
    Gdiplus::SolidBrush brush(color);
    g.DrawString(s.c_str(), -1, font, layout, Sf(ellipsis, align), &brush);
    return MeasureString(g, s, font, layout.Width);
}

float MeasureString(Gdiplus::Graphics& g, const std::wstring& s, Gdiplus::Font* font,
                    float maxWidth) {
    if (s.empty() || !font) return 0.f;
    Gdiplus::RectF layout(0, 0, maxWidth, 10000.f);
    Gdiplus::RectF bb;
    g.MeasureString(s.c_str(), -1, font, layout, Sf(false, Gdiplus::StringAlignmentNear), &bb);
    return bb.Width;
}

namespace {
Gdiplus::Graphics* MeasureSurface() {
    static Gdiplus::Bitmap* bmp = nullptr;
    static Gdiplus::Graphics* g = nullptr;
    if (!g) {
        bmp = new Gdiplus::Bitmap(8, 8, PixelFormat32bppARGB);
        g = Gdiplus::Graphics::FromImage(bmp);
        g->SetTextRenderingHint(Gdiplus::TextRenderingHintClearTypeGridFit);
    }
    return g;
}
}  // namespace

float TextWidth(HWND hwnd, const std::wstring& s, float px96, FontStyle style) {
    Gdiplus::Graphics* g = MeasureSurface();
    return MeasureString(*g, s, Font(hwnd, px96, style));
}

float TextHeight(HWND hwnd, const std::wstring& s, float px96, FontStyle style) {
    Gdiplus::Graphics* g = MeasureSurface();
    return StringHeight(*g, s, Font(hwnd, px96, style));
}

float StringHeight(Gdiplus::Graphics& g, const std::wstring& s, Gdiplus::Font* font) {
    if (!font) return 0.f;
    Gdiplus::RectF layout(0, 0, 100000.f, 100000.f);
    Gdiplus::RectF bb;
    g.MeasureString(s.empty() ? L"X" : s.c_str(), -1, font, layout,
                    Sf(false, Gdiplus::StringAlignmentNear), &bb);
    return bb.Height;
}

void DrawGlyph(Gdiplus::Graphics& g, wchar_t glyph, Gdiplus::Font* font,
               const Gdiplus::RectF& layout, Gdiplus::Color color, Gdiplus::StringAlignment align) {
    const std::wstring s(1, glyph);
    Gdiplus::SolidBrush brush(color);
    g.DrawString(s.c_str(), -1, font, layout, Sf(false, align), &brush);
}

void DrawIcon(Gdiplus::Graphics& g, HICON icon, const Gdiplus::RectF& r) {
    if (!icon) return;
    const HDC dc = g.GetHDC();
    DrawIconEx(dc, static_cast<int>(r.X), static_cast<int>(r.Y), icon,
               static_cast<int>(r.Width), static_cast<int>(r.Height), 0, nullptr, DI_NORMAL);
    g.ReleaseHDC(dc);
}

Gdiplus::Bitmap* AppIconBitmap(int px) {
    const auto it = g_appIcons.find(px);
    if (it != g_appIcons.end()) return it->second;
    HICON hi = static_cast<HICON>(
        LoadImageW(GetModuleHandleW(nullptr), MAKEINTRESOURCEW(1), IMAGE_ICON, px, px,
                   LR_DEFAULTCOLOR));
    Gdiplus::Bitmap* bmp = hi ? Gdiplus::Bitmap::FromHICON(hi) : nullptr;
    if (hi) DestroyIcon(hi);
    g_appIcons[px] = bmp;
    return bmp;
}

Gdiplus::RectF RectFOf(const RECT& r) {
    return Gdiplus::RectF(static_cast<Gdiplus::REAL>(r.left), static_cast<Gdiplus::REAL>(r.top),
                          static_cast<Gdiplus::REAL>(r.right - r.left),
                          static_cast<Gdiplus::REAL>(r.bottom - r.top));
}

RECT RectOf(const Gdiplus::RectF& r) {
    RECT out{};
    out.left = static_cast<LONG>(r.X);
    out.top = static_cast<LONG>(r.Y);
    out.right = static_cast<LONG>(r.X + r.Width);
    out.bottom = static_cast<LONG>(r.Y + r.Height);
    return out;
}

}  // namespace tig::gfx
