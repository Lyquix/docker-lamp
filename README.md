# docker-lamp

A high-performance local LAMP web environment for Windows

Windows Subsystem for Linux
---------------------------

1.  Open Turn Windows features on and off:

*   Enable Virtual Machine Platform
*   Enable Windows Subsystem for Linux

1.  Restart Windows
1.  Open Windows Command Prompt as Administrator

*   Set future WSL installations to Version 2
```
wsl --set-default-version 2
```

1.  Install [Ubuntu](https://www.microsoft.com/store/productId/9PDXGNCFSCZV) from the Microsoft Store
1.  Open the Ubuntu application and wait a moment for it to initialize for the first time

*   Once a prompt appears, input the following:
    *   UNIX username: `ubuntu`
    *   Password: `ubuntu`
    *   Retype password: `ubuntu`
*   Create the Docker folder
```
mkdir /home/ubuntu/Docker
```

1.  Open Windows Command Prompt as Administrator

*   Make sure Ubuntu is running on WSL version 2
```
wsl --set-version Ubuntu 2
```
*   Make sure Ubuntu is set as the default distribution
```
wsl --set-default Ubuntu
```
*   To check that Ubuntu is the default distro and that it's running on WSL 2 use
```
wsl -l -v
```
*   Create a symbolic link from the Documents folder to the Docker folder in Ubuntu
```
cd %userprofile%\Documents
mklink /d Docker \\wsl.localhost\Ubuntu\home\ubuntu\Docker
```

1.  You can close Windows Command Prompt now
1.  Restart Windows

Notes:

*   You can access the entire WSL Ubuntu filesystem by looking for the Linux section in Windows Explorer. If you cannot find this, use the following URL in the Windows Explorer window: `\\wsl.localhost\Ubuntu`
*   If you ever need to uninstall Ubuntu and reinstall you can remove the app by right-clicking the icon and clicking uninstall, and after that run the following command: `wsl –unregister Ubuntu`

Docker Desktop for Windows
--------------------------

1.  Install [Docker Desktop for Windows v.4.14.1](https://desktop.docker.com/win/main/amd64/91661/Docker%20Desktop%20Installer.exe)

*   Enable WSL2 Backend during the installation

1.  Once installed and running, go to Settings, make sure these are enabled:

*   General -> Use the WSL 2 based engine
*   Resources -> WSL Integration -> Enable integration with my default WSL distro

Setup Container
---------------

1.  Open the Ubuntu application

*   Check that you are at `/home/ubuntu`
```
cd
```
*   Download and extract the Lyquix Docker Package
```
curl -O -L https://github.com/Lyquix/docker-lamp/archive/refs/heads/main.zip
sudo apt install unzip
unzip main.zip
mv docker-lamp-main/* Docker
rm -r docker-lamp-main main.zip
```
*   Execute the container setup script
```
cd Docker
chmod +x container-setup.sh
./container-setup.sh
```

1.  You can close the Ubuntu app now, you should not need to use it anymore.

Setup the LAMP Server
---------------------

1.  Go to Docker Desktop
1.  Under Containers, you should see the two new containers: ubuntu18 and ubuntu20 in "Exited" status. NOTE: since both containers use the same ports, you can only use one of the containers at a time.
1.  Setup ubuntu18:

*   Start the container
*   Open the container terminal
*   Change to the bash shell
```
bash
```
*   Execute the LAMP setup script
```
./lamp-setup.sh
```
*   The script is mostly automated. When prompted to select a timezone, use US (option 12) and Eastern time (option 5)
*   The whole process should be completed in less than 10 minutes

1.  Repeat the steps above for ubuntu20

Important notes about this LAMP setup:

*   When starting the Docker container, the Apache and MySQL services will not be running. Just go to the terminal and run `/start.sh` to get them started.
*   The access logs for all the local sites are discarded. If you need to see the access log for a specific site, change the `CustomLog` setting in its VirtualHost file
*   The error log for all sites can be found at `/var/log/apache2/error.log`
*   MySQL has been configured so that you only need to use one user for all sites
    User: `dbuser`
    Password: `dbpassword`
*   phpMyAdmin has been installed and configured to login automatically
    [http://localhost/pma](http://localhost/pma)
*   Search-Replace DB has been installed and configured to login automatically
    [http://localhost/srdb](http://localhost/srdb)

Setup a New Site
----------------

1.  Make sure you are setting the site on the correct container, the one that matches the Ubuntu version of the development and production environments
1.  Go to Docker Desktop and open the container terminal

*   Change to the bash shell
```
bash
```
*   Run the new site setup script
```
/srv/www/site-setup.sh
```
*   Enter the local domain, typically a `.test` domain. This will be used to generate the VirtualHost file.
*   Enter the production domain, this will be used to create the directory under `www`.
*   Enter the database name

1.  Set the local repo and download the site files to
```
C:\Users\[username]\Documents\Docker\ubuntu\[18|20]\www\[site-directory]\public_html
```
1.  Download a database dump and import it to the local database
```
mysql -u dbuser -p databasename < dump.sql
```
1.  Adjust Joomla's configuration.php
```
$user = 'dbuser'
$password = 'dbpassword'
$force_ssl = '0'
$caching = '0'
$cookie_domain = '[local.test domain]'
```
1.  Adjust WordPress wp-config.php
```
define( 'DB_USER', 'dbuser' );
define( 'DB_PASSWORD', 'dbpassword' );
```
1.  Adjust .htaccess
*   Comment out
```
ModPagespeed
```
*   Comment out domain and SSL redirect, for example:
```
RewriteCond %{HTTP_HOST} !^example.com$ [OR,NC]
RewriteCond %{SERVER_PORT} 80
RewriteRule ^(.*)$ https://example.com/$1 [R=301,L]
```
1.  To allow connection from Windows using the custom local domain, modify the Windows etc/hosts file

*   Right-click on the Notepad icon (or your preferred text editor) and click on Run as Administrator
*   Open the file `C:\Windows\System32\drivers\etc\hosts`
*   Add the following line at the bottom of the file
```
127.0.0.1  domain.test
```

Fix File Permissions
--------------------

File permissions for the `www` directory need to be properly set up to ensure that you are able to work on the folder and that the sites work correctly on the virtual machine. Run this script whenever you encounter issues with creating, modifying or deleting files in `www`.

1.  Go to Docker Desktop and open the container terminal

*   Change to the bash shell
```
bash
```
*   Run the new file permissions script
```
/srv/www/file-permissions.sh
```
*   Choose whether to update one directory or all directories
*   If selected one directory, select directory from the list

Quirks
------

*   When accessing the files in the WSL Ubuntu distro, the default behavior is for Linux to see you as the default user (`ubuntu`). However, I noticed that right after installing Ubuntu, the user was root. This made me think it would always be root and after I restarted my computer I had several issues with permissions.
*   The files in the `www` directory must be owned by `www-data` for sites to work correctly. Since we're editing the files with the ubuntu user, files permissions have to be different than the way they are set up in the development and production environments. For this local machine, we need to give write and execute permissions to all users.

To Do
-----

*   Configure the Windows Firewall to prevent external access to port 80 and phpMyAdmin
*   Setup SSH server and expose port 22 so that we can use Putty to connect to the Docker VM instead of using the Docker Desktop terminal (will also need to look into the Windows Firewall to protect this
*   Automatically start Apache and MySQL when the container is started (or have a way to monitor when those services aren't running and restart them automatically).
