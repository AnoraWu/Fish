
Follow these steps to set up your environment before running the master.do

## 1. Install R.4.4.1
- For Mac users: go to https://cran.r-project.org/bin/macosx/big-sur-arm64/base/, click "R-4.4.1-arm64.pkg" to download the installer. Open the installer and install the R.4.4.1. Use the default location to install and select the default options everywhere.
- For Windows users: go to https://cran.r-project.org/bin/windows/base/old/4.4.1/, click "R-4.4.1-win.exe" to download the installer. Run the installer. Use the default location to install and select the default options everywhere.

## 2. Install RTools (Only for Windows users to help download R packages)
1. Go to [Rtools42 for Windows](https://cran.r-project.org/bin/windows/Rtools/rtools42/rtools.html), and click the "Rtools42 installer" to download the the RTools installer. After downloading has completed, run the installer. Select the default options everywhere.

## 3. Install GnuPG 2.4.7 (A prior for some R packages installation)
- For Mac users: download GnuPG 2.4.7 from [GnuPG for OS X / macOS Documentation](https://sourceforge.net/p/gpgosx/docu/Download/) by clicking the "disk image". (If the lastest version of GnuPG is not 2.4.7, check https://sourceforge.net/p/gpgosx/docu/Release%20Archive/ and click the "Release 2.4.7" to download the dmg file.) Click the downloaded file and then click the "Install.pkg". There will be a pop-up warning, click "OK". Then go to System Settings - Privacy & Security, click "Open Anyway". Click "open" if another pop-up appears. Then you can install the program. Select the (!important) default location and default options everywhere.

- For Windows users: Download Gpg4win from [Gpg4win Download](https://files.gpg4win.org/) by clicking the "gpg4win-4.4.0.exe". Run the installer after downloading it. Select the (!important) default location and default options everywhere. There is no need to click "Run Kleopatra" after installation. 

## 4. Install Anaconda
- For Mac users: On [Anaconda Installation](https://www.anaconda.com/download/), click "Skip registration" under the green button "Submit" and download the Anaconda installer compatible with your system. Choose the graphical installer rather than the command line installer. Then run the installer. Click "Allow" for any pop-ups, and then keep clicking "Continue". In "Destination Select" section, click "install for all users of this computer". 

- For Windows users: On [Anaconda Installation](https://www.anaconda.com/download/), click "Skip registration" under the green button "Submit" and download the Anaconda installer. Click "Allow" for any pop-ups, and then keep clicking "Continue". At the last step of installation, click "Clear the package cache upon completion", and click "Install". 

## 5. Activate Conda Environment
Type the following command in the terminal:
```
conda env create -f fish.yml
```

Once all these steps are completed, your environment should be fully set up and ready for the script to run.
