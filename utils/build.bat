:: Copyright (C) 2015-2018 Virgil Security Inc.
::
:: All rights reserved.
::
:: Redistribution and use in source and binary forms, with or without
:: modification, are permitted provided that the following conditions are
:: met:
::
::     (1) Redistributions of source code must retain the above copyright
::     notice, this list of conditions and the following disclaimer.
::
::     (2) Redistributions in binary form must reproduce the above copyright
::     notice, this list of conditions and the following disclaimer in
::     the documentation and/or other materials provided with the
::     distribution.
::
::     (3) Neither the name of the copyright holder nor the names of its
::     contributors may be used to endorse or promote products derived from
::     this software without specific prior written permission.
::
:: THIS SOFTWARE IS PROVIDED BY THE AUTHOR ''AS IS'' AND ANY EXPRESS OR
:: IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
:: WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
:: DISCLAIMED. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT,
:: INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
:: (INCLUDING, BUT NOT LIMITED TO, PROCUremENT OF SUBSTITUTE GOODS OR
:: SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
:: HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
:: STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
:: IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
:: POSSIBILITY OF SUCH DAMAGE.
::
:: Lead Maintainer: Virgil Security Inc. <support@virgilsecurity.com>

:: This script helps to build Virgil Security Crypto library under Windows OS with MSVC toolchain.

@echo off
setlocal

:: Prepare environment variables
if defined MSVC_ROOT call :remove_quotes MSVC_ROOT
if defined JAVA_HOME call :remove_quotes JAVA_HOME
if defined PHP_HOME call :remove_quotes PHP_HOME
if defined PHP_DEVEL_HOME call :remove_quotes PHP_DEVEL_HOME
if defined PHPUNIT_HOME call :remove_quotes PHPUNIT_HOME

:: Check environment prerequisite
if "%MSVC_ROOT%" == "" goto error_not_msvc_root

if exist "%MSVC_ROOT%\VC\vcvarsall.bat" set VCVARSALL=%MSVC_ROOT%\VC\vcvarsall.bat

if exist "%MSVC_ROOT%\VC\Auxiliary\Build\vcvarsall.bat" set VCVARSALL=%MSVC_ROOT%\VC\Auxiliary\Build\vcvarsall.bat

if "%VCVARSALL%" == "" goto :error_vcvarsall_not_found

:: Define script global variables
set CURRENT_DIR=%CD%
set SCRIPT_DIR=%~dp0

:: Parse input parameters
if not "%1" == "" (
    set TARGET=%1
) else (
    set TARGET=cpp
)
call :show_info TARGET: %TARGET%

:: Parse target format target-version-architecture, i.e nodejs-0.12.7-x86
for /F "tokens=1,2,3 delims=-" %%a in ("%TARGET%") do (
    set TARGET_NAME=%%a
    set TARGET_VERSION=%%b
    set TARGET_ARCH=%%c
)

call :show_info TARGET_NAME: %TARGET_NAME%
if not "%TARGET_VERSION%" == "" call :show_info TARGET_VERSION: %TARGET_VERSION%
if not "%TARGET_ARCH%" == "" call :show_info TARGET_ARCH: %TARGET_ARCH%

if not "%2" == "" (
    call :abspath SRC_DIR=%2
) else (
    set SRC_DIR=%CURRENT_DIR%
)
call :show_info SRC_DIR: %SRC_DIR%

if not "%3" == "" (
    mkdir %3 2>nul || REM Ignore error during creation
    call :abspath BUILD_DIR=%3
) else (
    set BUILD_DIR=%CURRENT_DIR%\build\%TARGET_NAME%
)
if not "%TARGET_VERSION%" == "" (
    set BUILD_DIR=%BUILD_DIR%\%TARGET_VERSION%
)
if not "%TARGET_ARCH%" == "" (
    set BUILD_DIR=%BUILD_DIR%\%TARGET_ARCH%
)
call :show_info BUILD_DIR: %BUILD_DIR%

if not "%4" == "" (
    mkdir %4 2>nul || REM Ignore error during creation
    call :abspath INSTALL_DIR=%4
) else (
    set INSTALL_DIR=%CURRENT_DIR%\install\%TARGET_NAME%
)
if not "%TARGET_VERSION%" == "" (
    set INSTALL_DIR=%INSTALL_DIR%\%TARGET_VERSION%
)
if not "%TARGET_ARCH%" == "" (
    set INSTALL_DIR=%INSTALL_DIR%\%TARGET_ARCH%
)
call :show_info INSTALL_DIR: %INSTALL_DIR%

:: Configure common CMake parameters
set CMAKE_ARGS=-DCMAKE_BUILD_TYPE=Release -G"NMake Makefiles" -DVIRGIL_CRYPTO_FEATURE_LOW_LEVEL_WRAP=ON

:: Prepare build and install directories
mkdir %BUILD_DIR% %INSTALL_DIR% 2>nul
call :clean_dirs %BUILD_DIR% %INSTALL_DIR%
cd "%BUILD_DIR%"

:: Route target build
if "%TARGET_NAME%" == "cpp" goto cpp
if "%TARGET_NAME%" == "java" goto java
if "%TARGET_NAME%" == "net" goto net
if "%TARGET_NAME%" == "nodejs" goto nodejs
if "%TARGET_NAME%" == "python" goto python
if "%TARGET_NAME%" == "php" goto php

:: No supported target was found
goto error_target_not_supported

:cpp
call :native
goto :eof

:java
if "%JAVA_HOME%" == "" goto error_not_java_home
call :native
goto :eof

:nodejs
if not "%TARGET_VERSION%" == "" (
    set CMAKE_ARGS=%CMAKE_ARGS% -DLANG_VERSION=%TARGET_VERSION%
)
call :native
goto :eof

:python
if not "%TARGET_VERSION%" == "" (
    set CMAKE_ARGS=%CMAKE_ARGS% -DLANG_VERSION=%TARGET_VERSION%
)
call :native
goto :eof

:net
:: Build x86 architecture
setlocal
    set PLATFORM_ARCH=x86
    call :clean_dirs %BUILD_DIR%
    call :configure_env %PLATFORM_ARCH%
    set CMAKE_ARGS=%CMAKE_ARGS% -DPLATFORM_ARCH=%PLATFORM_ARCH% -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%"
    cmake %CMAKE_ARGS% -DLANG=%TARGET_NAME% "%SRC_DIR%" || goto end
    nmake && nmake install || goto end
endlocal
:: Build x64 architecture
setlocal
    set PLATFORM_ARCH=x64
    call :clean_dirs %BUILD_DIR%
    call :configure_env %PLATFORM_ARCH%
    set CMAKE_ARGS=%CMAKE_ARGS% -DPLATFORM_ARCH=%PLATFORM_ARCH% -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%"
    cmake %CMAKE_ARGS% -DLANG=%TARGET_NAME% "%SRC_DIR%" || goto end
    nmake && nmake install || goto end
endlocal
:: Make .NET specific file organization
xcopy /y/q "%SRC_DIR%\VERSION" "%INSTALL_DIR%" >nul
set /p ARCHIVE_NAME=<lib_name.txt
call :archive_artifacts %INSTALL_DIR% %ARCHIVE_NAME%
goto :eof

:php
if "%PHP_DEVEL_HOME%" == "" goto error_not_php_devel_home
if not "%TARGET_VERSION%" == "" (
    set CMAKE_ARGS=%CMAKE_ARGS% -DLANG_VERSION=%TARGET_VERSION%
)
call :native
goto :eof

:native
if "%TARGET_ARCH%" == "" (
    call :native_arch x86
    call :native_arch x64
) else (
    call :native_arch %TARGET_ARCH%
)
goto :eof

:native_arch
:: Make native build with given architecture
setlocal
    set PLATFORM_ARCH=%1
    set INSTALL_DIR=%INSTALL_DIR%\%PLATFORM_ARCH%
    call :clean_dirs %BUILD_DIR%
    call :configure_env %PLATFORM_ARCH%
    set CMAKE_ARGS=%CMAKE_ARGS% -DPLATFORM_ARCH=%PLATFORM_ARCH% -DCMAKE_INSTALL_PREFIX="%INSTALL_DIR%"
    cmake %CMAKE_ARGS% -DLANG=%TARGET_NAME% "%SRC_DIR%" || goto end
    nmake && nmake install || goto end
    xcopy /y/q "%SRC_DIR%\VERSION" "%INSTALL_DIR%" >nul
    set /p ARCHIVE_NAME=<lib_name_full.txt
    call :archive_artifacts %INSTALL_DIR% %ARCHIVE_NAME%
endlocal
goto :eof

:: usage: call :archive_artifacts <src_dir> <archive_name>
:archive_artifacts
call :pack_and_zip %1 %2
goto :eof

:: Utility functions
:abspath
pushd %2
set %1=%CD%
popd
goto :eof

:remove_quotes
for /f "delims=" %%A in ('echo %%%1%%') do set %1=%%~fA
goto :eof

:show_info
echo [INFO] %*
goto :eof

:show_warning
echo [WARNING] %*
goto :eof

:show_error
echo [ERROR] %*
goto :eof

:configure_env
call "%VCVARSALL%" %1
goto :eof

:: Remove content of the given directories.
:: usage: call :clean_dirs <path_to_dir> ...
:clean_dirs
for %%x in (%*) do (
    if exist "%%~x" (
        pushd %%~x
        for /F "delims=" %%i in ('dir /b') do (rmdir /s/q "%%i" 2>nul || del /s/q "%%i" >nul)
        popd
    )
)
goto :eof

:: Move content of the given directory to the dir and zip it.
:: usage: call :pack_and_zip <src_dir> <dir_name>
:pack_and_zip
pushd %1
for /F "delims=" %%i in ('dir /b') do (
    if not exist "%2" mkdir "%2"
    move /y "%%i" "%2" > nul
)
CScript "%SCRIPT_DIR%\zip.vbs" "%2" "%2.zip" >nul && rmdir /s/q "%2"
popd
goto :eof

:: Errors
:error_not_msvc_root
echo MSVC_ROOT environment variable is not defined
echo Please set environment variable MSVC_ROOT to point 'Microsoft Visual Studio' install directory.
exit /b 1

:error_not_java_home
echo JAVA_HOME environment variable is not defined
echo Please set environment variable JAVA_HOME to point JDK install directory.
exit /b 1

:error_not_php_devel_home
echo PHP_DEVEL_HOME environment variable is not defined
echo Please set environment variable PHP_DEVEL_HOME to point directory with PHP developement environment.
exit /b 1

:error_vcvarsall_not_found
echo Can not find vcvarsall.bat under %MSVC_ROOT%\VC directory.
echo Can not find vcvarsall.bat under %MSVC_ROOT%\VC\Auxiliary\Build directory as well.
exit /b 1

:error_target_not_supported
call :show_error Target with name '%TARGET_NAME%' is not supported.
exit /b 1

:end
if %errorlevel% neq 0 exit /b %errorlevel%
goto :eof
