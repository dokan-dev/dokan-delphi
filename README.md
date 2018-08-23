# Dokan Delphi/FreePascal Binding

## What is Dokan Delphi/FreePascal Binding
By using Dokan library, you can create your own file systems very easily
without writing device driver. Dokan Delphi/FreePascal Binding is a library that allows
you to make a file system on Win32/Win64 environment.

## Licensing
Dokan Delphi/FreePascal Binding is distributed under a version of the "MIT License",
which is a BSD-like license. See the 'license.mit.txt' file for details.

##Environment
Delphi/FreePascal and Dokan library

## How to write a file system
To make a file system, an application needs to implement IDokanOperations interface.
Once implemented, you can invoke Mount function on your driver instance
to mount a drive. The function blocks until the file system is unmounted.
Semantics and parameters are just like Dokan library. Details are described
at 'README.md' file in Dokan library. See sample codes under 'sample'
directory. Administrator privileges are required to run file system
applications.

## Unmounting
Just run the bellow command or your file system application call Dokan.Unmount
to unmount a drive.

   > dokanctl.exe /u DriveLetter
   