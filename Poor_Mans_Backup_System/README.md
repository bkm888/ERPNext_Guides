Sometime ago I posted a "Step by Step guide to the Poor Man's Backup System" and it was received with some goodwill. However nice it was it was not complete. It did a very nice job of running the database backups and moving them around to other servers, but it was missing the associated files that are in the /public/files and /private/files directoriues. This newer version of the PoorMan's Backup System corrects for those omissions.

If you spot something I left out please chime in and I will update the text of the post. Likewise if you see an error in syntax, also let me know and I will humbly fix it. However, if after reading all of this you know of a better solution, then please start a new thread with your simpler and better solution explained in step by step detail, then place your link to it here so all of the new users may benefit from it. Anything less is just you wanting to hear yourself talk and not really say much.

** Fair Warning ** I am not a developer or even a fair programmer of high level languages, I am just a systems implementer with just enough knowledge of linux to keep my head above water. So I hope I can get the point across for most newcomers to ERPNext.

Poor Man’s Backup System (v2) Details:

This plan requires you to have 2 identical KVM type VPS servers usually from the same cloud VPS service provider but on different physical hardware. These can be in the same building, different buildings or even in different cities as long as they are different physical hardware. If you are using OpenVM style servers, this solution may not work (ERPNext may not work either).

One server is the primary live production server and the other is an identical standby production server. If you are just setting up ERPNext for the first time, it is best to set up both servers at the same time. You can then install everything on both servers at the same time. If you already have a live production server running (even if it is only a day or two old), it is probably best to use the image backup service provided by your cloud VPS service provider to make the second server.

This means you should use the image backup service (usually available to you in your service provider dashboard account) and generate a copy of the running primary server. When the backup is finished, send a service request to your service provider asking them to restore that image to your second server. This sometimes takes a day or so for the service providers to get the 2nd server restored. They usually schedule during their off-peak times (at least this is how the few companies I worked with have done it). This image backup and restore service is usually free with your account. Check with your service provider. They sometimes call this a snapshot service so you can make a snapshot of your server and download it to your local workstation for safe keeping. I just use it to keep identical servers running.

If you used the image backup and restore method, you will also have to edit the following file to reflect the correct ip address information for your standby server:

/etc/network/interfaces

When restoring an image of another server, it is going to faithfully write this file as it was on the original server and that would keep the standby server from being available to the internet. Ask your service provider for the correct data to edit into this file, or make a copy of it from the bare standby server before you overwrite it with the new image.

Additionally, you will have to edit the “site_config.json” file on the standby server to remove any URL assignments that were from the primary server. You can use bench to assign a new name later (like maybe server2.MyERPServer.com to avoid having to buy another URL just use a sub domain).

The Poor Man’s Backup System essentially runs database backups and backups up the related /files directories on a schedule that you choose into a single backup file and sends a copy of the file to the standby server so that everything can be restored on very short notice in the event of a catastrophic failure of the primary live production server. You can set the interval of the “backup and send” routine to best fit your comfort level.
SPECIAL NOTE to User of Roiginal PMBS:  If you have implemented the fist version of the PMBS (Poor Man's Backup System) and want to take advantage of this newer version, there will be some additional notes to you along the way. Please pay attention to them so that you do not interfere with your previous PMBS that is still running. On the primary host machine you will notice that the directory structure has changed by only one character so the original PMBS can continue to run while you work on this newer version. Once youhave the new version running you can delet the older directory structure without causing any harm to the new PMBS. This does not affect users setting up a PMBS for the first time.

8 Steps to building the Poor Man’s Backup System:

1.) Setup 2 identical VPS server on different hardware and different ip addresses

2.) Create simple directory structure on primary server for the created backup files

3.) Add one script file on the primary server to run the backups, compress and collect the related /files directories, combine the compressed files and the database backup into a single file, manage the combined backup files, and send those files to other servers for safe keeping

4.) Add one crontab entry on the primary server to run the custom script file

5.) Create simple directory structure on standby server to manage inbound backup files

6.) Add one script file on the standby server to manage the inbound backup files

