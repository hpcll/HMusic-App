#ifndef AppVersion
#define AppVersion "0.0.0"
#endif

#ifndef SourceDir
#define SourceDir "..\build\windows\x64\runner\Release"
#endif

#ifndef OutputDir
#define OutputDir "..\dist"
#endif

#ifndef IconFile
#define IconFile "..\windows\runner\resources\app_icon.ico"
#endif

#ifndef LanguageFile
#define LanguageFile "ChineseSimplified.isl"
#endif

#define AppName "HMusic"
#define AppPublisher "HMusic"
#define AppExeName "hmusic.exe"

[Setup]
AppId={{E2B6B8BC-2E55-4C20-8E50-9D0E7C0D9E1A}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=https://github.com/hpcll/HMusic-App
AppSupportURL=https://github.com/hpcll/HMusic-App/issues
LicenseFile=..\LICENSE
DefaultDirName={localappdata}\Programs\HMusic
DefaultGroupName=HMusic
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=hmusic-{#AppVersion}-windows-x64-setup
SetupIconFile={#IconFile}
UninstallDisplayIcon={app}\{#AppExeName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
Uninstallable=yes
VersionInfoVersion={#AppVersion}
VersionInfoDescription=HMusic 安装程序

[Languages]
Name: "chinesesimp"; MessagesFile: "{#LanguageFile}"

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加快捷方式:"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\HMusic"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"
Name: "{autodesktop}\HMusic"; Filename: "{app}\{#AppExeName}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "启动 HMusic"; Flags: nowait postinstall skipifsilent
