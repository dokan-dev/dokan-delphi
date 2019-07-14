Mount a windows logical drive against a NFS export using Dokan and Libnfs (https://github.com/sahlberg/libnfs).<br/>

Dokan can either be installed manually (see manual_install.zip) or using the official installer (https://github.com/dokan-dev/dokany/releases).<br/>

Dokan is built against VC 2017 (you will need the VC runtime).<br/>
Libnfs is built against VC 2010 (you will need the VC runtime).<br/>
Todo : have dokan and libnfs use the same VC runtime (preferably the generic msvcr.dll).<br/>

NFS_dokan run without arguments will give the possible options.<br/>
Below a simple command line to mount a nfs export on X:<br/>
NFS_DOKAN.exe /r "nfs://192.168.1.248/volume1/download/" /l x<br/>

The below file system operations have been tested successfully :<br/>
directory listing <br/>
directory browsing <br/>
create directory <br/>
rename directory <br/>
create file <br/>
rename file <br/>
read file (except vlc? but videos still read fine in chrome...)<br/>
write file (i truncate the file by default on the first write. to be reviewed in the future) <br/>
copy/paste file<br/>
delete file<br/>
delete directory<br/>

