unit ulibzip;

interface

uses  windows,classes,sysutils,strutils,math,
      Dokan ,
      DokanWin ,
      dateutils,
      libzip ;


function _FindFiles(FileName: LPCWSTR;
                FillFindData: TDokanFillFindData; // function pointer
                var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;


function _GetFileInformation(
    FileName: LPCWSTR; var HandleFileInformation: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

function _CreateFile(FileName: LPCWSTR; var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;
                 DesiredAccess: ACCESS_MASK; FileAttributes: ULONG;
                 ShareAccess: ULONG; CreateDisposition: ULONG;
                 CreateOptions: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

function _WriteFile(FileName: LPCWSTR; const Buffer;
                         NumberOfBytesToWrite: DWORD;
                         var NumberOfBytesWritten: DWORD;
                         Offset: LONGLONG;
                         var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
function _ReadFile(FileName: LPCWSTR; var Buffer;
                        BufferLength: DWORD;
                        var ReadLength: DWORD;
                        Offset: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

procedure _Cleanup(FileName: LPCWSTR;var DokanFileInfo: DOKAN_FILE_INFO); stdcall;
function _DeleteFile(FileName: LPCWSTR; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
function _DeleteDirectory(FileName: LPCWSTR; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;

function _Mount(filename:string):boolean; stdcall;
function _unMount:NTSTATUS; stdcall;

implementation

var
dw:dword;

procedure DbgPrint(format: string; const args: array of const); overload;
begin
//dummy
end;

procedure DbgPrint(fmt: string); overload;
begin
//dummy
end;

function GetTempDir: string;
var
  MyBuffer, MyFileName: array[0..MAX_PATH] of char;
begin
  FillChar(MyBuffer, MAX_PATH, 0);
  GetTempPath(SizeOf(MyBuffer), MyBuffer);
  Result := mybuffer;
end;

function GetTempFile(const APrefix: string): string;
var
  MyBuffer, MyFileName: array[0..MAX_PATH] of char;
begin
  FillChar(MyBuffer, MAX_PATH, 0);
  FillChar(MyFileName, MAX_PATH, 0);
  GetTempPath(SizeOf(MyBuffer), MyBuffer);
  GetTempFileName(MyBuffer, pchar(APrefix), 0, MyFileName);
  Result := MyFileName;
end;

function Occurrences(const Substring, Text: string): integer;
var
  offset: integer;
begin
  result := 0;
  offset := PosEx(Substring, Text, 1);
  while offset <> 0 do
  begin
    inc(result);
    offset := PosEx(Substring, Text, offset + length(Substring));
  end;
end;

function DateTimeToFileTime(DateTime: TDateTime): TFileTime;
const
  FileTimeBase      = -109205.0;
  FileTimeStep: Extended = 24.0 * 60.0 * 60.0 * 1000.0 * 1000.0 * 10.0; // 100 nSek per Day
var
  E: Extended;
  F64: Int64;
begin
  E := (DateTime - FileTimeBase) * FileTimeStep;
  F64 := Round(E);
  Result := TFileTime(F64);
end;

function _refresh:boolean;
var err:integer;
begin
   result:=zip_close (arch)=-1;
   err:=0;
   arch:=zip_open(pchar(zipfile),0,@err);
   if (arch=nil) or (err<>0) then
    begin
    writeln('zip_open failed:'+inttostr(err));
    result:=false;
    end
    else result:=true;
end;

function _locate(path:string;var DokanFileInfo: DOKAN_FILE_INFO):int64;
var
temp:string;
begin
result:=-1;
  //de-normalize
  temp:=stringreplace(path,'\','/',[rfReplaceAll, rfIgnoreCase]); //libzip specific
  //writeln(temp); //debug
  //a new file?
  result:=zip_name_locate(arch,pchar(temp),0);
  //a new folder?
  if result=-1 then
    begin
    result:=zip_name_locate(arch,pchar(temp+'/'),0);
    if result<>-1 then DokanFileInfo.IsDirectory :=true;
    end;

end;

{

ExtractFileDir('C:\Path\Path2') gives 'C:\Path'
ExtractFileDir('C:\Path\Path2\') gives 'C:\Path\Path2'

ExtractFileDir(ExcludeTrailingBackslash('C:\Path\Path2')) gives 'C:\Path'
ExtractFileDir(ExcludeTrailingBackslash('C:\Path\Path2\')) gives 'C:\Path'
}

//https://stackoverflow.com/questions/10314757/delphi-converting-array-variant-to-string
//VT_FILETIME = 64
function _FindFiles(FileName: LPCWSTR;
                FillFindData: TDokanFillFindData; // function pointer
                var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
i:integer;
num:int64;
stat:tzip_stat;

findData: WIN32_FIND_DATAW;
i64:int64;
temp:string;
widetemp:widestring;

begin
writeln('_FindFiles:'+FileName);
 try
 //the below should/could take place in the _open function
 if arch=nil then exit;

 num:=zip_get_num_entries(arch,0);


   //SetProgressCallback(nil, ProgressCallback); //optional
   for i := 0 to num - 1 do
   begin
   if zip_stat_index(arch,i,0,@stat)=0 then
   begin


    if 1=1 then
    begin
    temp:=stat.name;
    //remove trailing '/'
    if temp[length(temp)]='/' then system.delete(temp,length(temp),1);
    //normalize it
    temp:=stringreplace(temp,'/','\',[rfReplaceAll, rfIgnoreCase]);
    //writeln(filename+' - '+temp); //debug
    if filename=extractfiledir('\'+temp) then
    //if Occurrences('/',stat.name)<=1 then //initial cheat mode to restrict to root
      begin
      FillChar (findData ,sizeof(findData ),0);
      //
      if stat.size >0
            then findData.dwFileAttributes := FILE_ATTRIBUTE_NORMAL
            else findData.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
      //

      widetemp:=ExtractFileName(temp);
      //if widetemp[length(widetemp)]='/' then system.delete(widetemp,length(widetemp),1);
      Move(widetemp[1],  findData.cFileName,Length(widetemp)*Sizeof(Widechar));
      //
        findData.nFileSizeHigh :=LARGE_INTEGER(stat.size).HighPart;
        findData.nFileSizeLow  :=LARGE_INTEGER(stat.size).LowPart;
      //

      findData.ftCreationTime:=DateTimeToFileTime(dateutils.UnixToDateTime (int64(stat.mtime)));
      findData.ftLastAccessTime:=DateTimeToFileTime(dateutils.UnixToDateTime (int64(stat.mtime)));
      findData.ftLastWriteTime   :=DateTimeToFileTime(dateutils.UnixToDateTime (int64(stat.mtime)));

      //
      FillFindData(findData, DokanFileInfo);
      end;// if (pos('\',Itempath[i])=0) then
      end;//if string(filename)='\' then
      end; //if zip_stat_index(arch,i,0,@stat)=0 then
      end;//for i := 0 to num - 1 do

 Result := STATUS_SUCCESS;


except
 on e:exception do writeln(e.Message );
end;

end;

procedure _fseek(file_:pointer;offset:longlong);
const step:integer=1024*1024; //1MB
var
dummy:pointer;
len:integer;
begin
while offset>0 do
  begin
  len:=min(offset,step);
  dummy:=allocmem(len);
  zip_fread (file_,dummy,len);
  //writeln('read '+inttostr(len));
  freemem(dummy);
  dec(offset,len);
  end;
end;

function _ReadFile(FileName: LPCWSTR; var Buffer;
                        BufferLength: DWORD;
                        var ReadLength: DWORD;
                        Offset: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
i:integer;
dummy:pointer;
file_:pointer;
path:string;
begin
path := WideCharToString(filename);
if arch=nil then exit;
writeln('_ReadFile:'+path+' '+inttostr(BufferLength)+'@'+inttostr(Offset));

if path[1]='\' then system.delete(path,1,1);
i:=DokanFileInfo.context-1;
//if i=-1 then i:=zip_name_locate(arch,pchar(path),0);
if i=-1 then exit;
try
//
file_:=nil;
file_:=zip_fopen_index(arch,i,0);
if file_=nil then
   begin
   writeln('zip_fopen_index failed');
   exit;
   end;
//cheap way to implement seek - we small implement small chunks of buffer
{
if offset>0 then
  begin
  dummy:=allocmem(offset);
  zip_fread (file_,dummy,offset);
  freemem(dummy);
  end;
}
if offset>0 then _fseek(file_,offset);
ReadLength:= dword(zip_fread (file_,@buffer,BufferLength));
zip_fclose (file_);
//
Result := STATUS_SUCCESS;
except
on e:exception do writeln('_ReadFile:'+e.message);
end;

end;

function _WriteFile(FileName: LPCWSTR; const Buffer;
                         NumberOfBytesToWrite: DWORD;
                         var NumberOfBytesWritten: DWORD;
                         Offset: LONGLONG;
                         var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  path,tempfile:string;
  data,source,file_:pointer; //=nil; only if fpc...
  stat:tzip_stat;
  i:integer;
  size:int64;
  fs:TFileStream;
begin
path := WideCharToString(filename);
if arch=nil then exit;
writeln('_WriteFile: '+ path+' '+inttostr(NumberOfBytesToWrite)+'@'+inttostr(Offset) );

i:=DokanFileInfo.context-1;
//if i=-1 then i:=zip_name_locate(arch,pchar(path),0);
if i=-1 then
  begin
  writeln('file without a context');
  //exit; //we need to handle creation/addition of new files
  end;


  //first call=creation - we add the file to the zip
  //we could this part and rely on the cleanup
  //but then we should handle the read part (from temp) in readfile and getfileinformation, etc
  if offset=0 then
  begin
  source:=nil;
  source:=zip_source_buffer(arch,@buffer,NumberOfBytesToWrite ,0);
  //
  if source<>nil then
    begin
    if zip_file_add (arch,pchar(ExtractFileName(path)),source,0)=-1
       then writeln('zip_file_add failed')
       else
       begin
       writeln('zip_file_add OK');
       _refresh;
       end;
    //zip_source_free(source); //done by zip_file_add
    end
    else writeln('source=nil');
  end;


  if offset<>0 then
  if 1=1 then
    begin
    if not FileExists(GetTempDir+'\'+path) then
    begin
    //second call - we dump the first part in the zip to a temp file + the new second part coming in
    //we need its current size
    if zip_stat_index(arch,i,0,@stat)<>-1 then
      begin
      //writeln('zip file exists');
      //we need a pointer to the file
      file_:=nil;
      file_:=zip_fopen_index(arch,i,0);
      //in case of big files we may want to handle smaller chunks buffer...
      data:=allocmem(stat.size );
      size:= zip_fread (file_,data,stat.size);
      zip_fclose (file_);
      //we need to extract the file to temp
      FS := TFileStream.Create(GetTempDir+'\'+path , fmOpenWrite or fmCreate);
      fs.size:=offset+NumberOfBytesToWrite;
      fs.seek(0,soFromBeginning);
      fs.write(data^,size );
      //writeln('written '+inttostr(size)+' bytes @0');
      //modify this file
      fs.Seek(offset,soFromBeginning);
      NumberOfBytesWritten:=fs.write(Buffer ,NumberOfBytesToWrite );
      //writeln('written '+inttostr(NumberOfBytesWritten)+' bytes @'+inttostr(offset));
      //
      fs.Free ;
      freemem(data);
      end
      else
      //temp file does not exist? zip file does not exist? unlikely for now
      begin
      //writeln('zip file does not exists');
      FS := TFileStream.Create(GetTempDir+'\'+path , fmOpenWrite or fmCreate);
      fs.size:=offset+NumberOfBytesToWrite;
      fs.Seek(offset,soFromBeginning);
      fs.write(Buffer ,NumberOfBytesToWrite );
      fs.Free ;
      end;
    //
    //writeln(GetTempDir+'\'+path+' created');
    end
    else //if not FileExists(GetTempDir+'\'+path) then
    begin
    //3rd+ call(s) - temp file exist so modify this file
    FS := TFileStream.Create(GetTempDir+'\'+path , fmOpenWrite );
    fs.size:=offset+NumberOfBytesToWrite;
    fs.Seek(offset,soFromBeginning);
    NumberOfBytesWritten:=fs.write(Buffer ,NumberOfBytesToWrite );
    //writeln('written '+inttostr(NumberOfBytesWritten)+' bytes @'+inttostr(offset));
    fs.Free ;
    //writeln(GetTempDir+'\'+path+' updated');
    end;
    //add it back to the zip on cleanup or closefile
    end;

  Result := STATUS_SUCCESS;

end;

procedure _Cleanup(FileName: LPCWSTR;var DokanFileInfo: DOKAN_FILE_INFO); stdcall;
var
path:string;
source,data:pointer;
size:int64;
fs:TFileStream;
i:integer;
begin
path := WideCharToString(filename);
if path='\' then exit; //nothing to do.
writeln('_Cleanup:'+path+ ' '+inttostr(DokanFileInfo.context));
if arch=nil then exit;
i:=DokanFileInfo.context-1;
//
if fileexists(GetTempDir+'\'+path) then
  begin
  //source:=zip_source_file(arch,pchar(GetTempDir+'\'+path),0,0);
  //or
  FS := TFileStream.Create(pchar(GetTempDir+'\'+path), fmOpenRead or fmShareDenyWrite);
  size:=fs.Size;
  data:=AllocMem(size );
  fs.ReadBuffer(data^,size );
  fs.Free ;    
  source:=zip_source_buffer(arch,data,size ,0);

  //add or replace?
  if source<>nil
    //then if zip_file_replace (arch,DokanFileInfo.context-1,source,0)=-1
    then if zip_file_add  (arch,pchar(ExtractFileName(path)),source,ZIP_FL_OVERWRITE)=-1
      then writeln('zip_file_replace failed')
      else
      begin
      writeln('zip_file_replace OK');
      _refresh;
      end;

  if source=nil then writeln('source=nil');
  {$i-}deletefile(GetTempDir+'\'+path);{$i-};
  end;
//


  if DokanFileInfo.DeleteOnClose=true then
    begin
    //item is a file
    if DokanFileInfo.IsDirectory =false then
         begin
         if zip_delete (arch,int64(i) )=-1
           then writeln('zip_delete failed')
           else
           begin
           writeln('file has been deleted');
           _refresh;
           end;//if zip_delete....
         end
      else
      //item is a directory
      begin
      end;

    end;//  if DokanFileInfo.DeleteOnClose=true then
    
end;

function _DeleteFile(FileName: LPCWSTR; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
  var path: string;

begin
  result:=STATUS_NO_SUCH_FILE;
  path := WideCharToString(filename);
  writeln('_DeleteFile:'+path+ ' '+inttostr(DokanFileInfo.context));
  if DokanFileInfo.context>0 then
    begin
    //DokanFileInfo.DeleteOnClose :=true; //not necessary according to doc
    Result := STATUS_SUCCESS; //this actully tells that deleteonclose should be set to true
    end;
end;

function _DeleteDirectory(FileName: LPCWSTR; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var path: string;
begin
result:=STATUS_NO_SUCH_FILE;
path := WideCharToString(filename);
writeln('_DeleteDirectory:'+path+ ' '+inttostr(DokanFileInfo.context));
end;

function _GetFileInformation(
    FileName: LPCWSTR; var HandleFileInformation: BY_HANDLE_FILE_INFORMATION;
    var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  error: DWORD;
  find: WIN32_FIND_DATAW;
  //
  path:string;
  systime_:systemtime;
  filetime_:filetime;
  i:integer;
  stat:tzip_stat;

begin
  result:=STATUS_NO_SUCH_FILE;
path := WideCharToString(filename);
//writeln('_GetFileInformation:'+path+ ' '+inttostr(DokanFileInfo.context)); //too verbose

//root folder need to a success result + directory attribute...
if path='\' then
  begin
  HandleFileInformation.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
  Result := STATUS_SUCCESS;
  exit;
  end;

writeln('_GetFileInformation:'+path+ ' '+inttostr(DokanFileInfo.context));

if arch=nil then exit;

if path[1]='\' then system.delete(path,1,1);

i:=DokanFileInfo.context-1;
//not convinced the below is really needed - should only happen in createfile
//actually needed when we add a new file to the archive
if i=-1 then
  begin
  i:=_locate(path,DokanFileInfo);
  //
  DokanFileInfo.Context :=i+1;
  if DokanFileInfo.Context<>0 then  writeln('new context:'+inttostr(DokanFileInfo.Context));
  end;
if i=-1 then
  begin
  writeln('_GetFileInformation:'+path+ ' no such file');
  exit;
  end;



try
fillchar(stat,sizeof(stat),0);
if zip_stat_index(arch,i,0,@stat)=-1 then exit;

      fillchar(HandleFileInformation,sizeof(HandleFileInformation),0);
      //
      if stat.size>0
            then HandleFileInformation.dwFileAttributes := FILE_ATTRIBUTE_NORMAL
            else HandleFileInformation.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
      //
      HandleFileInformation.nFileSizeHigh :=LARGE_INTEGER(stat.size ).HighPart;
      HandleFileInformation.nFileSizeLow  :=LARGE_INTEGER(stat.size).LowPart;
      //
      HandleFileInformation.ftCreationTime:=DateTimeToFileTime(dateutils.UnixToDateTime (int64(stat.mtime)));
      HandleFileInformation.ftLastAccessTime:=DateTimeToFileTime(dateutils.UnixToDateTime (int64(stat.mtime)));
      HandleFileInformation.ftLastWriteTime   :=DateTimeToFileTime(dateutils.UnixToDateTime (int64(stat.mtime)));

      //
  Result := STATUS_SUCCESS;
  except
  on e:exception do writeln(e.message);
  end;

  end;

function _CreateFile(FileName: LPCWSTR; var SecurityContext: DOKAN_IO_SECURITY_CONTEXT;
                 DesiredAccess: ACCESS_MASK; FileAttributes: ULONG;
                 ShareAccess: ULONG; CreateDisposition: ULONG;
                 CreateOptions: ULONG; var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
  creationDisposition: DWORD;
  fileAttributesAndFlags: DWORD;
  genericDesiredAccess: ACCESS_MASK;
path,temp:string;
i:integer;
stat:tzip_stat;
begin
Result := STATUS_SUCCESS;
path := WideCharToString(filename);
//writeln('_CreateFile:'+path); //too verbose.

if path='\' then
  begin
  DokanFileInfo.IsDirectory:=true;
  exit;
  end;

writeln('_CreateFile:'+path+' '+inttostr(DokanFileInfo.context));

if arch=nil then exit;

//manage creationdisposition
DokanMapKernelToUserCreateFileFlags(
      DesiredAccess, FileAttributes, CreateOptions, CreateDisposition,
      @genericDesiredAccess, @fileAttributesAndFlags, @creationDisposition);

if path[1]='\' then system.delete(path,1,1);
i:=DokanFileInfo.context-1;
if i=-1 then
  begin
  i:=_locate(path,DokanFileInfo);
  //
  DokanFileInfo.Context :=i+1;
  if DokanFileInfo.Context<>0 then writeln('new context:'+inttostr(DokanFileInfo.Context));
  end;
if i=-1 then
  begin
  writeln('no such file - '+inttostr(creationDisposition)+' - '+booltostr(DokanFileInfo.IsDirectory));
  //this is needed so that files can execute
  if creationDisposition = CREATE_NEW
    then result := STATUS_SUCCESS
    else result:=STATUS_NO_SUCH_FILE;
  exit;
  end;

//zip_stat_index(arch,i,0,@stat);

//we could re use it in the readfile
//and eventually in the close if we want to keep stream opened


 //DbgPrint
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

end;

function _unMount:NTSTATUS; stdcall;
begin
result:=STATUS_UNSUCCESSFUL;
try
if arch<>nil then
   if zip_close (arch)=-1 then writeln('zip_close failed');
result:=STATUS_SUCCESS;
except
on e:exception do writeln('_unMount:'+e.message);
end;
end;

function _Mount(filename:string):boolean; stdcall;
var
err:integer;
begin
result:=false;
{
writeln('extractfilepath:'+extractfilepath('folderone\'));
writeln('extractfilepath:'+extractfilepath('folderone\test.txt'));
//no trailing '\'
writeln('extractfiledir:'+extractfiledir('folderone\'));
writeln('extractfiledir:'+extractfiledir('folderone\test.txt'));
exit;
}
//
zipfile :=filename;
init;
//writeln(filename);
//
try
arch:=zip_open(pchar(filename),0,@err);
if arch=nil then
  begin writeln('_Mount:'+inttostr(err));exit;end;
  //else writeln('zip_open OK');
  result:=true;
except
on e:exception do writeln('_unMount:'+e.message);
end;

end;

end.
