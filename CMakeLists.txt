cmake_minimum_required(VERSION 3.16)
project(TrayIconGuard VERSION 8.6.3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

file(GLOB_RECURSE TIG_SOURCES CONFIGURE_DEPENDS src/*.cpp)
file(GLOB_RECURSE TIG_HEADERS CONFIGURE_DEPENDS src/*.h)

add_executable(TrayIconGuard WIN32 ${TIG_SOURCES} ${TIG_HEADERS} resources/resources.rc)
target_include_directories(TrayIconGuard PRIVATE src)
target_compile_definitions(TrayIconGuard PRIVATE
    UNICODE _UNICODE WIN32_LEAN_AND_MEAN NOMINMAX
    WINVER=0x0A00 _WIN32_WINNT=0x0A00 NTDDI_VERSION=0x0A000006)
if(MSVC)
    target_compile_options(TrayIconGuard PRIVATE /W4 /permissive- /O2 /Gy)
    # The application manifest is embedded by resources.rc (RT_MANIFEST); let the
    # MSVC linker skip generating its own, otherwise CVTRES fails with
    # "CVT1100: duplicate resource. type:MANIFEST".
    target_link_options(TrayIconGuard PRIVATE /OPT:REF /OPT:ICF /MANIFEST:NO)
else()
    target_compile_options(TrayIconGuard PRIVATE
        -Wall -Wextra -Wno-unused-parameter -ffunction-sections -fdata-sections -O2)
    target_link_options(TrayIconGuard PRIVATE
        -static -static-libgcc -static-libstdc++ -Wl,--gc-sections -s -municode)
endif()
target_link_libraries(TrayIconGuard PRIVATE
    gdiplus comctl32 comdlg32 dwmapi uxtheme shlwapi version winhttp
    ole32 oleaut32 shell32 advapi32 gdi32 user32 kernel32 bcrypt)
set_target_properties(TrayIconGuard PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_SOURCE_DIR}/dist)
