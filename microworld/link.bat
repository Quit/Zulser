@echo off
REM Execute this batch file as administrator to create a symbolic link to this folder inside the microworld-worlds
REM This allows you to have this mod's microworlds accessible using the world name "zulser.{WORLD_NAME}"
REM Requires Windows Vista or higher. Must be executed as administrator (rightclick->run as->administrator)
REM Switch to the right drive
%~d0
REM Switch to the right folder
cd %~dp0

echo Remove existing folder
rmdir ..\..\microworld\worlds\zulser
echo Create link
mklink /D "..\..\microworld\worlds\zulser" "%~dp0"
IF EXIST ..\..\microworld\.git GOTO add_gitignore
pause

:end
exit 0

:add_gitignore
echo CD to .git directory...
cd ..\..\microworld\.git
IF NOT EXIST info ( mkdir info )
echo Add to git exclude
(echo.) >> info\exclude
(echo worlds/zulser) >> info\exclude
goto end