// Release 1.2.0.1000
// commit: f6de99b914b8f858acf940073ae8836eb476de7f

(*
  Dokan : user-mode file system library for Windows

  Copyright (C) 2015 - 2018 Adrien J. <liryna.stark@gmail.com> and Maxime C. <maxime@islog.com>
  Copyright (C) 2007 - 2011 Hiroki Asakawa <info@dokan-dev.net>

  https://dokan-dev.github.io/

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*)

unit Dokan;

{$ifdef FPC}
  {$mode delphi}
{$endif FPC}

{$align 8}
{$minenumsize 4}

interface

uses
  Windows, DokanWin;

{$ifndef FPC}
type
  ULONGLONG = UInt64;
  //LPCWSTR=pwidechar;
{$endif}  

const
  DokanLibrary = 'dokan1.dll';

  //The current Dokan version (ver 1.2.0)
  DOKAN_VERSION = 120;
  //Minimum Dokan version (ver 1.1.0) accepted
  DOKAN_MINIMUM_COMPATIBLE_VERSION = 110;
  DOKAN_MAX_INSTANCES = 32;

  DOKAN_OPTION_DEBUG = 1;                //Enable ouput debug message
  DOKAN_OPTION_STDERR = 2;               //Enable ouput debug message to stderr
  DOKAN_OPTION_ALT_STREAM = 4;           //Use alternate stream
  DOKAN_OPTION_WRITE_PROTECT = 8;        //Enable mount drive as write-protected
  DOKAN_OPTION_NETWORK = 16;             //Use network drive - Dokan network provider needs to be installed
  DOKAN_OPTION_REMOVABLE = 32;           //Use removable drive
  DOKAN_OPTION_MOUNT_MANAGER = 64;       //Use mount manager
  DOKAN_OPTION_CURRENT_SESSION = 128;    //Mount the drive on current session only
  DOKAN_OPTION_FILELOCK_USER_MODE = 256; //Enable Lockfile/Unlockfile operations. Otherwise Dokan will take care of it


