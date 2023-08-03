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
    *  Create the Docker folder
        ```
        mkdir /home/ubuntu/Docker
        ```

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
*  If you ever need to uninstall Ubuntu and reinstall you can remove the app by right-clicking the icon and clicking uninstall, and after that run the following command: `wsl –unregister Ubuntu`

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
    *  Clone the Lyquix Docker LAMP repository
        ```
        sudo apt install git
        git clone https://github.com/Lyquix/docker-lamp.git Docker
        ```
    *  Execute the container setup script
        ```
        cd Docker
        chmod +x container-setup.sh
        ./container-setup.sh
        ```
    *  Wait for the setup to complete. On the first boot of each container the lamp-setup.sh script will be executed. The script is completely automated and will take 5 to 10 minutes to complete. You can follow progress in the container log viewer.

Important notes about this LAMP setup:

*  The access logs for all the local sites are discarded. If you need to see the access log for a specific site, change the `CustomLog` setting in its VirtualHost file
*  The error log for all sites can be found at `/var/log/apache2/error.log`
*  MySQL has been configured so that you only need to use one user for all sites
    User: `dbuser`
    Password: `dbpassword`
*  phpMyAdmin has been installed and configured to login automatically
    [http://localhost/pma](http://localhost/pma)
*  Search-Replace DB has been installed and configured to login automatically
    [http://localhost/srdb](http://localhost/srdb)

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

*  Set the local repo and download the site files to
    ```
    C:\Users\[username]\Documents\Docker\ubuntu\[18|20]\www\[site-directory]\public_html
    ```
*  Download a database dump and import it to the local database
    ```
    mysql -u dbuser -p databasename < dump.sql
    ```
*  Adjust Joomla's configuration.php
    ```
    $user = 'dbuser'
    $password = 'dbpassword'
    $host = '127.0.0.1'
    $force_ssl = '0'
    $caching = '0'
    $cookie_domain = '[local.test domain]'
    ```
*  Adjust WordPress wp-config.php
    ```
    define( 'DB_USER', 'dbuser' );
    define( 'DB_PASSWORD', 'dbpassword' );
    define( 'DB_HOST', '127.0.0.1' );
    ```
*  Adjust .htaccess
*  Comment out
    ```
    ModPagespeed
    ```
*  Comment out domain and SSL redirect, for example:
    ```
    RewriteCond %{HTTP_HOST} !^example.com$ [OR,NC]
    RewriteCond %{SERVER_PORT} 80
    RewriteRule ^(.*)$ https://example.com/$1 [R=301,L]
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

Quirks
------

*  When accessing the files in the WSL Ubuntu distro, the default behavior is for Linux to see you as the default user (`ubuntu`). However, I noticed that right after installing Ubuntu, the user was root. This made me think it would always be root and after I restarted my computer I had several issues with permissions.
*  Some times MySQL will not start when the container boots. You can manually run `sudo /start.sh` from the Docker terminal to start the services again
To Do
-----

*  Configure the Windows Firewall to prevent external access to port 80 and phpMyAdmin
*  Setup SSH server and expose port 22 so that we can use Putty to connect to the Docker VM instead of using the Docker Desktop terminal (will also need to look into the Windows Firewall to protect this)
