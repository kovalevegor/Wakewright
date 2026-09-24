@echo off
setlocal enabledelayedexpansion

:: ────────────────────────────────────────────────────────
:: STEP 0: HANDLE COMMAND-LINE ARGUMENTS
:: ────────────────────────────────────────────────────────
set "SKIP_SAVED=0"
set "SKIP_DERIVED=0"
set "SKIP_VS=0"
set "SKIP_BINARIES=0"
set "SKIP_INTERMEDIATE=0"
set "SKIP_SLN=0"
set "SKIP_IDEA=0"
set "SKIP_VSCONFIG=0"
set "SKIP_PLUGINS_BINARIES=0"
set "SKIP_PLUGINS_INTERMEDIATE=0"

:: Debug: Show if any parameters were passed
if "%~1"=="" (
    goto end_args
)

:: Process all parameters using FOR loop (more reliable than goto)
for %%p in (%*) do (
    if /i "%%p"=="no_saved" set "SKIP_SAVED=1"
    if /i "%%p"=="no_derived" set "SKIP_DERIVED=1"
    if /i "%%p"=="no_vs" set "SKIP_VS=1"
    if /i "%%p"=="no_binaries" set "SKIP_BINARIES=1"
    if /i "%%p"=="no_intermediate" set "SKIP_INTERMEDIATE=1"
    if /i "%%p"=="no_sln" set "SKIP_SLN=1"
    if /i "%%p"=="no_vsconfig" set "SKIP_VSCONFIG=1"
    if /i "%%p"=="no_idea" set "SKIP_IDEA=1"
    if /i "%%p"=="no_plugins_binaries" set "SKIP_PLUGINS_BINARIES=1"
    if /i "%%p"=="no_plugins_intermediate" set "SKIP_PLUGINS_INTERMEDIATE=1"
)

:end_args

:: ────────────────────────────────────────────────────────
:: STEP 1: LOCATE .uproject in PARENT DIRECTORY
:: ────────────────────────────────────────────────────────
set "SCRIPT_DIR=%~dp0"
set "PARENT_DIR=%SCRIPT_DIR%..\"  :: Go up one level
set "UPROJECT_FILE="

for %%f in ("%PARENT_DIR%*.uproject") do (
    set "UPROJECT_FILE=%%f"
    goto found_uproject
)

echo [ERROR] .uproject not found in parent directory: %PARENT_DIR%
pause
exit /b 1

:found_uproject
echo [INFO] .uproject: %UPROJECT_FILE%

:: ────────────────────────────────────────────────────────
:: STEP 2: EXTRACT UE VERSION
:: ────────────────────────────────────────────────────────
set "UE_VERSION="

for /f "usebackq tokens=*" %%a in (`findstr /C:"EngineAssociation" "%UPROJECT_FILE%" 2^>nul`) do (
    for /f "tokens=2 delims=:" %%b in ("%%a") do (
        set "value=%%b"
        set "value=!value:"=!"
        set "value=!value: =!"
        set "value=!value:,=!"
        set "UE_VERSION=!value!"
    )
)

if not defined UE_VERSION (
    echo [ERROR] "EngineAssociation" not found in %UPROJECT_FILE%
    pause
    exit /b 1
)

echo [INFO] UE version: %UE_VERSION%

:: ────────────────────────────────────────────────────────
:: STEP 3: FIND ENGINE PATH (CU -> LM)
:: ────────────────────────────────────────────────────────
set "ENGINE_PATH="

:: 1. Check HKEY_CURRENT_USER (with space: "Epic Games")
set "REG_PATH_CU=HKEY_CURRENT_USER\SOFTWARE\Epic Games\Unreal Engine\%UE_VERSION%"
reg query "!REG_PATH_CU!" /v "InstalledDirectory" >nul 2>&1
if !errorlevel! equ 0 (
    for /f "tokens=2* delims= " %%a in ('reg query "!REG_PATH_CU!" /v "InstalledDirectory" 2^>nul ^| findstr "REG_SZ"') do (
        set "ENGINE_PATH=%%b"
    )
)

