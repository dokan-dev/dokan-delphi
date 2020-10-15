(*
  Dokan API wrapper for Delphi based on Release 1.4.0.1000
  https://github.com/dokan-dev/dokany/releases/tag/v1.4.0.1000
  Copyright (C) 2019 - 2020 Sven Harazim

  Dokan : user-mode file system library for Windows

  Copyright (C) 2015 - 2019 Adrien J. <liryna.stark@gmail.com> and Maxime C. <maxime@islog.com>
  Copyright (C) 2020 Google, Inc.
  Copyright (C) 2007 - 2011 Hiroki Asakawa <info@dokan-dev.net>

  http://dokan-dev.github.io

  This program is free software; you can redistribute it and/or modify it under
  the terms of the GNU Lesser General Public License as published by the Free
  Software Foundation; either version 3 of the License, or (at your option) any
  later version.

  This program is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU Lesser General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.
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

const
  DokanLibrary = 'dokan1.dll';

  //The current Dokan version (ver 1.4.0)
  DOKAN_VERSION = 140;
  //Minimum Dokan version (ver 1.1.0) accepted
  DOKAN_MINIMUM_COMPATIBLE_VERSION = 110;

  //Enable ouput debug message
  DOKAN_OPTION_DEBUG = 1;
  //Enable ouput debug message to stderr
  DOKAN_OPTION_STDERR = 2;
  //Enable the use of alternate stream paths in the form
  //<file-name>:<stream-name>. If this is not specified then the driver will
  //fail any attempt to access a path with a colon.
  DOKAN_OPTION_ALT_STREAM = 4;
  //Enable mount drive as write-protected
  DOKAN_OPTION_WRITE_PROTECT = 8;
  //Use network drive - Dokan network provider needs to be installed
  DOKAN_OPTION_NETWORK = 16;
  //Use removable drive
  DOKAN_OPTION_REMOVABLE = 32;
  //Use mount manager
  DOKAN_OPTION_MOUNT_MANAGER = 64;
  //Mount the drive on current session only
  DOKAN_OPTION_CURRENT_SESSION = 128;
  //Enable Lockfile/Unlockfile operations. Otherwise Dokan will take care of it
  DOKAN_OPTION_FILELOCK_USER_MODE = 256;
  //Whether DokanNotifyXXX functions should be enabled, which requires this
  //library to maintain a special handle while the file system is mounted.
  //Without this flag, the functions always return FALSE if invoked.
  DOKAN_OPTION_ENABLE_NOTIFICATION_API = 512;
  //Whether to disable any oplock support on the volume.
  //Regular range locks are enabled regardless.
  DOKAN_OPTION_DISABLE_OPLOCKS = 1024;
  //The advantage of the FCB GC approach is that it prevents filter drivers (Anti-virus)
  //from exponentially slowing down procedures like zip file extraction due to
  //repeatedly rebuilding state that they attach to the FCB header.
  DOKAN_OPTION_ENABLE_FCB_GARBAGE_COLLECTION = 2048;

type
  //Dokan mount options used to describe Dokan device behavior.
  _DOKAN_OPTIONS = record
    Version: USHORT;          //Version of the Dokan features requested without dots (version "123" is equal to Dokan version 1.2.3).
    ThreadCount: USHORT;      //Number of threads to be used by Dokan library internally. More threads will handle more events at the same time.
    Options: ULONG;           //Features enabled for the mount. See \ref DOKAN_OPTION.
    GlobalContext: ULONG64;   //FileSystem can store anything here.
    MountPoint: LPCWSTR;      //Mount point. It can be a driver letter like "M:\" or a folder path "C:\mount\dokan" on a NTFS partition.
    UNCName: LPCWSTR;         //UNC Name for the Network Redirector
    Timeout: ULONG;           //Max timeout in milliseconds of each request before Dokan gives up to wait events to complete.
    AllocationUnitSize: ULONG;//Allocation Unit Size of the volume. This will affect the file size.
    SectorSize: ULONG;        //Sector Size of the volume. This will affect the file size.
  end;
  DOKAN_OPTIONS = _DOKAN_OPTIONS;
  PDOKAN_OPTIONS = ^_DOKAN_OPTIONS;
  TDokanOptions = DOKAN_OPTIONS;
  PDokanOptions = PDOKAN_OPTIONS;

  //Dokan file information on the current operation.
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

  //FillFindData Used to add an entry in FindFiles operation
  //return 1 if buffer is full, otherwise 0 (currently it never returns 1)
  TDokanFillFindData = function (
    var FindData: WIN32_FIND_DATAW;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): Integer; stdcall;

  //FillFindStreamData Used to add an entry in FindStreams
  //return 1 if buffer is full, otherwise 0 (currently it never returns 1)
  TDokanFillFindStreamData = function (
    var FindStreamData: WIN32_FIND_STREAM_DATA;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): Integer; stdcall;

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
  DokanIsNameInExpression: function (Expression, Name: LPCWSTR; IgnoreCase: BOOL): BOOL; stdcall = nil;
  DokanVersion: function (): ULONG; stdcall = nil;
  DokanDriverVersion: function (): ULONG; stdcall = nil;
  DokanResetTimeout: function (Timeout: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): BOOL; stdcall = nil;
  DokanOpenRequestorToken: function (var DokanFileInfo: DOKAN_FILE_INFO): THandle; stdcall = nil;
  DokanGetMountPointList: function (uncOnly: BOOL; var nbRead: ULONG): PDOKAN_CONTROL; stdcall = nil;
  DokanReleaseMountPointList: procedure (list: PDOKAN_CONTROL); stdcall = nil;
  DokanMapKernelToUserCreateFileFlags: procedure (DesiredAccess: ACCESS_MASK; FileAttributes, CreateOptions,
    CreateDisposition: ULONG;outDesiredAccess: PACCESS_MASK; outFileAttributesAndFlags,
    outCreationDisposition: PDWORD); stdcall = nil;
  DokanNotifyCreate: function (FilePath: LPCWSTR; IsDirectory : BOOL) : BOOL;
  DokanNotifyDelete: function (FilePath : LPCWSTR; BOOL IsDirectory) : BOOL;
  DokanNotifyUpdate: function (FilePath : LPCWSTR) : BOOL;
  DokanNotifyXAttrUpdate: function (FilePath : LPCWSTR) : BOOL;
  DokanNotifyRename: function (OldPath: LPCWSTR; NewPath : LPCWSTR; IsDirectory : BOOL;
    IsInSameDirectory: BOOL) : BOOL;
  DokanNtStatusFromWin32: function (Error: DWORD): NTSTATUS; stdcall = nil;

function DokanLoad(const LibFileName: string = DokanLibrary): Boolean;
procedure DokanFree();

{$else DOKAN_EXPLICIT_LINK}

function DokanMain(var Options: DOKAN_OPTIONS; var Operations: DOKAN_OPERATIONS): Integer; stdcall;
function DokanUnmount(DriveLetter: WCHAR): BOOL; stdcall;
function DokanRemoveMountPoint(MountPoint: LPCWSTR): BOOL; stdcall;
function DokanIsNameInExpression(Expression, Name: LPCWSTR; IgnoreCase: BOOL): BOOL; stdcall;
function DokanVersion(): ULONG; stdcall;
function DokanDriverVersion(): ULONG; stdcall;
function DokanResetTimeout(Timeout: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): BOOL; stdcall;
function DokanOpenRequestorToken(var DokanFileInfo: DOKAN_FILE_INFO): THandle; stdcall;
function DokanGetMountPointList(uncOnly: BOOL; var nbRead: ULONG): PDOKAN_CONTROL; stdcall;
procedure DokanReleaseMountPointList(list: PDOKAN_CONTROL);
procedure DokanMapKernelToUserCreateFileFlags(DesiredAccess: ACCESS_MASK; FileAttributes, CreateOptions,
  CreateDisposition: ULONG; outDesiredAccess: PACCESS_MASK; outFileAttributesAndFlags,
  outCreationDisposition: PDWORD); stdcall;
function DokanNotifyCreate(FilePath: LPCWSTR; IsDirectory : BOOL) : BOOL; stdcall;
function DokanNotifyDelete(FilePath : LPCWSTR; IsDirectory : BOOL) : BOOL; stdcall;
function DokanNotifyUpdate(FilePath : LPCWSTR) : BOOL; stdcall;
function DokanNotifyXAttrUpdate(FilePath : LPCWSTR) : BOOL; stdcall;
function DokanNotifyRename(OldPath: LPCWSTR; NewPath : LPCWSTR; IsDirectory : BOOL;
  IsInSameDirectory: BOOL) : BOOL; stdcall;
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
  DokanReleaseMountPointList := GetProc('DokanReleaseMountPointList');
  DokanMapKernelToUserCreateFileFlags := GetProc('DokanMapKernelToUserCreateFileFlags');
  DokanNotifyCreate := GetProc('DokanNotifyCreate');
  DokanNotifyDelete := GetProc('DokanNotifyDelete');
  DokanNotifyUpdate := GetProc('DokanNotifyUpdate');
  DokanNotifyXAttrUpdate := GetProc('DokanNotifyXAttrUpdate');
  DokanNotifyRename := GetProc('DokanNotifyRename');
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
  DokanReleaseMountPointList := nil;
  DokanMapKernelToUserCreateFileFlags := nil;
  DokanNotifyCreate := nil;
  DokanNotifyDelete := nil;
  DokanNotifyUpdate := nil;
  DokanNotifyXAttrUpdate := nil;
  DokanNotifyRename := nil;
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
procedure DokanReleaseMountPointList; external DokanLibrary;
procedure DokanMapKernelToUserCreateFileFlags; external DokanLibrary;
function DokanNotifyCreate; external DokanLibrary;
function DokanNotifyDelete; external DokanLibrary;
function DokanNotifyUpdate; external DokanLibrary;
function DokanNotifyXAttrUpdate; external DokanLibrary;
function DokanNotifyRename; external DokanLibrary;
function DokanNtStatusFromWin32; external DokanLibrary;

{$endif DOKAN_EXPLICIT_LINK}

initialization

finalization

{$ifdef DOKAN_EXPLICIT_LINK}
  DokanFree();
{$endif DOKAN_EXPLICIT_LINK}

end.
