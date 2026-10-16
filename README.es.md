# TrayIconGuard v8 «Aurora» 🛡️✨

[![Versión](https://img.shields.io/badge/versión-8.6.3-green)](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest)
[![Licencia](https://img.shields.io/badge/licencia-PolyForm%20Noncommercial%201.0.0-orange)](LICENSE)
[![C++17 nativo](https://img.shields.io/badge/nativo-C%2B%2B17-00599C?logo=cplusplus&logoColor=white)](https://en.cppreference.com/w/)
[![Sin dependencias](https://img.shields.io/badge/dependencias-CERO-brightgreen)](docs/BUILD.md)
[![Tamaño exe](https://img.shields.io/badge/exe-~1.05%20MB-blue)](https://github.com/paulmann/windows-show-all-tray-icons/releases/latest)
[![Windows](https://img.shields.io/badge/Windows-10%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows/)
[![CI](https://github.com/paulmann/windows-show-all-tray-icons/actions/workflows/ci.yml/badge.svg)](https://github.com/paulmann/windows-show-all-tray-icons/actions/workflows/ci.yml)
[![Downloads](https://img.shields.io/github/downloads/paulmann/windows-show-all-tray-icons/total?logo=github&color=blue)](https://github.com/paulmann/windows-show-all-tray-icons/releases)
[![Stars](https://img.shields.io/github/stars/paulmann/windows-show-all-tray-icons?logo=github&color=yellow)](https://github.com/paulmann/windows-show-all-tray-icons/stargazers)
📚 [Documentation site](https://paulmann.github.io/windows-show-all-tray-icons/) · [Knowledge base](https://github.com/paulmann/windows-show-all-tray-icons/wiki) · [docs/](docs/)

> **Mantiene visibles todos los iconos del área de notificación (bandeja del sistema) en
> Windows 10/11 — y los mantiene así. Un único ejecutable nativo, cero dependencias,
> cero telemetría.**

**En otros idiomas:** [English](README.md) · [Русский](README.ru.md) · [Deutsch](README.de.md) · [中文](README.zh.md) · Español · [हिन्दी](README.hi.md)

TrayIconGuard devuelve a la barra de tareas los iconos que Windows esconde en el desplegable
de desbordamiento — y un **guardia basado en eventos** los recupera en el instante en que
Explorer los vuelve a ocultar (inicio de app, actualización, reregistro). Escribe exactamente
en el mismo almacén del Registro que usa el interruptor de Configuración de Windows, por
usuario y sin derechos de administrador, y ofrece una GUI Fluent moderna, un modo vigilante
sin interfaz y una CLI completa en **un exe estático de ~1 MB** que funciona en cualquier
Windows de serie.

![Panel claro y oscuro, todas las páginas](shots/preview-2x2.png)

---

## 📋 Tabla de contenidos

- [🚀 ¿Por qué TrayIconGuard?](#-por-qué-trayiconguard)
- [✨ Características clave](#-características-clave)
- [⚡ Inicio rápido](#-inicio-rápido)
- [📦 Opciones de instalación](#-opciones-de-instalación)
- [🖥️ Recorrido por la GUI](#-recorrido-por-la-gui)
- [🧰 Referencia CLI](#-referencia-cli)
- [🏗️ Cómo funciona](#-cómo-funciona)
- [🔄 Autoactualización vía Git](#-autoactualización-vía-git)
- [🌍 Idiomas](#-idiomas)
- [🌗 Temas y apariencia](#-temas-y-apariencia)
- [🏢 Despliegue y automatización](#-despliegue-y-automatización)
- [🔍 Solución de problemas](#-solución-de-problemas)
- [🛠️ Compilar desde el código fuente](#-compilar-desde-el-código-fuente)
- [🗂️ Mapa del repositorio](#-mapa-del-repositorio)
- [🤝 Contribuir](#-contribuir)
- [📄 Licencia](#-licencia)
- [👨‍ Autor y soporte](#-autor-y-soporte)
- [🎯 Hoja de ruta](#-hoja-de-ruta)

---

## 🚀 ¿Por qué TrayIconGuard?

Windows recuerda la visibilidad de cada icono de la bandeja — y **la olvida constantemente**:
cada vez que una aplicación (re)registra su icono de notificación, Explorer recrea la subclave
del Registro con `IsPromoted=0`, y los iconos vuelven a caer en el desplegable `^`. Por eso los
ajustes puntuales y los archivos `.reg` se degradan en cuestión de horas.

```text
# Lo que pasa realmente en un Windows 10/11 de serie
La app inicia / se actualiza / reregistra su icono
        │
        ▼
Explorer recrea HKCU\Control Panel\NotifyIconSettings\{id}
con IsPromoted = 0          ← el icono acaba de esconderse
        │
        ▼
Vigilante de TrayIconGuard (RegNotifyChangeKeyValue, ~400 ms de debounce)
        │
        ▼
IsPromoted = 1 restaurado   ← el icono vuelve al instante a la barra
```

### Beneficios reales

- **⚡ Inmediato**: basado en eventos, no en sondeos — la corrección tarda menos de medio segundo
- **🎯 Preciso**: control por icono, exclusiones, reordenar arrastrando, tres modos de visibilidad
- **🛡️ Respetuoso**: solo HKCU, usuario estándar, nunca administrador, sin telemetría, autoinicio opcional
- **📦 Minúsculo**: un exe estático (~1,05 MB) — sin .NET, sin runtimes, sin redistribuibles
- **🔁 Autoreparable**: sobrevive a reinicios de Explorer, actualizaciones de apps y ciclos de sesión

## ✨ Características clave

### 🛡️ **Corrección y seguridad**

- **Mecánica al nivel de Configuración** — escribe `IsPromoted` en
  `HKCU\Control Panel\NotifyIconSettings`, el mismo almacén que usa el interruptor de Windows
  (ver [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md))
- **Instantáneas JSON** (esquema v8) con copia automática antes de operaciones destructivas,
  gestor de restaurar/exportar/eliminar, retención de 30 instantáneas
- **Degradación elegante** en compilaciones antiguas: estado claro, alternativas heredadas, sin cierres
- **Códigos de salida estables** (`0/1/2/3`) para scripts e integración RMM

### 🎯 **Motor de guardia inteligente**

- **Vigilante por eventos**: `RegNotifyChangeKeyValue` sobre el subárbol del almacén + debounce,
  sondeo opcional de respaldo, descubrimiento de iconos nuevos, pausa/reanudar
- **Modos de visibilidad**: *Completo* (todo visible), *Personalizado* (su elección por icono),
  *Compacto* (ocultar todo salvo TrayIconGuard) — desde el menú de bandeja o la CLI
- **Control por icono**: promover/ocultar/excluir con exclusiones comodín (`onedrive.exe`, `*teams*`)
- **Reordenar arrastrando** los iconos de la bandeja, persistido por equipo
- **Reinicio seguro de Explorer** con enfriamiento y confirmación

### 🎨 **GUI Fluent moderna (2026)**

- Interfaz Win32/GDI+ dibujada a medida: riel de navegación, tarjetas, interruptores animados,
  controles segmentados, barras de superposición, DPI Per-Monitor-V2, esquinas de Windows 11
  y barra de título oscura
- Temas **Claro / Oscuro / Sistema** con conmutador rápido, persistencia y autodetección inicial
- **Color de acento**: seguir a Windows u 8 preajustes
- Diseño responsivo (el riel se pliega por debajo de 860 px), navegación completa por teclado

### 📦 **Instalador integrado**

- Asistente de primera ejecución: **ámbito** (*Solo para mí* / *Para todos los usuarios* — un
  aviso UAC), carpeta, autoinicio, accesos en Escritorio y Menú Inicio — o *ejecutar una sola vez*
- Entrada en «Aplicaciones y características»; `--uninstall` lo elimina todo (se eleva solo si hace falta)

### 🔄 **Autoactualización basada en Git**

- Comprobación opt-in contra `update/stable.json` del repo, descarga **fijada con SHA-256**,
  autorreemplazo y relanzamiento; botón manual + comprobación diaria opcional (solo globo)
- Contrato de publicación para ingenieros de release: [Updater_SKILL.MD](Updater_SKILL.MD)

## ⚡ Inicio rápido

```text
# 1. Descargue la última release (exe o zip)
https://github.com/paulmann/windows-show-all-tray-icons/releases/latest

# 2. Desbloquee (Mark-of-the-Web) y ejecute — esa es toda la instalación
Clic derecho TrayIconGuard.exe → Propiedades → Desbloquear → Aceptar
TrayIconGuard.exe

# 3. Primera ejecución: el asistente pregunta ámbito / carpeta / accesos
#    …o elija «Ejecutar una sola vez» para modo portable
```

Sin interfaz / en una línea:

```powershell
TrayIconGuard.exe --promote-all          # mostrar todo ahora y salir
TrayIconGuard.exe --watch                # guardia sin GUI, p. ej. desde el Programador de tareas
TrayIconGuard.exe --status --json        # estado legible por máquina para monitorización
TrayIconGuard.exe --check-update         # preguntar al feed git si hay versión nueva
```

## 📦 Opciones de instalación

| Modo | Cómo | ¿Admin? | Qué obtiene |
|---|---|---|---|
| **Portable** | ejecutar el exe donde sea | ❌ | nada salvo ajustes en `%APPDATA%` |
| **Por usuario** (predeterminado) | asistente → *Solo para mí* | ❌ | `%LOCALAPPDATA%\Programs\TrayIconGuard`, autoinicio HKCU Run, accesos de usuario, entrada en Aplicaciones |
| **Para todos** | asistente → *Para todos los usuarios* | ✅ una vez (UAC) | `%ProgramFiles%\TrayIconGuard`, autoinicio HKLM Run, accesos comunes de Escritorio/Inicio, entrada de desinstalación de máquina |

Desinstalar: *Aplicaciones y características → TrayIconGuard*, o `TrayIconGuard.exe --uninstall`.

![Asistente de instalación](shots/setup-wizard-light.png)

## 🖥️ Recorrido por la GUI

| Página | Qué hace |
|---|---|
| **Panel** | contadores en vivo (registrados / en barra / ocultos / excluidos), estado del guardia, acciones en un clic, tarjetas de sistema y actividad reciente |
| **Iconos de bandeja** | búsqueda, filtros, interruptores por icono, exclusiones, reordenar arrastrando, menú contextual |
| **Guardia** | ajuste del vigilante (debounce, sondeo, política de reinicio de Explorer), reparaciones heredadas, estadísticas, exclusiones |
| **Apariencia** | tema (Claro/Oscuro/Sistema), acento, idioma, animaciones, filas compactas |
| **Copias** | lista de instantáneas, crear/restaurar/exportar/eliminar, copia automática |
| **Actividad** | visor de registros con filtro por nivel, exportar, abrir carpeta |
| **Acerca de** | versión, panel de actualización, botones de Licencia y Base de conocimiento, copia de diagnóstico, chip de modo de instalación |

Modo oscuro, página «Acerca de» con panel de actualización y enlaces:

![Acerca de, oscuro](shots/dark-about.png)

## 🧰 Referencia CLI

| Comando | Efecto |
|---|---|
| *(sin argumentos)* | iniciar la GUI residente en bandeja |
| `--minimized` | iniciar oculto en el área de notificación |
| `--show` / `--toggle-guard` | IPC a la instancia en ejecución (activar / pausar-reanudar) |
| `--status [--json]` | imprimir el estado de la bandeja y salir |
| `--promote-all` | promover todos los iconos ocultos y salir |
| `--restore-defaults` | borrar los valores `IsPromoted` (devolver el control a Windows) |
| `--restart-explorer` | reinicio seguro del shell y salir |
| `--backup` / `--restore-latest` | crear / restaurar instantánea JSON |
| `--watch` | bucle de guardia sin interfaz (vigilante por eventos) |
| `--install-autostart` / `--uninstall-autostart` | gestionar la entrada HKCU Run |
| `--install-machine <dir> [--autostart] [--desktop] [--menu]` | instalación para todos los usuarios (requiere elevación) |
| `--uninstall` | eliminar accesos, autoinicio y la copia instalada (se eleva solo en installs de máquina) |
| `--mode full\|custom\|compact` | fijar el modo de visibilidad de bandeja |
| `--check-update` / `--update-now` | comprobar el feed git / actualizar sin interacción |
| `--version` / `--help` | introspección |

**Códigos de salida:** `0` ok · `1` argumentos inválidos · `2` SO no soportado · `3` fallo parcial.

## 🏗️ Cómo funciona

Almacén principal (Windows 10 1703+ / 11), por usuario, sin administrador:

```text
HKCU\Control Panel\NotifyIconSettings\{<icon-id>}
    IsPromoted            DWORD      1 = en la barra, 0 = en el desplegable
    ExecutablePath       REG_SZ     proceso propietario
    IconResource         REG_SZ     ruta,-id
    IconSnapshot         REG_BINARY imagen en caché
    LastNotificationAddedTime  REG_QWORD
```

Refuerzos heredados (opcionales): `EnableAutoTray=0` y eliminación de las políticas `HideSCA*`
en `HKCU\…\Policies\Explorer`. Investigación completa, análisis de degradación y lista de
«no tocar» (`StuckRects3` etc.): [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md).

## 🔄 Autoactualización vía Git

- Feed: [`update/stable.json`](update/stable.json) en `main` (esquema, pines sha256, notas)
- Cliente: descarga WinHTTP → verificación BCrypt SHA-256 → autorreemplazo por cadena de
  renombrados → relanzamiento
- Nunca en silencio: diálogo de confirmación en actualizaciones manuales; la comprobación
  automática es opt-in, ≤ 1 vez/24 h, solo globo
- CI fija el feed **desde los bytes que la release realmente sirve** (`scripts/make_feed.py`),
  así feed y activos nunca discrepan — ver [Updater_SKILL.MD](Updater_SKILL.MD)

## 🌍 Idiomas

30 idiomas con respaldo al inglés cadena por cadena y autodetección del idioma del SO en el
primer arranque (cambio en vivo en **Apariencia → Idioma**):

| | | | |
|---|---|---|---|
| English (predeterminado) | Русский | 中文 (简体) | हिन्दी |
| Español | Deutsch | Français | Português |
| 日本語 | 한국어 | Italiano | العربية |
| Indonesian | اردو | Türkçe | Tiếng Việt |
| Polski | ไทย | Українська | Nederlands |
| Română | Ελληνικά | Čeština | Svenska |
| Magyar | Suomi | Dansk | עברית |
| فارسی | বাংলা | | |

Detalles y guía de traducción: [docs/I18N.md](docs/I18N.md).

## 🌗 Temas y apariencia

- **Claro / Oscuro / Sistema** — persistidos, autodetectados al inicio, conmutador rápido en la
  barra de título; título oscuro inmersivo y esquinas de Windows 11
- **Acento**: seguir la coloración de Windows u 8 preajustes integrados
- **Movimiento**: deslizamientos de interruptor de 140 ms y estados hover (desactivables),
  modo de filas compactas
- DPI Per-Monitor-V2 correcto en toda la interfaz

## 🏢 Despliegue y automatización

- **Programador de tareas / scripts de inicio de sesión GPO**: `TrayIconGuard.exe --watch`
  (sin interfaz) o `--minimized` (GUI en bandeja)
- **RMM / monitorización**: `--status --json`, códigos de salida estables, registros rotatorios
  de 14 días en `%LOCALAPPDATA%\TrayIconGuard\logs`
- **Seguro para flotas**: el ámbito por usuario no requiere admin; el de máquina usa
  `--install-machine` desde un contexto elevado
- Listo para Store: manifiesto MSIX + activos + script de empaquetado en [`store/`](store/) —
  ver [docs/STORE.md](docs/STORE.md)

## 🔍 Solución de problemas

| Síntoma | Solución |
|---|---|
| «Configuración side-by-side incorrecta» al iniciar | exe descomprimido en una carpeta llamada `*.exe` o sin desbloquear; ver [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) |
| Aviso de SmartScreen en la primera ejecución | esperado en binarios sin firmar: Propiedades → Desbloquear; guía de firmado en [docs/SMARTSCREEN.md](docs/SMARTSCREEN.md) |
| Los iconos se reocultan tras actualizar una app | ¿guardia en pausa? menú de bandeja → *Pausar/Reanudar*; la página Actividad muestra los eventos |
| Actualización rechazada: sha256 mismatch | deriva feed/activos — republicar según [Updater_SKILL.MD](Updater_SKILL.MD) §3 |
| No promueve nada en Win10 < 1703 | almacén no soportado; la app lo indica y ofrece alternativas heredadas |

Más: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) · [FAQ del wiki](https://github.com/paulmann/windows-show-all-tray-icons/wiki)

## 🛠️ Compilar desde el código fuente

```bash
# Compilación cruzada en Linux (exe estático, stripped, sin dependencias)
sudo apt install g++-mingw-w64-x86-64 cmake
./scripts/build.sh          # puertas: 0 avisos, chequeo de manifiesto, auditoría de DLLs del SO
./scripts/package.sh        # zip + SHA256SUMS

# O nativo con MSVC en Windows
cmake -S . -B build -G "Visual Studio 17 2022" -A x64
cmake --build build --config Release
```

CI ejecuta ambas rutas en cada push (cross en ubuntu + MSVC en windows) y publica releases con
etiquetas `v*`. Detalles: [docs/BUILD.md](docs/BUILD.md).

## 🗂️ Mapa del repositorio

| Ruta | Contenido |
|---|---|
| `src/core` | motor: almacén de registro, guardia, explorer, copias, autoinicio, instalador, actualizador, CLI |
| `src/ui` | kit Fluent, páginas, asistente, bandeja, temas, i18n de 30 idiomas |
| `docs/` | documentación técnica y de usuario (HOW-IT-WORKS, CLI, DESIGN, I18N, STORE, SMARTSCREEN…) |
| `store/` | manifiesto MSIX + activos de Store + `make_msix.ps1` |
| `scripts/` | herramientas de build/empaquetado/feed (`build.sh`, `package.sh`, `make_feed.py`) |
| `installer/` | auxiliares opcionales ps1/bat/Inno para empaquetado corporativo |
| `update/` | feed de actualización en vivo (`stable.json`) |
| `.github/workflows/ci.yml` | puertas + release + pipeline de fijado del feed |

## 🤝 Contribuir

Se agradecen issues y PRs. Por favor mantenga: cero dependencias de runtime, el modelo de
seguridad solo-HKCU, la puerta de compilación sin avisos (`-Wall -Wextra`) y el contrato de
feed de `Updater_SKILL.MD`. Consulta [`CONTRIBUTING.md`](CONTRIBUTING.md) y el [Código de Conducta](CODE_OF_CONDUCT.md); los problemas de seguridad se reportan vía [`SECURITY.md`](SECURITY.md).

## 📄 Licencia

[PolyForm Noncommercial License 1.0.0](LICENSE) — libre para uso no comercial; licenciamiento
comercial: contactar con el autor.

## 👨‍💻 Autor y soporte

**Mikhail Deynekin** · <icons@Deynekin.com> · [Deynekin.com](https://Deynekin.com) ·
[GitHub](https://github.com/paulmann) ·
[Base de conocimiento (wiki)](https://github.com/paulmann/windows-show-all-tray-icons/wiki) ·
[Licencia](https://github.com/paulmann/windows-show-all-tray-icons/blob/main/LICENSE)

## 🎯 Hoja de ruta

- [ ] Pipeline de firmado de código (reputación SmartScreen)
- [ ] Espejado de diseño RTL para árabe/hebreo/persa/urdu
- [ ] Empaquetado MSI para SCCM/Intune Win32 apps
- [ ] Compilación nativa ARM64

---

<sub>Hecho con 🧡 para barras de tareas ordenadas. TrayIconGuard no está afiliado a Microsoft.</sub>
