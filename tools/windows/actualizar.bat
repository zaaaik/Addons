@echo off
chcp 65001 >nul
title Actualizar MisionesES
cd /d "%~dp0..\.."
echo Descargando la ultima version de MisionesES...
git pull
echo.
echo Listo. Haz /reload en el juego.
pause
