@echo off
  
 :: ----------------------
:: KUDU Deployment Script
:: ----------------------
 
:: Prerequisites
:: -------------
 
:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)
 
:: Setup
:: -----
 
setlocal enabledelayedexpansion
 
SET ARTIFACTS=%~dp0%artifacts
 
IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)
 
IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)
 
IF NOT DEFINED NEXT_MANIFEST_PATH (
  SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest
 
  IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
    SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
  )
)
 
IF NOT DEFINED KUDU_SYNC_CMD (
  call npm config set ca "" 
  
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g
  IF !ERRORLEVEL! NEQ 0 goto error
 
  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=node "%appdata%\npm\node_modules\kuduSync\bin\kuduSync"
)
IF NOT DEFINED DEPLOYMENT_TEMP (
  SET DEPLOYMENT_TEMP=%temp%\___deployTemp%random%
  SET CLEAN_LOCAL_DEPLOYMENT_TEMP=true
)
 
IF DEFINED CLEAN_LOCAL_DEPLOYMENT_TEMP (
  IF EXIST "%DEPLOYMENT_TEMP%" rd /s /q "%DEPLOYMENT_TEMP%"
  mkdir "%DEPLOYMENT_TEMP%"
)
 
IF NOT DEFINED MSBUILD_PATH (
  SET MSBUILD_PATH=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\msbuild.exe
)
 
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------
 
echo Handling .NET Web Application deployment.
 
:: 1. Build to the temporary path
%MSBUILD_PATH% "%DEPLOYMENT_SOURCE%\build\nop.proj" /nologo /verbosity:m /p:_PackageTempDir="%DEPLOYMENT_TEMP%";AutoParameterizationWebConfigConnectionStrings=false;Configuration=Release
IF !ERRORLEVEL! NEQ 0 goto error

%MSBUILD_PATH% "%DEPLOYMENT_SOURCE%\build\nop.proj" /target:Deploy /nologo /verbosity:m /p:_PackageTempDir="%DEPLOYMENT_TEMP%";AutoParameterizationWebConfigConnectionStrings=false;Configuration=Release
IF !ERRORLEVEL! NEQ 0 goto error
 
:: 2. KuduSync
echo Kudu Sync from "%DEPLOYMENT_SOURCE%\Deployable\nop_3.20" to "%DEPLOYMENT_TARGET%"
call %KUDU_SYNC_CMD% -q -f "%DEPLOYMENT_SOURCE%\Deployable\nop_3.20" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.deployment;deploy.cmd" 2>nul
IF !ERRORLEVEL! NEQ 0 goto error
 
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
 
goto end
 
:error
echo An error has occured during web site deployment.
echo !ERRORLEVEL!
exit /b 1
 
:end
echo Finished successfully.