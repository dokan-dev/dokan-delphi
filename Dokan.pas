(*******************************************************************************
 *
 *   Dokan : user-mode file system library for Windows
 *
 *   Copyright (C) 2008 Hiroki Asakawa info@dokan-dev.net
 *
 *   http://dokan-dev.net/en
 *
 *   Delphi header translation by Vincent Forman (vincent.forman@gmail.com)
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU Lesser General Public License as published by the Free
 * Software Foundation; either version 3 of the License, or (at your option) any
 * later version.

 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 *******************************************************************************)

unit Dokan;

interface

uses
  Windows;

const
  DokanLibrary = 'dokan.dll';

  DOKAN_VERSION	 =	730;

  DOKAN_OPTION_DEBUG    	=	1; // ouput debug message
  DOKAN_OPTION_STDERR	    =	2; // ouput debug message to stderr
  DOKAN_OPTION_ALT_STREAM	= 4; // use alternate stream
  DOKAN_OPTION_KEEP_ALIVE =	8; // use auto unmount
  DOKAN_OPTION_NETWORK	  =16; // use network drive, you need to install Dokan network provider.
  DOKAN_OPTION_REMOVABLE  =32; // use removable drive

type
  _DOKAN_OPTIONS = packed record
    Version : Word;
    ThreadCount: Word;      // Number of threads to be used
    Options: UInt;     // Ouput debug message
    GlobalContext: UInt64;   // User-mode filesystem can use this variable
    MountPoint: LPCWSTR;     // Drive letter to be mounted
  end;
  PDOKAN_OPTIONS = ^_DOKAN_OPTIONS;
  DOKAN_OPTIONS = _DOKAN_OPTIONS;

  TDokanOptions = _DOKAN_OPTIONS;
  PDokanOptions = PDOKAN_OPTIONS;

  _DOKAN_FILE_INFO = packed record
    Context: UInt64;         // User-mode filesystem can use this variable
    DokanContext: UInt64;    // Reserved. Don't touch this!
    DokanOptions : PDOKAN_OPTIONS; // A pointer to DOKAN_OPTIONS which was  passed to DokanMain.
    ProcessId: ULONG;       // process id for the thread that originally requested a given I/O operation
    IsDirectory: Boolean;   // requesting a directory file
    DeleteOnClose: Boolean; // Delete on when "cleanup" is called
    PagingIo: Boolean;	// Read or write is paging IO.
    SynchronousIo: Boolean;  // Read or write is synchronous IO.
    Nocache: Boolean;
    WriteToEndOfFile: Boolean; //  If true, write to the current end of file instead of Offset parameter.
  end;
  PDOKAN_FILE_INFO = ^_DOKAN_FILE_INFO;
  DOKAN_FILE_INFO = _DOKAN_FILE_INFO;

  TDokanFileInfo = _DOKAN_FILE_INFO;
  PDokanFileInfo = PDOKAN_FILE_INFO;

type
// When an error occurs, the following user-mode callbacks should return
// negative values. Usually, you should return GetLastError() * -1.

