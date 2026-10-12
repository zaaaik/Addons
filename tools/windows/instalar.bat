@echo off
chcp 65001 >nul
setlocal
title Instalador de MisionesES
echo ============================================
echo   Instalador de MisionesES (clon de trabajo)
echo ============================================
echo.

rem 1. Git
where git >nul 2>nul
if errorlevel 1 (
    echo Git no esta instalado. Instalando con winget...
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    set "PATH=%PATH%;C:\Program Files\Git\cmd"
)
where git >nul 2>nul
if errorlevel 1 (
    echo No se pudo instalar Git. Instalalo desde https://git-scm.com/download/win y vuelve a ejecutar este archivo.
    pause
    exit /b 1
)

rem 2. Clonar o actualizar el repo
set "DEST=C:\Proyectos\Addons"
if exist "%DEST%\.git" (
    echo Actualizando %DEST% ...
    git -C "%DEST%" pull
) else (
    echo Clonando el repo en %DEST% ...
    git clone -b claude/wizardly-cannon-femusv https://github.com/zaaaik/Addons.git "%DEST%"
)
if not exist "%DEST%\MisionesES\MisionesES.toc" (
    echo No se pudo clonar el repo. Revisa tu conexion o tu acceso a GitHub.
    pause
    exit /b 1
)

rem 3. Carpeta AddOns de WoW Forever
echo.
echo Abre Battle.net, elige WoW Forever, pulsa el engranaje y "Mostrar en el Explorador".
echo Entra en la carpeta de Forever y luego en Interface\AddOns. Copia esa ruta.
echo.
set /p "ADDONS=Pega aqui la ruta de Interface\AddOns y pulsa Enter: "
set "ADDONS=%ADDONS:"=%"
if not exist "%ADDONS%" (
    echo La carpeta "%ADDONS%" no existe.
    pause
    exit /b 1
)

rem 4. Sustituir la copia antigua por un enlace al repo
if exist "%ADDONS%\MisionesES" (
    rem Si ya es un enlace, rmdir solo quita el enlace. Si es una carpeta real, se renombra.
    rmdir "%ADDONS%\MisionesES" 2>nul
    if exist "%ADDONS%\MisionesES" ren "%ADDONS%\MisionesES" "MisionesES_antiguo"
)
mklink /J "%ADDONS%\MisionesES" "%DEST%\MisionesES"
if errorlevel 1 (
    echo No se pudo crear el enlace.
    pause
    exit /b 1
)

echo.
echo Listo. El addon de WoW apunta ahora a %DEST%\MisionesES
echo Para actualizar en el futuro, ejecuta %DEST%\tools\windows\actualizar.bat y haz /reload en el juego.
if exist "%ADDONS%\MisionesES_antiguo" echo (La copia antigua quedo como MisionesES_antiguo; puedes borrarla.)
pause