type
  _DOKAN_ACCESS_STATE = record
    SecurityEvaluated: ByteBool;
    GenerateAudit: ByteBool;
    GenerateOnClose: ByteBool;
    AuditPrivileges: ByteBool;
    Flags: ULONG;
    RemainingDesiredAccess: ACCESS_MASK;
    PreviouslyGrantedAccess: ACCESS_MASK;
    OriginalDesiredAccess: ACCESS_MASK;
    SecurityDescriptor: PSECURITY_DESCRIPTOR;
    ObjectName: UNICODE_STRING;
    ObjectType: UNICODE_STRING;
  end;
  DOKAN_ACCESS_STATE = _DOKAN_ACCESS_STATE;
  PDOKAN_ACCESS_STATE = ^_DOKAN_ACCESS_STATE;
  TDokanAccessState = DOKAN_ACCESS_STATE;
  PDokanAccessState = PDOKAN_ACCESS_STATE;

  _DOKAN_IO_SECURITY_CONTEXT = record
    AccessState: DOKAN_ACCESS_STATE;
    DesiredAccess: ACCESS_MASK;
  end;
  DOKAN_IO_SECURITY_CONTEXT = _DOKAN_IO_SECURITY_CONTEXT;
  PDOKAN_IO_SECURITY_CONTEXT = ^_DOKAN_IO_SECURITY_CONTEXT;
  TDokanIOSecurityContext = DOKAN_IO_SECURITY_CONTEXT;
  PDokanIOSecurityContext = PDOKAN_IO_SECURITY_CONTEXT;

  _DOKAN_OPTIONS = record
    Version: USHORT;
    ThreadCount: USHORT;
    Options: ULONG;
    GlobalContext: ULONG64;
    MountPoint: LPCWSTR;
    UNCName: LPCWSTR;
    Timeout: ULONG;
    AllocationUnitSize: ULONG;
    SectorSize: ULONG;
  end;
  DOKAN_OPTIONS = _DOKAN_OPTIONS;
  PDOKAN_OPTIONS = ^_DOKAN_OPTIONS;
  TDokanOptions = DOKAN_OPTIONS;
  PDokanOptions = PDOKAN_OPTIONS;

  _DOKAN_FILE_INFO = record
    Context: ULONG64;
    DokanContext: ULONG64;
    DokanOptions: PDOKAN_OPTIONS;
    ProcessId: ULONG;
    IsDirectory: ByteBool;
    DeleteOnClose: ByteBool;
    PagingIo: ByteBool;
    SynchronousIo: ByteBool;
    Nocache: ByteBool;
    WriteToEndOfFile: ByteBool;
  end;
  DOKAN_FILE_INFO = _DOKAN_FILE_INFO;
  PDOKAN_FILE_INFO = ^_DOKAN_FILE_INFO;
  TDokanFileInfo = DOKAN_FILE_INFO;
  PDokanFileInfo = PDOKAN_FILE_INFO;

  TDokanFillFindData = function (
    var FindData: WIN32_FIND_DATAW;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): Integer; stdcall;

  TDokanFillFindStreamData = function (
    var FindStreamData: WIN32_FIND_STREAM_DATA;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): Integer; stdcall;

  TDokanZwCreateFile = function (
    FileName: LPCWSTR;
    var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;
    DesiredAccess: ACCESS_MASK;
    FileAttributes: ULONG;
    ShareAccess: ULONG;
    CreateDisposition: ULONG;
    CreateOptions: ULONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanCleanup = procedure (
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ); stdcall;

  TDokanCloseFile = procedure (
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ); stdcall;

  TDokanReadFile = function (
    FileName: LPCWSTR;
    var Buffer;
    BufferLength: DWORD;
    var ReadLength: DWORD;
    Offset: LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanWriteFile = function (
    FileName: LPCWSTR;
    const Buffer;
    NumberOfBytesToWrite: DWORD;
    var NumberOfBytesWritten: DWORD;
    Offset: LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanFlushFileBuffers = function (
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanGetFileInformation = function (
    FileName: LPCWSTR;
    var Buffer: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanFindFiles = function (
    PathName: LPCWSTR;
    FillFindData: TDokanFillFindData;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanFindFilesWithPattern = function (
    PathName: LPCWSTR;
    SearchPattern: LPCWSTR;
    FillFindData: TDokanFillFindData;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetFileAttributes = function (
    FileName: LPCWSTR;
    FileAttributes: DWORD;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetFileTime = function (
    FileName: LPCWSTR;
    var CreationTime: FILETIME;
    var LastAccessTime: FILETIME;
    var LastWriteTime: FILETIME;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanDeleteFile = function (
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanDeleteDirectory = function (
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanMoveFile = function (
    FileName: LPCWSTR;
    NewFileName: LPCWSTR;
    ReplaceIfExisting: BOOL;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetEndOfFile = function (
    FileName: LPCWSTR;
    ByteOffset: LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetAllocationSize = function (
    FileName: LPCWSTR;
    AllocSize: LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanLockFile = function (
    FileName: LPCWSTR;
    ByteOffset: LONGLONG;
    Length: LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanUnlockFile = function (
    FileName: LPCWSTR;
    ByteOffset: LONGLONG;
    Length: LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanGetDiskFreeSpace = function (
    var FreeBytesAvailable: ULONGLONG;
    var TotalNumberOfBytes: ULONGLONG;
    var TotalNumberOfFreeBytes: ULONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanGetVolumeInformation = function (
    VolumeNameBuffer: LPWSTR;
    VolumeNameSize: DWORD;
    var VolumeSerialNumber: DWORD;
    var MaximumComponentLength: DWORD;
    var FileSystemFlags: DWORD;
    FileSystemNameBuffer: LPWSTR;
    FileSystemNameSize: DWORD;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanMounted = function (
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanUnmounted = function (
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanGetFileSecurity = function (
    FileName: LPCWSTR;
    var SecurityInformation: SECURITY_INFORMATION;
    SecurityDescriptor: PSECURITY_DESCRIPTOR;
    BufferLength: ULONG;
    var LengthNeeded: ULONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetFileSecurity = function (
    FileName: LPCWSTR;
    var SecurityInformation: SECURITY_INFORMATION;
    SecurityDescriptor: PSECURITY_DESCRIPTOR;
    BufferLength: ULONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanFindStreams = function (
    FileName: LPCWSTR;
    FillFindStreamData: TDokanFillFindStreamData;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  _DOKAN_OPERATIONS = record
    ZwCreateFile: TDokanZwCreateFile;
    Cleanup: TDokanCleanup;
    CloseFile: TDokanCloseFile;
    ReadFile: TDokanReadFile;
    WriteFile: TDokanWriteFile;
    FlushFileBuffers: TDokanFlushFileBuffers;
    GetFileInformation: TDokanGetFileInformation;
    FindFiles: TDokanFindFiles;
    FindFilesWithPattern: TDokanFindFilesWithPattern;
    SetFileAttributes: TDokanSetFileAttributes;
    SetFileTime: TDokanSetFileTime;
    DeleteFile: TDokanDeleteFile;
    DeleteDirectory: TDokanDeleteDirectory;
    MoveFile: TDokanMoveFile;
    SetEndOfFile: TDokanSetEndOfFile;
    SetAllocationSize: TDokanSetAllocationSize;
    LockFile: TDokanLockFile;
    UnlockFile: TDokanUnlockFile;
    GetDiskFreeSpace: TDokanGetDiskFreeSpace;
    GetVolumeInformation: TDokanGetVolumeInformation;
    Mounted: TDokanMounted;
    Unmounted: TDokanUnmounted;
    GetFileSecurity: TDokanGetFileSecurity;
    SetFileSecurity: TDokanSetFileSecurity;
    FindStreams: TDokanFindStreams;
  end;
  DOKAN_OPERATIONS = _DOKAN_OPERATIONS;
  PDOKAN_OPERATIONS = ^_DOKAN_OPERATIONS;
  TDokanOperations = DOKAN_OPERATIONS;
  PDokanOperations = PDOKAN_OPERATIONS;

  _DOKAN_CONTROL = record
    Type_: ULONG;
    MountPoint: array [0 .. MAX_PATH - 1] of WCHAR;
    UNCName: array [0 .. 63] of WCHAR;
    DeviceName: array [0 .. 63] of WCHAR;
    DeviceObject: Pointer;
  end;
  DOKAN_CONTROL = _DOKAN_CONTROL;
  PDOKAN_CONTROL = ^_DOKAN_CONTROL;
  TDokanControl = DOKAN_CONTROL;
  PDokanControl = PDOKAN_CONTROL;

const
  DOKAN_SUCCESS = 0;
  DOKAN_ERROR = -1;
  DOKAN_DRIVE_LETTER_ERROR = -2;
  DOKAN_DRIVER_INSTALL_ERROR = -3;
  DOKAN_START_ERROR = -4;
  DOKAN_MOUNT_ERROR = -5;
  DOKAN_MOUNT_POINT_ERROR = -6;
  DOKAN_VERSION_ERROR = -7;

{$ifdef DOKAN_EXPLICIT_LINK}

var
  DokanLibHandle: HMODULE = 0;
  DokanMain: function (var Options: DOKAN_OPTIONS; var Operations: DOKAN_OPERATIONS): Integer; stdcall = nil;
  DokanUnmount: function (DriveLetter: WCHAR): BOOL; stdcall = nil;
  DokanRemoveMountPoint: function (MountPoint: LPCWSTR): BOOL; stdcall = nil;
  //DokanRemoveMountPointEx: function (MountPoint: LPCWSTR; Safe: BOOL): BOOL; stdcall = nil;
  DokanIsNameInExpression: function (Expression, Name: LPCWSTR; IgnoreCase: BOOL): BOOL; stdcall = nil;
  DokanVersion: function (): ULONG; stdcall = nil;
  DokanDriverVersion: function (): ULONG; stdcall = nil;
  DokanResetTimeout: function (Timeout: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): BOOL; stdcall = nil;
  DokanOpenRequestorToken: function (var DokanFileInfo: DOKAN_FILE_INFO): THandle; stdcall = nil;
  DokanGetMountPointList: function (list: PDOKAN_CONTROL; length: ULONG; uncOnly: BOOL;
    var nbRead: ULONG): BOOL; stdcall = nil;
  DokanMapKernelToUserCreateFileFlags: procedure (
    DesiredAccess: ACCESS_MASK; FileAttributes, CreateOptions, CreateDisposition: ULONG;
    outDesiredAccess: PACCESS_MASK; outFileAttributesAndFlags, outCreationDisposition: PDWORD); stdcall = nil;
  DokanNtStatusFromWin32: function (Error: DWORD): NTSTATUS; stdcall = nil;

function DokanLoad(const LibFileName: string = DokanLibrary): Boolean;
procedure DokanFree();

{$else DOKAN_EXPLICIT_LINK}

function DokanMain(var Options: DOKAN_OPTIONS; var Operations: DOKAN_OPERATIONS): Integer; stdcall;
function DokanUnmount(DriveLetter: WCHAR): BOOL; stdcall;
function DokanRemoveMountPoint(MountPoint: LPCWSTR): BOOL; stdcall;
//function DokanRemoveMountPointEx(MountPoint: LPCWSTR; Safe: BOOL): BOOL; stdcall;
function DokanIsNameInExpression(Expression, Name: LPCWSTR; IgnoreCase: BOOL): BOOL; stdcall;
function DokanVersion(): ULONG; stdcall;
function DokanDriverVersion(): ULONG; stdcall;
function DokanResetTimeout(Timeout: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): BOOL; stdcall;
function DokanOpenRequestorToken(var DokanFileInfo: DOKAN_FILE_INFO): THandle; stdcall;
function DokanGetMountPointList(list: PDOKAN_CONTROL; length: ULONG; uncOnly: BOOL;
  var nbRead: ULONG): BOOL; stdcall;
procedure DokanMapKernelToUserCreateFileFlags(
  DesiredAccess: ACCESS_MASK; FileAttributes, CreateOptions, CreateDisposition: ULONG;
  outDesiredAccess: PACCESS_MASK; outFileAttributesAndFlags, outCreationDisposition: PDWORD); stdcall;
function DokanNtStatusFromWin32(Error: DWORD): NTSTATUS; stdcall;

{$endif DOKAN_EXPLICIT_LINK}

implementation

{$ifdef DOKAN_EXPLICIT_LINK}

function DokanLoad(const LibFileName: string = DokanLibrary): Boolean;
  function GetProc(const ProcName: string): Pointer;
  begin
    Result := GetProcAddress(DokanLibHandle, PChar(ProcName));
    if Result = nil then
      DokanLoad := False;
  end;
begin
  if DokanLibHandle <> 0 then begin
    Result := True;
    Exit;
  end;

  DokanLibHandle := LoadLibrary(PChar(LibFileName));
  if DokanLibHandle = 0 then begin
    Result := False;
    Exit;
  end;

  Result := True;

  DokanMain := GetProc('DokanMain');
  DokanUnmount := GetProc('DokanUnmount');
  DokanRemoveMountPoint := GetProc('DokanRemoveMountPoint');
  //DokanRemoveMountPointEx := GetProc('DokanRemoveMountPointEx');
  DokanIsNameInExpression := GetProc('DokanIsNameInExpression');
  DokanVersion := GetProc('DokanVersion');
  DokanDriverVersion := GetProc('DokanDriverVersion');
  DokanResetTimeout := GetProc('DokanResetTimeout');
  DokanOpenRequestorToken := GetProc('DokanOpenRequestorToken');
  DokanGetMountPointList := GetProc('DokanGetMountPointList');
  DokanMapKernelToUserCreateFileFlags := GetProc('DokanMapKernelToUserCreateFileFlags');
  DokanNtStatusFromWin32 := GetProc('DokanNtStatusFromWin32');

  if not Result then
    DokanFree();
end;

procedure DokanFree();
begin
  if DokanLibHandle = 0 then
    Exit;

  DokanMain := nil;
  DokanUnmount := nil;
  DokanRemoveMountPoint := nil;
  //DokanRemoveMountPointEx := nil;
  DokanIsNameInExpression := nil;
  DokanVersion := nil;
  DokanDriverVersion := nil;
  DokanResetTimeout := nil;
  DokanOpenRequestorToken := nil;
  DokanGetMountPointList := nil;
  DokanMapKernelToUserCreateFileFlags := nil;
  DokanNtStatusFromWin32 := nil;

  FreeLibrary(DokanLibHandle);
  DokanLibHandle := 0;
end;

{$else DOKAN_EXPLICIT_LINK}

function DokanMain; external DokanLibrary;
function DokanUnmount; external DokanLibrary;
function DokanRemoveMountPoint; external DokanLibrary;
//function DokanRemoveMountPointEx; external DokanLibrary;
function DokanIsNameInExpression; external DokanLibrary;
function DokanVersion; external DokanLibrary;
function DokanDriverVersion; external DokanLibrary;
function DokanResetTimeout; external DokanLibrary;
function DokanOpenRequestorToken; external DokanLibrary;
function DokanGetMountPointList; external DokanLibrary;
procedure DokanMapKernelToUserCreateFileFlags; external DokanLibrary;
function DokanNtStatusFromWin32; external DokanLibrary;

{$endif DOKAN_EXPLICIT_LINK}

initialization

finalization

{$ifdef DOKAN_EXPLICIT_LINK}
  DokanFree();
{$endif DOKAN_EXPLICIT_LINK}

end.
