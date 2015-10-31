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

  DOKAN_VERSION	 =	800;

  DOKAN_OPTION_DEBUG    	=	1; // ouput debug message
  DOKAN_OPTION_STDERR	    =	2; // ouput debug message to stderr
  DOKAN_OPTION_ALT_STREAM	= 4; // use alternate stream
  DOKAN_OPTION_NETWORK	  =16; // use network drive, you need to install Dokan network provider.
  DOKAN_OPTION_REMOVABLE  =32; // use removable drive

type
  NTSTATUS = Longint;

const
  NTSTATUS_SUCCESS = NTSTATUS($00000000); // ntsubauth
  NTSTATUS_INVALID_HANDLE = NTSTATUS($C0000008); // winnt
  NTSTATUS_OBJECT_NAME_NOT_FOUND = NTSTATUS($C0000034);
  NTSTATUS_OBJECT_PATH_NOT_FOUND = NTSTATUS($C000003A);
  NTSTATUS_INVALID_PARAMETER = NTSTATUS($C000000D);
  NTSTATUS_ACCESS_DENIED = NTSTATUS($C0000022);

type
  _DOKAN_OPTIONS = packed record
    Version : Word;       // Supported Dokan Version, ex. "530" (Dokan ver 0.5.3)
    ThreadCount: Word;    // number of threads to be used internally by Dokan library
    Options: UInt;        // combination of DOKAN_OPTIONS_*
    GlobalContext: UInt64;// FileSystem can store anything here
    MountPoint: LPCWSTR;  // mount point "M:\" (drive letter) or "C:\mount\dokan" (path in NTFS)
    Timeout: UInt;        // IrpTimeout in milliseconds
  end;
  PDOKAN_OPTIONS = ^_DOKAN_OPTIONS;
  DOKAN_OPTIONS = _DOKAN_OPTIONS;

  TDokanOptions = _DOKAN_OPTIONS;
  PDokanOptions = PDOKAN_OPTIONS;

  _DOKAN_FILE_INFO = packed record
    Context: UInt64;               // FileSystem can store anything here
    DokanContext: UInt64;          // Used internally, never modify
    DokanOptions : PDOKAN_OPTIONS; // A pointer to DOKAN_OPTIONS which was passed to DokanMain.
    ProcessId: ULONG;              // process id for the thread that originally requested a given I/O operation
    IsDirectory: Boolean;          // requesting a directory file
    DeleteOnClose: Boolean;        // Delete on when "cleanup" is called
    PagingIo: Boolean;	           // Read or write is paging IO.
    SynchronousIo: Boolean;        // Read or write is synchronous IO.
    Nocache: Boolean;
    WriteToEndOfFile: Boolean; //  If true, write to the current end of file instead of Offset parameter.
  end;
  PDOKAN_FILE_INFO = ^_DOKAN_FILE_INFO;
  DOKAN_FILE_INFO = _DOKAN_FILE_INFO;

  TDokanFileInfo = _DOKAN_FILE_INFO;                                                     
  PDokanFileInfo = PDOKAN_FILE_INFO;

