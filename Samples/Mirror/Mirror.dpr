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

program Mirror;

{$ifdef FPC}
  {$mode delphi}
{$endif FPC}

{$align 8}
{$minenumsize 4}
{$apptype console}

uses
  Windows, SysUtils, Math,
  Dokan in '..\..\Dokan.pas',
  DokanWin in '..\..\DokanWin.pas';

const
  EXIT_SUCCESS = 0;
  EXIT_FAILURE = 1;

  CSTR_EQUAL = 2;
  LOCALE_NAME_SYSTEM_DEFAULT  = '!x-sys-default-locale';

type
  LPVOID = Pointer;
  size_t = NativeUInt;

  _TOKEN_USER = record
    User : TSIDAndAttributes;
  end;
  TOKEN_USER = _TOKEN_USER;
  PTOKEN_USER = ^_TOKEN_USER;

  STREAM_INFO_LEVELS = (FindStreamInfoStandard = 0);

  FILE_INFO_BY_HANDLE_CLASS = (FileRenameInfo = 3, FileDispositionInfo = 4);

  _FILE_RENAME_INFO = record
    ReplaceIfExists: ByteBool;
    RootDirectory: THandle;
    FileNameLength: DWORD;
    FileName: array [0 .. 0] of WCHAR;
  end;
  FILE_RENAME_INFO = _FILE_RENAME_INFO;
  PFILE_RENAME_INFO = ^_FILE_RENAME_INFO;

  _FILE_DISPOSITION_INFO = record
    DeleteFile: ByteBool;
  end;
  FILE_DISPOSITION_INFO = _FILE_DISPOSITION_INFO;
  PFILE_DISPOSITION_INFO = ^_FILE_DISPOSITION_INFO;

function GetFileSizeEx(hFile: THandle;
  var lpFileSize: LARGE_INTEGER): BOOL; stdcall; external kernel32;

function SetFilePointerEx(hFile: THandle; liDistanceToMove: LARGE_INTEGER;
  lpNewFilePointer: PLargeInteger; dwMoveMethod: DWORD): BOOL; stdcall; external kernel32;

function FindFirstStreamW(lpFileName: LPCWSTR; InfoLevel: STREAM_INFO_LEVELS;
  lpFindStreamData: LPVOID; dwFlags: DWORD): THandle; stdcall; external kernel32;

function FindNextStreamW(hFindStream: THandle;
  lpFindStreamData: LPVOID): BOOL; stdcall; external kernel32;

function CompareStringEx(lpLocaleName: LPCWSTR; dwCmpFlags: DWORD;
  lpString1: LPCWSTR; cchCount1: Integer;
  lpString2: LPCWSTR; cchCount2: Integer;
  lpVersionInformation: Pointer; lpReserved: LPVOID;
  lParam: LPARAM): Integer; stdcall; external kernel32;

function SetFileInformationByHandle(hFile: THandle;
  FileInformationClass: FILE_INFO_BY_HANDLE_CLASS; lpFileInformation: LPVOID;
  dwBufferSize: DWORD): BOOL; stdcall; external kernel32;

