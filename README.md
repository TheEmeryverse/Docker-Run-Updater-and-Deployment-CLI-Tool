# runr.sh - the set and forget docker container updater
A lightweight Bash script that automatically deploys and updates all your containers run with 'docker run'.
 
Current release is fully compatible with MacOS Sequoia 15.2, Docker Desktop, and 'brew install docker'.

<h2>Features:</h2>
- An easy to use and simple to understand CLI tool to keep your docker containers deployed and updated.<br>
- Easily scheduled with CRON to automate container updating.<br>
- Say goodbye to long and complicated documents filled with poorly formatted docker run commands.<br>
- Follow along and troubleshoot with detailed error messages so you can get up and running fast.<br>

<h2>Requirements:</h2>
- A terminal, running zsh or bash, that has basic tools like 'grep', 'wc', and 'tail', and 'tr'. These are almost certainly installed on your system.<br>
- Currently, MacOS Sequoia 15.2 and docker.<br>
- A text editor, such as VSCode, vim, nano, etc.<br>
- OPTIONAL (But highly recommended!): CRON familiarity. Read about CRON here: <a href="https://www.howtogeek.com/devops/what-is-a-cron-job-and-how-do-you-use-them/">here</a><br>

<h2>Documentation:</h2>
To get up and running, simply download the runr.sh folder to your desired location.<br>
It contains the files runr.sh, config.txt, and sampleContainerData.txt<br><br>
Open config.txt in your preferred text editor.<br>
It should look like this:<br><br>
Location of container data file|sampleContainerData.txt<br>
Always-on container flags|-e TZ=America/Chicago --restart=unless-stopped<br><br>

This is the file that will be used by runr.sh to find the container data it will use to deploy and update containers.<br>
It will also be used to define the flags that every container will use.<br>
Do NOT change the name of this file. It must also be in the same folder as runr.sh!<br><br>
Notice the pipe '|' separator being used, it is critical that this is present in the file, and that what comes after the '|' is the proper information.<br>
<h3>The first line of config.txt</h3>
The first line of the config.txt file is for the location of the container data file that runr.sh will build your containers from.<br>
It is recommended to keep the container data file in the same folder as runr.sh, but you can put it anywhere as long as you specify the correct path.<br><br>
An example first line of config.txt is where the container data is NOT in the same folder as runr.sh is:<br><br>
Location of container data file|/home/yourAccount/data/containerData.txt<br><br>
NOTE: Do not put quotes around the path or a space after the '|' separator.<br>
<h3>The second line of config.txt</h3>
The second line of config.txt is where the always-on flags for all of your containers will go.<br>
For example, every container needs your timezone set, so adding it here will mean you won't have to manually add it to every container.<br>
You may also want to set certain restart conditions, like 'restart=unless-stopped'.<br><br>
When you open config.txt for the first time the second line will look like this:<br><br>
Always-on container flags|-e TZ=America/Chicago --restart=unless-stopped<br><br>
Just like the first line, the '|' separator is used, and the custom flags must come after it.<br>
NOTE: Do not use quotes around the flags, or put a space after the '|' seperator.<br>
<h3>The container data file:</h3>
The is the file that contains all of the container data that runr.sh will use to build the containers.<br>
While runr.sh does come with sampleContainerData.txt, you are free to create your own as long as you correctly format it and put the proper path in config.txt.<br><br>
The proper format of the file is as follows:<br><br>
IMAGE|NAME|RUN PARAMETERS<br>
IMAGE2|NAME2|RUN PARAMETERS 2<br><br>
Just like the config.txt, file parsing uses the '|' separator. Do not put quotations around any of the fields,<br>or spaces before or after the '|' separators.<br><br>
Each line in this file is a container, and each container must include an image and a name.<br>
Containers do not need any run parameters, and will just be run with the always-on flags present in config.txt.<br><br>
If you just want to run a container with the always-on flags, there are two acceptable formats:<br><br>
IMAGE|NAME|<br><br>
Or<br><br>
IMAGE|NAME<br><br>
Remember, the minimum amount of data to build a container is the image and the name.<br>
<h2>Running runr.sh</h2>
If all of your configuration is complete, runr.sh can be run with 'bash runr.sh'. You may need to use 'sudo', depending on what account docker is running on.<br><br>
First, runr.sh checks the config.txt file to make sure it is properly formatted.<br>
If it is, it then reads the container data file specified in config.txt and checks to see if it is properly formatted.<br>
Once the check passes, runr.sh will then begin to read the container data to build the containers.<br>
Once the arrays with the container data is complete, runr.sh moves to importing them into docker.<br>
Runr.sh will automatically detect if the container is running, and if it is using an out of date image.<br>
If it finds the image the container is using is out of date, it will shut down the container and restart it using the new image.<br>
Once all of the containers are checked runr.sh will prune unused images and purge old docker logs to save space on your computer.<br><br>
NOTE: runr.sh will NOT detect if the run commands in the container data file for a container that is running are different than what is currently being used.<br><br>
Runr.sh will ONLY redeploy containers if the image is out of date. If you want to change the run commands of an existing, up-to-date container, you must first manually shut it down and then run runr.sh with the updated run parameters.<br><br>
Runr.sh also requires the docker daemon to be running, and will exit with an error message if it is not.
