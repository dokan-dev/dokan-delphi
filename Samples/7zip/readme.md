Before reading, this example is superseded by https://github.com/erwan2212/dokan-delphi/edit/master/Samples/Mount.

Mount a windows logical drive against an archive supported by 7zip using :<br/>
Dokan (https://github.com/dokan-dev/dokany) <br/>
7zip (https://www.7-zip.org/) <br/>

Dokan is built against VC 2017 (you need the VC2017 runtime - see installation.txt).<br/>
7z library is provided here.<br/>

sevenzip_dokan run without arguments will give the possible options.<br/>

Below a simple command line to mount a nfs export on X:<br/>
NFS_DOKAN.exe /r test.zip /l x<br/>

The below file system operations have been tested successfully :<br/>
directory listing, directory browsing, read file, copy/paste file, execute a binary.

Only read operations are supported for now.

![Screenshot](screenshot.png)