7.) Install the “incron” utility on the standby server

8.) Add one incrontab entry on the standby server to run the backup file management script

So, let’s get started!! If you followed the instructions up to this point you already have step one finished and are ready to begin adding the proper elements to the servers. So Step #1 is finished.

From this point forward there will be many references to the “default user account” on the servers. Since they are both identical the account should also be identical on them. The default user account is the linux user account that has the ERPNext installation within it. If you used the defaults in the easy install script that account would be /home/frappe/ however I recommend that you add the –user switch to the easy install script at install time and make the default account your cloud servers linux user login account. In this document is will always be called “def_user”

Step #2:

On the primary server perform the following commands from the default user account.

> mkdir /home/def_user/bin  
> mkdir /home/def_user/backup  
> mkdir /home/def_user/backup/current  
> mkdir /home/def_user/backup/last  
> mkdir /home/def_user/backup/bk_wip

You now have a simple directory structure for holding your backup files on the primary server and easily managing them.

**IMPORTANT - The /home/def_user/bin directory is where the executable scripts you generate in the next step will be stored. In order for them to be functional, you have to tell the system that the executable scripts in this directory can be run without specifying the directory path to the script.

To do this run the following command:

export PATH=$PATH:/home/def_user/bin

Now it will not matter where you are in the directory structure, if you type the name of the script file it will run as it it were a regular linux command. :grin:

Step #3:

Use the nano editor and create the following file named ‘bkup_cycle’ in the new /bin directory

#!/bin/bash
#
# This script performs on backup cycle. A cron job will be used
# to tell this script when to run thereby generating the cycle.
#
# In the last command(s) of this script we attempt to 'scp' the newly
# created file to a backup / storage host.

# First clear out the wip directory

