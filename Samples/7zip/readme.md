Mount a windows logical drive against an archive supported by 7zip using :<br/>
Dokan (https://github.com/dokan-dev/dokany) <br/>
7zip (https://www.7-zip.org/) <br/>

Dokan is built against VC 2017 (you need the VC2017 runtime - see installation.txt).<br/>
7z library is provided here.<br/>

sevenzip_dokan run without arguments will give the possible options.<br/>

Below a simple command line to mount a 7zip archive on X:<br/>
sevenzip_DOKAN.exe /r test.zip /l x<br/>
<br/>
Below a simple command line to mount a 7zip archive on c:\mount\<br/>
sevenzip_DOKAN.exe /r test.zip /l c:\mount\<br/>
<br/>
The below file system operations have been tested successfully :<br/>
directory listing, directory browsing, read file, copy/paste file, execute a binary.

Only read operations are supported for now.

![Screenshot](screenshot.png)


