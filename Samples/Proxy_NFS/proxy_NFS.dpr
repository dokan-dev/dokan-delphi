library proxy_nfs;

{ Important note about DLL memory management: ShareMem must be the
  first unit in your library's USES clause AND your project's (select
  Project-View Source) USES clause if your DLL exports any procedures or
  functions that pass strings as parameters or function results. This
  applies to all strings passed to and from your DLL--even those that
  are nested in records and classes. ShareMem is the interface unit to
  the BORLNDMM.DLL shared memory manager, which must be deployed along
  with your DLL. To avoid using BORLNDMM.DLL, pass string information
  using PChar or ShortString parameters. }

uses
  SysUtils,
  Classes,
  unfs in 'unfs.pas',
  Dokan in '..\..\Dokan.pas',
  DokanWin in '..\..\DokanWin.pas';

{$R *.res}

//REMEMBER : getprocaddress is f...ing CASE SENSITIVE !!!
exports
   _CreateFile,
   _ReadFile,
   _WriteFile,
   _FindFiles,
   _GetFileInformation,
   _Mount,
   _unMount,
   _Cleanup,
   _CloseFile,
   _MoveFile;
   //_DeleteFile,
   //_DeleteDirectory;

begin
end.
