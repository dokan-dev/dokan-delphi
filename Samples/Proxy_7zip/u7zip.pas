unit u7zip;

interface

uses  windows,classes,sysutils,variants,activex,
      Dokan,DokanWin,
      sevenzip_ ;


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

function _Mount(filename:string):boolean; stdcall;
function _unMount:NTSTATUS; stdcall;

implementation

var
arch:i7zInArchive;
guid:tguid;
archive:string;

procedure DbgPrint(format: string; const args: array of const); overload;
begin
//dummy
end;

procedure DbgPrint(fmt: string); overload;
begin
//dummy
end;

function VarToInt(const AVariant: Variant): integer;
begin
  Result := StrToIntDef(Trim(VarToStr(AVariant)), 0);
end;

function VarToInt64(const AVariant: Variant): int64;
begin
  Result := StrToInt64Def(Trim(VarToStr(AVariant)), 0);
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

//
s:tstream;
instream: IInStream;
v:OleVariant;
findData: WIN32_FIND_DATAW;
i64:int64;
temp:string;
widetemp:widestring;
pv:TPropVariant;
begin
//writeln('findfiles: full path '+FileName);
 try
 //the below should/could take place in the _open function
 if arch=nil
  then arch:=CreateInArchive(guid,{ExtractFilePath (Application.ExeName )+} '7z-win32.dll' );

 with  arch do
 begin
   OpenFile(Archive);
   //SetProgressCallback(nil, ProgressCallback); //optional
   for i := 0 to NumberOfItems - 1 do
   begin


    //if (string(filename)<>'\') then
    if 1=0 then
      begin
      // folder\filename
      if {(pos('\',Itempath[i])>0) and} (filename=extractfiledir('\'+Itempath[i])) then
        begin
        //
        if not ItemIsFolder[i]
            then findData.dwFileAttributes := FILE_ATTRIBUTE_NORMAL
            else findData.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
        //
        widetemp:=extractfilename(Itempath[i]);
        Move(widetemp[1],  findData.cFileName,Length(widetemp)*Sizeof(Widechar));
        //
        inArchive.GetProperty(i,kpidSize,v);
        if vartype(v)=21 then
        begin
        findData.nFileSizeHigh :=LARGE_INTEGER(VarToInt64(v)).HighPart;
        findData.nFileSizeLow  :=LARGE_INTEGER(VarToInt64(v)).LowPart;
        end;//if vartype(v)=21 then
        //
        inArchive.GetProperty(i,kpidCreationTime,v);
        if vartype(v)=64 then  findData.ftCreationTime :=_filetime(TvarData( V ).VInt64); //WriteFiletime(TvarData( V ).VInt64);
        inArchive.GetProperty(i,kpidLastAccessTime,v);
        if vartype(v)=64 then  findData.ftLastAccessTime  :=_filetime(TvarData( V ).VInt64); //WriteFiletime(TvarData( V ).VInt64);
        inArchive.GetProperty(i,kpidLastWriteTime,v);
        if vartype(v)=64 then  findData.ftLastWriteTime   :=_filetime(TvarData( V ).VInt64); //WriteFiletime(TvarData( V ).VInt64);
        //
        FillFindData(findData, DokanFileInfo);
        end;//if (pos('\',Itempath[i])>0) and (filename=extractfiledir('\'+Itempath[i])) then
      end;//if (string(filename)<>'\') then

    //if string(filename)='\' then
    if 1=1 then
    begin
    if {(pos('\',Itempath[i])=0) and} (filename=extractfiledir('\'+Itempath[i])) then
      begin
      FillChar (findData ,sizeof(findData ),0);
      //
      if not ItemIsFolder[i]
            then findData.dwFileAttributes := FILE_ATTRIBUTE_NORMAL
            else findData.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
      //
      widetemp:=extractfilename(Itempath[i]);
      Move(widetemp[1],  findData.cFileName,Length(widetemp)*Sizeof(Widechar));
      //Move(Itempath[i][1],  findData.cFileName,Length(Itempath[i])*Sizeof(Widechar));
      //Move(Itemname[i][1],  findData.cFileName,Length(Itemname[i])*Sizeof(Widechar));
      //
      inArchive.GetProperty(i,kpidSize,v);
      if vartype(v)=21 then
        begin
        findData.nFileSizeHigh :=LARGE_INTEGER(VarToInt64(v)).HighPart;
        findData.nFileSizeLow  :=LARGE_INTEGER(VarToInt64(v)).LowPart;
        end;//if vartype(v)=21 then
      //
      try
      inArchive.GetProperty(i,kpidCreationTime,olevariant(pv));
      findData.ftCreationTime:=pv.filetime;
      //if vartype(v)=64 then  findData.ftCreationTime :=_filetime(TvarData( V ).VInt64 ); //WriteFiletime(TvarData( V ).VInt64);
      inArchive.GetProperty(i,kpidLastAccessTime,olevariant(pv));
      findData.ftLastAccessTime:=pv.filetime;
      //if vartype(v)=64 then  findData.ftLastAccessTime  :=_filetime(TvarData( V ).VInt64); //WriteFiletime(TvarData( V ).VInt64);
      inArchive.GetProperty(i,kpidLastWriteTime,olevariant(pv));
      findData.ftLastWriteTime   :=pv.filetime;
      //if vartype(v)=64 then  findData.ftLastWriteTime   :=_filetime(TvarData( V ).VInt64); //WriteFiletime(TvarData( V ).VInt64);
      except
      on e:exception do writeln('_FindFiles:'+e.message);
      end;

      //check varcast
      //i64:=varastype(v,64);
      //
      FillFindData(findData, DokanFileInfo);
      end;// if (pos('\',Itempath[i])=0) then
      end;//if string(filename)='\' then

      end;//for i := 0 to NumberOfItems - 1 do
 end;//with  arch do
 Result := STATUS_SUCCESS;


except
 on e:exception do writeln(e.Message );
end;

end;

function filename_to_index(filename:string):integer;
var
i:integer;
begin
result:=-1;
//
try
for i := 0 to arch.NumberOfItems - 1 do
begin
if '\'+ arch.ItemPath [i]=filename then
begin
result:=i;
break;
end; //if arch.ItemPath [i]=filename then
end; //for i := 0 to arch.NumberOfItems - 1 do
except
on e:exception do writeln(e.message);
end;

end;

function _ReadFile(FileName: LPCWSTR; var Buffer;
                        BufferLength: DWORD;
                        var ReadLength: DWORD;
                        Offset: LONGLONG;
                        var DokanFileInfo: DOKAN_FILE_INFO): NTSTATUS; stdcall;
var
stream:tmemorystream; //tstream does not have a seek function
i:integer;
begin
if WideCharToString(filename)='\' then exit;
writeln('_ReadFile:'+FileName+' '+inttostr(BufferLength)+'@'+inttostr(Offset));
//writeln(DokanFileInfo.context); //later ...
if arch=nil then exit;
i:=filename_to_index(filename);
if i=-1 then exit;
try
stream := tmemorystream.create(  );
//stream.SetSize(BufferLength); //the whole file will be read by extractitem ... :(
arch.ExtractItem(i,stream,false);
stream.Position :=offset; //we could read junks by junks to emulate a seek
ReadLength:=stream.read(buffer,BufferLength);
stream.free;
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
  dummy:string;
begin
  //writeln('WriteFile: '+ FileName+' '+inttostr(NumberOfBytesToWrite)+'@'+inttostr(Offset) );
  Result := STATUS_SUCCESS;

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
  v:olevariant;
  pv:TPropVariant;
begin
  result:=STATUS_NO_SUCH_FILE;
//writeln('_GetFileInformation:'+FileName);
path := WideCharToString(filename);

//root folder need to a success result + directory attribute...
if path='\' then
  begin
  HandleFileInformation.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
  Result := STATUS_SUCCESS;
  exit;
  end;

if arch=nil then exit;

i:=filename_to_index(WideCharToString(filename));
if i=-1 then
  begin
  writeln('_GetFileInformation:'+filename+ ' no such file');
  exit;
  end;


try
      fillchar(HandleFileInformation,sizeof(HandleFileInformation),0);
      //
      if not arch.ItemIsFolder[i]
            then HandleFileInformation.dwFileAttributes := FILE_ATTRIBUTE_NORMAL
            else HandleFileInformation.dwFileAttributes := FILE_ATTRIBUTE_DIRECTORY;
      //
      arch.inArchive.GetProperty(i,kpidSize,v);
      if vartype(v)=21 then
        begin
        HandleFileInformation.nFileSizeHigh :=LARGE_INTEGER(VarToInt64(v)).HighPart;
        HandleFileInformation.nFileSizeLow  :=LARGE_INTEGER(VarToInt64(v)).LowPart;
        end;//if vartype(v)=21 then
      //writeln('kpidSize:'+inttostr(VarToInt64(v) ));
      //

      arch.inArchive.GetProperty(i,kpidCreationTime,olevariant(pv));
      HandleFileInformation.ftCreationTime:=pv.filetime;
      //if vartype(v)=64 then  findData.ftCreationTime :=_filetime(TvarData( V ).VInt64 ); //WriteFiletime(TvarData( V ).VInt64);
      arch.inArchive.GetProperty(i,kpidLastAccessTime,olevariant(pv));
      HandleFileInformation.ftLastAccessTime:=pv.filetime;
      //if vartype(v)=64 then  findData.ftLastAccessTime  :=_filetime(TvarData( V ).VInt64); //WriteFiletime(TvarData( V ).VInt64);
      arch.inArchive.GetProperty(i,kpidLastWriteTime,olevariant(pv));
      HandleFileInformation.ftLastWriteTime   :=pv.filetime;
      //if vartype(v)=64 then  findData.ftLastWriteTime   :=_filetime(TvarData( V ).VInt64); //WriteFiletime(TvarData( V ).VInt64);

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
path:string;
i:integer;
begin
Result := STATUS_SUCCESS;
path := WideCharToString(filename);
//writeln('CreateFile:'+path);
if path='\' then exit;
if arch=nil then exit;

DokanMapKernelToUserCreateFileFlags(
      DesiredAccess, FileAttributes, CreateOptions, CreateDisposition,
      @genericDesiredAccess, @fileAttributesAndFlags, @creationDisposition);

i:=filename_to_index(path);
if i=-1 then
  begin
  writeln('_CreateFile:'+filename+ ' no such file');
  //this is needed so that files can execute
  if creationDisposition = CREATE_NEW
    then result := STATUS_SUCCESS
    else result:=STATUS_NO_SUCH_FILE;
  exit;
  end;

//we could re use it in the readfile
//and eventually in the close if we want to keep stream opened
 DokanFileInfo.Context :=i;

 if not arch.ItemIsFolder[i]
            then DokanFileInfo.IsDirectory := false
            else DokanFileInfo.IsDirectory := True;

//manage creationdisposition

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

end;

function _unMount:NTSTATUS; stdcall;
begin
result:=STATUS_UNSUCCESSFUL;
try
arch.Close ;
result:=STATUS_SUCCESS;
except
end; //temp hack to avoid badvarianttype error...
end;

function _Mount(filename:string):boolean; stdcall;
var
ext:string;
begin
result:=false;
guid:=StringToGUID ('{00000000-0000-0000-0000-000000000000}');
ext:=ExtractFileExt(filename);
if lowercase(ext)='.iso' then guid:=CLSID_CFormatiso;
if lowercase(ext)='.wim' then guid:=CLSID_CFormatWim;
//  guid:=CLSID_CFormatUdf;
if lowercase(ext)='.zip' then guid:=CLSID_CFormatzip;
if lowercase(ext)='.7z' then guid:=CLSID_CFormat7z;
if lowercase(ext)='.cab' then guid:=CLSID_CFormatCab ;
//if lowercase(ext)='.vhd' then guid:=CLSID_CFormatvhd;
if lowercase(ext)='.wim' then guid:=CLSID_CFormatwim;
//if lowercase(ext)='.img' then guid:=CLSID_CFormatmbr;
//  guid:=CLSID_CFormatNtfs;   guid:=CLSID_CFormatFat;
if lowercase(ext)='.squashfs' then guid:=CLSID_CFormatsquashfs;
if lowercase(ext)='.bz2' then guid:=CLSID_CFormatBZ2;
if lowercase(ext)='.rar' then guid:=CLSID_CFormatRar;
if lowercase(ext)='.arj' then guid:=CLSID_CFormatArj;
if lowercase(ext)='.z' then guid:=CLSID_CFormatZ;
if lowercase(ext)='.lzh' then guid:=CLSID_CFormatLzh;
if lowercase(ext)='.bkf' then guid:=CLSID_CFormatbkf;
if lowercase(ext)='.gz' then guid:=CLSID_CFormatgzip;
if lowercase(ext)='.split' then guid:=CLSID_CFormatsplit;
if lowercase(ext)='.tar' then guid:=CLSID_CFormattar;
if lowercase(ext)='.dmg' then guid:=CLSID_CFormatDmg;
if lowercase(ext)='.tar' then guid:=CLSID_CFormatTar;
if lowercase(ext)='.cab' then guid:=CLSID_CFormatcab;
if lowercase(ext)='.xz' then guid:=CLSID_CFormatxz;


if GUIDToString(guid)='{00000000-0000-0000-0000-000000000000}' then
  begin
  writeln('unknown archive');
  exit;
  end;
archive:=filename;  
result:=true;
end;

end.
