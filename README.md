# docker-lamp

A high-performance local LAMP web environment for Windows


Windows Subsystem for Linux
---------------------------

*  Open Turn Windows features on and off:

    *  Enable Virtual Machine Platform
    *  Enable Windows Subsystem for Linux

*  Restart Windows
*  Open Windows Command Prompt as Administrator

    *  Set future WSL installations to Version 2
        ```
        wsl --set-default-version 2
        ```

*  Install [Ubuntu](https://www.microsoft.com/store/productId/9PDXGNCFSCZV) from the Microsoft Store
*  Open the Ubuntu application and wait a moment for it to initialize for the first time

    *  Once a prompt appears, input the following:
        *  UNIX username: `ubuntu`
        *  Password: `ubuntu`
        *  Retype password: `ubuntu`

*  You can close the Ubuntu terminal
*  Open Windows Command Prompt as Administrator

    *  Make sure Ubuntu is running on WSL version 2
        ```
        wsl --set-version Ubuntu 2
        ```
    *  Make sure Ubuntu is set as the default distribution
        ```
        wsl --set-default Ubuntu
        ```
    *  To check that Ubuntu is the default distro and that it's running on WSL 2 use
        ```
        wsl -l -v
        ```
    *  Create a symbolic link from the Documents folder to the Docker folder in Ubuntu
        ```
        cd %userprofile%\Documents
        mklink /d Docker \\wsl.localhost\Ubuntu\home\ubuntu\Docker
        ```

*  You can close Windows Command Prompt now
*  Restart Windows

Notes:

*  You can access the entire WSL Ubuntu filesystem by looking for the Linux section in Windows Explorer. If you cannot find this, use the following URL in the Windows Explorer window: `\\wsl.localhost\Ubuntu`
*  If you ever need to uninstall Ubuntu and reinstall you can remove the app by right-clicking the icon and clicking uninstall, and after that run the following command: `wsl -unregister Ubuntu`


Docker Desktop for Windows
--------------------------

*  Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/)

    *  Enable WSL2 Backend during the installation

*  Once installed and running, go to Settings, make sure these are enabled:

    *  General -> Use the WSL 2 based engine
    *  Resources -> WSL Integration -> Enable integration with my default WSL distro


Setup Container
---------------