// FillFileData is a client-side callback to enumerate a file list when
// FindFiles is called. It is supposed to return 1 if buffer is full, 0
// otherwise (currently it never returns 1)
  TDokanFillFindData = function(var FindData: WIN32_FIND_DATAW;
                                var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

// CreateFile may be called when FileName is the name of an existing directory.
// In that case, CreateFile should return 0 if that directory can be opened and
// you should set DokanFileInfo.IsDirectory to True.
// When CreationDisposition is CREATE_ALWAYS or OPEN_ALWAYS and a file with the
// same name already exists, you should return ERROR_ALREADY_EXISTS (183) (not
// the negative value)
  TDokanCreateFile = function(FileName: LPCWSTR;
                              DesiredAccess, ShareMode, CreationDisposition, FlagsAndAttributes: DWORD;
                              var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanOpenDirectory = function(FileName: LPCWSTR;
                                 var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanCreateDirectory = function(FileName: LPCWSTR;
                                   var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;
                                   
// When FileInfo.DeleteOnClose is set to True, you must delete the file during
// Cleanup.
  TDokanCleanup = function(FileName: LPCWSTR;
                           var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanCloseFile = function(FileName: LPCWSTR;
                             var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanReadFile = function(FileName: LPCWSTR;
                            var Buffer;
                            NumberOfBytesToRead: DWORD;
                            var NumberOfBytesRead: DWORD;
                            Offset: LONGLONG;
                            var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanWriteFile = function(FileName: LPCWSTR;
                             var Buffer;
                             NumberOfBytesToWrite: DWORD;
                             var NumberOfBytesWritten: DWORD;
                             Offset: LONGLONG;
                             var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanFlushFileBuffers = function(FileName: LPCWSTR;
                                    var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanGetFileInformation = function(FileName: LPCWSTR;
                                      FileInformation: PByHandleFileInformation;
                                      var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanFindFiles = function(PathName: LPCWSTR;
                             // For each matched file, call this function with a filled PWIN32_FIND_DATAW structure
                             FillFindDataCallback: TDokanFillFindData;
                             var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

// You should implement either FindFiles or FindFilesWithPattern
  TDokanFindFilesWithPattern = function(PathName, SearchPattern: LPCWSTR;
                                        // For each matched file, call this function with a filled PWIN32_FIND_DATAW structure
                                        FillFindDataCallback: TDokanFillFindData;
                                        var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanSetFileAttributes = function(FileName: LPCWSTR;
                                     FileAttributes: DWORD;
                                     var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanSetFileTime = function(FileName: LPCWSTR;
                               CreationTime, LastAccessTime, LastWriteTime: PFileTime;
                               var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

// You should not delete any file or directory when DeleteFile or 
// DeleteDirectory is called. Instead, you must check whether it can be deleted
// or not, return 0 (ERROR_SUCCESS) if yes, or appropriate error codes such as
// -ERROR_DIR_NOT_EMPTY, -ERROR_SHARING_VIOLATION... otherwise.
// Returning 0 ensures that the Cleanup callback will be called later with
// FileInfo.DeleteOnClose set to True, and you will be able to safely delete
// the file at that time.
  TDokanDeleteFile = function(FileName: LPCWSTR;
                              var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanDeleteDirectory = function(FileName: LPCWSTR;
                                   var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanMoveFile = function(ExistingFileName, NewFileName: LPCWSTR;
                            ReplaceExisiting: BOOL;
                            var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanSetEndOfFile = function(FileName: LPCWSTR;
                                Length: LONGLONG;
                                var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanSetAllocationSize = function(FileName: LPCWSTR;
                                Length: LONGLONG;
                                var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanLockFile = function(FileName: LPCWSTR;
                            ByteOffset, Length: LONGLONG;
                            var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanUnlockFile = function(FileName: LPCWSTR;
                              ByteOffset, Length: LONGLONG;
                              var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

// Neither GetDiskFreeSpace nor GetVolumeInformation will save the value of
// DokanFileContext.Context.

  ULONGLONG = ULARGE_INTEGER;

// See Win32 API GetDiskFreeSpaceEx
  TDokanGetDiskFreeSpace = function(var FreeBytesAvailable, TotalNumberOfBytes, TotalNumberOfFreeBytes: ULONGLONG;
                                    var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

// See Win32 API GetVolumeInformation
  TDokanGetVolumeInformation = function(VolumeNameBuffer: LPWSTR;
                                        VolumeNameSize: DWORD;
                                        var VolumeSerialNumber, MaximumComponentLength, FileSystemFlags: DWORD;
                                        FileSystemNameBuffer: LPWSTR;
                                        FileSystemNameSize: DWORD;
                                        var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanUnmount = function(var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanGetFileSecurity = function(FileName: LPCWSTR;
                                      var SecurityInformation : SECURITY_INFORMATION;
                                      var SecurityDescriptor : SECURITY_DESCRIPTOR;
                                      LengthOfSecurityDescriptorBuffer : ULONG;
                                      var LengthNeeded  : ULONG;
                                      var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  TDokanSetFileSecurity = function(FileName: LPCWSTR;
                                    var SecurityInformation : SECURITY_INFORMATION;
                                    var SecurityDescriptor : SECURITY_DESCRIPTOR;
                                    SecurityDescriptorLength : ULONG;
                                    var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

  _DOKAN_OPERATIONS = packed record
    CreateFile: TDokanCreateFile;
    OpenDirectory: TDokanOpenDirectory;
    CreateDirectory: TDokanCreateDirectory;
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
    SetAllocationSize : TDokanSetAllocationSize;
    LockFile: TDokanLockFile;
    UnlockFile: TDOkanUnlockFile;
    GetFileSecurity: TDokanGetFileSecurity;
    SetFileSecurity: TDokanSetFileSecurity;
    GetDiskFreeSpace: TDokanGetDiskFreeSpace;
    GetVolumeInformation:TDokanGetVolumeInformation;
    Unmount: TDokanUnmount;
  end;
  PDOKAN_OPERATIONS = ^_DOKAN_OPERATIONS;
  DOKAN_OPERATIONS = _DOKAN_OPERATIONS;

  TDokanOperations = _DOKAN_OPERATIONS;
  PDokanOperations = PDOKAN_OPERATIONS;

const
  DOKAN_SUCCESS              =  0;
  DOKAN_ERROR                = -1; // General error
  DOKAN_DRIVE_LETTER_ERROR   = -2; // Bad drive letter
  DOKAN_DRIVER_INSTALL_ERROR = -3; // Cannot install driver
  DOKAN_START_ERROR          = -4; // Something is wrong with the driver
  DOKAN_MOUNT_ERROR          = -5; // Cannot assign the drive letter
  DOKAN_MOUNT_POINT_ERROR    = -6; // Mountpoint is invalid

function DokanMain(var Options: DOKAN_OPTIONS; var Operations: DOKAN_OPERATIONS): Integer; stdcall;
function DokanUnmount(DriveLetter: WCHAR): BOOL; stdcall;
function DokanRemoveMountPoint(MountPoint : LPCWSTR): BOOL; stdcall;
// DokanIsNameInExpression
// check whether Name can match Expression
// Expression can contain wildcard characters (? and *)
function DokanIsNameInExpression(Expression, Name: LPCWSTR; IgnoreCase: BOOL): Bool; stdcall;
function DokanVersion: ULONG; stdcall;
function DokanDriverVersion: ULONG; stdcall;
// DokanResetTimeout
// extends the time out of the current IO operation in driver.
function DokanResetTimeout(Timeout : ULONG;var DokanFileInfo: DOKAN_FILE_INFO): Bool; stdcall;
// Get the handle to Access Token
// This method needs be called in CreateFile, OpenDirectory or CreateDirectly callback.
// The caller must call CloseHandle for the returned handle.
function DokanOpenRequestorToken(var DokanFileInfo: DOKAN_FILE_INFO): THandle; stdcall;

// For internal use only. Do not call these!
function DokanServiceInstall(ServiceName: LPCWSTR; ServiceType: DWORD; ServiceFullPath: LPCWSTR): Bool; stdcall;
function DokanServiceDelete(ServiceName: LPCWSTR): Bool; stdcall;

implementation

function DokanMain; external DokanLibrary;
function DokanUnmount; external DokanLibrary;
function DokanRemoveMountPoint; external DokanLibrary;
function DokanIsNameInExpression; external DokanLibrary;
function DokanVersion; external DokanLibrary;
function DokanDriverVersion; external DokanLibrary;
function DokanResetTimeout; external DokanLibrary;
function DokanOpenRequestorToken; external DokanLibrary;
function DokanServiceInstall; external DokanLibrary;
function DokanServiceDelete; external DokanLibrary;

end.
