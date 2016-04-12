(*
  Dokan : user-mode file system library for Windows

  Copyright (C) 2015 - 2016 Adrien J. <liryna.stark@gmail.com> and Maxime C. <maxime@islog.com>
  Copyright (C) 2007 - 2011 Hiroki Asakawa <info@dokan-dev.net>

  http://dokan-dev.github.io

  Delphi header translation by Vincent Forman (vincent.forman@gmail.com)

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
{$endif}

interface

uses
  Windows,
  DokanWin;

const
  DokanLibrary = 'dokan1.dll';

  // The current Dokan version (ver 1.0.0). Please set this constant on
  // DokanOptions->Version.
  DOKAN_VERSION = 100;
  DOKAN_MINIMUM_COMPATIBLE_VERSION = 100;

  DOKAN_MAX_INSTANCES        = 32;  // Maximum number of dokan instances

  DOKAN_OPTION_DEBUG         = 1;   // ouput debug message
  DOKAN_OPTION_STDERR        = 2;   // ouput debug message to stderr
  DOKAN_OPTION_ALT_STREAM    = 4;   // use alternate stream
  DOKAN_OPTION_WRITE_PROTECT = 8;   // mount drive as write-protected.
  DOKAN_OPTION_NETWORK       = 16;  // use network drive, you need to
                                    // install Dokan network provider.
  DOKAN_OPTION_REMOVABLE     = 32;  // use removable drive
  DOKAN_OPTION_MOUNT_MANAGER = 64;  // use mount manager
  DOKAN_OPTION_CURRENT_SESSION=128; // mount the drive on current session only

type
  _DOKAN_ACCESS_STATE = packed record
    SecurityEvaluated:       ByteBool;
    GenerateAudit:           ByteBool;
    GenerateOnClose:         ByteBool;
    AuditPrivileges:         ByteBool;
    Flags:                   ULONG;
    RemainingDesiredAccess:  ACCESS_MASK;
    PreviouslyGrantedAccess: ACCESS_MASK;
    OriginalDesiredAccess:   ACCESS_MASK;
    SecurityDescriptor:      PSECURITY_DESCRIPTOR;
    ObjectName:              UNICODE_STRING;
    ObjectType:              UNICODE_STRING;
  end;
  DOKAN_ACCESS_STATE = _DOKAN_ACCESS_STATE;
  PDOKAN_ACCESS_STATE = ^_DOKAN_ACCESS_STATE;
  TDokanAccessState = DOKAN_ACCESS_STATE;
  PDokanAccessState = PDOKAN_ACCESS_STATE;

  _DOKAN_IO_SECURITY_CONTEXT = packed record
    AccessState:   DOKAN_ACCESS_STATE;
    DesiredAccess: ACCESS_MASK;
  end;
  DOKAN_IO_SECURITY_CONTEXT = _DOKAN_IO_SECURITY_CONTEXT;
  PDOKAN_IO_SECURITY_CONTEXT = ^_DOKAN_IO_SECURITY_CONTEXT;
  TDokanIOSecurityContext = DOKAN_IO_SECURITY_CONTEXT;
  PDokanIOSecurityContext = PDOKAN_IO_SECURITY_CONTEXT;

  _DOKAN_OPTIONS = packed record
    Version:       USHORT;   // Supported Dokan Version, ex. "530" (Dokan ver 0.5.3)
    ThreadCount:   USHORT;   // number of threads to be
                             // used internally by Dokan library
    Options:       ULONG;    // combination of DOKAN_OPTIONS_*
    GlobalContext: ULONG64;  // FileSystem can store anything here
    MountPoint:    LPCWSTR;  // mount point "M:\" (drive letter) or "C:\mount\dokan"
                             // (path in NTFS)
    UNCName:       LPCWSTR;  // UNC provider name
    Timeout:       ULONG;    // IrpTimeout in milliseconds
    AllocationUnitSize: ULONG;// Device allocation size
    SectorSize:    ULONG;    // Device sector size
  end;
  DOKAN_OPTIONS = _DOKAN_OPTIONS;
  PDOKAN_OPTIONS = ^_DOKAN_OPTIONS;
  TDokanOptions = DOKAN_OPTIONS;
  PDokanOptions = PDOKAN_OPTIONS;

  _DOKAN_FILE_INFO = packed record
    Context:          ULONG64;         // FileSystem can store anything here
    DokanContext:     ULONG64;         // Used internally, never modify
    DokanOptions:     PDOKAN_OPTIONS;  // A pointer to DOKAN_OPTIONS
                                       // which was passed to DokanMain.
    ProcessId:        ULONG;           // process id for the thread that originally requested a
                                       // given I/O operation
    IsDirectory:      ByteBool;        // requesting a directory file
    DeleteOnClose:    ByteBool;        // Delete on when "cleanup" is called
    PagingIo:         ByteBool;        // Read or write is paging IO.
    SynchronousIo:    ByteBool;        // Read or write is synchronous IO.
    Nocache:          ByteBool;
    WriteToEndOfFile: ByteBool;        // If true, write to the current end of file instead
                                       // of Offset parameter.
  end;
  DOKAN_FILE_INFO = _DOKAN_FILE_INFO;
  PDOKAN_FILE_INFO = ^_DOKAN_FILE_INFO;
  TDokanFileInfo = DOKAN_FILE_INFO;
  PDokanFileInfo = PDOKAN_FILE_INFO;

  // FillFindData
  //   is used to add an entry in FindFiles
  //   returns 1 if buffer is full, otherwise 0
  //   (currently it never returns 1)
  TDokanFillFindData = function(
    var FindData:      WIN32_FIND_DATAW;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): Integer; stdcall;

  // FillFindStreamData
  //   is used to add an entry in FindStreams
  //   returns 1 if buffer is full, otherwise 0
  //   (currently it never returns 1)
  TDokanFillFindStreamData = function(
    var FindStreamData: WIN32_FIND_STREAM_DATA;
    var DokanFileInfo:  DOKAN_FILE_INFO
  ): Integer; stdcall;

  // When an error occurs, return NTSTATUS
  // (https://support.microsoft.com/en-us/kb/113996)

  // CreateFile
  //   In case OPEN_ALWAYS & CREATE_ALWAYS are opening successfully a already
  //   existing file,
  //   you have to SetLastError(ERROR_ALREADY_EXISTS)
  //   If file is a directory, CreateFile (not OpenDirectory) may be called.
  //   In this case, CreateFile should return STATUS_SUCCESS when that directory
  //   can be opened.
  //   You should set TRUE on DokanFileInfo->IsDirectory when file is a
  //   directory.
  //   See ZwCreateFile()
  //   https://msdn.microsoft.com/en-us/library/windows/hardware/ff566424(v=vs.85).aspx
  //   for more information about the parameters of this callback.
  TDokanZwCreateFile = function(
    FileName:            LPCWSTR;
    var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;  // see
    // https://msdn.microsoft.com/en-us/library/windows/hardware/ff550613(v=vs.85).aspx
    DesiredAccess:       ACCESS_MASK;
    FileAttributes:      ULONG;
    ShareAccess:         ULONG;
    CreateDisposition:   ULONG;
    CreateOptions:       ULONG;
    var DokanFileInfo:   DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // When FileInfo->DeleteOnClose is true, you must delete the file in Cleanup.
  // Refer to comment at DeleteFile definition below in this file for
  // explanation.
  TDokanCleanup = procedure(
    FileName:          LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ); stdcall;

  TDokanCloseFile = procedure(
    FileName:          LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ); stdcall;

  // ReadFile and WriteFile can be called from multiple threads in
  // the same time with the same DOKAN_FILE_INFO.Context if a OVERLAPPED is
  // requested.
  TDokanReadFile = function(
    FileName:              LPCWSTR;
    var Buffer;
    NumberOfBytesToRead:   DWORD;
    var NumberOfBytesRead: DWORD;
    Offset:                LONGLONG;
    var DokanFileInfo:     DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanWriteFile = function(
    FileName:                 LPCWSTR;
    var Buffer;
    NumberOfBytesToWrite:     DWORD;
    var NumberOfBytesWritten: DWORD;
    Offset:                   LONGLONG;
    var DokanFileInfo:        DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanFlushFileBuffers = function(
    FileName:          LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanGetFileInformation = function(
    FileName:            LPCWSTR;
    var FileInformation: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo:   DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // FindFilesWithPattern is checking first. If it is not implemented or
  // returns STATUS_NOT_IMPLEMENTED, then FindFiles is called, if implemented.
  TDokanFindFiles = function(
    PathName:          LPCWSTR;
    FillFindData:      TDokanFillFindData;  // call this function with PWIN32_FIND_DATAW
    var DokanFileInfo: DOKAN_FILE_INFO      //  (see PFillFindData definition)
  ): NTSTATUS; stdcall;

  TDokanFindFilesWithPattern = function(
    PathName:          LPCWSTR;
    SearchPattern:     LPCWSTR;
    FillFindData:      TDokanFillFindData;  // call this function with PWIN32_FIND_DATAW
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // SetFileAttributes and SetFileTime are called only if both of them
  // are implemented.
  TDokanSetFileAttributes = function(
    FileName:          LPCWSTR;
    FileAttributes:    DWORD;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetFileTime = function(
    FileName:          LPCWSTR;
    CreationTime:      PFILETIME;
    LastAccessTime:    PFILETIME;
    LastWriteTime:     PFILETIME;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // You should not delete the file on DeleteFile or DeleteDirectory, but
  // instead
  // you must only check whether you can delete the file or not,
  // and return STATUS_SUCCESS (when you can delete it) or appropriate error
  // codes such as
  // STATUS_ACCESS_DENIED, STATUS_OBJECT_PATH_NOT_FOUND,
  // STATUS_OBJECT_NAME_NOT_FOUND.
  // When you return STATUS_SUCCESS, you get a Cleanup call afterwards with
  // FileInfo->DeleteOnClose set to TRUE and only then you have to actually
  // delete the file being closed.
  TDokanDeleteFile = function(
    FileName:          LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanDeleteDirectory = function(
    FileName:          LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanMoveFile = function(
    ExistingFileName:  LPCWSTR;
    NewFileName:       LPCWSTR;
    ReplaceExisiting:  BOOL;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetEndOfFile = function(
    FileName:          LPCWSTR;
    Length:            LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetAllocationSize = function(
    FileName:          LPCWSTR;
    Length:            LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanLockFile = function(
    FileName:          LPCWSTR;
    ByteOffset:        LONGLONG;
    Length:            LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanUnlockFile = function(
    FileName:          LPCWSTR;
    ByteOffset:        LONGLONG;
    Length:            LONGLONG;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // Neither GetDiskFreeSpace nor GetVolumeInformation
  // save the DokanFileContext->Context.
  // Before these methods are called, CreateFile may not be called.
  // (ditto CloseFile and Cleanup)

  // see Win32 API GetDiskFreeSpaceEx
  TDokanGetDiskFreeSpace = function(
    var FreeBytesAvailable:     ULONGLONG;
    var TotalNumberOfBytes:     ULONGLONG;
    var TotalNumberOfFreeBytes: ULONGLONG;
    var DokanFileInfo:          DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // Note:
  // FILE_READ_ONLY_VOLUME is automatically added to the
  // FileSystemFlags if DOKAN_OPTION_WRITE_PROTECT was
  // specified in DOKAN_OPTIONS when the volume was mounted.

  // see Win32 API GetVolumeInformation
  TDokanGetVolumeInformation = function(
    VolumeNameBuffer:           LPWSTR;
    VolumeNameSize:             DWORD;  // in num of chars
    var VolumeSerialNumber:     DWORD;
    var MaximumComponentLength: DWORD;  // in num of chars
    var FileSystemFlags:        DWORD;
    FileSystemNameBuffer:       LPWSTR;
    FileSystemNameSize:         DWORD;  // in num of chars
    var DokanFileInfo:          DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanMounted = function(
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanUnmounted = function(
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // Suported since 0.6.0. You must specify the version at
  // DOKAN_OPTIONS.Version.
  TDokanGetFileSecurity = function(
    FileName:                 LPCWSTR;
    var SecurityInformation:  SECURITY_INFORMATION;  // A pointer to SECURITY_INFORMATION value being
                                                     // requested
    var SecurityDescriptor:   SECURITY_DESCRIPTOR;   // A pointer to SECURITY_DESCRIPTOR buffer to be filled
    SecurityDescriptorLength: ULONG;                 // length of Security descriptor buffer
    var LengthNeeded:         ULONG;
    var DokanFileInfo:        DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  TDokanSetFileSecurity = function(
    FileName:                 LPCWSTR;
    var SecurityInformation:  SECURITY_INFORMATION;
    var SecurityDescriptor:   SECURITY_DESCRIPTOR;
    SecurityDescriptorLength: ULONG;
    var DokanFileInfo:        DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

  // Supported since 0.8.0. You must specify the version at
  // DOKAN_OPTIONS.Version.
  TDokanFindStreams = function(
    FileName:           LPCWSTR;
    FillFindStreamData: TDokanFillFindStreamData;  // call this function with PWIN32_FIND_STREAM_DATA
    var DokanFileInfo:  DOKAN_FILE_INFO            //  (see PFillFindStreamData definition)
  ): NTSTATUS; stdcall;

  _DOKAN_OPERATIONS = packed record
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
    GetVolumeInformation:TDokanGetVolumeInformation;
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

//TODO
//typedef struct _DOKAN_CONTROL {
//  ULONG Type;
//  WCHAR MountPoint[MAX_PATH];
//  WCHAR UNCName[64];
//  WCHAR DeviceName[64];
//  PVOID DeviceObject;
//} DOKAN_CONTROL, *PDOKAN_CONTROL;

(* DokanMain returns error codes *)
const
  DOKAN_SUCCESS              =  0;
  DOKAN_ERROR                = -1;  (* General Error *)
  DOKAN_DRIVE_LETTER_ERROR   = -2;  (* Bad Drive letter *)
  DOKAN_DRIVER_INSTALL_ERROR = -3;  (* Can't install driver *)
  DOKAN_START_ERROR          = -4;  (* Driver something wrong *)
  DOKAN_MOUNT_ERROR          = -5;  (* Can't assign a drive letter or mount point *)
  DOKAN_MOUNT_POINT_ERROR    = -6;  (* Mountpoint is invalid *)
  DOKAN_VERSION_ERROR        = -7;  (* Requested an incompatible version *)

function DokanMain(
  var Options:    DOKAN_OPTIONS;
  var Operations: DOKAN_OPERATIONS
): Integer; stdcall;

function DokanUnmount(
  DriveLetter: WCHAR
): BOOL; stdcall;

function DokanRemoveMountPoint(
  MountPoint: LPCWSTR
): BOOL; stdcall;

// DokanIsNameInExpression
//   checks whether Name can match Expression
//   Expression can contain wildcard characters (? and *)
function DokanIsNameInExpression(
  Expression: LPCWSTR;  // matching pattern
  Name:       LPCWSTR;  // file name
  IgnoreCase: BOOL
): BOOL; stdcall;

function DokanVersion(
): ULONG; stdcall;

function DokanDriverVersion(
): ULONG; stdcall;

// DokanResetTimeout
//   extends the time out of the current IO operation in driver.
function DokanResetTimeout(
  Timeout:           ULONG;  // timeout in millisecond
  var DokanFileInfo: DOKAN_FILE_INFO
): BOOL; stdcall;

// Get the handle to Access Token
// This method needs be called in CreateFile, OpenDirectory or CreateDirectly
// callback.
// The caller must call CloseHandle for the returned handle.
function DokanOpenRequestorToken(
  var DokanFileInfo: DOKAN_FILE_INFO
): THandle; stdcall;

//TODO
//function DokanGetMountPointList(
//  PDOKAN_CONTROL list, ULONG length,
//                                     BOOL uncOnly, PULONG nbRead
//): BOOL; stdcall;

procedure DokanMapKernelToUserCreateFileFlags(
  FileAttributes:            ULONG;
  CreateOptions:             ULONG;
  CreateDisposition:         ULONG;
  outFileAttributesAndFlags: PDWORD;
  outCreationDisposition:    PDWORD
); stdcall;

implementation

function DokanMain; external DokanLibrary;
function DokanUnmount; external DokanLibrary;
function DokanRemoveMountPoint; external DokanLibrary;
function DokanIsNameInExpression; external DokanLibrary;
function DokanVersion; external DokanLibrary;
function DokanDriverVersion; external DokanLibrary;
function DokanResetTimeout; external DokanLibrary;
function DokanOpenRequestorToken; external DokanLibrary;
procedure DokanMapKernelToUserCreateFileFlags; external DokanLibrary;

end.
