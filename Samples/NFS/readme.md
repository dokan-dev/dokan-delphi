Mount a windows logical drive against a NFS export using Dokan and Libnfs (https://github.com/sahlberg/libnfs).

Dokan can either be installed manually (see manual_install.zip) or using the official installer (https://github.com/dokan-dev/dokany/releases).

Dokan is built against VC 2017 (you will need the VC runtime).
Libnfs is built against VC 2010 (you will need the VC runtime).
Todo : have dokan and libnfs use the same VC runtime (preferably the generic msvcr.dll).

NFS_dokan run without arguments will give the possible options.
Below a simple command line to mount a nfs export on X:
NFS_DOKAN.exe /r "nfs://192.168.1.248/volume1/download/" /l x

