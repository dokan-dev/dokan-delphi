program Mirror;

(*******************************************************************************
 *
 * Copyright (c) 2007, 2008 Hiroki Asakawa info@dokan-dev.net
 *
 * Delphi translation by Vincent Forman (vincent.forman@gmail.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 *******************************************************************************)

{$APPTYPE CONSOLE}

uses
  Windows,
  SysUtils,
  Dokan in 'Dokan.pas';

// Not available in Windows.pas
function SetFilePointerEx(hFile: THandle; lDistanceToMove: LARGE_INTEGER; lpNewFilePointer: Pointer; dwMoveMethod: DWORD): BOOL; stdcall; external kernel32;

// Some additional Win32 flags
const
  FILE_READ_DATA                     = $00000001;
  FILE_WRITE_DATA                    = $00000002;
  FILE_APPEND_DATA                   = $00000004;
  FILE_READ_EA                       = $00000008;
  FILE_WRITE_EA                      = $00000010;
  FILE_EXECUTE                       = $00000020;
  FILE_READ_ATTRIBUTES               = $00000080;
  FILE_WRITE_ATTRIBUTES              = $00000100;

  FILE_ATTRIBUTE_ENCRYPTED           = $00000040;
  FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = $00002000;
  FILE_FLAG_OPEN_NO_RECALL           = $00100000;
  FILE_FLAG_OPEN_REPARSE_POINT       = $00200000;

  STATUS_DIRECTORY_NOT_EMPTY         = $C0000101;

  INVALID_SET_FILE_POINTER           = $FFFFFFFF;

// Utilities routines, to be defined later
procedure DbgPrint(const Message: string); overload; forward;
procedure DbgPrint(const Format: string; const Args: array of const); overload; forward;
function MirrorConvertPath(FileName: PWideChar): string; forward;

// Output the value of a flag by searching amongst an array of value/name pairs
procedure CheckFlag(const Flag: Cardinal;
                    Values: array of Cardinal;
                    Names: array of string);
var
  i:Integer;
begin
  for i:=Low(Values) to High(Values) do
    if Values[i]=Flag then
      DbgPrint('    %s',[Names[i]]);
end;

type
  EDokanMainError = class(Exception)
  public
    constructor Create(DokanErrorCode: Integer);
  end;

constructor EDokanMainError.Create(DokanErrorCode: Integer);
var
  s:string;
begin
  case DokanErrorCode of
    DOKAN_SUCCESS: s := 'Success';
    DOKAN_ERROR: s := 'Generic error';
    DOKAN_DRIVE_LETTER_ERROR: s := 'Bad drive letter';
    DOKAN_DRIVER_INSTALL_ERROR: s := 'Cannot install driver';
    DOKAN_START_ERROR: s := 'Cannot start driver';
    DOKAN_MOUNT_ERROR: s := 'Cannot mount on the specified drive letter';
    DOKAN_MOUNT_POINT_ERROR : s := 'Mount point error';
  else
    s := 'Unknown error';
  end;
  inherited CreateFmt('Dokan Error. Code: %d.'+sLineBreak+'%s',[DokanErrorCode,s]);
end;

// Dokan callbacks
function MirrorCreateFile(FileName: PWideChar;
                          AccessMode, ShareMode, CreationDisposition, FlagsAndAttributes: Cardinal;
                          var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
const
  AccessModeValues: array[1..19] of Cardinal = (
    GENERIC_READ, GENERIC_WRITE, GENERIC_EXECUTE,
    _DELETE, FILE_READ_DATA, FILE_READ_ATTRIBUTES, FILE_READ_EA, READ_CONTROL,
    FILE_WRITE_DATA, FILE_WRITE_ATTRIBUTES, FILE_WRITE_EA, FILE_APPEND_DATA, WRITE_DAC, WRITE_OWNER,
    SYNCHRONIZE, FILE_EXECUTE,
    STANDARD_RIGHTS_READ, STANDARD_RIGHTS_WRITE, STANDARD_RIGHTS_EXECUTE
  );
  AccessModeNames: array[1..19] of string = (
    'GENERIC_READ', 'GENERIC_WRITE', 'GENERIC_EXECUTE',
    'DELETE', 'FILE_READ_DATA', 'FILE_READ_ATTRIBUTES', 'FILE_READ_EA', 'READ_CONTROL',
    'FILE_WRITE_DATA', 'FILE_WRITE_ATTRIBUTES', 'FILE_WRITE_EA', 'FILE_APPEND_DATA', 'WRITE_DAC', 'WRITE_OWNER',
    'SYNCHRONIZE', 'FILE_EXECUTE',
    'STANDARD_RIGHTS_READ', 'STANDARD_RIGHTS_WRITE', 'STANDARD_RIGHTS_EXECUTE'
  );
  ShareModeValues: array[1..3] of Cardinal = (
    FILE_SHARE_READ, FILE_SHARE_WRITE, FILE_SHARE_DELETE
  );
  ShareModeNames: array[1..3] of string = (
    'FILE_SHARE_READ', 'FILE_SHARE_WRITE', 'FILE_SHARE_DELETE'
  );
  CreationDispositionValues: array[1..5] of Cardinal = (
    CREATE_NEW, OPEN_ALWAYS, CREATE_ALWAYS, OPEN_EXISTING, TRUNCATE_EXISTING
  );
  CreationDispositionNames: array[1..5] of string = (
    'CREATE_NEW', 'OPEN_ALWAYS', 'CREATE_ALWAYS', 'OPEN_EXISTING', 'TRUNCATE_EXISTING'
  );
  FlagsAndAttributesValues: array[1..26] of Cardinal = (
    FILE_ATTRIBUTE_ARCHIVE, FILE_ATTRIBUTE_ENCRYPTED, FILE_ATTRIBUTE_HIDDEN,
    FILE_ATTRIBUTE_NORMAL, FILE_ATTRIBUTE_NOT_CONTENT_INDEXED, FILE_ATTRIBUTE_OFFLINE,
    FILE_ATTRIBUTE_READONLY, FILE_ATTRIBUTE_SYSTEM, FILE_ATTRIBUTE_TEMPORARY,
    FILE_FLAG_WRITE_THROUGH, FILE_FLAG_OVERLAPPED, FILE_FLAG_NO_BUFFERING,
    FILE_FLAG_RANDOM_ACCESS, FILE_FLAG_SEQUENTIAL_SCAN, FILE_FLAG_DELETE_ON_CLOSE,
    FILE_FLAG_BACKUP_SEMANTICS, FILE_FLAG_POSIX_SEMANTICS, FILE_FLAG_OPEN_REPARSE_POINT,
    FILE_FLAG_OPEN_NO_RECALL,
    SECURITY_ANONYMOUS, SECURITY_IDENTIFICATION, SECURITY_IMPERSONATION,
    SECURITY_DELEGATION, SECURITY_CONTEXT_TRACKING, SECURITY_EFFECTIVE_ONLY,
    SECURITY_SQOS_PRESENT
  );
  FlagsAndAttributesNames: array[1..26] of string = (
    'FILE_ATTRIBUTE_ARCHIVE', 'FILE_ATTRIBUTE_ENCRYPTED', 'FILE_ATTRIBUTE_HIDDEN',
    'FILE_ATTRIBUTE_NORMAL', 'FILE_ATTRIBUTE_NOT_CONTENT_INDEXED', 'FILE_ATTRIBUTE_OFFLINE',
    'FILE_ATTRIBUTE_READONLY', 'FILE_ATTRIBUTE_SYSTEM', 'FILE_ATTRIBUTE_TEMPORARY',
    'FILE_FLAG_WRITE_THROUGH', 'FILE_FLAG_OVERLAPPED', 'FILE_FLAG_NO_BUFFERING',
    'FILE_FLAG_RANDOM_ACCESS', 'FILE_FLAG_SEQUENTIAL_SCAN', 'FILE_FLAG_DELETE_ON_CLOSE',
    'FILE_FLAG_BACKUP_SEMANTICS', 'FILE_FLAG_POSIX_SEMANTICS', 'FILE_FLAG_OPEN_REPARSE_POINT',
    'FILE_FLAG_OPEN_NO_RECALL',
    'SECURITY_ANONYMOUS', 'SECURITY_IDENTIFICATION', 'SECURITY_IMPERSONATION',
    'SECURITY_DELEGATION', 'SECURITY_CONTEXT_TRACKING', 'SECURITY_EFFECTIVE_ONLY',
    'SECURITY_SQOS_PRESENT'
  );
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('CreateFile: %s', [filePath]);

  (*
  if (ShareMode = 0) and ((AccessMode and FILE_WRITE_DATA) <> 0) then
    ShareMode := FILE_SHARE_WRITE
  else
    if ShareMode = 0 then
      ShareMode := FILE_SHARE_READ;
  *)

  DbgPrint('    AccessMode = 0x%x', [AccessMode]);
  CheckFlag(AccessMode, AccessModeValues, AccessModeNames);

  DbgPrint('    ShareMode = 0x%x', [ShareMode]);
  CheckFlag(ShareMode, ShareModeValues, ShareModeNames);

  DbgPrint('    CreationDisposition = 0x%x', [ShareMode]);
  CheckFlag(CreationDisposition, CreationDispositionValues, CreationDispositionNames);

// Check if FilePath is a directory
  if (GetFileAttributes(PChar(FilePath)) and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
    FlagsAndAttributes := FlagsAndAttributes or FILE_FLAG_BACKUP_SEMANTICS;
  DbgPrint('    FlagsAndAttributes = 0x%x', [FlagsAndAttributes]);
  CheckFlag(FlagsAndAttributes, FlagsAndAttributesValues, FlagsAndAttributesNames);

// Save the file handle in Context
  DokanFileInfo.Context := CreateFile(PChar(FilePath), AccessMode, ShareMode, nil, CreationDisposition, FlagsAndAttributes, 0);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    // Error codes are negated value of Win32 error codes
    Result := -GetLastError;
    DbgPrint('CreateFile failed, error code = %d', [-Result]);
  end else
    Result := 0;
  DbgPrint('');
end;

function MirrorOpenDirectory(FileName: PWideChar;
                             var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('OpenDirectory: %s', [FilePath]);
  DokanFileInfo.Context := CreateFile(PChar(FilePath), 0, FILE_SHARE_READ or FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -GetLastError;
    DbgPrint('CreateFile failed, error code = %d', [-Result]);
  end else
    Result := 0;
  DbgPrint('');
end;

function MirrorCreateDirectory(FileName: PWideChar;
                               var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('CreateDirectory: %s', [FilePath]);
  if not CreateDirectory(PChar(FilePath), nil) then
  begin
    Result := -GetLastError;
    DbgPrint('CreateDirectory failed, error code = %d', [-Result]);
  end else
    Result := 0;
  DbgPrint('');
end;

function MirrorCleanup(FileName: PWideChar;
                       var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('Cleanup: %s', [FilePath]);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -1;
    DbgPrint('Error: invalid handle', [FilePath]);
  end else
  begin
    Result := 0;
    CloseHandle(DokanFileInfo.Context);
    DokanFileInfo.Context := INVALID_HANDLE_VALUE;
    if DokanFileInfo.DeleteOnClose then
    begin
      if DokanFileInfo.IsDirectory then
      begin
        DbgPrint('DeleteOnClose -> RemoveDirectory');
        if not RemoveDirectory(PChar(FilePath)) then
          DbgPrint('RemoveDirectory failed, error code = %d', [GetLastError]);
      end else
      begin
        DbgPrint('DeleteOnClose -> DeleteFile');
        if not DeleteFile(PChar(FIlePath)) then
          DbgPrint('DeleteFile failed, error code = %d', [GetLastError]);
      end;
    end;
  end;
  DbgPrint('');
end;

function MirrorCloseFile(FileName: PWideChar;
                         var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  Result := 0;
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('CloseFile: %s', [FilePath]);
  if DokanFileInfo.Context <> INVALID_HANDLE_VALUE then
  begin
    DbgPrint('Error: file was not closed during cleanup');
    CloseHandle(DokanFileInfo.Context);
    DokanFileInfo.Context := INVALID_HANDLE_VALUE;
  end;
  DbgPrint('');
end;

function MirrorReadFile(FileName: PWideChar;
                        var Buffer;
                        NumberOfBytesToRead: Cardinal;
                        var NumberOfBytesRead: Cardinal;
                        Offset: Int64;
                        var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
  Opened: Boolean;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('ReadFile: %s (Offset: %d, Length: %d)', [FilePath, Offset, NumberOfBytesToRead]);
  Opened := DokanFileInfo.Context = INVALID_HANDLE_VALUE;
  if Opened then
  begin
    DbgPrint('Invalid handle (maybe passed through cleanup?), creating new one');
    DokanFileInfo.Context := CreateFile(PChar(FilePath), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, 0, 0);
  end;
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -GetLastError;
    DbgPrint('CreateFile failed, error code = %d', [-Result]);
  end else 
    try
      if SetFilePointerEx(DokanFileInfo.Context, LARGE_INTEGER(Offset), nil, FILE_BEGIN) then
      begin
        if ReadFile(DokanFileInfo.Context, Buffer, NumberOfBytesToRead, NumberOfBytesRead, nil) then
        begin
          Result := 0;
          DbgPrint('Read: %d', [NumberOfBytesRead]);
        end else
        begin
          Result := -GetLastError;
          DbgPrint('ReadFile failed, error code = %d', [-Result]);
        end;
      end else
      begin
        Result := -GetLastError;
        DbgPrint('Seek failed, error code = %d', [-Result]);
      end;
    finally
      if Opened then
      begin
        CloseHandle(DokanFileInfo.Context);
        DokanFileInfo.Context := INVALID_HANDLE_VALUE;
      end;
    end;
  DbgPrint('');
end;

function MirrorWriteFile(FileName: PWideChar;
                         var Buffer;
                         NumberOfBytesToWrite: Cardinal;
                         var NumberOfBytesWritten: Cardinal;
                         Offset: Int64;
                         var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
  Opened: Boolean;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('WriteFile: %s (Offset: %d, Length: %d)', [FilePath, Offset, NumberOfBytesToWrite]);
  Opened := DokanFileInfo.Context = INVALID_HANDLE_VALUE;
  if Opened then
  begin
    DbgPrint('Invalid handle (maybe passed through cleanup?), creating new one');
    DokanFileInfo.Context := CreateFile(PChar(FilePath), GENERIC_WRITE, FILE_SHARE_WRITE, nil, OPEN_EXISTING, 0, 0);
  end;
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -GetLastError;
    DbgPrint('CreateFile failed, error code = %d', [-Result]);
  end else
    try
      if SetFilePointerEx(DokanFileInfo.Context, LARGE_INTEGER(Offset), nil, FILE_BEGIN) then
      begin
        if WriteFile(DokanFileInfo.Context, Buffer, NumberOfBytesToWrite, NumberOfBytesWritten, nil) then
        begin
          Result := 0;
          DbgPrint('Written: %d', [NumberOfBytesWritten]);
        end else
        begin
          Result := -GetLastError;
          DbgPrint('ReadFile failed, error code = %d', [-Result]);
        end;
      end else
      begin
        Result := -GetLastError;
        DbgPrint('Seek failed, error code = %d', [-Result]);
      end;
    finally
      if Opened then
      begin
        CloseHandle(DokanFileInfo.Context);
        DokanFileInfo.Context := INVALID_HANDLE_VALUE;
      end;
    end;
  DbgPrint('');
end;

function MirrorFlushFileBuffers(FileName: PWideChar;
                                var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('FlushFileBuffers: %s', [FilePath]);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -1;
    DbgPrint('Error: invalid handle')
  end else
  begin
    if FlushFileBuffers(DokanFileInfo.Context) then
      Result := 0
    else
    begin
      Result := -GetLastError;
      DbgPrint('FlushFileBuffers failed, error code = %d', [-Result]);
    end;
  end;
  DbgPrint('');
end;

function MirrorGetFileInformation(FileName: PWideChar;
                                  FileInformation: PByHandleFileInformation;
                                  var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
  Opened: Boolean;
  FindData: WIN32_FIND_DATAA;
  FindHandle: THandle;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('GetFileInformation: %s', [FilePath]);
  Opened := DokanFileInfo.Context = INVALID_HANDLE_VALUE;
  if Opened then
  begin
    DbgPrint('Invalid handle (maybe passed through cleanup?), creating new one');
    DokanFileInfo.Context := CreateFile(PChar(FilePath), GENERIC_WRITE, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, 0);
  end;
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -1;
    DbgPrint('CreateFile failed, error code = %d', [GetLastError]);
  end else
    try
      if GetFileInformationByHandle(DokanFileInfo.Context, FileInformation^) then
        Result := 0
      else
      begin
        DbgPrint('GetFileInformationByHandle failed, error code = %d', [GetLastError]);
        if Length(FileName) = 1 then
        begin
          Result := 0;
          FileInformation.dwFileAttributes := GetFileAttributes(PChar(FilePath));
        end else
        begin
          ZeroMemory(@FindData, SizeOf(FindData));
          FindHandle := FindFirstFileA(PAnsiChar(AnsiString(FilePath)), FindData);
          if FindHandle = INVALID_HANDLE_VALUE then
          begin
            Result := -1;
            DbgPrint('FindFirstFile failed, error code = %d', [GetLastError]);
          end else
          begin
            Result := 0;
            FileInformation.dwFileAttributes := FindData.dwFileAttributes;
            FileInformation.ftCreationTime := FindData.ftCreationTime;
            FileInformation.ftLastAccessTime := FindData.ftLastAccessTime;
            FileInformation.ftLastWriteTime := FindData.ftLastWriteTime;
            FileInformation.nFileSizeHigh := FindData.nFileSizeHigh;
            FileInformation.nFileSizeLow := FindData.nFileSizeLow;
            Windows.FindClose(FindHandle);
          end;
        end;
      end;
    finally
      if Opened then
      begin
        CloseHandle(DokanFileInfo.Context);
        DokanFileInfo.Context := INVALID_HANDLE_VALUE;
      end;
    end;
  DbgPrint('');
end;

function MirrorFindFiles(PathName: PWideChar;
                         FillFindDataCallback: TDokanFillFindData;
                         var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: widestring;
  FindData: WIN32_FIND_DATAW;
  FindHandle: THandle;
begin
  FilePath := MirrorConvertPath(PathName) + '\*';
  DbgPrint('GetFileInformation: %s', [FilePath]);
  FindHandle := FindFirstFileW(PWideChar(FilePath), FindData);
  if FindHandle = INVALID_HANDLE_VALUE then
  begin
    Result := -1;
    DbgPrint('FindFirstFile failed, error code = %d', [GetLastError]);
  end else
  begin
    Result := 0;
    try
      FillFindDataCallback(FindData, DokanFileInfo);
      while FindNextFileW(FindHandle, FindData) do
        FillFindDataCallback(FindData, DokanFileInfo);
    finally
      Windows.FindClose(FindHandle);
    end;
  end;
  DbgPrint('');
end;

function MirrorSetFileAttributes(FileName: PWideChar;
                                 FileAttributes: Cardinal;
                                 var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('SetFileAttributes: %s', [FilePath]);
  if SetFileAttributes(PChar(FilePath), FileAttributes) then
    Result := 0
  else
  begin
    Result := -GetLastError;
    DbgPrint('SetFileAttributes failed, error code = %d', [-Result]);
  end;
  DbgPrint('');
end;

function MirrorSetFileTime(FileName: PWideChar;
                           CreationTime, LastAccessTime, LastWriteTime: PFileTime;
                           var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('SetFileTime: %s', [FilePath]);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -1;
    DbgPrint('Error: invalid handle');
  end else
  begin
    if SetFileTime(DokanFileInfo.Context, CreationTime, LastAccessTime, LastWriteTime) then
      Result := 0
    else
    begin
      Result := -GetLastError;
      DbgPrint('SetFileTime failed, error code = %d', [-Result]);
    end;
  end;
  DbgPrint('');
end;

function MirrorDeleteFile(FileName: PWideChar;
                          var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  Result := 0;
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('DeleteFile: %s', [FilePath]);
  DbgPrint('');
end;

function MirrorDeleteDirectory(FileName: PWideChar;
                               var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
  FindData: WIN32_FIND_DATAA;
  FindHandle: THandle;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('DeleteDirectory: %s', [FilePath]);
  FindHandle := FindFirstFileA(PAnsiChar(AnsiString(FilePath)), FindData);
  if FindHandle = INVALID_HANDLE_VALUE then
  begin
    Result := -GetLastError;
    if Result = -ERROR_NO_MORE_FILES then
      Result := 0
    else
      DbgPrint('FindFirstFile failed, error code = %d', [-Result]);
  end else
  begin
    Cardinal(Result) := STATUS_DIRECTORY_NOT_EMPTY;
    Result := -Result;
    Windows.FindClose(FindHandle);
  end;
  DbgPrint('');
end;

function MirrorMoveFile(ExistingFileName, NewFileName: PWideChar;
                        ReplaceExisiting: LongBool;
                        var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  ExistingFilePath, NewFilePath: string;
  Status: Boolean;
begin
  ExistingFilePath := MirrorConvertPath(ExistingFileName);
  NewFilePath := MirrorConvertPath(NewFileName);
  DbgPrint('MoveFile: %s -> %s', [ExistingFilePath, NewFilePath]);
  if DokanFileInfo.Context <> INVALID_HANDLE_VALUE then
  begin
    CloseHandle(DokanFileInfo.Context);
    DokanFileInfo.Context := INVALID_HANDLE_VALUE;
  end;
  if ReplaceExisiting then
    Status := MoveFileEx(PChar(ExistingFilePath), PChar(NewFilePath), MOVEFILE_REPLACE_EXISTING)
  else
    Status := MoveFile(PChar(ExistingFilePath), PChar(NewFilePath));
  if Status then
    Result := 0
  else
  begin
    Result := -GetLastError;
    DbgPrint('MoveFile failed, error code = %d', [-Result]);
  end;
  DbgPrint('');
end;

function MirrorSetEndOfFile(FileName: PWideChar;
                            Length: Int64;
                            var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('SetEndOfFile: %s', [FilePath]);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    Result := -1;
    DbgPrint('Invalid handle');
  end else
  begin
    if SetFilePointerEx(DokanFileInfo.Context, LARGE_INTEGER(Length), nil, FILE_BEGIN) then
    begin
      if SetEndOfFile(DokanFileInfo.Context) then
        Result := 0
      else
      begin
        Result := -GetLastError;
        DbgPrint('SetEndOfFile failed, error code = %d', [-Result]);
      end;
    end else
    begin
      Result := -GetLastError;
      DbgPrint('Seek failed, error code = %d', [-Result]);
    end;
  end;
  DbgPrint('');
end;

function MirrorLockFile(FileName: PWideChar;
                        Offset, Length: Int64;
                        var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('LockFile: %s', [FilePath]);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    DbgPrint('Invalid handle');
    Result := -1;
  end else
  begin
    if LockFile(DokanFileInfo.Context,
                LARGE_INTEGER(Offset).LowPart, LARGE_INTEGER(Offset).HighPart,
                LARGE_INTEGER(Length).LowPart, LARGE_INTEGER(Length).HighPart) then
      Result := 0
    else
    begin
      Result := -GetLastError;
      DbgPrint('LockFile failed, error code = %d', [-Result]);
    end;
  end;
  DbgPrint('');
end;

function MirrorUnlockFile(FileName: PWideChar;
                          Offset, Length: Int64;
                          var DokanFileInfo: TDokanFileInfo): Integer; stdcall;


var
  FilePath: string;
begin
  FilePath := MirrorConvertPath(FileName);
  DbgPrint('LockFile: %s', [FilePath]);
  if DokanFileInfo.Context = INVALID_HANDLE_VALUE then
  begin
    DbgPrint('Invalid handle');
    Result := -1;
  end else
  begin
    if UnlockFile(DokanFileInfo.Context,
                  LARGE_INTEGER(Offset).LowPart, LARGE_INTEGER(Offset).HighPart,
                  LARGE_INTEGER(Length).LowPart, LARGE_INTEGER(Length).HighPart) then
      Result := 0
    else
    begin
      Result := -GetLastError;
      DbgPrint('UnlockFile failed, error code = %d', [-Result]);
    end;
  end;
  DbgPrint('');
end;

function MirrorUnmount(var DokanFileInfo: TDokanFileInfo): Integer; stdcall;
begin
  Result := 0;
  DbgPrint('Unmount');
  DbgPrint('');
end;

// Global vars
var
  g_RootDirectory: string = '';

  g_DokanOperations: TDokanOperations = (
    CreateFile: MirrorCreateFile;
    OpenDirectory: MirrorOpenDirectory;
    CreateDirectory: MirrorCreateDirectory;
    Cleanup: MirrorCleanup;
    CloseFile: MirrorCloseFile;
    ReadFile: MirrorReadFile;
    WriteFile: MirrorWriteFile;
    FlushFileBuffers: MirrorFlushFileBuffers;
    GetFileInformation: MirrorGetFileInformation;
    FindFiles: MirrorFindFiles;
    FindFilesWithPattern: nil;
    SetFileAttributes: MirrorSetFileAttributes;
    SetFileTime: MirrorSetFileTime;
    DeleteFile: MirrorDeleteFile;
    DeleteDirectory: MirrorDeleteDirectory;
    MoveFile: MirrorMoveFile;
    SetEndOfFile: MirrorSetEndOfFile;
    SetAllocationSize: nil;
    LockFile: MirrorLockFile;
    UnlockFile: MirrorUnlockFile;
    GetFileSecurity: nil;
    SetFileSecurity: nil;
    GetDiskFreeSpace: nil;
    GetVolumeInformation: nil;
    Unmount: MirrorUnmount
  );

  g_DokanOptions: TDokanOptions = (
    Version : 0;
    ThreadCount: 0;
    Options: 0;
    GlobalContext: 0;
    MountPoint: #0;
  );

// Utilities routines
procedure DbgPrint(const Message: string); overload;
begin
  if (g_DokanOptions.Options and DOKAN_OPTION_DEBUG) = DOKAN_OPTION_DEBUG then
  begin
    if (g_DokanOptions.Options and DOKAN_OPTION_STDERR) = DOKAN_OPTION_STDERR then
      Writeln(ErrOutput,Message)
    else
      Writeln(Message)
  end;
end;

procedure DbgPrint(const Format: string; const Args: array of const); overload;
begin
  if (g_DokanOptions.Options and DOKAN_OPTION_DEBUG) = DOKAN_OPTION_DEBUG then
  begin
    if (g_DokanOptions.Options and DOKAN_OPTION_STDERR) = DOKAN_OPTION_STDERR then
      Writeln(ErrOutput,SysUtils.Format(Format,Args))
    else
      Writeln(SysUtils.Format(Format,Args))
  end;
end;

function MirrorConvertPath(FileName: PWideChar): string;
begin
  if FileName = nil then
  begin
    WriteLn('Null filename');
    Result := g_RootDirectory
  end else
    Result := g_RootDirectory + FileName;
end;

// Main procedure
procedure Main;
var
  i: Integer;

  function FindSwitch(const s: string; t: array of Char): Integer;
  var
    i: Integer;
    c: Char;
  begin
    if (Length(s) = 2) and CharInSet(s[1],['/','-','\']) then
    begin
      c := UpCase(s[2]);
      for i:=Low(t) to High(t) do
        if t[i] = c then
        begin
          Result := i;
          Exit;
        end;
    end;
    Result := Low(t) - 1;
  end;

begin
  IsMultiThread := True;
  i := 1;
  g_DokanOptions.Version := DOKAN_VERSION;
  g_DokanOptions.ThreadCount := 0;
  while i <= ParamCount do
  begin
    case FindSwitch(ParamStr(i), ['R','L','T','D','S','N','M','K','A']) of
      0: begin
        if (i = ParamCount) or (ParamStr(i+1) = '') then
          raise Exception.Create('Missing root directory after /R');
        Inc(i);
        g_RootDirectory := ParamStr(i);
      end;
      1: begin
        if (i = ParamCount) then //or (Length(ParamStr(i+1)) <> 1) then
          raise Exception.Create('Missing drive letter after /L');
        Inc(i);
        g_DokanOptions.MountPoint := PWideChar(ParamStr(i));
      end;
      2: begin
        if (i = ParamCount) or (ParamStr(i+1) = '') then
          raise Exception.Create('Missing thread count after /T');
        Inc(i);
        g_DokanOptions.ThreadCount := StrToInt(ParamStr(i));
      end;
      3: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_DEBUG;
      4: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_STDERR;
      5: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_NETWORK;
      6: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_REMOVABLE;
      7: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_KEEP_ALIVE;
      8: g_DokanOptions.Options := g_DokanOptions.Options or DOKAN_OPTION_ALT_STREAM;
    end;
    Inc(i);
  end;
  if (g_RootDirectory = '') or (g_DokanOptions.MountPoint = #0) then
  begin
    WriteLn('Usage: ',ExtractFileName(ParamStr(0)));
    WriteLn('   /R RootDirectory    (e.g. /R C:\test)');
    WriteLn('   /L DriveLetter      (e.g. /L m)');
    WriteLn('   /T ThreadCount      (optional, e.g. /T 5)');
    WriteLn('   /D                  (optional, enable debug output)');
    WriteLn('   /S                  (optional, use stderr for output)');
    WriteLn('   /N                  (optional, use network drive)');
    WriteLn('   /M                  (optional, use removable drive)');
    WriteLn('   /K                  (optional, keep alive)');
    WriteLn('   /A                  (optional, use alternate stream)');
  end else
  begin
    i := DokanMain(g_DokanOptions, g_DokanOperations);
    if i <> DOKAN_SUCCESS then
      raise EDokanMainError.Create(i);
  end;
end;

begin
  try
    Main;
  except
    on e: Exception do
      WriteLn('Error (',e.ClassName,'): ',e.Message);
    else
      WriteLn('Unspecified error');
  end;
end.