:: 2. Check HKEY_LOCAL_MACHINE (without space: "EpicGames")
if not defined ENGINE_PATH (
    set "REG_PATH_LM=HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine\%UE_VERSION%"
    reg query "!REG_PATH_LM!" /v "InstalledDirectory" >nul 2>&1
    if !errorlevel! equ 0 (
        for /f "tokens=2* delims= " %%a in ('reg query "!REG_PATH_LM!" /v "InstalledDirectory" 2^>nul ^| findstr "REG_SZ"') do (
            set "ENGINE_PATH=%%b"
        )
    )
)

:: 3. Validate result
if not defined ENGINE_PATH (
    echo [ERROR] UE %UE_VERSION% not found in registry!
    echo Check:
    echo   1. Is version installed via Epic Games Launcher?
    echo   2. Verify registry keys exist:
    echo      - HKEY_CURRENT_USER\SOFTWARE\Epic Games\Unreal Engine\%UE_VERSION%
    echo      - HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine\%UE_VERSION%
    echo.
    echo [DEBUG] Testing registry access...
    echo   - Checking CU: reg query "HKEY_CURRENT_USER\SOFTWARE\Epic Games\Unreal Engine\%UE_VERSION%"
    reg query "HKEY_CURRENT_USER\SOFTWARE\Epic Games\Unreal Engine\%UE_VERSION%" 2>nul || echo     CU path not found
    echo   - Checking LM: reg query "HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine\%UE_VERSION%"
    reg query "HKEY_LOCAL_MACHINE\SOFTWARE\EpicGames\Unreal Engine\%UE_VERSION%" 2>nul || echo     LM path not found
    pause
    exit /b 1
)

:: ────────────────────────────────────────────────────────
:: STEP 4: VERIFY UBT
:: ────────────────────────────────────────────────────────
set "UBT_PATH=%ENGINE_PATH%\Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.exe"
if not exist "%UBT_PATH%" (
    echo [ERROR] UBT not found: %UBT_PATH%
    pause
    exit /b 1
)

:: ────────────────────────────────────────────────────────
:: STEP 5: CLEAN TEMP FOLDERS (in parent directory)
:: ────────────────────────────────────────────────────────
set "CLEAN_DIR=%PARENT_DIR%"
set "EXCLUSIONS="

if "%SKIP_SAVED%"=="1" set "EXCLUSIONS=%EXCLUSIONS% Saved"
if "%SKIP_DERIVED%"=="1" set "EXCLUSIONS=%EXCLUSIONS% DerivedDataCache"
if "%SKIP_VS%"=="1" set "EXCLUSIONS=%EXCLUSIONS% .vs"
if "%SKIP_BINARIES%"=="1" set "EXCLUSIONS=%EXCLUSIONS% Binaries"
if "%SKIP_INTERMEDIATE%"=="1" set "EXCLUSIONS=%EXCLUSIONS% Intermediate"
if "%SKIP_SLN%"=="1" set "EXCLUSIONS=%EXCLUSIONS% .sln"
if "%SKIP_VSCONFIG%"=="1" set "EXCLUSIONS=%EXCLUSIONS% .vsconfig"
if "%SKIP_IDEA%"=="1" set "EXCLUSIONS=%EXCLUSIONS% .idea"
if "%SKIP_PLUGINS_BINARIES%"=="1" set "EXCLUSIONS=%EXCLUSIONS% Plugins_Binaries"
if "%SKIP_PLUGINS_INTERMEDIATE%"=="1" set "EXCLUSIONS=%EXCLUSIONS% Plugins_Intermediate"

if "%EXCLUSIONS%"=="" echo [CLEAN] Removing ALL temp folders/files...
if not "%EXCLUSIONS%"=="" echo [CLEAN] Removing temp folders/files (excluding:%EXCLUSIONS%)...