procedure wcsncat_s(dst: PWCHAR; dst_len: size_t; src: PWCHAR; src_len: size_t);
begin
  while (dst^ <> #0) and (dst_len > 1) do begin
    Inc(dst);
    Dec(dst_len);
  end;
  while (dst_len > 1) and (src^ <> #0) and (src_len > 0) do begin
    dst^ := src^;
    Inc(dst);
    Dec(dst_len);
    Inc(src);
    Dec(src_len);
  end;
  if (dst_len > 0) then
    dst^ := #0
end;

function _wcsnicmp(str1, str2: PWCHAR; len: Integer): Integer;
begin
  Result := CompareStringEx(
    LOCALE_NAME_SYSTEM_DEFAULT,
    NORM_IGNORECASE,
    str1, Math.Min(lstrlenW(str1), len),
    str2, Math.Min(lstrlenW(str2), len),
    nil, nil, 0
  ) - CSTR_EQUAL;
end;

function escape_replace(const esc: string): string;
var
  i, j, len: Integer;
begin
  i := 1;
  j := 1;
  len:=Length(esc);
  SetLength(Result, len);
  while (i <= len) do begin
    if (esc[i] = '\') then begin
      Inc(i);
      case (esc[i]) of
        't': Result[j] := #09;
        'n': Result[j] := #10;
      else
        Result[j] := esc[i];
      end;
    end else
      Result[j] := esc[i];
    Inc(i);
    Inc(j);
  end;
  if (i <> j) then
    SetLength(Result, j - 1);
end;

//{$define WIN10_ENABLE_LONG_PATH}
{$ifdef WIN10_ENABLE_LONG_PATH}
//dirty but should be enough
const
	DOKAN_MAX_PATH = 32768;
{$else}
const
	DOKAN_MAX_PATH = MAX_PATH;
{$endif} // DEBUG

type
  WCHAR_PATH = array [0 .. DOKAN_MAX_PATH-1] of WCHAR;

var
  g_UseStdErr: Boolean;
  g_DebugMode: Boolean;
  g_HasSeSecurityPrivilege: Boolean;
  g_ImpersonateCallerUser: Boolean;

procedure DbgPrint(format: string; const args: array of const); overload;
var
  outputString: string;
begin
  if (g_DebugMode) then begin
    outputString := SysUtils.Format(escape_replace(format), args);
    if (g_UseStdErr) then begin
      Write(ErrOutput, outputString);
      Flush(ErrOutput);
    end else
      OutputDebugString(PChar(outputString));
  end;
end;

procedure DbgPrint(fmt: string); overload;
begin
  DbgPrint(fmt, []);
end;

var
  RootDirectory: WCHAR_PATH;
  MountPoint: WCHAR_PATH;
  UNCName: WCHAR_PATH;

procedure GetFilePath(filePath: PWCHAR; numberOfElements: ULONG;
                      const FileName: LPCWSTR);
var
  unclen: size_t;
begin
  lstrcpynW(filePath, RootDirectory, numberOfElements);
  unclen := lstrlenW(UNCName);
  if (unclen > 0) and (_wcsnicmp(FileName, UNCName, unclen) = 0) then begin
    if (_wcsnicmp(FileName + unclen, '.', 1) <> 0) then begin
      wcsncat_s(filePath, numberOfElements, FileName + unclen,
                size_t(lstrlenW(FileName)) - unclen);
    end;
  end else begin
    wcsncat_s(filePath, numberOfElements, FileName, lstrlenW(FileName));
  end;
end;

procedure PrintUserName(var DokanFileInfo: DOKAN_FILE_INFO);
var
  handle: THandle;
  buffer: array [0 .. 1023] of UCHAR;
  returnLength: DWORD;
  accountName: array [0 .. 255] of WCHAR;
  domainName: array [0 .. 255] of WCHAR;
  accountLength: DWORD;
  domainLength: DWORD;
  tokenUser_: PTOKEN_USER;
  snu: SID_NAME_USE;
begin
  accountLength := SizeOf(accountName) div SizeOf(WCHAR);
  domainLength := SizeOf(domainName) div SizeOf(WCHAR);

  if (not g_DebugMode) then begin
    Exit;
  end;

  handle := DokanOpenRequestorToken(DokanFileInfo);
  if (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('  DokanOpenRequestorToken failed\n');
    Exit;
  end;

  if (not GetTokenInformation(handle, TokenUser, @buffer, SizeOf(buffer),
                           returnLength)) then begin
    DbgPrint('  GetTokenInformaiton failed: %d\n', [GetLastError()]);
    CloseHandle(handle);
    Exit;
  end;

  CloseHandle(handle);

  tokenUser_ := PTOKEN_USER(@buffer);
  if (not LookupAccountSidW(nil, tokenUser_^.User.Sid, accountName, accountLength,
                        domainName, domainLength, snu)) then begin
    DbgPrint('  LookupAccountSid failed: %d\n', [GetLastError()]);
    Exit;
  end;

  DbgPrint('  AccountName: %s, DomainName: %s\n', [accountName, domainName]);
end;

function AddSeSecurityNamePrivilege(): Boolean;
var
  token: THandle;
  err: DWORD;
  luid: TLargeInteger;
  attr: LUID_AND_ATTRIBUTES;
  priv: TOKEN_PRIVILEGES;
  oldPriv: TOKEN_PRIVILEGES;
  retSize: DWORD;
  privAlreadyPresent: Boolean;
  i: Integer;
begin
  token := 0;
  DbgPrint(
      '## Attempting to add SE_SECURITY_NAME privilege to process token ##\n');
  if (not LookupPrivilegeValueW(nil, 'SeSecurityPrivilege', luid)) then begin
    err := GetLastError();
    if (err <> ERROR_SUCCESS) then begin
      DbgPrint('  failed: Unable to lookup privilege value. error = %u\n',
               [err]);
      Result := False; Exit;
    end;
  end;

  attr.Attributes := SE_PRIVILEGE_ENABLED;
  attr.Luid := luid;

  priv.PrivilegeCount := 1;
  priv.Privileges[0] := attr;

  if (not OpenProcessToken(GetCurrentProcess(),
                        TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, token)) then begin
    err := GetLastError();
    if (err <> ERROR_SUCCESS) then begin
      DbgPrint('  failed: Unable obtain process token. error = %u\n', [err]);
      Result := False; Exit;
    end;
  end;

  AdjustTokenPrivileges(token, False, priv, SizeOf(TOKEN_PRIVILEGES), oldPriv,
                        retSize);
  err := GetLastError();
  if (err <> ERROR_SUCCESS) then begin
    DbgPrint('  failed: Unable to adjust token privileges: %u\n', [err]);
    CloseHandle(token);
    Result := False; Exit;
  end;

  privAlreadyPresent := False;
  for i := 0 to oldPriv.PrivilegeCount - 1 do begin
    if (oldPriv.Privileges[i].Luid = luid) then begin
      privAlreadyPresent := True;
      Break;
    end;
  end;
  if (privAlreadyPresent) then
    DbgPrint('  success: privilege already present\n')
  else
    DbgPrint('  success: privilege added\n');
  if (token <> 0) then
    CloseHandle(token);
  Result := True; Exit;
end;

procedure MirrorCheckFlag(const val: DWORD; const flag: DWORD; const flagname: string);
begin
  if (val and flag <> 0) then
    DbgPrint('\t%s\n', [flagname]);
end;

function MirrorCreateFile(FileName: LPCWSTR; var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;
                 DesiredAccess: ACCESS_MASK; FileAttributes: ULONG;
                 ShareAccess: ULONG; CreateDisposition: ULONG;
                 CreateOptions: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  fileAttr: DWORD;
  status: NTSTATUS;
  creationDisposition: DWORD;
  fileAttributesAndFlags: DWORD;
  error: DWORD;
  securityAttrib: SECURITY_ATTRIBUTES;
  genericDesiredAccess: ACCESS_MASK;
  // userTokenHandle is for Impersonate Caller User Option
  userTokenHandle: THandle;
begin
  status := STATUS_SUCCESS;

  securityAttrib.nLength := SizeOf(securityAttrib);
  securityAttrib.lpSecurityDescriptor :=
      SecurityContext.AccessState.SecurityDescriptor;
  securityAttrib.bInheritHandle := False;

  DokanMapKernelToUserCreateFileFlags(
      DesiredAccess, FileAttributes, CreateOptions, CreateDisposition,
      @genericDesiredAccess, @fileAttributesAndFlags, @creationDisposition);

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('CreateFile: %s\n', [filePath]);

  PrintUserName(DokanFileInfo);

  (*
  if (ShareMode = 0) and (AccessMode and FILE_WRITE_DATA <> 0) then
          ShareMode := FILE_SHARE_WRITE
  else if (ShareMode = 0) then
          ShareMode := FILE_SHARE_READ;
  *)

  DbgPrint('\tShareMode = 0x%x\n', [ShareAccess]);

  MirrorCheckFlag(ShareAccess, FILE_SHARE_READ, 'FILE_SHARE_READ');
  MirrorCheckFlag(ShareAccess, FILE_SHARE_WRITE, 'FILE_SHARE_WRITE');
  MirrorCheckFlag(ShareAccess, FILE_SHARE_DELETE, 'FILE_SHARE_DELETE');

  DbgPrint('\tDesiredAccess = 0x%x\n', [DesiredAccess]);

  MirrorCheckFlag(DesiredAccess, GENERIC_READ, 'GENERIC_READ');
  MirrorCheckFlag(DesiredAccess, GENERIC_WRITE, 'GENERIC_WRITE');
  MirrorCheckFlag(DesiredAccess, GENERIC_EXECUTE, 'GENERIC_EXECUTE');

  MirrorCheckFlag(DesiredAccess, DELETE, 'DELETE');
  MirrorCheckFlag(DesiredAccess, FILE_READ_DATA, 'FILE_READ_DATA');
  MirrorCheckFlag(DesiredAccess, FILE_READ_ATTRIBUTES, 'FILE_READ_ATTRIBUTES');
  MirrorCheckFlag(DesiredAccess, FILE_READ_EA, 'FILE_READ_EA');
  MirrorCheckFlag(DesiredAccess, READ_CONTROL, 'READ_CONTROL');
  MirrorCheckFlag(DesiredAccess, FILE_WRITE_DATA, 'FILE_WRITE_DATA');
  MirrorCheckFlag(DesiredAccess, FILE_WRITE_ATTRIBUTES, 'FILE_WRITE_ATTRIBUTES');
  MirrorCheckFlag(DesiredAccess, FILE_WRITE_EA, 'FILE_WRITE_EA');
  MirrorCheckFlag(DesiredAccess, FILE_APPEND_DATA, 'FILE_APPEND_DATA');
  MirrorCheckFlag(DesiredAccess, WRITE_DAC, 'WRITE_DAC');
  MirrorCheckFlag(DesiredAccess, WRITE_OWNER, 'WRITE_OWNER');
  MirrorCheckFlag(DesiredAccess, SYNCHRONIZE, 'SYNCHRONIZE');
  MirrorCheckFlag(DesiredAccess, FILE_EXECUTE, 'FILE_EXECUTE');
  MirrorCheckFlag(DesiredAccess, STANDARD_RIGHTS_READ, 'STANDARD_RIGHTS_READ');
  MirrorCheckFlag(DesiredAccess, STANDARD_RIGHTS_WRITE, 'STANDARD_RIGHTS_WRITE');
  MirrorCheckFlag(DesiredAccess, STANDARD_RIGHTS_EXECUTE, 'STANDARD_RIGHTS_EXECUTE');

  // When filePath is a directory, needs to change the flag so that the file can
  // be opened.
  fileAttr := GetFileAttributesW(filePath);

  if (fileAttr <> INVALID_FILE_ATTRIBUTES) then begin
    if (fileAttr and FILE_ATTRIBUTE_DIRECTORY <> 0) then begin
      if (CreateOptions and FILE_NON_DIRECTORY_FILE = 0) then begin
        DokanFileInfo.IsDirectory := True;
        // Needed by FindFirstFile to list files in it
        // TODO: use ReOpenFile in MirrorFindFiles to set share read temporary
        ShareAccess := ShareAccess or FILE_SHARE_READ;
      end else begin // FILE_NON_DIRECTORY_FILE - Cannot open a dir as a file
        DbgPrint('\tCannot open a dir as a file\n');
        Result := STATUS_FILE_IS_A_DIRECTORY; Exit;
      end;
    end;
  end;

  DbgPrint('\tFlagsAndAttributes = 0x%x\n', [fileAttributesAndFlags]);

  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_ARCHIVE, 'FILE_ATTRIBUTE_ARCHIVE');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_COMPRESSED, 'FILE_ATTRIBUTE_COMPRESSED');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_DEVICE, 'FILE_ATTRIBUTE_DEVICE');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_DIRECTORY, 'FILE_ATTRIBUTE_DIRECTORY');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_ENCRYPTED, 'FILE_ATTRIBUTE_ENCRYPTED');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_HIDDEN, 'FILE_ATTRIBUTE_HIDDEN');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_INTEGRITY_STREAM, 'FILE_ATTRIBUTE_INTEGRITY_STREAM');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_NORMAL, 'FILE_ATTRIBUTE_NORMAL');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_NOT_CONTENT_INDEXED, 'FILE_ATTRIBUTE_NOT_CONTENT_INDEXED');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_NO_SCRUB_DATA, 'FILE_ATTRIBUTE_NO_SCRUB_DATA');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_OFFLINE, 'FILE_ATTRIBUTE_OFFLINE');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_READONLY, 'FILE_ATTRIBUTE_READONLY');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_REPARSE_POINT, 'FILE_ATTRIBUTE_REPARSE_POINT');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_SPARSE_FILE, 'FILE_ATTRIBUTE_SPARSE_FILE');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_SYSTEM, 'FILE_ATTRIBUTE_SYSTEM');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_TEMPORARY, 'FILE_ATTRIBUTE_TEMPORARY');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_ATTRIBUTE_VIRTUAL, 'FILE_ATTRIBUTE_VIRTUAL');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_WRITE_THROUGH, 'FILE_FLAG_WRITE_THROUGH');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_OVERLAPPED, 'FILE_FLAG_OVERLAPPED');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_NO_BUFFERING, 'FILE_FLAG_NO_BUFFERING');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_RANDOM_ACCESS, 'FILE_FLAG_RANDOM_ACCESS');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_SEQUENTIAL_SCAN, 'FILE_FLAG_SEQUENTIAL_SCAN');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_DELETE_ON_CLOSE, 'FILE_FLAG_DELETE_ON_CLOSE');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_BACKUP_SEMANTICS, 'FILE_FLAG_BACKUP_SEMANTICS');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_POSIX_SEMANTICS, 'FILE_FLAG_POSIX_SEMANTICS');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_OPEN_REPARSE_POINT, 'FILE_FLAG_OPEN_REPARSE_POINT');
  MirrorCheckFlag(fileAttributesAndFlags, FILE_FLAG_OPEN_NO_RECALL, 'FILE_FLAG_OPEN_NO_RECALL');
  MirrorCheckFlag(fileAttributesAndFlags, SECURITY_ANONYMOUS, 'SECURITY_ANONYMOUS');
  MirrorCheckFlag(fileAttributesAndFlags, SECURITY_IDENTIFICATION, 'SECURITY_IDENTIFICATION');
  MirrorCheckFlag(fileAttributesAndFlags, SECURITY_IMPERSONATION, 'SECURITY_IMPERSONATION');
  MirrorCheckFlag(fileAttributesAndFlags, SECURITY_DELEGATION, 'SECURITY_DELEGATION');
  MirrorCheckFlag(fileAttributesAndFlags, SECURITY_CONTEXT_TRACKING, 'SECURITY_CONTEXT_TRACKING');
  MirrorCheckFlag(fileAttributesAndFlags, SECURITY_EFFECTIVE_ONLY, 'SECURITY_EFFECTIVE_ONLY');
  MirrorCheckFlag(fileAttributesAndFlags, SECURITY_SQOS_PRESENT, 'SECURITY_SQOS_PRESENT');

  if (creationDisposition = CREATE_NEW) then begin
    DbgPrint('\tCREATE_NEW\n');
  end else if (creationDisposition = OPEN_ALWAYS) then begin
    DbgPrint('\tOPEN_ALWAYS\n');
  end else if (creationDisposition = CREATE_ALWAYS) then begin
    DbgPrint('\tCREATE_ALWAYS\n');
  end else if (creationDisposition = OPEN_EXISTING) then begin
    DbgPrint('\tOPEN_EXISTING\n');
  end else if (creationDisposition = TRUNCATE_EXISTING) then begin
    DbgPrint('\tTRUNCATE_EXISTING\n');
  end else begin
    DbgPrint('\tUNKNOWN creationDisposition!\n');
  end;

  if (g_ImpersonateCallerUser) then begin
    userTokenHandle := DokanOpenRequestorToken(DokanFileInfo);

    if (userTokenHandle = INVALID_HANDLE_VALUE) then begin
      DbgPrint('  DokanOpenRequestorToken failed\n');
      // Should we return some error?
    end;
  end else
    userTokenHandle := INVALID_HANDLE_VALUE; //to prevent compiler-warning

  if (DokanFileInfo.IsDirectory) then begin
    // It is a create directory request

    if (creationDisposition = CREATE_NEW) or
       (creationDisposition = OPEN_ALWAYS) then begin

      if (g_ImpersonateCallerUser) then begin
        // if g_ImpersonateCallerUser option is on, call the ImpersonateLoggedOnUser function.
        if (not ImpersonateLoggedOnUser(userTokenHandle)) then begin
          // handle the error if failed to impersonate
          DbgPrint('\tImpersonateLoggedOnUser failed.\n');
        end;
      end;

      //We create folder
      if (not CreateDirectoryW(filePath, @securityAttrib)) then begin
        error := GetLastError();
        // Fail to create folder for OPEN_ALWAYS is not an error
        if (error <> ERROR_ALREADY_EXISTS) or
           (creationDisposition = CREATE_NEW) then begin
          DbgPrint('\terror code = %d\n\n', [error]);
          status := DokanNtStatusFromWin32(error);
        end;
      end;

      if (g_ImpersonateCallerUser) then begin
        // Clean Up operation for impersonate
        RevertToSelf();
      end;
    end;

    if (status = STATUS_SUCCESS) then begin

      //Check first if we're trying to open a file as a directory.
      if (fileAttr <> INVALID_FILE_ATTRIBUTES) and
          (fileAttr and FILE_ATTRIBUTE_DIRECTORY = 0) and
          (CreateOptions and FILE_DIRECTORY_FILE <> 0) then begin
        Result := STATUS_NOT_A_DIRECTORY; Exit;
      end;

      if (g_ImpersonateCallerUser) then begin
        // if g_ImpersonateCallerUser option is on, call the ImpersonateLoggedOnUser function.
        if (not ImpersonateLoggedOnUser(userTokenHandle)) then begin
          // handle the error if failed to impersonate
          DbgPrint('\tImpersonateLoggedOnUser failed.\n');
        end;
      end;

      // FILE_FLAG_BACKUP_SEMANTICS is required for opening directory handles
      handle :=
          CreateFileW(filePath, genericDesiredAccess, ShareAccess,
                     @securityAttrib, OPEN_EXISTING,
                     fileAttributesAndFlags or FILE_FLAG_BACKUP_SEMANTICS, 0);

      if (g_ImpersonateCallerUser) then begin
        // Clean Up operation for impersonate
        RevertToSelf();
      end;

      if (handle = INVALID_HANDLE_VALUE) then begin
        error := GetLastError();
        DbgPrint('\terror code = %d\n\n', [error]);

        status := DokanNtStatusFromWin32(error);
      end else begin
        DokanFileInfo.Context :=
            ULONG64(handle); // save the file handle in Context

        // Open succeed but we need to inform the driver
        // that the dir open and not created by returning STATUS_OBJECT_NAME_COLLISION
        if (creationDisposition = OPEN_ALWAYS) and
           (fileAttr <> INVALID_FILE_ATTRIBUTES) then begin
          Result := STATUS_OBJECT_NAME_COLLISION; Exit;
        end;
      end;
    end;
  end else begin
    // It is a create file request

    // Cannot overwrite a hidden or system file if flag not set
    if (fileAttr <> INVALID_FILE_ATTRIBUTES) and
        (((fileAttributesAndFlags and FILE_ATTRIBUTE_HIDDEN = 0) and
          (fileAttr and FILE_ATTRIBUTE_HIDDEN <> 0)) or
         ((fileAttributesAndFlags and FILE_ATTRIBUTE_SYSTEM = 0) and
          (fileAttr and FILE_ATTRIBUTE_SYSTEM <> 0))) and
        ((creationDisposition = TRUNCATE_EXISTING) or
         (creationDisposition = CREATE_ALWAYS)) then begin
      Result := STATUS_ACCESS_DENIED; Exit;
    end;

    // Cannot delete a read only file
    if (((fileAttr <> INVALID_FILE_ATTRIBUTES) and
             (fileAttr and FILE_ATTRIBUTE_READONLY <> 0) or
         (fileAttributesAndFlags and FILE_ATTRIBUTE_READONLY <> 0)) and
        (fileAttributesAndFlags and FILE_FLAG_DELETE_ON_CLOSE <> 0)) then begin
      Result := STATUS_CANNOT_DELETE; Exit;
    end;

    // Truncate should always be used with write access
    if (creationDisposition = TRUNCATE_EXISTING) then
      genericDesiredAccess := genericDesiredAccess or GENERIC_WRITE;

    if (g_ImpersonateCallerUser) then begin
      // if g_ImpersonateCallerUser option is on, call the ImpersonateLoggedOnUser function.
      if (not ImpersonateLoggedOnUser(userTokenHandle)) then begin
        // handle the error if failed to impersonate
        DbgPrint('\tImpersonateLoggedOnUser failed.\n');
      end;
    end;

    handle := CreateFileW(
        filePath,
        genericDesiredAccess, // GENERIC_READ or GENERIC_WRITE or GENERIC_EXECUTE,
        ShareAccess,
        @securityAttrib, // security attribute
        creationDisposition,
        fileAttributesAndFlags, // or FILE_FLAG_NO_BUFFERING,
        0);                  // template file handle

    if (g_ImpersonateCallerUser) then begin
      // Clean Up operation for impersonate
      RevertToSelf();
    end;

    if (handle = INVALID_HANDLE_VALUE) then begin
      error := GetLastError();
      DbgPrint('\terror code = %d\n\n', [error]);

      status := DokanNtStatusFromWin32(error);
    end else begin

      //Need to update FileAttributes with previous when Overwrite file
      if (fileAttr <> INVALID_FILE_ATTRIBUTES) and
         (creationDisposition = TRUNCATE_EXISTING) then begin
        SetFileAttributesW(filePath, fileAttributesAndFlags or fileAttr);
      end;

      DokanFileInfo.Context :=
          ULONG64(handle); // save the file handle in Context

      if (creationDisposition = OPEN_ALWAYS) or
          (creationDisposition = CREATE_ALWAYS) then begin
        error := GetLastError();
        if (error = ERROR_ALREADY_EXISTS) then begin
          DbgPrint('\tOpen an already existing file\n');
          // Open succeed but we need to inform the driver
          // that the file open and not created by returning STATUS_OBJECT_NAME_COLLISION
          status := STATUS_OBJECT_NAME_COLLISION;
        end;
      end;
    end;
  end;

  DbgPrint('\n');
  Result := status; Exit;
