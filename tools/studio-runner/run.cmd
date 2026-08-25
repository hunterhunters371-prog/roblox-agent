@echo off
REM ===================================================================
REM  Roblox Agent Bridge -- runner de Studio
REM  Ejecuta diagnose.luau dentro de Roblox Studio sin abrir la ventana
REM  a mano, y sube el informe al repositorio para que el agente lo lea.
REM
REM  EDITA SOLO LAS TRES LINEAS DE ABAJO. Una vez. Nunca mas.
REM ===================================================================

set "REPO=C:\Users\dayal\roblox-agent"
set "PLACE_ID=90800641570450"
set "UNIVERSE_ID=PON_AQUI_EL_UNIVERSE_ID"

REM ------------------------------------------------------------------
setlocal enabledelayedexpansion

if not exist "%REPO%\.git" (
  echo [ERROR] No hay repositorio en: %REPO%
  echo         Clonalo primero o corrige la variable REPO.
  exit /b 1
)

if "%UNIVERSE_ID%"=="PON_AQUI_EL_UNIVERSE_ID" (
  echo [ERROR] Falta el UNIVERSE_ID.
  echo         Creator Dashboard ^> tu juego ^> los tres puntos ^> Copy Universe ID
  exit /b 1
)

REM --- localizar Studio: la version mas reciente instalada -----------
set "STUDIO="
for /f "delims=" %%d in ('dir /b /a:d /o:-d "%LOCALAPPDATA%\Roblox\Versions" 2^>nul') do (
  if not defined STUDIO (
    if exist "%LOCALAPPDATA%\Roblox\Versions\%%d\RobloxStudioBeta.exe" (
      set "STUDIO=%LOCALAPPDATA%\Roblox\Versions\%%d\RobloxStudioBeta.exe"
    )
  )
)

if not defined STUDIO (
  echo [ERROR] No encuentro RobloxStudioBeta.exe en %LOCALAPPDATA%\Roblox\Versions
  exit /b 1
)
echo [1/5] Studio: !STUDIO!

REM --- traer el script de diagnostico mas reciente -------------------
echo [2/5] Actualizando el repositorio...
git -C "%REPO%" pull --quiet
if errorlevel 1 echo        (aviso: el pull fallo, sigo con la copia local)

set "SCRIPT=%REPO%\tools\studio-runner\diagnose.luau"
if not exist "%SCRIPT%" (
  echo [ERROR] No existe %SCRIPT%
  exit /b 1
)

for /f "delims=" %%t in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%t"
set "DESTINO=%REPO%\informes"
if not exist "%DESTINO%" mkdir "%DESTINO%"
set "SALIDA=%DESTINO%\studio_!STAMP!.txt"

REM --- ejecutar. Studio abre el place, corre el script y se cierra ---
REM     Sin --quitAfterExecution la ventana quedaria abierta.
REM     Studio NO guarda al cerrarse asi: el mundo queda intacto.
echo [3/5] Ejecutando el diagnostico dentro de Studio...
echo        (tarda entre 40 y 90 segundos, no toques nada)
start /wait "" "!STUDIO!" --task RunScript --runScriptFile "%SCRIPT%" --outputFile "!SALIDA!" --placeId %PLACE_ID% --universeId %UNIVERSE_ID% --quitAfterExecution

if not exist "!SALIDA!" (
  echo [ERROR] Studio no dejo ningun informe.
  echo         Suele significar que el place esta abierto en otra ventana.
  echo         Cierra Studio del todo y vuelve a lanzar esto.
  exit /b 1
)

for %%f in ("!SALIDA!") do echo [4/5] Informe generado: %%~nxf  (%%~zf bytes)

REM --- publicar el informe ------------------------------------------
echo [5/5] Subiendo el informe...
git -C "%REPO%" add "informes"
git -C "%REPO%" commit -m "informe de Studio !STAMP!" --quiet
git -C "%REPO%" push --quiet
if errorlevel 1 (
  echo [ERROR] El push fallo. Revisa tus credenciales de git.
  exit /b 1
)

echo.
echo ==================================================================
echo  LISTO. Dile al agente: "ya hay informe nuevo".
echo  Archivo: informes/studio_!STAMP!.txt
echo ==================================================================
endlocal