: Clean folders (one-line if statements, no parentheses)
if not "%SKIP_VS%"=="1" if exist "%CLEAN_DIR%.vs" rmdir /s /q "%CLEAN_DIR%.vs" >nul 2>&1 & echo   - .vs deleted
if not "%SKIP_BINARIES%"=="1" if exist "%CLEAN_DIR%Binaries" rmdir /s /q "%CLEAN_DIR%Binaries" >nul 2>&1 & echo   - Binaries deleted
if not "%SKIP_INTERMEDIATE%"=="1" if exist "%CLEAN_DIR%Intermediate" rmdir /s /q "%CLEAN_DIR%Intermediate" >nul 2>&1 & echo   - Intermediate deleted
if not "%SKIP_SAVED%"=="1" if exist "%CLEAN_DIR%Saved" rmdir /s /q "%CLEAN_DIR%Saved" >nul 2>&1 & echo   - Saved deleted
if not "%SKIP_DERIVED%"=="1" if exist "%CLEAN_DIR%DerivedDataCache" rmdir /s /q "%CLEAN_DIR%DerivedDataCache" >nul 2>&1 & echo   - DerivedDataCache deleted
if not "%SKIP_IDEA%"=="1" if exist "%CLEAN_DIR%.idea" rmdir /s /q "%CLEAN_DIR%.idea" >nul 2>&1 & echo   - .idea deleted

:: Clean files
if not "%SKIP_SLN%"=="1" if exist "%CLEAN_DIR%*.sln" del /f /q "%CLEAN_DIR%*.sln" >nul 2>&1 & echo   - .sln files deleted
if not "%SKIP_VSCONFIG%"=="1" if exist "%CLEAN_DIR%*.vsconfig" del /f /q "%CLEAN_DIR%*.vsconfig" >nul 2>&1 & echo   - .vsconfig files deleted

:: ────────────────────────────────────────────────────────
:: STEP 5.1: CLEAN PLUGIN TEMP FOLDERS
:: ────────────────────────────────────────────────────────
if exist "%CLEAN_DIR%Plugins\" (
    echo [CLEAN] Scanning plugin folders for temp files...
    
    :: Clean plugin Binaries folders
    if %SKIP_PLUGINS_BINARIES% equ 0 (
        set "PLUGIN_BINARIES_COUNT=0"
        for /d /r "%CLEAN_DIR%Plugins" %%d in (Binaries) do (
            if exist "%%d" (
                set /a PLUGIN_BINARIES_COUNT+=1
                rmdir /s /q "%%d" >nul 2>&1
                echo   - Plugin Binaries deleted: %%d
            )
        )
        if !PLUGIN_BINARIES_COUNT! equ 0 (
            echo   - No plugin Binaries folders found
        )
    ) else (
        echo   - Plugin Binaries skipped (excluded)
    )
    
    :: Clean plugin Intermediate folders
    if %SKIP_PLUGINS_INTERMEDIATE% equ 0 (
        set "PLUGIN_INTERMEDIATE_COUNT=0"
        for /d /r "%CLEAN_DIR%Plugins" %%d in (Intermediate) do (
            if exist "%%d" (
                set /a PLUGIN_INTERMEDIATE_COUNT+=1
                rmdir /s /q "%%d" >nul 2>&1
                echo   - Plugin Intermediate deleted: %%d
            )
        )
        if !PLUGIN_INTERMEDIATE_COUNT! equ 0 (
            echo   - No plugin Intermediate folders found
        )
    ) else (
        echo   - Plugin Intermediate skipped (excluded)
    )
) else (
    echo [CLEAN] No Plugins folder found - skipping plugin cleanup
)

:: ────────────────────────────────────────────────────────
:: STEP 6: GENERATE PROJECT
:: ────────────────────────────────────────────────────────
echo [ACTION] Generating project...
"%UBT_PATH%" -projectfiles Development Win64 -project="%UPROJECT_FILE%" -TargetType=Editor -Progress -NoEngineChanges -NoHotReloadFromIDE

if %errorlevel% neq 0 (
    echo [ERROR] Project generation failed!
    pause
    exit /b %errorlevel%
)

:: ────────────────────────────────────────────────────────
:: STEP 7: OPEN .uproject
:: ────────────────────────────────────────────────────────
start "" "%UPROJECT_FILE%"

:: ────────────────────────────────────────────────────────
:: FINAL MESSAGE
:: ────────────────────────────────────────────────────────
echo [DONE] Project generated successfully!
echo   - .uproject: %UPROJECT_FILE%
echo   - Engine: %ENGINE_PATH%
echo Closing window in 5 seconds...
timeout /t 5 /nobreak >nul
exit /b 0