rm -f -r /home/erp_jmi/backup/bk_wip/*
sleep 1

# Next rotate the most recent file out of the /current directory
# into the /last holding directory

mv /home/erp_jmi/backup/current/*.tar.gz /home/erp_jmi/backup/last/

# Next just sleep for a few seconds to let filesystem settle

sleep 2

# Next, clear out the oldest records in ~/backups/last

find /home/erp_jmi/backup/last -maxdepth 1 -type f -name "*.tar.gz" -print0 | xargs -r0 ls -t | tail -n +16 | tr '\n' '\0' | xargs -r0 rm

# Next just sleep for a few seconds to let file system settle

sleep 2

# Now we just run the backup command

mysqldump -u root -pG0nefishin 1bd3e0294da19198 | gzip > /home/erp_jmi/backup/bk_wip/db_bkup.sql.gz

# Next just sleep for a few seconds to let file system settle

sleep 2

# now we have to make compressed copies of the related files:

tar -czf /home/erp_jmi/backup/bk_wip/pri-files.tar.gz -C /home/erp_jmi/frappe-bench/sites/site1.local/private/files .
sleep 2

tar -czf /home/erp_jmi/backup/bk_wip/pub-files.tar.gz -C /home/erp_jmi/frappe-bench/sites/site1.local/public/files .
sleep 2

# Now we have to combine the database backup with the other related files:

tar -czf /home/erp_jmi/backup/current/"$(date '+%m%d-%H%M').tar.gz" -C /home/erp_jmi/backup/bk_wip .

# Move the backup file to the hot spare host...

# scp /home/erp_jmi/backups/current/*.tar.gz erp_jmi@209.159.150.111:/home/erp_jmi/drop/


# Sleep at least 10 secons between scp commands

# sleep 20

# And finally we attemto to move the file to another host for storage

scp /home/erp_jmi/backup/current/*.tar.gz erp_jmi@216.158.225.221:/home/erp_jmi/drop/

# This should complete the cycle
# BKM - Apr 08,2019 @ 2:24pm

(Please NOTE that all 3 ‘tar’ commands end with a space and a period. Don’t forget them!)
.
You are not out of the woods yet… You still have to make this new script file executable. To do this run the following command:

chmod +x ~/bin/bkup_cycle

Now we can move onto the explanations of the lines in the script file:

I am not going to cover the sleep commands here, just the main important commands that do all the work and all ‘wait’ commands are there to allow the previous command to complete before allowing the script to move to the next command. So one at a time and in order, here is what they do:

mv /home/def_user/backup/current/*.tar.gz /home/def_user/backup/last/

This command moves the previous backup file out of the /current directory so it is clear for the creation of the next backup file. Previous files are stored in /backup/last/

find /home/def_user/backups/last -maxdepth 1 -type f -name "*.sql.gz" -print0 | xargs -r0 ls -t | tail -n +16 | tr '\n' '\0' | xargs $

This command was pretty hard to develop. It uses the linux ‘find’ command and digs into the /backups/last/ directory to remove all but the most recent 15 files. My system makes 15 backup files per day and I keep one day’s worth on hand on the primary server. You can adjust this to whatever number of files you are comfortable having on hand. Just edit the number 16 in “tail –n +16” to be the number of files you want to keep plus 1.

mysqldump -u root -pMySQLpassword 1da3b1049ac21798 | gzip > /home/def_user/backups/current/"$(date '+%m%d-%H%M').sql.gz"

This is the command that runs the database backup. You will need to edit in your mariadb password and your specific database name so this command will work for you. The mariadb password begins with the character immediately following the “-p” so in my case it is MySQLpassword. The next random string of characters is actually the database name. You can find yours by reading the “site_config.json” file for your site. It is very easy to identify there.

scp /home/def_user/backups/current/*.sql.gz def_user@192.168.222.111:/home/def_user/drop/

This last command is the linux Secure Copy command and allows you to securely copy files from on server to another across the internet. Just replace the dummy ip address in this command with the ip address of your standby server.

** ALERT** Before you can expect this command to run from a script via unattended crontab trigger, you must first run the command manually yourself from the command prompt. When you do this it will ask for the password to the user account on the target server. Once you manually answer the password question, the information is stored and it will run unattended from the script after that. This is my experience on Ubuntu 16.04 LTS, you mileage may vary :grin:

** ALERT 2 ** If the above method for getting the ‘scp’ command to work does not give you the results you expected, please use the information in this post to fix it:

    I have been using the linux command ‘scp’ for a while now to move copies of my scheduled backup files from my live production server to several other servers across the internet for safe keeping. However, I recently ran into a hiccup with how I have been implementing this command. I almost all cases up to this point I had been using Ubuntu 16.04 LTS linux and mostly on the same cloud services vendor networks. This led me to make an assumption about using this command within a cron triggered scr… 

:open_mouth: Bonus Info :open_mouth:

If you are really smart, you will also have another place on the internet where you can send copies of your backup files for safe keeping. Maybe on a different service provider or even a folder buried in one of your websites. All you have to do is add a 10 second sleep command followed by a second ‘scp’ command to move a copy to another location as well. My actual setup sends files to 3 aditional locations aside from the standby server.

Step #4

From the default linux user account, use the following command to open the nano editor into the crontab list:

crontab -e

Add the following line to the bottom of the list:

58 5-18,23 * * 1-6 /home/erp_jmi/bin/bkup_cycle

Adjust the numbers to best fit your desired frequency of running backups. I do it every hour at 2 minutes before the hour for the busiest 14 hours of the day and then one last time at 2 minutes before midnight. The script runs every day except Sunday. If you are not familiar with crontab syntax, please do a google search for an explanation of each setting and build your string to match your desired number of backup cycles per day.

This completes the setup steps for the primary server. The next group of steps will take place on the standby server so ssh into that server to begin.

Step #5

On the standby server perform the following commands from the default user account:

mkdir /home/def_user/bin
mkdir /home/def_user/drop
mkdir /home/def_user/current
mkdir /home/def_user/local_ready
mkdir /home/def_user/local_restore

This creates the simple directory structure for managing the database backup files generated on the primary server and sent over to this server. You may not wish to keep as elaborate a set of data files as I keep, so adjust this to your own liking.

/bin – is where the script that incrontab runs will be stored.
/drop - is where the inbound fresh database backup file is deposited from the primary server
/current – is where I keep the same 15 files that I keep on the primary server
/local_ready – is where I put a copy of the most recent inbound file (easier to find this way)
/local_restore – is a location I use to unzip a file that I am about to restore to the server

Again, the /home/def_user/bin directory is where the executable scripts you generate in the next step will be stored. In order for them to be functional, you have to tell the system that the executable scripts in this directory can be run without specifying the directory path to the script.

To do this run the following command:

export PATH=$PATH:/home/def_user/bin

Step #6

Use the nano editor and create the following file named ‘cycle_backups’ in /def_user/bin/

#!/bin/sh
#
# This script is triggered by and entry in incrontab.
# When incron detects a new file in the /drop directory it runs this script.
# Ths script moves the newely dropped file from /drop
# to the /current directory and then purges /current down to a size

rm /home/def_user/local_ready/*
sleep 2
cp /home/def_user/drop/*.sql.gz /home/def_user/local_ready/
sleep 4
mv /home/def_user/drop/*.sql.gz /home/def_user/current/
sleep 2
rm /home/erp_jmi/drop/*
sleep 2
find /home/erp_jmi/current -maxdepth 1 -type f -name "*.sql.gz" -print0 | xargs -r0 ls -t | tail -n +16 | tr '\n' '\0' | xarg$

# This should complete the movement of files in this test
# BKM - Aug 18,2018 @ 2:48pm

.
.
Also again, you must set the script file to be executable with the following command:

chmod +x ~/home/def_user/bin/cycle_backups

Now you are ready to move on…

Commands in the script explained:

rm /home/def_user/local_ready/*

This command deletes everything in the /local_ready directory so it can receive the new file

cp /home/def_user/drop/*.sql.gz /home/def_user/local_ready/

This command copies the new file from /drop to the now clean /local_ready directory. Note that I also give more sleep time before the next command. On my system the cp command seems to take a little longer to complete and settle that other commands.

mv /home/def_user/drop/*.sql.gz /home/def_user/current/

This command moves the new file out of /drop and into /current directory

rm /home/erp_jmi/drop/*

This command is really optional, but since there is really nothing else that keeps /drop in order I put this in to delete and stray entries that might show up here. I noticed a random file in /drop one time and decided to use this to keep it clean. It just deletes anything leftover.

find /home/erp_jmi/current -maxdepth 1 -type f -name "*.sql.gz" -print0 | xargs -r0 ls -t | tail -n +16 | tr '\n' '\0' | xarg$

Again, this command keeps the /current directory purged down to your chosen number of files just like on the primary server.

Step #7

The ‘incron’ utility allows you to constantly monitor a directory and then take action when something changes or is added to the directory. In our case we will be monitoring the /drop directory for new inbound database backup files form the primary server and immediately using a script (from Step #6) to handle all of the files management

From the default linux user account use the following command to install ‘incron’ utility:

sudo apt-get install incron

This will install the incron utility and allow us to use incrontab to run you script later. However, we are not done with ‘incron’ yet. The thing that makes the incron utility even better than the regular ‘cron’ utility is that it requires someone with ‘sudo’ access to tell the utility exactly who is authorized to use incrontab. So, to complete the installation and setup for incron, you need to run the following command:

sudo nano /etc/incron.allow

When the editor opens up, be sure to enter the default linux user account that you have been using everywhere else ( in our example that is def_user ). Then close the editor saving the updated file. If you also wanted the root user to be able to use incrontab then you would add a second to the file for root.

Step #8

Use the following command to open the incrontab editor:

incrontab –e

Add to following line in the editor and save it:

/home/def_user/drop/ IN_CREATE /home/def_user/bin/cycle_backups

Everything is now in place to keep the same set of database backup files on both servers and we are even automatically setting up the most recent file on the standby server for you to easily be able to restore the right file on your first try. When the primary server suffers some major failure, you are already stresses enough and choosing the right file to restore from a list of available files may be a source of further problems if you accidently pick the wrong file. This is why the /local_ready is in place.

You can create other scripts for yourself if you want to further simplify the process. Maybe one to move the file from /local_ready to /local_restore and then unzip the file.

However you want to do it, you need to have an unzipped database backup file so you can run the bench command to restore to the standby server.

BTW… here is the best command to use for running the restore (from ~/frappe-bench):

sudo bench --force --site Your.Site.Name restore ~/local_restore/YourUnzippedFile.sql

Using the above command reduces the chances of getting errors and forces the restore even if the target server is not the same as the source server.

Note: In case you are not familiar with how to create executable script files, the following command should be used after you create the file in order for it to be executable.

chmod +755 ~/bin/script_file_name

For some this might also work:

chmod +x ~/bin/script_file_name

Conclusion:

I know this is maybe not the best way to have a backup system, but it IS a method that even most novices can understand and actually maintain without a great deal of linux or developer knowledge. In my case I set my backups to be every hour during the busy part of the workday. This means that the worst case failure for me would be that the users have to repeat up to an hour of their past work in order to catch up after they login to the standby server.

I also have intentionally NOT made everything too automated. I want to make sure I am asking the users questions before I restore something to the standby system. I want to make sure the file I use is the best file for their current needs.

Recently, I had a primary server failure due to a DNS and DoS attack. The most recent backup on the standby server was only 9 minutes old. It took me a total of 23 minutes to question the users, determine the right path forward, restore the database to the standby server, and get them back to running on the standby server. Total down time was 32 minutes and they only had to repeat 9 minutes of their past work to get caught up. But that could have been as much as one hour due to how I have my Poor Man’s Backup System configured. You need to determine your own comfort level and adjust everything to fit your needs. However, I would not recommend running this process any more frequent than every 15 minutes. Running backups does put a strain on the system when it is heavily used. You will have to balance that yourself.

And finally, I have been asked why I bother to keep so many backup files on hand when you only need the most recent one for a disaster recovery. So there are 2 reasons for this. The first is just in case the disaster interrupts the scheduled backup process, you at least have the one immediately before that to use instead (you know, kind of a Murhpy’s Law protection). The second reason is a bit more insidious when it comes to the cause of the problem.

Over a decade ago, I happened to be a regular user on a system for another company. A disgruntled employee sabotaged the system before she was fired by deleting some important directories and redirecting some regular tasks to perform incorrectly so they would cause further record damage for a while without detection. It was just over 3 business days later before we figured out what had been going wrong with our system. We fortunately had a backup from 5 days prior that we were able to restore to the system. This meant we had 5 days of work to be repeated in order to catch up. However, we DID recover, and that was an important lesson learned. That is the second reason I keep so many backups on hand. The space the backups use is NOTHING compared to the possible tragic loss of business if those files didn’t exist at all.

Again, you will have to determine your comfort level for this.

Bonus Information

In order to keep even more restore opportunities available to my system, I have added an additional set of files for those “just-in-case” times. I keep 6 days of the most recent midnight backups rotating constantly on the standby server. To do this I added a /recent directory and created a regular crontab entry (not incron) on the server that looks like this:

15 0 * * 0,2-6 /home/erp_jmi/bin/cycle_files

And I have another script file called “cycle_files” that takes care of keeping those 6 days of files.

#!/bin/bash
#
# This script will cycle the most recent file in the /current directory to the /recent directory
# and then purge /recent down to the last 6 files. This script is intended to be run by a crontab
# entry at about 12:15am to load the last backup from the previous day into /recent thereby 
# creating a 6 day record of the midnight backups.
# First copy most recent file from /current to /recent

cp $(ls -t /home/def_user/current/* | head -1) /home/def_user/recent
sleep 5

# Now purge  /recent directory down to the last 6 files (hopefully the last 6 midnight backups)

find /home/def_user/recent -maxdepth 1 -type f -name "*.sql.gz" -print0 | xargs -r0 ls -t | tail -n +7 | tr '\n' '\0' | xargs $

# This should complete the rotation of the midnight backup files
# BKM - Aug 18,2018 @ 6:18pm  

This is just a starting point for you to design you own Poor Man’s Backup System. Good Luck!

BKM :sunglasses:
