Unicode true
RequestExecutionLevel user
SetCompressor zlib
ShowInstDetails show

!include "MUI2.nsh"
!include "nsDialogs.nsh"
!include "LogicLib.nsh"

!ifndef STAGEDIR
  !error "STAGEDIR is required"
!endif

!define CURRENT_APP_VERSION "0.1.0"

Name "Nalia"
OutFile "Nalia-Windows-Installer.exe"
InstallDir "$LOCALAPPDATA\Programs\Nalia"

Var DriveDialog
Var DriveInfo
Var DriveSelected
Var DriveCount
Var InstallPathLabel

!define MUI_ABORTWARNING
Page custom DrivePage DrivePageLeave
!insertmacro MUI_PAGE_INSTFILES
!define MUI_FINISHPAGE_RUN "$INSTDIR\nalia.exe"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

!macro DRIVE_OPTION INDEX Y
  ReadINIStr $0 "$DriveInfo" "Drive${INDEX}" "Root"
  ${If} $0 != ""
    ReadINIStr $1 "$DriveInfo" "Drive${INDEX}" "Display"
    ReadINIStr $4 "$DriveInfo" "Drive${INDEX}" "Recommended"
    ${If} $4 == "1"
      StrCpy $1 "$1  -  Recommended"
    ${EndIf}
    ${NSD_CreateRadioButton} 0 ${Y} 100% 12u "$1"
    Pop $2
    nsDialogs::SetUserData $2 "$0"
    ${NSD_OnClick} $2 DriveRadioClick
    ReadINIStr $3 "$DriveInfo" "Drive${INDEX}" "Default"
    ${If} $DriveCount == 0
      ${NSD_Check} $2
      StrCpy $DriveSelected "$0"
    ${EndIf}
    ${If} $3 == 1
      ${NSD_Check} $2
      StrCpy $DriveSelected "$0"
    ${EndIf}
    IntOp $DriveCount $DriveCount + 1
  ${EndIf}
!macroend

Function DrivePage
  InitPluginsDir
  StrCpy $DriveInfo "$PLUGINSDIR\foxmoss-drives.ini"
  StrCpy $DriveSelected ""
  StrCpy $DriveCount 0

  File /oname=$PLUGINSDIR\drive-options.ps1 "drive-options.ps1"
  nsExec::ExecToStack 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$PLUGINSDIR\drive-options.ps1" -OutputPath "$DriveInfo" -CurrentInstallDir "$INSTDIR"'
  Pop $0
  Pop $1

  nsDialogs::Create 1018
  Pop $DriveDialog
  ${If} $DriveDialog == error
    Abort
  ${EndIf}

  !insertmacro MUI_HEADER_TEXT "Choose a drive" "Nalia will install on the drive you select."
  ${NSD_CreateLabel} 0 0 100% 24u "Choose one local writable drive. The option marked Recommended is chosen from this computer's detected storage hardware (NVMe/SSD/HDD/removable) and available space. Cloud, optical, virtual, and read-only targets are excluded."
  Pop $4

  !insertmacro DRIVE_OPTION 1 30u
  !insertmacro DRIVE_OPTION 2 43u
  !insertmacro DRIVE_OPTION 3 56u
  !insertmacro DRIVE_OPTION 4 69u
  !insertmacro DRIVE_OPTION 5 82u
  !insertmacro DRIVE_OPTION 6 95u
  !insertmacro DRIVE_OPTION 7 108u
  !insertmacro DRIVE_OPTION 8 121u
  !insertmacro DRIVE_OPTION 9 134u
  !insertmacro DRIVE_OPTION 10 147u

  ${If} $DriveCount == 0
    MessageBox MB_ICONSTOP "No writable local fixed drive was found."
    Abort
  ${EndIf}

  ${NSD_CreateLabel} 0 166u 100% 18u ""
  Pop $InstallPathLabel
  ${If} $DriveSelected != ""
    StrCpy $INSTDIR "$DriveSelected\Nalia"
    ${NSD_SetText} $InstallPathLabel "Install location: $INSTDIR"
  ${EndIf}

  nsDialogs::Show
FunctionEnd

Function DriveRadioClick
  Pop $0
  nsDialogs::GetUserData $0
  Pop $DriveSelected
  StrCpy $INSTDIR "$DriveSelected\Nalia"
  ${NSD_SetText} $InstallPathLabel "Install location: $INSTDIR"
FunctionEnd

Function DrivePageLeave
  ${If} $DriveSelected == ""
    MessageBox MB_ICONEXCLAMATION "Choose a drive for Nalia."
    Abort
  ${EndIf}
  StrCpy $INSTDIR "$DriveSelected\Nalia"
FunctionEnd

Section "Install"
  InitPluginsDir
  File /oname=$PLUGINSDIR\check-latest-installer.ps1 "check-latest-installer.ps1"
  DetailPrint "Checking for the newest Nalia release..."
  nsExec::ExecToLog /TIMEOUT=900000 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$PLUGINSDIR\check-latest-installer.ps1" -CurrentVersion "${CURRENT_APP_VERSION}" -ReleaseRepo "FoxandMoss/Nalia-releases" -StableAssetName "Nalia-Windows-Installer.exe" -AppName "Nalia"'
  Pop $0
  ${If} $0 == "timeout"
    MessageBox MB_ICONSTOP "Nalia could not finish checking the newest release. Nothing has been installed yet."
    Abort
  ${ElseIf} $0 == 10
    DetailPrint "A newer Nalia installer was opened. Closing this older installer."
    Quit
  ${ElseIf} $0 == 20
    MessageBox MB_ICONSTOP "A newer Nalia release exists, but it could not be downloaded and verified safely. Nothing has been installed."
    Abort
  ${EndIf}

  InitPluginsDir
  File /oname=$PLUGINSDIR\cleanup-legacy.ps1 "cleanup-legacy.ps1"
  nsExec::ExecToLog 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$PLUGINSDIR\cleanup-legacy.ps1" -App "Nalia" -KeepInstallDir "$INSTDIR"'

  SetOutPath "$INSTDIR"
  File /r "${STAGEDIR}\*.*"

  CreateDirectory "$INSTDIR\.foxmoss"
  SetOutPath "$INSTDIR\.foxmoss"
  File /oname=cleanup-legacy.ps1 "cleanup-legacy.ps1"
  File /oname=owned-files.json "owned-files.json"

  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\uninstall.exe"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Nalia" "DisplayName" "Nalia"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Nalia" "DisplayVersion" "0.1.0.1"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Nalia" "Publisher" "Fox & Moss"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Nalia" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Nalia" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Nalia" "DisplayIcon" "$INSTDIR\nalia.exe"

  CreateDirectory "$SMPROGRAMS\Fox & Moss"
  CreateShortcut "$SMPROGRAMS\Fox & Moss\Nalia.lnk" "$INSTDIR\nalia.exe"
SectionEnd

Section "Uninstall"
  nsExec::ExecToLog 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$INSTDIR\.foxmoss\cleanup-legacy.ps1" -App "Nalia" -KeepInstallDir ""'
  Delete "$SMPROGRAMS\Fox & Moss\Nalia.lnk"
  RMDir "$SMPROGRAMS\Fox & Moss"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\Nalia"
  InitPluginsDir
  File /oname=$PLUGINSDIR\remove-owned-files.ps1 "remove-owned-files.ps1"
  nsExec::ExecToLog 'powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "$PLUGINSDIR\remove-owned-files.ps1" -InstallDir "$INSTDIR" -ManifestPath "$INSTDIR\.foxmoss\owned-files.json"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "Nalia could not safely remove its owned files. User files were preserved."
    Abort
  ${EndIf}
  RMDir "$INSTDIR"
SectionEnd
