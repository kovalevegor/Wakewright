echo off

rmdir /s /q .vs
rmdir /s /q Binaries
rmdir /s /q Intermediate
rmdir /s /q Saved
rmdir /s /q DerivedDataCache
rmdir /s /q Plugins\SMSystem\Binaries
rmdir /s /q Plugins\SMSystem\Intermediate
rmdir /s /q Plugins\PlushesLoadingScreen\Binaries
rmdir /s /q Plugins\PlushesLoadingScreen\Intermediate

set MyFullPath="%cd%\Wakewright"

%MyUBT% Development Win64 -Project=%MyFullPath%.uproject -TargetType=Editor -Progress -NoEngineChanges -NoHotReloadFromIDE

%MyFullPath%.uproject