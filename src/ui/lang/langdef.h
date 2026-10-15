// Helper macros for language pack TUs (lang_xx.cpp). Entries are id-tagged,
// order-independent; missing ids fall back to English at runtime.
#pragma once
#include "ui/lang/strings.h"

#define TIG_STR_(x) #x
#define TIG_WIDEN2_(x) L##x
#define TIG_WIDEN_(x) TIG_WIDEN2_(x)

#define TIG_LANG_BEGIN() \
    namespace tig::l10n { \
    static const Entry kEntries[] = {
#define TIG_E(ID, STR) { static_cast<int>(S::ID), STR },
#define TIG_LANG_END(CODE, NATIVE, ENGLISH) \
    }; \
    extern const LangTable kTable_##CODE; \
    const LangTable kTable_##CODE = { \
        TIG_WIDEN_(TIG_STR_(CODE)), NATIVE, ENGLISH, kEntries, \
        sizeof(kEntries) / sizeof(kEntries[0])}; \
    }
