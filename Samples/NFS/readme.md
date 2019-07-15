Mount a windows logical drive against a NFS export using Dokan and Libnfs (https://github.com/sahlberg/libnfs).<br/>

Dokan can either be installed manually (see manual_install_md.zip or manual_install_mt.zip) or using the official installer (https://github.com/dokan-dev/dokany/releases).<br/>

Dokan is built against VC 2017 (you will need the VC2017 runtime - or use the static (alias MT) manual_install_mt.zip).<br/>
Libnfs is built against VC 2010 (you will need the VC2010 runtime - msvcr100.dll is provided).<br/>
Todo : have dokan and libnfs use the same VC runtime (preferably the generic msvcrt.dll).<br/>

NFS_dokan run without arguments will give the possible options.<br/>
Below a simple command line to mount a nfs export on X:<br/>
NFS_DOKAN.exe /r "nfs://192.168.1.248/volume2/public/" /l x<br/>

You can discover nfs exports on your lan with the below command:<br/>
NFS_DOKAN.exe /discover<br/>

The below file system operations have been tested successfully :<br/>
directory listing, directory browsing, create directory, rename directory, create file, rename file, read file, write file, copy/paste file, delete file, delete directory.