type
  // When an error occurs, return NTSTATUS (https://support.microsoft.com/en-us/kb/113996)

  // FillFindData
  //   is used to add an entry in FindFiles                                              
  //   returns 1 if buffer is full, otherwise 0
  //   (currently it never returns 1)
  TDokanFillFindData = function(var FindData: WIN32_FIND_DATAW;
                                var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

// FillFindStreamData
//   is used to add an entry in FindStreams
//   returns 1 if buffer is full, otherwise 0
//   (currently it never returns 1)
  WIN32_FIND_STREAM_DATA = packed record
    StreamSize: LARGE_INTEGER;
    cStreamName: array [0 .. (MAX_PATH + 36) - 1] of WCHAR;
  end;
  TDokanFillFindStreamData = function(var FindStreamData: WIN32_FIND_STREAM_DATA;
                                      var DokanFileInfo: DOKAN_FILE_INFO): Integer; stdcall;

	// CreateFile
	//   If file is a directory, CreateFile (not OpenDirectory) may be called.
	//   In this case, CreateFile should return STATUS_SUCCESS when that directory can be opened.
	//   You should set TRUE on DokanFileInfo->IsDirectory when file is a directory.
  TDokanCreateFile = function(FileName: LPCWSTR;
                              DesiredAccess, ShareMode, CreationDisposition, FlagsAndAttributes: DWORD;
                              var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanOpenDirectory = function(FileName: LPCWSTR;
                                 var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanCreateDirectory = function(FileName: LPCWSTR;
                                   var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
                                   
	// When FileInfo->DeleteOnClose is true, you must delete the file in Cleanup.
	// Refer to comment at DeleteFile definition below in this file for explanation.
  TDokanCleanup = procedure (FileName: LPCWSTR;
                           var DokanFileInfo: DOKAN_FILE_INFO); stdcall;

  TDokanCloseFile = procedure (FileName: LPCWSTR;
                             var DokanFileInfo: DOKAN_FILE_INFO); stdcall;

  TDokanReadFile = function(FileName: LPCWSTR;
                            var Buffer;
                            NumberOfBytesToRead: DWORD;
                            var NumberOfBytesRead: DWORD;
                            Offset: LONGLONG;
                            var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanWriteFile = function(FileName: LPCWSTR;
                             var Buffer;
                             NumberOfBytesToWrite: DWORD;
                             var NumberOfBytesWritten: DWORD;
                             Offset: LONGLONG;
                             var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanFlushFileBuffers = function(FileName: LPCWSTR;
                                    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanGetFileInformation = function(FileName: LPCWSTR;
                                      FileInformation: PByHandleFileInformation;
                                      var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

	// You should implement either FindFiles or FindFilesWithPattern

  TDokanFindFiles = function(PathName: LPCWSTR;
                             // For each matched file, call this function with a filled PWIN32_FIND_DATAW structure
                             FillFindDataCallback: TDokanFillFindData;
                             var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanFindFilesWithPattern = function(PathName, SearchPattern: LPCWSTR;
                                        // For each matched file, call this function with a filled PWIN32_FIND_DATAW structure
                                        FillFindDataCallback: TDokanFillFindData;
                                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanSetFileAttributes = function(FileName: LPCWSTR;
                                     FileAttributes: DWORD;
                                     var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanSetFileTime = function(FileName: LPCWSTR;
                               CreationTime, LastAccessTime, LastWriteTime: PFileTime;
                               var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

	// You should not delete the file on DeleteFile or DeleteDirectory, but instead
	// you must only check whether you can delete the file or not, 
	// and return ERROR_SUCCESS (when you can delete it) or appropriate error codes such as 
	// STATUS_ACCESS_DENIED, STATUS_OBJECT_PATH_NOT_FOUND, STATUS_OBJECT_NAME_NOT_FOUND.
	// When you return ERROR_SUCCESS, you get a Cleanup call afterwards with
	// FileInfo->DeleteOnClose set to TRUE and only then you have to actually delete
	// the file being closed.
  TDokanDeleteFile = function(FileName: LPCWSTR;
                              var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanDeleteDirectory = function(FileName: LPCWSTR;
                                   var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanMoveFile = function(ExistingFileName, NewFileName: LPCWSTR;
                            ReplaceExisiting: BOOL;
                            var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanSetEndOfFile = function(FileName: LPCWSTR;
                                Length: LONGLONG;
                                var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanSetAllocationSize = function(FileName: LPCWSTR;
                                Length: LONGLONG;
                                var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanLockFile = function(FileName: LPCWSTR;
                            ByteOffset, Length: LONGLONG;
                            var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanUnlockFile = function(FileName: LPCWSTR;
                              ByteOffset, Length: LONGLONG;
                              var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

	// Neither GetDiskFreeSpace nor GetVolumeInformation
	// save the DokanFileContext->Context.
	// Before these methods are called, CreateFile may not be called.
	// (ditto CloseFile and Cleanup)

  ULONGLONG = ULARGE_INTEGER;

// See Win32 API GetDiskFreeSpaceEx
  TDokanGetDiskFreeSpace = function(var FreeBytesAvailable, TotalNumberOfBytes, TotalNumberOfFreeBytes: ULONGLONG;
                                    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

// See Win32 API GetVolumeInformation
  TDokanGetVolumeInformation = function(VolumeNameBuffer: LPWSTR;
                                        VolumeNameSize: DWORD;
                                        var VolumeSerialNumber, MaximumComponentLength, FileSystemFlags: DWORD;
                                        FileSystemNameBuffer: LPWSTR;
                                        FileSystemNameSize: DWORD;
                                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanUnmount = function(var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanGetFileSecurity = function(FileName: LPCWSTR;
                                      var SecurityInformation : SECURITY_INFORMATION;
                                      var SecurityDescriptor : SECURITY_DESCRIPTOR;
                                      LengthOfSecurityDescriptorBuffer : ULONG;
                                      var LengthNeeded  : ULONG;
                                      var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

  TDokanSetFileSecurity = function(FileName: LPCWSTR;
                                    var SecurityInformation : SECURITY_INFORMATION;
                                    var SecurityDescriptor : SECURITY_DESCRIPTOR;
                                    SecurityDescriptorLength : ULONG;
                                    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

	// Supported since 0.8.0. You must specify the version at DOKAN_OPTIONS.Version.
  TDokanFindStreams = function(FileName: LPCWSTR;
                               FillFindStreamDataCallback: TDokanFillFindStreamData;
                               var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

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
    GetDiskFreeSpace: TDokanGetDiskFreeSpace;
    GetVolumeInformation:TDokanGetVolumeInformation;
    Unmount: TDokanUnmount;
    GetFileSecurity: TDokanGetFileSecurity;
    SetFileSecurity: TDokanSetFileSecurity;
    FindStreams: TDokanFindStreams;
  end;
  PDOKAN_OPERATIONS = ^_DOKAN_OPERATIONS;
  DOKAN_OPERATIONS = _DOKAN_OPERATIONS;

  TDokanOperations = _DOKAN_OPERATIONS;
  PDokanOperations = PDOKAN_OPERATIONS;

// DokanMain returns error codes
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

implementation

function DokanMain; external DokanLibrary;
function DokanUnmount; external DokanLibrary;
function DokanRemoveMountPoint; external DokanLibrary;
function DokanIsNameInExpression; external DokanLibrary;
function DokanVersion; external DokanLibrary;
function DokanDriverVersion; external DokanLibrary;
function DokanResetTimeout; external DokanLibrary;
function DokanOpenRequestorToken; external DokanLibrary;

end.
