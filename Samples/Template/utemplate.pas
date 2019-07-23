unit utemplate;

//dokan options
//https://dokan-dev.github.io/dokany-doc/html/struct_d_o_k_a_n___o_p_t_i_o_n_s.html

//dokan operations
//https://dokan-dev.github.io/dokany-doc/html/struct_d_o_k_a_n___o_p_e_r_a_t_i_o_n_s.html

interface

uses windows,sysutils,classes,
    wininet,
    Dokan,DokanWin ;

function UNIXTimeToDateTimeFAST(UnixTime: LongWord): TDateTime;    

function _FindFiles(FileName: LPCWSTR;
  FillFindData: TDokanFillFindData;
  var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

function _GetFileInformation(
    FileName: LPCWSTR; var HandleFileInformation: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

function _ReadFile(FileName: LPCWSTR; var Buffer;
                        BufferLength: DWORD;
                        var ReadLength: DWORD;
                        Offset: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

function _WriteFile(FileName: LPCWSTR; const Buffer;
                         NumberOfBytesToWrite: DWORD;
                         var NumberOfBytesWritten: DWORD;
                         Offset: LONGLONG;
                         var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

function _MoveFile(FileName: LPCWSTR; // existing file name
               NewFileName: LPCWSTR; ReplaceIfExisting: BOOL;
               var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

procedure _CloseFile(FileName: LPCWSTR;
                          var DokanFileInfo: DOKAN_FILE_INFO); stdcall;               

procedure _Cleanup(FileName: LPCWSTR;
                        var DokanFileInfo: DOKAN_FILE_INFO); stdcall;

function _CreateFile(FileName: LPCWSTR; var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;
                 DesiredAccess: ACCESS_MASK; FileAttributes: ULONG;
                 ShareAccess: ULONG; CreateDisposition: ULONG;
                 CreateOptions: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

function _DeleteFile(
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

function _DeleteDirectory(
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;

function _Mount(mount:string):NTSTATUS;stdcall
function _UnMount: boolean;stdcall


implementation

var
err:dword;

const
	DOKAN_MAX_PATH = MAX_PATH;

type
  WCHAR_PATH = array [0 .. DOKAN_MAX_PATH-1] of WCHAR;

function UNIXTimeToDateTimeFAST(UnixTime: LongWord): TDateTime;
begin
Result := (UnixTime / 86400) + 25569;
end;

procedure DbgPrint(format: string; const args: array of const); overload;
begin
//dummy
end;

procedure DbgPrint(fmt: string); overload;
begin
//dummy
end;


function _FindFiles(FileName: LPCWSTR;
  FillFindData: TDokanFillFindData;
  var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;
begin

Result := STATUS_SUCCESS;
end;

function _GetFileInformation(
    FileName: LPCWSTR; var HandleFileInformation: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

begin
Result := STATUS_SUCCESS;
end;

function _ReadFile(FileName: LPCWSTR; var Buffer;
                        BufferLength: DWORD;
                        var ReadLength: DWORD;
                        Offset: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

begin
  Result := STATUS_SUCCESS;
end;

function _WriteFile(FileName: LPCWSTR; const Buffer;
                         NumberOfBytesToWrite: DWORD;
                         var NumberOfBytesWritten: DWORD;
                         Offset: LONGLONG;
                         var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
begin

  Result := STATUS_SUCCESS;

end;


procedure _Cleanup(FileName: LPCWSTR;
                        var DokanFileInfo: DOKAN_FILE_INFO); stdcall;

begin
//


end;

procedure _CloseFile(FileName: LPCWSTR;
                          var DokanFileInfo: DOKAN_FILE_INFO); stdcall;

begin

end;
//

function _CreateFile(FileName: LPCWSTR; var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;
                 DesiredAccess: ACCESS_MASK; FileAttributes: ULONG;
                 ShareAccess: ULONG; CreateDisposition: ULONG;
                 CreateOptions: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;


begin

  result := STATUS_SUCCESS;
 

end;

function _DeleteFile(
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;
begin
result := STATUS_SUCCESS;
end;

function _DeleteDirectory(
    FileName: LPCWSTR;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;
begin
result := STATUS_SUCCESS;
end;

function _MoveFile (
    FileName: LPCWSTR;
    NewFileName: LPCWSTR;
    ReplaceIfExisting: BOOL;
    var DokanFileInfo: DOKAN_FILE_INFO
  ): NTSTATUS; stdcall;
begin
result := STATUS_SUCCESS;
end;


function _Mount(mount:string):NTSTATUS;stdcall;

begin

  Result := STATUS_SUCCESS;
end;

function _unMount: boolean;
begin
  result:=true
end;




end.