end;

procedure MirrorCloseFile(FileName: LPCWSTR;
                          var DokanFileInfo: DOKAN_FILE_INFO); stdcall;
var
  filePath: WCHAR_PATH;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  if (DokanFileInfo.Context <> 0) then begin
    DbgPrint('CloseFile: %s\n', [filePath]);
    DbgPrint('\terror : not cleanuped file\n\n');
    CloseHandle(THandle(DokanFileInfo.Context));
    DokanFileInfo.Context := 0;
  end else begin
    DbgPrint('Close: %s\n\n', [filePath]);
  end;
end;

procedure MirrorCleanup(FileName: LPCWSTR;
                        var DokanFileInfo: DOKAN_FILE_INFO); stdcall;
var
  filePath: WCHAR_PATH;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  if (DokanFileInfo.Context <> 0) then begin
    DbgPrint('Cleanup: %s\n\n', [filePath]);
    CloseHandle(THandle(DokanFileInfo.Context));
    DokanFileInfo.Context := 0;
  end else begin
    DbgPrint('Cleanup: %s\n\tinvalid handle\n\n', [filePath]);
  end;

  if (DokanFileInfo.DeleteOnClose) then begin
    // Should already be deleted by CloseHandle
    // if open with FILE_FLAG_DELETE_ON_CLOSE
    DbgPrint('\tDeleteOnClose\n');
    if (DokanFileInfo.IsDirectory) then begin
      DbgPrint('  DeleteDirectory ');
      if (not RemoveDirectoryW(filePath)) then begin
        DbgPrint('error code = %d\n\n', [GetLastError()]);
      end else begin
        DbgPrint('success\n\n');
      end;
    end else begin
      DbgPrint('  DeleteFile ');
      if (DeleteFileW(filePath) = False) then begin
        DbgPrint(' error code = %d\n\n', [GetLastError()]);
      end else begin
        DbgPrint('success\n\n');
      end;
    end;
  end;
