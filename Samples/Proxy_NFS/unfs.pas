unit unfs;



interface

uses windows,sysutils,classes,
    libnfs,
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

function _Mount(mount:string):boolean;stdcall
function _unMount: ntstatus;stdcall
function _Discover(items:tstrings):boolean;stdcall;

implementation

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
var
nfsdirent:pnfsdirent ;
nfsdir:pointer;
stat:nfs_stat_64;
str_type,str_size:string;
p:pchar;
findData: WIN32_FIND_DATAW;
ws:widestring;
systime_:systemtime;
filetime_:filetime;
path:string;
begin
result:=2;
//
path := WideCharToString(filename);
path:=stringreplace(path,'\','/',[rfReplaceAll, rfIgnoreCase]);
if path='' then ;

//
if nfs=nil then exit;
if nfs_opendir(nfs, pchar(path), @nfsdir) <>0 then //raise exception.create(strpas( nfs_get_error(nfs)));
  begin
  Exit;
  end;
//
if nfs_chdir (nfs,pchar(path))<>0 then //;raise exception.create(strpas( nfs_get_error(nfs)));
  begin
  exit;
  end;
//

nfsdirent := nfs_readdir(nfs, nfsdir);

while nfsdirent <>nil do
  begin
  FillChar (findData ,sizeof(findData ),0);  
  case (nfsdirent^.type_) of
     1:findData.dwFileAttributes := FILE_ATTRIBUTE_NORMAL; //str_type :='<FILE>'; //filename
     2:findData.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;//str_type :='<DIR>';
     else str_type :='';
  end;
  if nfs_stat64(nfs,nfsdirent^.name,@stat)<>0 then
  begin
  //is a directory?
  end
  else
  begin
    if findData.dwFileAttributes = FILE_ATTRIBUTE_NORMAL then
    begin
    findData.nFileSizeHigh :=LARGE_INTEGER(stat.nfs_size).HighPart;
    findData.nFileSizeLow  :=LARGE_INTEGER(stat.nfs_size).LowPart;
    //str_size :=inttostr(stat.nfs_size );
    end;
  end;
  DateTimeToSystemTime(UNIXTimeToDateTimeFAST(stat.nfs_ctime),systime_);
  SystemTimeToFileTime(systime_ ,filetime_);
  findData.ftCreationTime :=filetime_ ;
  DateTimeToSystemTime(UNIXTimeToDateTimeFAST(stat.nfs_atime),systime_);
  SystemTimeToFileTime(systime_ ,filetime_);
  findData.ftLastAccessTime:=filetime_ ;
  DateTimeToSystemTime(UNIXTimeToDateTimeFAST(stat.nfs_mtime),systime_);
  SystemTimeToFileTime(systime_ ,filetime_);
  findData.ftLastWriteTime :=filetime_ ;

  
  //writeln(str_type+#9+nfsdirent^.name+#9+str_size);
  //StrPLCopy(@findData.cFileName[0],nfsdirent^.name,260);
  ws:=widestring(nfsdirent^.name);
  Move(ws[1],  findData.cFileName,Length(ws)*Sizeof(Widechar));
  FillFindData(findData, DokanFileInfo);
  nfsdirent := nfs_readdir(nfs, nfsdir);
  end; //while nfsdirent <>nil do
//
nfs_closedir(nfs,nfsdir );
Result := STATUS_SUCCESS;
end;

function _GetFileInformation(
    FileName: LPCWSTR; var HandleFileInformation: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  handle: THandle;
  error: DWORD;
  find: WIN32_FIND_DATAW;
  findHandle: THandle;
  opened: Boolean;
  //
  path:string;
  stat:nfs_stat_64;
  systime_:systemtime;
  filetime_:filetime;
begin
  result:=STATUS_NO_SUCH_FILE;

  //writeln('_GetFileInformation:'+FileName);

path := WideCharToString(filename);
path:=stringreplace(path,'\','/',[rfReplaceAll, rfIgnoreCase]);

  if nfs_stat64(nfs,pchar(path),@stat)<>0 then
  begin
  writeln(strpas( nfs_get_error(nfs)));
  exit;
  end
  else
  begin
  //writeln(path+':'+inttostr(stat.nfs_size  )+','+inttostr(stat.nfs_blksize )+','+inttostr(stat.nfs_blocks ));
  //writeln(path+':'+inttostr(stat.nfs_dev   )+','+inttostr(stat.nfs_ino  )+','+inttostr(stat.nfs_nlink  ));
  if stat.nfs_nlink=1
    then  HandleFileInformation.dwFileAttributes := FILE_ATTRIBUTE_NORMAL
    else HandleFileInformation.dwFileAttributes :=FILE_ATTRIBUTE_DIRECTORY;
  //writeln('dwFileAttributes:'+inttostr(HandleFileInformation.dwFileAttributes));
  DateTimeToSystemTime(UNIXTimeToDateTimeFAST(stat.nfs_ctime),systime_);
  SystemTimeToFileTime(systime_ ,filetime_);
  HandleFileInformation.ftCreationTime :=filetime_ ;
  DateTimeToSystemTime(UNIXTimeToDateTimeFAST(stat.nfs_atime),systime_);
  SystemTimeToFileTime(systime_ ,filetime_);
  HandleFileInformation.ftLastAccessTime:=filetime_ ;
  DateTimeToSystemTime(UNIXTimeToDateTimeFAST(stat.nfs_mtime),systime_);
  SystemTimeToFileTime(systime_ ,filetime_);
  HandleFileInformation.ftLastWriteTime :=filetime_ ;
      if stat.nfs_size>0 then
      begin
      HandleFileInformation.nFileSizeHigh := LARGE_INTEGER(stat.nfs_size).highPart;
      HandleFileInformation.nFileSizeLow := LARGE_INTEGER(stat.nfs_size).LowPart;
      end;

  Result := STATUS_SUCCESS;
  end;

  end;

function _ReadFile(FileName: LPCWSTR; var Buffer;
                        BufferLength: DWORD;
                        var ReadLength: DWORD;
                        Offset: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  handle: THandle;
  offset_: ULONG;
  opened: Boolean;
  error: DWORD;
  distanceToMove: LARGE_INTEGER;
  //
  path:string;
  nfsfh:pointer;
begin
  result:=STATUS_NO_SUCH_FILE;


  path := WideCharToString(filename);

  path:=stringreplace(path,'\','/',[rfReplaceAll, rfIgnoreCase]);
  if path='/' then begin exit;end;
  if DokanFileInfo.Context <>0 then nfsfh :=pointer(DokanFileInfo.Context);  
  if DokanFileInfo.Context =0 then
    if nfs_open (nfs,pchar(path) ,O_RDONLY ,@nfsfh)<>0  then
      begin
      writeln(strpas( nfs_get_error(nfs)));
      exit;
      end;
  if DokanFileInfo.Context =0 then
    begin
    DokanFileInfo.Context:=integer(nfsfh);
    end;
//
//if nfs_fstat64(nfs,nfsfh,@stat)<>0 then raise exception.create(strpas( nfs_get_error(nfs)));
//

//ReadLength := nfs_read(nfs, nfsfh, BufferLength , @buffer);
ReadLength := nfs_pread(nfs, nfsfh, Offset,BufferLength , @buffer);
if ReadLength<0 then
  begin
  writeln(strpas( nfs_get_error(nfs)));
  //nfs_close(nfs, nfsfh);
  exit;
  end;

//
//if nfs_close(nfs, nfsfh)<>0 then ;//raise exception.create(strpas( nfs_get_error(nfs)));


  Result := STATUS_SUCCESS; Exit;
end;

function _WriteFile(FileName: LPCWSTR; const Buffer;
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
  //
  path:string;
  nfsfh:pointer;
begin
  result:=STATUS_NO_SUCH_FILE;

  path := WideCharToString(filename);
  path:=stringreplace(path,'\','/',[rfReplaceAll, rfIgnoreCase]);
  if path='/' then begin exit;end;
  if DokanFileInfo.Context <>0 then nfsfh :=pointer(DokanFileInfo.Context);
  if DokanFileInfo.Context =0 then
    if nfs_open (nfs,pchar(path) ,O_RDWR or O_TRUNC or O_APPEND   ,@nfsfh)<>0  then
      begin
      writeln(strpas( nfs_get_error(nfs)));
      exit;
      end;
  //lets store the handle, or rather pointer..., to our file
  if DokanFileInfo.Context =0 then
    begin
    DokanFileInfo.Context:=integer(nfsfh);
    if nfs_truncate (nfs,pchar(path),0)<>0 then
      begin
      writeln(strpas( nfs_get_error(nfs)));
      end;//
    end;
//
//if nfs_fstat64(nfs,nfsfh,@stat)<>0 then raise exception.create(strpas( nfs_get_error(nfs)));
//
NumberOfBytesWritten := nfs_pwrite(nfs, nfsfh, Offset,NumberOfBytesToWrite , @buffer);
if NumberOfBytesWritten<0 then
  begin
  writeln(strpas( nfs_get_error(nfs)));
  //nfs_close(nfs, nfsfh);
  exit;
  end;

//we will close it in the onclosefile event
//if nfs_close(nfs, nfsfh)<>0 then ;//raise exception.create(strpas( nfs_get_error(nfs)));


  Result := STATUS_SUCCESS; Exit;
end;

function _MoveFile(FileName: LPCWSTR; // existing file name
               NewFileName: LPCWSTR; ReplaceIfExisting: BOOL;
               var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  old_path,new_path:string;
begin

  old_path := WideCharToString(filename);
  old_path:=stringreplace(old_path,'\','/',[rfReplaceAll, rfIgnoreCase]);
  new_path := WideCharToString(NewFileName);
  new_path:=stringreplace(new_path,'\','/',[rfReplaceAll, rfIgnoreCase]);
  if nfs_rename (nfs,pchar(old_path),pchar(new_path))<>0 then
  begin
  writeln(strpas( nfs_get_error(nfs)));
  end
  else result:=STATUS_SUCCESS;


end;

procedure _Cleanup(FileName: LPCWSTR;
                        var DokanFileInfo: DOKAN_FILE_INFO); stdcall;
var
   path:string;
begin
//

path := WideCharToString(filename);
 path:=stringreplace(path,'\','/',[rfReplaceAll, rfIgnoreCase]);
 if path='/' then begin exit;end;

if DokanFileInfo.DeleteOnClose=true then
  begin
  if DokanFileInfo.IsDirectory =false then
    begin
    //will zero file but will not delete it
    //if nfs_truncate(nfs,pchar(path),0)<>0 then
    nfs_chdir (nfs,'/');
    if nfs_unlink (nfs,pchar(path))<>0 then
    begin
    writeln('Cleanup:'+strpas( nfs_get_error(nfs)));
    exit;
    end;
    end
    else
    //is a directory
    begin
    //system.delete(path,1,1);
    nfs_chdir (nfs,'/');
    if nfs_rmdir (nfs,pchar(path))<>0 then
    begin
    writeln('Cleanup:'+strpas( nfs_get_error(nfs)));
    exit;
    end;
    end;
  end;
//
exit;

end;

procedure _CloseFile(FileName: LPCWSTR;
                          var DokanFileInfo: DOKAN_FILE_INFO); stdcall;
var
  filePath: WCHAR_PATH;
begin

if DokanFileInfo.Context<>0 then
  begin
  //if we ever keep a pointer to the nfs file...
  try
  if DokanFileInfo.Context <>0
  then nfs_close (nfs,pointer(DokanFileInfo.Context ));
  except
  on e:exception do writeln(e.message);
  end;
  DokanFileInfo.Context := 0;
  end;
end;
//

function _CreateFile(FileName: LPCWSTR; var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;
                 DesiredAccess: ACCESS_MASK; FileAttributes: ULONG;
                 ShareAccess: ULONG; CreateDisposition: ULONG;
                 CreateOptions: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var

  fileAttr: DWORD;
  status: NTSTATUS;
  creationDisposition: DWORD;
  fileAttributesAndFlags: DWORD;
  error: DWORD;
  genericDesiredAccess: ACCESS_MASK;
  path:string;
  stat:nfs_stat_64;
  nfsfh:pointer;
begin

  result := STATUS_SUCCESS;
  //DokanFileInfo.Context :=int64(nfsfh);
  //we will handle creationDisposition later

 path := WideCharToString(filename);
 path:=stringreplace(path,'\','/',[rfReplaceAll, rfIgnoreCase]);
 if path='/' then begin exit;end;
 try
 if nfs_stat64(nfs,pchar(path),@stat)<>0 then
  begin
  result:=STATUS_NO_SUCH_FILE;
  end
  else
  begin
  if stat.nfs_nlink <>1 then
    begin
    //this is a directory
    fileAttr := FILE_ATTRIBUTE_DIRECTORY;
    if (CreateOptions and FILE_NON_DIRECTORY_FILE = 0) then
      begin
        DokanFileInfo.IsDirectory := True;
        // Needed by FindFirstFile to list files in it
        // TODO: use ReOpenFile in FindFiles to set share read temporary
        ShareAccess := ShareAccess or FILE_SHARE_READ;
      end
      else
      begin // FILE_NON_DIRECTORY_FILE - Cannot open a dir as a file
        DbgPrint('\tCannot open a dir as a file\n');
        Result := STATUS_FILE_IS_A_DIRECTORY;
        Exit;
      end;
    end
    else
    begin
    //this is a file

    end;
  end;
 except
 //
 DbgPrint('\tnfs_stat64 error\n');
 end;

   DokanMapKernelToUserCreateFileFlags(
      DesiredAccess, FileAttributes, CreateOptions, CreateDisposition,
      @genericDesiredAccess, @fileAttributesAndFlags, @creationDisposition);

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

if (DokanFileInfo.IsDirectory) then
  // It is a create directory request
  begin
  if (creationDisposition = CREATE_NEW) then
       begin
        //We create folder
        //nfs_chdir (nfs,pchar('.'));
        //system.Delete(path,1,1);
        if nfs_mkdir (nfs,pchar(path))<>0 then
        begin
        writeln(strpas( nfs_get_error(nfs)));
        error:=ERROR_ALREADY_EXISTS;
        // Fail to create folder for OPEN_ALWAYS is not an error
        if (error <> ERROR_ALREADY_EXISTS) or
           (creationDisposition = CREATE_NEW) then
        begin
          DbgPrint('\terror code = %d\n\n', [error]);
          status := DokanNtStatusFromWin32(error);
        end;
        end//if nfs_mkdir (nfs,pchar(path))<>0 then
        else result := STATUS_SUCCESS;
       end;

       //what about the below case
       {
        // Open succeed but we need to inform the driver
        // that the dir open and not created by returning STATUS_OBJECT_NAME_COLLISION
       if (creationDisposition = OPEN_ALWAYS) and
           (fileAttr <> INVALID_FILE_ATTRIBUTES) then begin
          Result := STATUS_OBJECT_NAME_COLLISION; Exit;
       }
  end
  else
  // It is a create file request
    begin
    if (creationDisposition = CREATE_NEW) then
    begin
    if nfs_creat (nfs,pchar(path),O_CREAT or O_RDWR,@nfsfh)<>0 then
      begin
      writeln(strpas( nfs_get_error(nfs)));
      end
      else result := STATUS_SUCCESS;
    if nfs_close(nfs, nfsfh)<>0 then ;
    end//if (creationDisposition = CREATE_NEW) then
    end;//if (DokanFileInfo.IsDirectory) then

end;



function _Mount(mount:string):boolean;stdcall
var
  url: pnfs_url;
begin
result:=false;

if libnfs.fLibHandle =thandle(-1) then lib_init;

if nfs=nil then nfs:=nfs_init_context;
url:=nil;
url:=nfs_parse_url_full (nfs,pchar(mount));
if url=nil  then
  begin
  writeln(strpas( nfs_get_error(nfs)));
  exit;
  end;
//try root ?
try
//nfs_set_uid(nfs, 0);
//nfs_set_gid(nfs, 0);
except
end;

if nfs_mount(nfs,url^.server , url^.path )<>0 then
  begin
  writeln(strpas( nfs_get_error(nfs)));
  nfs_destroy_url(url);
  exit;
  end;
nfs_destroy_url(url);
//
//writeln('readmax:'+inttostr(nfs_get_readmax(nfs)));
//writeln('writemax:'+inttostr(nfs_get_writemax(nfs)));


  Result := true;
end;

function _unMount: ntstatus;stdcall
begin
  if nfs<>nil then nfs_destroy_context(nfs);
  lib_free;
  result:=STATUS_SUCCESS;
end;

function _discover(items:tstrings):boolean;stdcall;
begin
result:=nfsdiscover(items); 
end;



end.
 