*  Open the Ubuntu application

    *  Go to `/home/ubuntu`
        ```
        cd
        ```
    *  Download and install NVM ([Node Version Manager](https://github.com/nvm-sh/nvm)) to switch between NodeJS versions as needed
        ```
        curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.38.0/install.sh | bash
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
        nvm install --lts
        ```
    *  Create the Docker folder
        ```
        mkdir /home/ubuntu/Docker
        ```
    *  Clone the Lyquix Docker LAMP repository
        ```
        sudo apt install git
        git config core.fileMode false
        git clone https://github.com/Lyquix/docker-lamp.git Docker
        ```
    *  Execute the container setup script
        ```
        cd Docker
        chmod +x container-setup.sh
        ./container-setup.sh
        ```
    *  You will be prompted to select what versions of Ubuntu you would like to create or recreated. Currently available: 18 through 24.

    *  Building each image will take about 5 to 10 minutes depending on your Internet connection and you computer speed. It will also create a container for each image.

    *  Installation is completed on the first boot of each container. This will take another 2 to 5 minutes. Please wait until this script is finished before using the container.

    *  Subsequent boots will only take 15 to 30 seconds. In the log view you can check the start process and confirm that Apache and MySQL are running. If needed you can restart all processes by running `/start.sh`

    *  While you wait, add the custom CA root certificate to prevent getting an alert on your browser regarding the SSL certificate:

       *  Open the Start Menu and search for "Manage user certificates" or press Windows key + R, then type `certmgr.msc` and hit Enter to open the Windows Certificate Manager.
       *  In the left pane, navigate to Certificates - Current User > Trusted Root Certification Authorities.
       *  In the right pane, right-click on the Certificates folder under Trusted Root Certification Authorities, go to All Tasks, and select Import.
       *  Follow the wizard, select the root CA certificate file you want to import (in WSL `~/Docker/ssl/root.pem`), and complete the import process.


Important notes about this LAMP setup:

*  The access logs for all the local sites are discarded. If you need to see the access log for a specific site, comment the `CustomLog` setting in its VirtualHost file
*  The error log for all sites can be found at `/var/log/apache2/error.log`
*  MySQL has been configured so that you only need to use one user for all sites
    User: `dbuser`
    Password: `dbpassword`
*  You must use host '127.0.0.1' to connect to MySQL, do not use 'localhost'.
*  phpMyAdmin has been installed and configured to login automatically
    [http://localhost/pma](http://localhost/pma)
*  Search-Replace DB has been installed and configured to login automatically
    [http://localhost/srdb](http://localhost/srdb)
*  A custom CA (certificate authority) root certificate is created in `Docker/ssl`. This is used to create SSL certificates for the local sites. Follow the instructions above to add the CA root certificate to Windows and be able to connect to your local sites with HTTPS without any warnings.


Set VSCode to use Ubutu as Default Terminal
-------------------------------------------

NodeJS and the scripts used to compile JS and CSS will be running on the Ubuntu WSL machine

*  Open VSCode
    *  Press `Ctrl + Shift + P` to open the Command Palette
    *  Type `terminal default profile` and click on the one result
    *  Select "Ubuntu (WSL)" as the default terminal


Update configuration of Git in Windows
--------------------------------------

The default Git configuration provides very poor performance when accessing repos in WSL. To improve the performance of Git operations perform the following steps:

*  Open a Command Prompt window **as Administrator**
*  Execute the following commands:
   ```
   git config --global core.autocrlf false
   git config --system core.longpaths true
   git config --system core.checkStat minimal
   git config --system core.trustctime false
   ```


Setup a New Site
----------------

*  Make sure you are setting the site on the correct container, the one that matches the Ubuntu version of the development and production environments

*  Go to Docker Desktop and open the container terminal

    *  Change to the bash shell
        ```
        bash
        ```
    *  Run the new site setup script
        ```
        /srv/www/site-setup.sh
        ```
    *  Enter the local domain, typically a `.test` domain. This will be used to generate the VirtualHost file.
    *  Enter the production domain, this will be used to create the directory under `www`.
    *  Enter the database name

*  The default .gitignore is automatically added to the new site public_html directory

*  If setting up a new site you can use this script to install WordPress

*  If setting up an existing site:

    *  Set the local repo and download the site files to
        ```
        C:\Users\[username]\Documents\Docker\ubuntu\[18|20]\www\[site-directory]\public_html
        ```
    *  Download a database dump and import it to the local database
        ```
        mysql -u dbuser -pdbpassword -h 127.0.0.1 databasename < dump.sql
        ```
    *  Adjust the CMS database settings:
        ```
        define( 'DB_USER', 'dbuser' );
        define( 'DB_PASSWORD', 'dbpassword' );
        define( 'DB_HOST', '127.0.0.1' );
        ```
    *  In .htaccess comment out
        ```
        ModPagespeed
        ```
    *  Fix file permissions (see details below)

*  To allow connection from Windows using the custom local domain, modify the Windows etc/hosts file

    *  Install [Microsoft PowerToys](https://apps.microsoft.com/store/detail/microsoft-powertoys/XP89DCGQ3K6VLD) and use the [Hosts File Editor](https://learn.microsoft.com/en-us/windows/powertoys/hosts-file-editor)

    *  Add the following line at the bottom of the file
        ```
        127.0.0.1  domain.test
        ```


Fix File Permissions
--------------------

File permissions for the `www` directory need to be properly set up to ensure that you are able to work on the folder and that the sites work correctly on the virtual machine. Run this script whenever you encounter issues with creating, modifying or deleting files in `www`.

*  Go to Docker Desktop and open the container terminal

    *  Change to the bash shell
        ```
        bash
        ```
    *  Run the new file permissions script
        ```
        /srv/www/file-permissions.sh
        ```
    *  Choose whether to update one directory or all directories

    *  If selected one directory, select directory from the list

    *  Choose whether to fix only the theme file permissions


Quirks
------

*  When accessing the files in the WSL Ubuntu distro, the default behavior is for Linux to see you as the default user (`ubuntu`). However, we noticed that right after installing Ubuntu, the user was root. This made me think it would always be root and after I restarted my computer I had several issues with permissions.

* When connecting to MySQL you must use host name 127.0.0.1, localhost doesn't work in Docker


To Do
-----

*  Configure the Windows Firewall to prevent external access to port 80, 443 and phpMyAdmin