end;

function MirrorReadFile(FileName: LPCWSTR; var Buffer;
                        BufferLength: DWORD;
                        var ReadLength: DWORD;
                        Offset: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  offset_: ULONG;
  opened: Boolean;
  error: DWORD;
  distanceToMove: LARGE_INTEGER;
begin
  handle := THandle(DokanFileInfo.Context);
  offset_ := ULONG(Offset);
  opened := False;

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('ReadFile : %s\n', [filePath]);

  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle, cleanuped?\n');
    handle := CreateFileW(filePath, GENERIC_READ, FILE_SHARE_READ, nil,
                        OPEN_EXISTING, 0, 0);
    if (handle = INVALID_HANDLE_VALUE) then begin
      error := GetLastError();
      DbgPrint('\tCreateFile error : %d\n\n', [error]);
      Result := DokanNtStatusFromWin32(error); Exit;
    end;
    opened := True;
  end;

  distanceToMove.QuadPart := Offset;
  if (not SetFilePointerEx(handle, distanceToMove, nil, FILE_BEGIN)) then begin
    error := GetLastError();
    DbgPrint('\tseek error, offset = %d\n\n', [offset_]);
    if (opened) then
      CloseHandle(handle);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  if (not ReadFile(handle, Buffer, BufferLength, ReadLength, nil)) then begin
    error := GetLastError();
    DbgPrint('\tread error = %u, buffer length = %d, read length = %d\n\n',
             [error, BufferLength, ReadLength]);
    if (opened) then
      CloseHandle(handle);
    Result := DokanNtStatusFromWin32(error); Exit;

  end else begin
    DbgPrint('\tByte to read: %d, Byte read %d, offset %d\n\n', [BufferLength,
             ReadLength, offset_]);
  end;

  if (opened) then
    CloseHandle(handle);

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorWriteFile(FileName: LPCWSTR; const Buffer;
                         NumberOfBytesToWrite: DWORD;
                         var NumberOfBytesWritten: DWORD;
                         Offset: LONGLONG;
                         var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  opened: Boolean;
  error: DWORD;
  fileSize: UINT64;
  fileSizeLow: DWORD;
  fileSizeHigh: DWORD;
  z: LARGE_INTEGER;
  bytes: UINT64;
  distanceToMove: LARGE_INTEGER;
begin
  handle := THandle(DokanFileInfo.Context);
  opened := False;

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('WriteFile : %s, offset %d, length %d\n', [filePath, Offset,
           NumberOfBytesToWrite]);

  // reopen the file
  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle, cleanuped?\n');
    handle := CreateFileW(filePath, GENERIC_WRITE, FILE_SHARE_WRITE, nil,
                        OPEN_EXISTING, 0, 0);
    if (handle = INVALID_HANDLE_VALUE) then begin
      error := GetLastError();
      DbgPrint('\tCreateFile error : %d\n\n', [error]);
      Result := DokanNtStatusFromWin32(error); Exit;
    end;
    opened := True;
  end;

  fileSizeHigh := 0;
  fileSizeLow := GetFileSize(handle, @fileSizeHigh);
  if (fileSizeLow = INVALID_FILE_SIZE) then begin
    error := GetLastError();
    DbgPrint('\tcan not get a file size error = %d\n', [error]);
    if (opened) then
      CloseHandle(handle);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  fileSize := (UINT64(fileSizeHigh) shl 32) or fileSizeLow;

  if (DokanFileInfo.WriteToEndOfFile) then begin
    z.QuadPart := 0;
    if (not SetFilePointerEx(handle, z, nil, FILE_END)) then begin
      error := GetLastError();
      DbgPrint('\tseek error, offset = EOF, error = %d\n', [error]);
      if (opened) then
        CloseHandle(handle);
      Result := DokanNtStatusFromWin32(error); Exit;
    end;
  end else begin
    // Paging IO cannot write after allocate file size.
    if (DokanFileInfo.PagingIo) then begin
      if (UINT64(Offset) >= fileSize) then begin
        NumberOfBytesWritten := 0;
        if (opened) then
          CloseHandle(handle);
        Result := STATUS_SUCCESS; Exit;
      end;

      if ((UINT64(Offset) + NumberOfBytesToWrite) > fileSize) then begin
        bytes := fileSize - UINT64(Offset);
        if (bytes shr 32 <> 0) then begin
          NumberOfBytesToWrite := DWORD(bytes and $FFFFFFFF);
        end else begin
          NumberOfBytesToWrite := DWORD(bytes);
        end;
      end;
    end;

    if (UINT64(Offset) > fileSize) then begin
      // In the mirror sample helperZeroFileData is not necessary. NTFS will
      // zero a hole.
      // But if user's file system is different from NTFS( or other Windows's
      // file systems ) then  users will have to zero the hole themselves.
    end;

    distanceToMove.QuadPart := Offset;
    if (not SetFilePointerEx(handle, distanceToMove, nil, FILE_BEGIN)) then begin
      error := GetLastError();
      DbgPrint('\tseek error, offset = %d, error = %d\n', [Offset, error]);
      if (opened) then
        CloseHandle(handle);
      Result := DokanNtStatusFromWin32(error); Exit;
    end;
  end;

  if (not WriteFile(handle, Buffer, NumberOfBytesToWrite, NumberOfBytesWritten,
                 nil)) then begin
    error := GetLastError();
    DbgPrint('\twrite error = %u, buffer length = %d, write length = %d\n',
             [error, NumberOfBytesToWrite, NumberOfBytesWritten]);
    if (opened) then
      CloseHandle(handle);
    Result := DokanNtStatusFromWin32(error); Exit;

  end else begin
    DbgPrint('\twrite %d, offset %d\n\n', [NumberOfBytesWritten, Offset]);
  end;

  // close the file when it is reopened
  if (opened) then
    CloseHandle(handle);

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorFlushFileBuffers(FileName: LPCWSTR; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  error: DWORD;
begin
  handle := THandle(DokanFileInfo.Context);

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('FlushFileBuffers : %s\n', [filePath]);

  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_SUCCESS; Exit;
  end;

  if (FlushFileBuffers(handle)) then begin
    Result := STATUS_SUCCESS; Exit;
  end else begin
    error := GetLastError();
    DbgPrint('\tflush error code = %d\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;
end;

function MirrorGetFileInformation(
    FileName: LPCWSTR; var HandleFileInformation: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  error: DWORD;
  find: WIN32_FIND_DATAW;
  findHandle: THandle;
  opened: Boolean;
begin
  handle := THandle(DokanFileInfo.Context);
  opened := False;

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('GetFileInfo : %s\n', [filePath]);

  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle, cleanuped?\n');
    handle := CreateFileW(filePath, GENERIC_READ, FILE_SHARE_READ, nil,
                        OPEN_EXISTING, 0, 0);
    if (handle = INVALID_HANDLE_VALUE) then begin
      error := GetLastError();
      DbgPrint('\tCreateFile error : %d\n\n', [error]);
      Result := DokanNtStatusFromWin32(error); Exit;
    end;
    opened := True;
  end;

  if (not GetFileInformationByHandle(handle, HandleFileInformation)) then begin
    DbgPrint('\terror code = %d\n', [GetLastError()]);

    // FileName is a root directory
    // in this case, FindFirstFile can't get directory information
    if (lstrlenW(FileName) = 1) then begin
      DbgPrint('  root dir\n');
      HandleFileInformation.dwFileAttributes := GetFileAttributesW(filePath);

    end else begin
      ZeroMemory(@find, SizeOf(WIN32_FIND_DATAW));
      findHandle := FindFirstFileW(filePath, find);
      if (findHandle = INVALID_HANDLE_VALUE) then begin
        error := GetLastError();
        DbgPrint('\tFindFirstFile error code = %d\n\n', [error]);
        if (opened) then
          CloseHandle(handle);
        Result := DokanNtStatusFromWin32(error); Exit;
      end;
      HandleFileInformation.dwFileAttributes := find.dwFileAttributes;
      HandleFileInformation.ftCreationTime := find.ftCreationTime;
      HandleFileInformation.ftLastAccessTime := find.ftLastAccessTime;
      HandleFileInformation.ftLastWriteTime := find.ftLastWriteTime;
      HandleFileInformation.nFileSizeHigh := find.nFileSizeHigh;
      HandleFileInformation.nFileSizeLow := find.nFileSizeLow;
      DbgPrint('\tFindFiles OK, file size = %d\n', [find.nFileSizeLow]);
      Windows.FindClose(findHandle);
    end;
  end else begin
    DbgPrint('\tGetFileInformationByHandle success, file size = %d\n',
             [HandleFileInformation.nFileSizeLow]);
  end;

  DbgPrint('FILE ATTRIBUTE  = %d\n', [HandleFileInformation.dwFileAttributes]);

  if (opened) then
    CloseHandle(handle);

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorFindFiles(FileName: LPCWSTR;
                FillFindData: TDokanFillFindData; // function pointer
                var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  fileLen: size_t;
  hFind: THandle;
  findData: WIN32_FIND_DATAW;
  error: DWORD;
  count: Integer;
  rootFolder: Boolean;
begin
  count := 0;

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('FindFiles : %s\n', [filePath]);

  fileLen := lstrlenW(filePath);
  if (filePath[fileLen - 1] <> '\') then begin
    filePath[fileLen] := '\';
    Inc(fileLen);
  end;
  filePath[fileLen] := '*';
  filePath[fileLen + 1] := #0;

  hFind := FindFirstFileW(filePath, findData);

  if (hFind = INVALID_HANDLE_VALUE) then begin
    error := GetLastError();
    DbgPrint('\tinvalid file handle. Error is %u\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  // Root folder does not have . and .. folder - we remove them
  rootFolder := (lstrcmpW(FileName, '\') = 0);
  repeat
    if (not rootFolder) or ((lstrcmpW(findData.cFileName, '.') <> 0) and
                        (lstrcmpW(findData.cFileName, '..') <> 0)) then
      FillFindData(findData, DokanFileInfo);
    Inc(count);
  until( FindNextFileW(hFind, findData) = False);

  error := GetLastError();
  Windows.FindClose(hFind);

  if (error <> ERROR_NO_MORE_FILES) then begin
    DbgPrint('\tFindNextFile error. Error is %u\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  DbgPrint('\tFindFiles return %d entries in %s\n\n', [count, filePath]);

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorDeleteFile(FileName: LPCWSTR; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  dwAttrib: DWORD;
  fdi: FILE_DISPOSITION_INFO;
begin
  handle := THandle(DokanFileInfo.Context);

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);
  DbgPrint('DeleteFile %s - %d\n', [filePath, Byte(DokanFileInfo.DeleteOnClose)]);

  dwAttrib := GetFileAttributesW(filePath);

  if (dwAttrib <> INVALID_FILE_ATTRIBUTES) and
      (dwAttrib and FILE_ATTRIBUTE_DIRECTORY <> 0) then begin
    Result := STATUS_ACCESS_DENIED; Exit;
  end;

  if (handle <> 0) and (handle <> INVALID_HANDLE_VALUE) then begin
    fdi.DeleteFile := DokanFileInfo.DeleteOnClose;
    if (not SetFileInformationByHandle(handle, FileDispositionInfo, @fdi,
                                    sizeof(FILE_DISPOSITION_INFO))) then begin
      Result := DokanNtStatusFromWin32(GetLastError()); Exit;
    end;
  end;

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorDeleteDirectory(FileName: LPCWSTR; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  hFind: THandle;
  findData: WIN32_FIND_DATAW;
  fileLen: size_t;
  error: DWORD;
begin
  ZeroMemory(@filePath[0], SizeOf(filePath));
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('DeleteDirectory %s - %d\n', [filePath,
           Byte(DokanFileInfo.DeleteOnClose)]);

  if (not DokanFileInfo.DeleteOnClose) then begin
    //Dokan notify that the file is requested not to be deleted.
    Result := STATUS_SUCCESS; Exit;
  end;

  fileLen := lstrlenW(filePath);
  if (filePath[fileLen - 1] <> '\') then begin
    filePath[fileLen] := '\';
    Inc(fileLen);
  end;
  filePath[fileLen] := '*';
  filePath[fileLen + 1] := #0;

  hFind := FindFirstFileW(filePath, findData);

  if (hFind = INVALID_HANDLE_VALUE) then begin
    error := GetLastError();
    DbgPrint('\tDeleteDirectory error code = %d\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  repeat
    if (lstrcmpW(findData.cFileName, '..') <> 0) and
        (lstrcmpW(findData.cFileName, '.') <> 0) then begin
      Windows.FindClose(hFind);
      DbgPrint('\tDirectory is not empty: %s\n', [findData.cFileName]);
      Result := STATUS_DIRECTORY_NOT_EMPTY; Exit;
    end;
  until (FindNextFileW(hFind, findData) = False);

  error := GetLastError();

  Windows.FindClose(hFind);

  if (error <> ERROR_NO_MORE_FILES) then begin
    DbgPrint('\tDeleteDirectory error code = %d\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorMoveFile(FileName: LPCWSTR; // existing file name
               NewFileName: LPCWSTR; ReplaceIfExisting: BOOL;
               var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  newFilePath: WCHAR_PATH;
  handle: THandle;
  bufferSize: DWORD;
  result_: Boolean;
  newFilePathLen: size_t;
  renameInfo: PFILE_RENAME_INFO;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);
  GetFilePath(newFilePath, DOKAN_MAX_PATH, NewFileName);

  DbgPrint('MoveFile %s -> %s\n\n', [filePath, newFilePath]);
  handle := THandle(DokanFileInfo.Context);
  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_INVALID_HANDLE; Exit;
  end;

  newFilePathLen := lstrlenW(newFilePath);

  // the PFILE_RENAME_INFO struct has space for one WCHAR for the name at
  // the end;, so that
  // accounts for the null terminator

  bufferSize := DWORD(SizeOf(FILE_RENAME_INFO) +
                       newFilePathLen * SizeOf(newFilePath[0]));

  GetMem(renameInfo, bufferSize);
  if (renameInfo = nil) then begin
    Result := STATUS_BUFFER_OVERFLOW; Exit;
  end;
  ZeroMemory(renameInfo, bufferSize);

  renameInfo^.ReplaceIfExists := ReplaceIfExisting;
  renameInfo^.RootDirectory := 0; // hope it is never needed, shouldn't be
  renameInfo^.FileNameLength :=
      DWORD(newFilePathLen) *
      SizeOf(newFilePath[0]); // they want length in bytes

  lstrcpynW(renameInfo^.FileName, newFilePath, newFilePathLen + 1);

  result_ := SetFileInformationByHandle(handle, FileRenameInfo, renameInfo,
                                      bufferSize);

  FreeMem(renameInfo);

  if (result_) then begin
    Result := STATUS_SUCCESS; Exit;
  end else begin
    error := GetLastError();
    DbgPrint('\tMoveFile error = %u\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;
end;

function MirrorLockFile(FileName: LPCWSTR;
                        ByteOffset: LONGLONG;
                        Length: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  offset: LARGE_INTEGER;
  length_: LARGE_INTEGER;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('LockFile %s\n', [filePath]);

  handle := THandle(DokanFileInfo.Context);
  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_INVALID_HANDLE; Exit;
  end;

  length_.QuadPart := Length;
  offset.QuadPart := ByteOffset;

  if (not LockFile(handle, offset.LowPart, offset.HighPart, length_.LowPart,
                length_.HighPart)) then begin
    error := GetLastError();
    DbgPrint('\terror code = %d\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  DbgPrint('\tsuccess\n\n');
  Result := STATUS_SUCCESS; Exit;
end;

function MirrorSetEndOfFile(
    FileName: LPCWSTR; ByteOffset: LONGLONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  offset: LARGE_INTEGER;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('SetEndOfFile %s, %d\n', [filePath, ByteOffset]);

  handle := THandle(DokanFileInfo.Context);
  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_INVALID_HANDLE; Exit;
  end;

  offset.QuadPart := ByteOffset;
  if (not SetFilePointerEx(handle, offset, nil, FILE_BEGIN)) then begin
    error := GetLastError();
    DbgPrint('\tSetFilePointer error: %d, offset = %d\n\n', [error,
             ByteOffset]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  if (not SetEndOfFile(handle)) then begin
    error := GetLastError();
    DbgPrint('\tSetEndOfFile error code = %d\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorSetAllocationSize(
    FileName: LPCWSTR; AllocSize: LONGLONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  fileSize: LARGE_INTEGER;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('SetAllocationSize %s, %d\n', [filePath, AllocSize]);

  handle := THandle(DokanFileInfo.Context);
  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_INVALID_HANDLE; Exit;
  end;

  if (GetFileSizeEx(handle, fileSize)) then begin
    if (AllocSize < fileSize.QuadPart) then begin
      fileSize.QuadPart := AllocSize;
      if (not SetFilePointerEx(handle, fileSize, nil, FILE_BEGIN)) then begin
        error := GetLastError();
        DbgPrint('\tSetAllocationSize: SetFilePointer eror: %d, ' +
                 'offset = %d\n\n',
                 [error, AllocSize]);
        Result := DokanNtStatusFromWin32(error); Exit;
      end;
      if (not SetEndOfFile(handle)) then begin
        error := GetLastError();
        DbgPrint('\tSetEndOfFile error code = %d\n\n', [error]);
        Result := DokanNtStatusFromWin32(error); Exit;
      end;
    end;
  end else begin
    error := GetLastError();
    DbgPrint('\terror code = %d\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;
  Result := STATUS_SUCCESS; Exit;
end;

function MirrorSetFileAttributes(
    FileName: LPCWSTR; FileAttributes: DWORD; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('SetFileAttributes %s 0x%x\n', [filePath, FileAttributes]);

  if (FileAttributes <> 0) then begin
    if (not SetFileAttributesW(filePath, FileAttributes)) then begin
      error := GetLastError();
      DbgPrint('\terror code = %d\n\n', [error]);
      Result := DokanNtStatusFromWin32(error); Exit;
    end;
  end else begin
    // case FileAttributes == 0 :
    // MS-FSCC 2.6 File Attributes : There is no file attribute with the value 0x00000000
    // because a value of 0x00000000 in the FileAttributes field means that the file attributes for this file MUST NOT be changed when setting basic information for the file
    DbgPrint('Set 0 to FileAttributes means MUST NOT be changed. Didn''t call ' +
             'SetFileAttributes function. \n');
  end;

  DbgPrint('\n');
  Result := STATUS_SUCCESS; Exit;
end;

function MirrorSetFileTime(FileName: LPCWSTR; var CreationTime: FILETIME;
                  var LastAccessTime: FILETIME; var LastWriteTime: FILETIME;
                  var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('SetFileTime %s\n', [filePath]);

  handle := THandle(DokanFileInfo.Context);

  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_INVALID_HANDLE; Exit;
  end;

  if (not SetFileTime(handle, @CreationTime, @LastAccessTime, @LastWriteTime)) then begin
    error := GetLastError();
    DbgPrint('\terror code = %d\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  DbgPrint('\n');
  Result := STATUS_SUCCESS; Exit;
end;

function MirrorUnlockFile(FileName: LPCWSTR; ByteOffset: LONGLONG; Length: LONGLONG;
                 var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  handle: THandle;
  length_: LARGE_INTEGER;
  offset: LARGE_INTEGER;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('UnlockFile %s\n', [filePath]);

  handle := THandle(DokanFileInfo.Context);
  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_INVALID_HANDLE; Exit;
  end;

  length_.QuadPart := Length;
  offset.QuadPart := ByteOffset;

  if (not UnlockFile(handle, offset.LowPart, offset.HighPart, length_.LowPart,
                  length_.HighPart)) then begin
    error := GetLastError();
    DbgPrint('\terror code = %d\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  DbgPrint('\tsuccess\n\n');
  Result := STATUS_SUCCESS; Exit;
end;

function MirrorGetFileSecurity(
    FileName: LPCWSTR; var SecurityInformation: SECURITY_INFORMATION;
    SecurityDescriptor: PSECURITY_DESCRIPTOR; BufferLength: ULONG;
    var LengthNeeded: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  requestingSaclInfo: Boolean;
  handle: THandle;
  DesiredAccess: DWORD;
  error: DWORD;
  securityDescriptorLength: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('GetFileSecurity %s\n', [filePath]);

  MirrorCheckFlag(SecurityInformation, FILE_SHARE_READ, 'FILE_SHARE_READ');
  MirrorCheckFlag(SecurityInformation, OWNER_SECURITY_INFORMATION, 'OWNER_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, GROUP_SECURITY_INFORMATION, 'GROUP_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, DACL_SECURITY_INFORMATION, 'DACL_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, SACL_SECURITY_INFORMATION, 'SACL_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, LABEL_SECURITY_INFORMATION, 'LABEL_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, ATTRIBUTE_SECURITY_INFORMATION, 'ATTRIBUTE_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, SCOPE_SECURITY_INFORMATION, 'SCOPE_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation,
                  PROCESS_TRUST_LABEL_SECURITY_INFORMATION, 'PROCESS_TRUST_LABEL_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, BACKUP_SECURITY_INFORMATION, 'BACKUP_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, PROTECTED_DACL_SECURITY_INFORMATION, 'PROTECTED_DACL_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, PROTECTED_SACL_SECURITY_INFORMATION, 'PROTECTED_SACL_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, UNPROTECTED_DACL_SECURITY_INFORMATION, 'UNPROTECTED_DACL_SECURITY_INFORMATION');
  MirrorCheckFlag(SecurityInformation, UNPROTECTED_SACL_SECURITY_INFORMATION, 'UNPROTECTED_SACL_SECURITY_INFORMATION');

  requestingSaclInfo := ((SecurityInformation and SACL_SECURITY_INFORMATION <> 0) or
                        (SecurityInformation and BACKUP_SECURITY_INFORMATION <> 0));

  if (not g_HasSeSecurityPrivilege) then begin
    SecurityInformation := SecurityInformation and not SACL_SECURITY_INFORMATION;
    SecurityInformation := SecurityInformation and not BACKUP_SECURITY_INFORMATION;
  end;

  DesiredAccess := READ_CONTROL;
  if (requestingSaclInfo and g_HasSeSecurityPrivilege) then begin
    DesiredAccess := DesiredAccess or ACCESS_SYSTEM_SECURITY;
  end;
  DbgPrint('  Opening new handle with READ_CONTROL access\n');
  handle := CreateFileW(
      filePath,
      DesiredAccess,
      FILE_SHARE_WRITE or FILE_SHARE_READ or FILE_SHARE_DELETE,
      nil, // security attribute
      OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS, // or FILE_FLAG_NO_BUFFERING,
      0);

  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    error := GetLastError();
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  if (not GetUserObjectSecurity(handle, SecurityInformation, SecurityDescriptor,
                             BufferLength, LengthNeeded)) then begin
    error := GetLastError();
    if (error = ERROR_INSUFFICIENT_BUFFER) then begin
      DbgPrint('  GetUserObjectSecurity error: ERROR_INSUFFICIENT_BUFFER\n');
      CloseHandle(handle);
      Result := STATUS_BUFFER_OVERFLOW; Exit;
    end else begin
      DbgPrint('  GetUserObjectSecurity error: %d\n', [error]);
      CloseHandle(handle);
      Result := DokanNtStatusFromWin32(error); Exit;
    end;
  end;

  // Ensure the Security Descriptor Length is set
  securityDescriptorLength :=
      GetSecurityDescriptorLength(SecurityDescriptor);
  DbgPrint('  GetUserObjectSecurity return true,  *LengthNeeded = ' +
           'securityDescriptorLength \n');
  LengthNeeded := securityDescriptorLength;

  CloseHandle(handle);

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorSetFileSecurity(
    FileName: LPCWSTR; var SecurityInformation: SECURITY_INFORMATION;
    SecurityDescriptor: PSECURITY_DESCRIPTOR; SecurityDescriptorLength: ULONG;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  handle: THandle;
  filePath: WCHAR_PATH;
  error: DWORD;
begin
  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('SetFileSecurity %s\n', [filePath]);

  handle := THandle(DokanFileInfo.Context);
  if (handle = 0) or (handle = INVALID_HANDLE_VALUE) then begin
    DbgPrint('\tinvalid handle\n\n');
    Result := STATUS_INVALID_HANDLE; Exit;
  end;

  if (not SetUserObjectSecurity(handle, SecurityInformation, SecurityDescriptor)) then begin
    error := GetLastError();
    DbgPrint('  SetUserObjectSecurity error: %d\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;
  Result := STATUS_SUCCESS; Exit;
end;

function MirrorGetVolumeInformation(
    VolumeNameBuffer: LPWSTR; VolumeNameSize: DWORD; var VolumeSerialNumber: DWORD;
    var MaximumComponentLength: DWORD; var FileSystemFlags: DWORD;
    FileSystemNameBuffer: LPWSTR; FileSystemNameSize: DWORD;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  volumeRoot: array [0 .. 3] of WCHAR;
  fsFlags: DWORD;
begin
  fsFlags := 0;

  lstrcpynW(VolumeNameBuffer, 'DOKAN', VolumeNameSize);
  if (@VolumeSerialNumber <> nil) then
    VolumeSerialNumber := $19831116;
  if (@MaximumComponentLength <> nil) then
    MaximumComponentLength := 255;
  if (@FileSystemFlags <> nil) then
    FileSystemFlags := FILE_CASE_SENSITIVE_SEARCH or FILE_CASE_PRESERVED_NAMES or
                     FILE_SUPPORTS_REMOTE_STORAGE or FILE_UNICODE_ON_DISK or
                     FILE_PERSISTENT_ACLS or FILE_NAMED_STREAMS;

  volumeRoot[0] := RootDirectory[0];
  volumeRoot[1] := ':';
  volumeRoot[2] := '\';
  volumeRoot[3] := #0;

  if (GetVolumeInformationW(@volumeRoot[0], nil, 0, nil, MaximumComponentLength,
                           fsFlags, FileSystemNameBuffer,
                           FileSystemNameSize)) then begin

    if (@FileSystemFlags <> nil) then
      FileSystemFlags := FileSystemFlags and fsFlags;

    if (@MaximumComponentLength <> nil) then begin
      DbgPrint('GetVolumeInformation: max component length %u\n',
               [MaximumComponentLength]);
    end;
    if (@FileSystemNameBuffer <> nil) then begin
      DbgPrint('GetVolumeInformation: file system name %s\n',
               [FileSystemNameBuffer]);
    end;
    if (@FileSystemFlags <> nil) then begin
      DbgPrint('GetVolumeInformation: got file system flags 0x%08x,' +
               ' returning 0x%08x\n',
               [fsFlags, FileSystemFlags]);
    end;
  end else begin

    DbgPrint('GetVolumeInformation: unable to query underlying fs,' +
             ' using defaults.  Last error = %u\n',
             [GetLastError()]);

    // File system name could be anything up to 10 characters.
    // But Windows check few feature availability based on file system name.
    // For this, it is recommended to set NTFS or FAT here.
    lstrcpynW(FileSystemNameBuffer, 'NTFS', FileSystemNameSize);
  end;

  Result := STATUS_SUCCESS; Exit;
end;

(*
//Uncomment for personalize disk space
function MirrorDokanGetDiskFreeSpace(
    var FreeBytesAvailable: ULONGLONG; var TotalNumberOfBytes: ULONGLONG;
    var TotalNumberOfFreeBytes: ULONGLONG; var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;
begin
  FreeBytesAvailable := (512 * 1024 * 1024);
  TotalNumberOfBytes := 9223372036854775807;
  TotalNumberOfFreeBytes := 9223372036854775807;

  Result := STATUS_SUCCESS; Exit;
end;
*)

(**
 * Avoid #include <winternl.h> which as conflict with FILE_INFORMATION_CLASS
 * definition.
 * This only for MirrorFindStreams. Link with ntdll.lib still required.
 *
 * Not needed if you're not using NtQueryInformationFile!
 *
 * BEGIN
 */
typedef struct _IO_STATUS_BLOCK {
  union {
    NTSTATUS Status;
    PVOID Pointer;
  } DUMMYUNIONNAME;

  ULONG_PTR Information;
} IO_STATUS_BLOCK, *PIO_STATUS_BLOCK;

NTSYSCALLAPI NTSTATUS NTAPI NtQueryInformationFile(
    _In_ HANDLE FileHandle, _Out_ PIO_STATUS_BLOCK IoStatusBlock,
    _Out_writes_bytes_(Length) PVOID FileInformation, _In_ ULONG Length,
    _In_ FILE_INFORMATION_CLASS FileInformationClass);
/**
 * END
 *)

function MirrorFindStreams(FileName: LPCWSTR; FillFindStreamData: TDokanFillFindStreamData;
                  var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  filePath: WCHAR_PATH;
  hFind: THandle;
  findData: WIN32_FIND_STREAM_DATA;
  error: DWORD;
  count: Integer;
begin
  count := 0;

  GetFilePath(filePath, DOKAN_MAX_PATH, FileName);

  DbgPrint('FindStreams :%s\n', [filePath]);

  hFind := FindFirstStreamW(filePath, FindStreamInfoStandard, @findData, 0);

  if (hFind = INVALID_HANDLE_VALUE) then begin
    error := GetLastError();
    DbgPrint('\tinvalid file handle. Error is %u\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  FillFindStreamData(findData, DokanFileInfo);
  Inc(count);

  while (FindNextStreamW(hFind, @findData) <> False) do begin
    FillFindStreamData(findData, DokanFileInfo);
    Inc(count);
  end;

  error := GetLastError();
  Windows.FindClose(hFind);

  if (error <> ERROR_HANDLE_EOF) then begin
    DbgPrint('\tFindNextStreamW error. Error is %u\n\n', [error]);
    Result := DokanNtStatusFromWin32(error); Exit;
  end;

  DbgPrint('\tFindStreams return %d entries in %s\n\n', [count, filePath]);

  Result := STATUS_SUCCESS; Exit;
end;

function MirrorMounted(var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
begin
  DbgPrint('Mounted\n');
  Result := STATUS_SUCCESS; Exit;
end;

function MirrorUnmounted(var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
begin
  DbgPrint('Unmounted\n');
  Result := STATUS_SUCCESS; Exit;
end;

function CtrlHandler(dwCtrlType: DWORD): BOOL; stdcall;
begin
  case (dwCtrlType) of
    CTRL_C_EVENT,
    CTRL_BREAK_EVENT,
    CTRL_CLOSE_EVENT,
    CTRL_LOGOFF_EVENT,
    CTRL_SHUTDOWN_EVENT: begin
      SetConsoleCtrlHandler(@CtrlHandler, False);
      DokanRemoveMountPoint(MountPoint);
      Result := True;
    end;
  else
    Result := False;
  end;
end;

procedure ShowUsage();
begin
    Write(ErrOutput, escape_replace('mirror.exe\n' +
    '  /r RootDirectory (ex. /r c:\\test)\t\t Directory source to mirror.\n' +
    '  /l MountPoint (ex. /l m)\t\t\t Mount point. Can be M:\\ (drive letter) or empty NTFS folder C:\\mount\\dokan .\n' +
    '  /t ThreadCount (ex. /t 5)\t\t\t Number of threads to be used internally by Dokan library.\n\t\t\t\t\t\t More threads will handle more event at the same time.\n' +
    '  /d (enable debug output)\t\t\t Enable debug output to an attached debugger.\n' +
    '  /s (use stderr for output)\t\t\t Enable debug output to stderr.\n' +
    '  /n (use network drive)\t\t\t Show device as network device.\n' +
    '  /m (use removable drive)\t\t\t Show device as removable media.\n' +
    '  /w (write-protect drive)\t\t\t Read only filesystem.\n' +
    '  /o (use mount manager)\t\t\t Register device to Windows mount manager.\n\t\t\t\t\t\t This enables advanced Windows features like recycle bin and more...\n' +
    '  /c (mount for current session only)\t\t Device only visible for current user session.\n' +
    '  /u (UNC provider name ex. \\localhost\\myfs)\t UNC name used for network volume.\n' +
    '  /p (Impersonate Caller User)\t\t\t Impersonate Caller User when getting the handle in CreateFile for operations.\n\t\t\t\t\t\t This option requires administrator right to work properly.\n' +
    '  /a Allocation unit size (ex. /a 512)\t\t Allocation Unit Size of the volume. This will behave on the disk file size.\n' +
    '  /k Sector size (ex. /k 512)\t\t\t Sector Size of the volume. This will behave on the disk file size.\n' +
    '  /f User mode Lock\t\t\t\t Enable Lockfile/Unlockfile operations. Otherwise Dokan will take care of it.\n' +
    '  /i (Timeout in Milliseconds ex. /i 30000)\t Timeout until a running operation is aborted and the device is unmounted.\n\n' +
    'Examples:\n' +
    '\tmirror.exe /r C:\\Users /l M:\t\t\t# Mirror C:\\Users as RootDirectory into a drive of letter M:\\.\n' +
    '\tmirror.exe /r C:\\Users /l C:\\mount\\dokan\t# Mirror C:\\Users as RootDirectory into NTFS folder C:\\mount\\dokan.\n' +
    '\tmirror.exe /r C:\\Users /l M: /n /u \\myfs\\myfs1\t# Mirror C:\\Users as RootDirectory into a network drive M:\\. with UNC \\\\myfs\\myfs1\n\n' +
    'Unmount the drive with CTRL + C in the console or alternatively via ''dokanctl /u MountPoint''.\n'));
end;

function wmain(argc: ULONG; argv: array of string): Integer;
var
  status: Integer;
  command: ULONG;
  dokanOperations: PDOKAN_OPERATIONS;
  dokanOptions: PDOKAN_OPTIONS;
begin
  New(dokanOperations);
  if (dokanOperations = nil) then begin
    Result := EXIT_FAILURE; Exit;
  end;
  New(dokanOptions);
  if (dokanOptions = nil) then begin
    Dispose(dokanOperations);
    Result := EXIT_FAILURE; Exit;
  end;

  if (argc < 3) then begin
    ShowUsage();
    Dispose(dokanOperations);
    Dispose(dokanOptions);
    Result := EXIT_FAILURE; Exit;
  end;

  g_DebugMode := False;
  g_UseStdErr := False;

  ZeroMemory(dokanOptions, SizeOf(DOKAN_OPTIONS));
  dokanOptions^.Version := DOKAN_VERSION;
  dokanOptions^.ThreadCount := 0; // use default

  command := 1;
  while (command < argc) do begin
    case (UpCase(argv[command][2])) of
      'R': begin
        Inc(command);
        lstrcpynW(RootDirectory, PWideChar(WideString(argv[command])), DOKAN_MAX_PATH);
        DbgPrint('RootDirectory: %s\n', [RootDirectory]);
      end;
      'L': begin
        Inc(command);
        lstrcpynW(MountPoint, PWideChar(WideString(argv[command])), DOKAN_MAX_PATH);
        dokanOptions^.MountPoint := MountPoint;
      end;
      'T': begin
        Inc(command);
        dokanOptions^.ThreadCount := StrToInt(argv[command]);
      end;
      'D': begin
        g_DebugMode := True;
      end;
      'S': begin
        g_UseStdErr := True;
      end;
      'N': begin
        dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_NETWORK;
      end;
      'M': begin
        dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_REMOVABLE;
      end;
      'W': begin
        dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_WRITE_PROTECT;
      end;
      'O': begin
        dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_MOUNT_MANAGER;
      end;
      'C': begin
        dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_CURRENT_SESSION;
      end;
      'F': begin
        dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_FILELOCK_USER_MODE;
      end;
      'U': begin
        Inc(command);
        lstrcpynW(UNCName, PWideChar(WideString(argv[command])), DOKAN_MAX_PATH);
        dokanOptions^.UNCName := UNCName;
        DbgPrint('UNC Name: %s\n', [UNCName]);
      end;
      'P': begin
        g_ImpersonateCallerUser := True;
      end;
      'I': begin
        Inc(command);
        dokanOptions^.Timeout := StrToInt(argv[command]);
      end;
      'A': begin
        Inc(command);
        dokanOptions^.AllocationUnitSize := StrToInt(argv[command]);
      end;
      'K': begin
        Inc(command);
        dokanOptions^.SectorSize := StrToInt(argv[command]);
      end;
    else
      Writeln(ErrOutput, 'unknown command: ', argv[command]);
      Dispose(dokanOperations);
      Dispose(dokanOptions);
      Result := EXIT_FAILURE; Exit;
    end;
    Inc(command);
  end;

  if (UNCName <> '') and
      (dokanOptions^.Options and DOKAN_OPTION_NETWORK = 0) then begin
    Writeln(
        ErrOutput,
        '  Warning: UNC provider name should be set on network drive only.');
  end;

  if (dokanOptions^.Options and DOKAN_OPTION_NETWORK <> 0) and
     (dokanOptions^.Options and DOKAN_OPTION_MOUNT_MANAGER <> 0) then begin
    Writeln(ErrOutput, 'Mount manager cannot be used on network drive.');
    Dispose(dokanOperations);
    Dispose(dokanOptions);
    Result := EXIT_FAILURE; Exit;
  end;

  if (dokanOptions^.Options and DOKAN_OPTION_MOUNT_MANAGER = 0) and
     (MountPoint = '') then begin
    Writeln(ErrOutput, 'Mount Point required.');
    Dispose(dokanOperations);
    Dispose(dokanOptions);
    Result := EXIT_FAILURE; Exit;
  end;

  if (dokanOptions^.Options and DOKAN_OPTION_MOUNT_MANAGER <> 0) and
     (dokanOptions^.Options and DOKAN_OPTION_CURRENT_SESSION <> 0) then begin
    Writeln(ErrOutput,
             'Mount Manager always mount the drive for all user sessions.');
    Dispose(dokanOperations);
    Dispose(dokanOptions);
    Result := EXIT_FAILURE; Exit;
  end;

  if (not SetConsoleCtrlHandler(@CtrlHandler, True)) then begin
    Writeln(ErrOutput, 'Control Handler is not set.');
  end;

  // Add security name privilege. Required here to handle GetFileSecurity
  // properly.
  g_HasSeSecurityPrivilege := AddSeSecurityNamePrivilege();
  if (not g_HasSeSecurityPrivilege) then begin
    Writeln(ErrOutput, 'Failed to add security privilege to process');
    Writeln(ErrOutput,
             #09'=> GetFileSecurity/SetFileSecurity may not work properly');
    Writeln(ErrOutput, #09'=> Please restart mirror sample with administrator ' +
                     'rights to fix it');
  end;

  if (g_ImpersonateCallerUser and not g_HasSeSecurityPrivilege) then begin
    Writeln(ErrOutput, 'Impersonate Caller User requires administrator right to ' +
                     'work properly\n');
    Writeln(ErrOutput, #09'=> Other users may not use the drive properly\n');
    Writeln(ErrOutput, #09'=> Please restart mirror sample with administrator ' +
                     'rights to fix it\n');
  end;

  if (g_DebugMode) then begin
    dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_DEBUG;
  end;
  if (g_UseStdErr) then begin
    dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_STDERR;
  end;

  dokanOptions^.Options := dokanOptions^.Options or DOKAN_OPTION_ALT_STREAM;

  ZeroMemory(dokanOperations, SizeOf(DOKAN_OPERATIONS));
  dokanOperations^.ZwCreateFile := MirrorCreateFile;
  dokanOperations^.Cleanup := MirrorCleanup;
  dokanOperations^.CloseFile := MirrorCloseFile;
  dokanOperations^.ReadFile := MirrorReadFile;
  dokanOperations^.WriteFile := MirrorWriteFile;
  dokanOperations^.FlushFileBuffers := MirrorFlushFileBuffers;
  dokanOperations^.GetFileInformation := MirrorGetFileInformation;
  dokanOperations^.FindFiles := MirrorFindFiles;
  dokanOperations^.FindFilesWithPattern := nil;
  dokanOperations^.SetFileAttributes := MirrorSetFileAttributes;
  dokanOperations^.SetFileTime := MirrorSetFileTime;
  dokanOperations^.DeleteFile := MirrorDeleteFile;
  dokanOperations^.DeleteDirectory := MirrorDeleteDirectory;
  dokanOperations^.MoveFile := MirrorMoveFile;
  dokanOperations^.SetEndOfFile := MirrorSetEndOfFile;
  dokanOperations^.SetAllocationSize := MirrorSetAllocationSize;
  dokanOperations^.LockFile := MirrorLockFile;
  dokanOperations^.UnlockFile := MirrorUnlockFile;
  dokanOperations^.GetFileSecurity := MirrorGetFileSecurity;
  dokanOperations^.SetFileSecurity := MirrorSetFileSecurity;
  dokanOperations^.GetDiskFreeSpace := nil; // MirrorDokanGetDiskFreeSpace;
  dokanOperations^.GetVolumeInformation := MirrorGetVolumeInformation;
  dokanOperations^.Unmounted := MirrorUnmounted;
  dokanOperations^.FindStreams := MirrorFindStreams;
  dokanOperations^.Mounted := MirrorMounted;

  status := DokanMain(dokanOptions^, dokanOperations^);
  case (status) of
    DOKAN_SUCCESS:
      Writeln(ErrOutput, 'Success');
    DOKAN_ERROR:
      Writeln(ErrOutput, 'Error');
    DOKAN_DRIVE_LETTER_ERROR:
      Writeln(ErrOutput, 'Bad Drive letter');
    DOKAN_DRIVER_INSTALL_ERROR:
      Writeln(ErrOutput, 'Can''t install driver');
    DOKAN_START_ERROR:
      Writeln(ErrOutput, 'Driver something wrong');
    DOKAN_MOUNT_ERROR:
      Writeln(ErrOutput, 'Can''t assign a drive letter');
    DOKAN_MOUNT_POINT_ERROR:
      Writeln(ErrOutput, 'Mount point error');
    DOKAN_VERSION_ERROR:
      Writeln(ErrOutput, 'Version error');
  else
    Writeln(ErrOutput, 'Unknown error: ', status);
  end;

  Dispose(dokanOptions);
  Dispose(dokanOperations);
  Result := EXIT_SUCCESS; Exit;
end;

var
  i: Integer;
  argc: ULONG;
  argv: array of string;

begin
  IsMultiThread := True;

  lstrcpyW(RootDirectory, 'C:');
  lstrcpyW(MountPoint, 'M:\');
  lstrcpyW(UNCName, '');

  argc := 1 + ParamCount();
  SetLength(argv, argc);
  for i := 0 to argc - 1 do
    argv[i] := ParamStr(i);

  try
    ExitCode := wmain(argc, argv);
  except
    ExitCode := EXIT_FAILURE;
  end;
end.
