// TrayIconGuard v8 — GDI+ drawing helpers (agent A2). All UI is custom-drawn
// for a consistent Fluent look with full light/dark theming.
#pragma once
#include <objidl.h>  // PROPID for gdiplus under WIN32_LEAN_AND_MEAN
#include <gdiplus.h>
#include <windows.h>

#include <string>

#include "ui/theme.h"

namespace tig::gfx {

bool Init();      // GdiplusStartup
void Shutdown();  // GdiplusShutdown

Gdiplus::Color C(COLORREF ref, BYTE alpha = 255);
COLORREF Ref(const Gdiplus::Color& c);

void RoundRectPath(Gdiplus::GraphicsPath& path, const Gdiplus::RectF& r, float radius);
void FillRoundRect(Gdiplus::Graphics& g, const Gdiplus::RectF& r, float radius, Gdiplus::Color color);
void StrokeRoundRect(Gdiplus::Graphics& g, const Gdiplus::RectF& r, float radius,
                     Gdiplus::Color color, float width);
void FillRect(Gdiplus::Graphics& g, const Gdiplus::RectF& r, Gdiplus::Color color);

// Fonts are cached per (family, px size, style, dpi).
enum class FontStyle { Regular, Medium, SemiBold, Bold };
Gdiplus::Font* Font(HWND hwnd, float px96, FontStyle style = FontStyle::Regular);
Gdiplus::Font* GlyphFont(HWND hwnd, float px96);  // Segoe Fluent Icons / MDL2 fallback
Gdiplus::Font* MonoFont(HWND hwnd, float px96);

void SetupText(Gdiplus::Graphics& g);  // antialias + pixel offset modes

// Single-line text with ellipsis; returns measured width (px, device).
float DrawString(Gdiplus::Graphics& g, const std::wstring& s, Gdiplus::Font* font,
                 const Gdiplus::RectF& layout, Gdiplus::Color color,
                 Gdiplus::StringAlignment align = Gdiplus::StringAlignmentNear,
                 bool ellipsis = true);
float MeasureString(Gdiplus::Graphics& g, const std::wstring& s, Gdiplus::Font* font,
                    float maxWidth = 100000.f);
// Layout-time measurement without a Graphics object (cached measure surface).
float TextWidth(HWND hwnd, const std::wstring& s, float px96, FontStyle style = FontStyle::Regular);
float TextHeight(HWND hwnd, const std::wstring& s, float px96, FontStyle style = FontStyle::Regular);
float StringHeight(Gdiplus::Graphics& g, const std::wstring& s, Gdiplus::Font* font);

void DrawGlyph(Gdiplus::Graphics& g, wchar_t glyph, Gdiplus::Font* font,
               const Gdiplus::RectF& layout, Gdiplus::Color color,
               Gdiplus::StringAlignment align = Gdiplus::StringAlignmentCenter);

void DrawIcon(Gdiplus::Graphics& g, HICON icon, const Gdiplus::RectF& r);
Gdiplus::Bitmap* AppIconBitmap(int px);  // cached, from embedded .ico resource

Gdiplus::RectF RectFOf(const RECT& r);
RECT RectOf(const Gdiplus::RectF& r);

}  // namespace tig::gfx
