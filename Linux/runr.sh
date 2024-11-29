#! /bin/bash
# Runr.sh, a script to set, and forget.
# Keep your docker containers up to date and deployed with this lightweight and easy to configure bash script!

# Variable initialization
set -e                              # Errors will exit script

RED=$(tput setaf 1)                 # Initialize terminal colors
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
UNDERLINE=$(tput smul)
NORMAL=$(tput sgr0)
BRIGHT=$(tput bold)
MAGENTA=$(tput setaf 5)

IFS=''                              # Ensure spaces don't break file parsing

file="sampleContainerData.txt"      # file for the container database
configFile="config.txt"             # file for config.txt, MUST be in same directory as the .sh script

totalContainerCtr=0                 # counter for the total number of containers present in the data file

nameArray=()                        # array to be generated of the container names
runCmdArray=()                      # array to be generated of the container run parameters
imageArray=()                       # array to be generated of the container images

configCtr=1                         # track what line of the config file is currently being read

clear

printf "\n${BRIGHT}Welcome to Runr.sh, the complete bash-based 'docker run' container updater and deployment tool.\n\n${NORMAL}Easily keep your containers up to date and deployed.\n\nKeep downtime to a minimum with Runr's smart update service that only shuts\ncontainers down if they are out of date.\n\nAvoid lengthy and confusing documents with your run commands.\n\nRunr.sh keeps things simple and gives you peace of mind. Set, and forget.\n\n"
printf "${GREEN}STARTING${NORMAL} Runr.sh${NORMAL}"

sleep 0.5

# Begin reading from config and container data files
while IFS='' read -r || [ -n "$REPLY" ]                 # read 'config.txt' file line by line
do
    numberOfPipes=$(echo "$REPLY" | tr -cd '|' | wc -c) # count the number of pipes present to properly import config variables
    IFS='|' read -ra tmpArray <<<"$REPLY"               # create arrays by '|' separator
    if [ $numberOfPipes -eq 1 ] && [ $configCtr -eq 1 ]                         # check if config file has the proper amount of '|' separators per line
    then
        printf "\n\n${GREEN}SUCCESS${NORMAL}, 'config.txt' properly configured.\n\n"
    elif [ $numberOfPipes -ge 2 ]
    then
        printf "${RED}ERROR${NORMAL}, 'config.txt' is incorrectly formatted with too many '|'. Please refer to github or example_config.txt for more information on setting up config.txt\n\n"
        exit 1
    fi
    if [ $configCtr -eq 1 ]                             # add container data file location
    then
        printf "${MAGENTA}TASK${NORMAL}, adding container data file '%s'\n\n" ${tmpArray[1]}
        file=${tmpArray[1]}
    elif [ $configCtr -eq 2 ]                           # add custom flags
    then
        printf "${MAGENTA}TASK${NORMAL}, adding custom flags to every run command:\n'%s'\n\n" ${tmpArray[1]}
        customFlags=${tmpArray[1]}
    else
        printf "${RED}ERROR${NORMAL}, too many lines detected in config.txt. Refer to github or to the exampleconfig.txt for a proper config.txt\n\n"
        exit 1
    fi
    configCtr=$(($configCtr+1))
done <"$configFile"

sleep 1

lastChar=$(tail -c 1 $file)         # check if the file is properly formatted without an empty line at the bottom
if [ -z $lastChar ]
then
    printf "\n${RED}ERROR${NORMAL}, file has a blank line as the last line. Please correct and refer to example configuration file on github for formatting.\n"
    exit 1                          # exit if blank line detected at end of file
else
    printf "\n${GREEN}SUCCESS${NORMAL}, file passed last line check.\n\n"
fi

printf "${GREEN}SUCCESS${NORMAL}, file loaded is: %s\n\n" $file
cat -n $file                        # display container data file
sleep 1
printf "\n\n${MAGENTA}TASK${NORMAL}, generating arrays based on contents of: ${UNDERLINE}%s${NORMAL}\n\n" $file

sleep 1

# Begin reading container data from file
while IFS='' read -r || [ -n "$REPLY" ]                 # read file line by line
do
    numberOfPipes=$(echo "$REPLY" | tr -cd '|' | wc -c) # count the number of pipes present to properly create arrays for containers
    IFS='|' read -ra tmpArray <<<"$REPLY"               # create arrays by '|' separator
    if [ $numberOfPipes -eq 0 ]
    then
        printf "${RED}ERROR${NORMAL}, container %i formatted incorrectly. You need at least the image repo and the container's name.\nPlease use '|' to separate the image, name, and run parameters.\nSee example config file on github for more information.\n\n" $(($totalContainerCtr+1))
        exit 1                                          # exit if missing image or name of the container or using improper separator
    elif [ $numberOfPipes -eq 1 ]                       # missing run command, fill tmpArray run parameter position with empty string
    then
        tmpArray[2]=""
    elif [ $numberOfPipes -ge 3 ]                       # check for too many '|' separators
    then
        printf "${RED}ERROR${NORMAL}, too many '|' separators found in container %i!! Please review example file on github.\n" $totalContainerCtr
    fi
    for ((arrayLineCtr = 0; arrayLineCtr <= 2; arrayLineCtr++)) # iterate through the line by the number of pipes present
    do
        if [ -z "${tmpArray[$arrayLineCtr]}" ]          # check if array content is empty
        then
            printf "\n${YELLOW}WARNING${NORMAL}, empty spot detected for container "
            if [ $arrayLineCtr -eq 0 ]
            then        # Image field is empty
                printf "\n\n${RED}ERROR${NORMAL}, container %s has a blank image repo!! Please add an image repository. Exiting.\n\n" "${nameArray[$totalContainerCtr - 1]}"
                exit 1  # missing image repo found
            elif [ $arrayLineCtr -eq 1 ]
            then        # Name field is empty
                printf "\n\n${RED}ERROR${NORMAL}, container %i has a blank name field!! Please add a name in the configuration file. Exiting.\n\n" "$((totalContainerCtr + 1))"
                exit 1  # missing name found
            elif [ $arrayLineCtr -eq 2 ]
            then        # Run command is empty
                printf "%i.\n" "$((totalContainerCtr + 1))"
                runCmdArray+=("")
                printf "${BRIGHT}INFO${NORMAL}, container will run with only set custom flags:\n'%s'\n\n" "$customFlags"
                totalContainerCtr=$((totalContainerCtr + 1))
            fi
        else
            if [ $arrayLineCtr -eq 0 ]
            then        # Image field
                imageArray+=("${tmpArray[$arrayLineCtr]}")
            elif [ $arrayLineCtr -eq 1 ]
            then        # Name field
                nameArray+=("${tmpArray[$arrayLineCtr]}")
            elif [ $arrayLineCtr -eq 2 ]
            then        # Run command field
                runCmdArray+=("${tmpArray[$arrayLineCtr]}")
                totalContainerCtr=$((totalContainerCtr + 1))
            fi
        fi
    done
done <"$file"

sleep 1

tmpCtr=1
printf "\n\n${UNDERLINE}Result of array generation:${NORMAL}"
for ((i = 0; i < ${#imageArray[@]}; i++))
do
    printf "\n\n${UNDERLINE}${GREEN}Container %i:${NORMAL}\n" $tmpCtr
    printf "${BRIGHT}Name:${NORMAL}\n%s\n" ${nameArray[$i]}
    printf "${BRIGHT}Image:${NORMAL}\n%s\n" ${imageArray[$i]}
    if [ -z ${runCmdArray[$i]} ]
    then
        printf "${BRIGHT}Run parameters:${NORMAL}\n%s ${BRIGHT}and no additional parameters.${NORMAL}\n" "$customFlags"
    else
        printf "${BRIGHT}Run parameters:${NORMAL}\n%s %s\n" ${runCmdArray[$i]} "$customFlags"
    fi
    printf "\n----------------------------------------"
    sleep .25
    tmpCtr=$((tmpCtr + 1))
done

unset IFS

sleep 0.5

printf "\n\n${GREEN}SUCCESS${NORMAL}, built arrays from file: ${UNDERLINE}%s${NORMAL}\n\n" $file

sleep 0.5

# Begin updating and deploying containers
printf "${MAGENTA}TASK${NORMAL}, checking if docker daemon is running.\nRunning '${UNDERLINE}docker${NORMAL}' command.\n\n"
if [ $(docker ps | grep -cim1 -i 'cannot connect') -eq 1 ]
then
    printf "\n${RED}ERROR${NORMAL}, docker daemon not running. Please start it and then restart this script.\n\n"
    exit 1
else
    printf "${GREEN}SUCCESS${NORMAL}, docker daemon is running.\n\n"
fi

for ((i = 0; i < ${#nameArray[@]}; i++))
do
    if [ $(docker pull ${imageArray[i]} | grep -cim1 -i 'Image is up to date') -eq 1 ]
    then            # Image is up to date
        echo "$\n{nameArray[i]} is up to date. Checking if it is running."       # Checking if it is running
        if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]
        then        # it is running
            printf "\n${GREEN}%s${NORMAL} is up to date and running. Moving to next container." ${nameArray[i]}
        else                                                                   # it is not running
            if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]
            then    # it does exist
                docker start ${nameArray[i]}                                   # Start container
                printf "\n${GREEN}%s${NORMAL} is now started, and is already up-to-date. Moving to next container." ${nameArray[i]}
            else    # it does not exist
                printf "${GREEN}%s${NORMAL} container does not exist. Running new container with name ${GREEN}%s${NORMAL}" ${nameArray[i]} ${nameArray[i]}
                docker run -d --name=${nameArray[i]} ${customFlags} ${runCmdArray[i]} ${imageArray[i]}
                printf "${GREEN}%s${NORMAL} is now running and up-to-date. Moving to next container." ${nameArray[i]}
            fi
        fi
    else            # Image is not up to date
        printf "${GREEN}%s${NORMAL} is not up to date." ${nameArray[i]}
        printf "Pulling new image for ${GREEN}%s${NORMAL}." ${nameArray[i]}                           # If not up to date, shut down and remove, then redeploy with updated container
        docker pull ${imageArray[i]}
        if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]
        then        # does it exist?
            if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]
            then    # it is running?
                printf "${GREEN}%s${NORMAL} is running and out-of-date. Shutting down out-of-date container." ${nameArray[i]}
                docker stop ${nameArray[i]}
                printf "${GREEN}%s${NORMAL} is now stopped." ${nameArray[i]}
            fi
            printf "Removing %s."
            docker rm ${nameArray[i]}
        fi
        printf "Starting %s with new image from %s" ${nameArray[i]} ${nameArray[i]}
        docker run -d --name=${nameArray[i]} ${customFlags} ${runCmdArray[i]} ${imageArray[i]}
        printf "%s started with updated image. Moving to next container." ${nameArray[i]}
    fi
done

sleep 1

printf "$\n\n{GREEN}SUCCESS${NORMAL}, all containers up to date and redeployed!"
docker ps

sleep 2

printf "${MAGENTA}TASK${NORMAL}, pruning all old unused images and old logs.\n\n"
docker system prune -a --volumes -f
find /var/lib/docker/containers/ -type f -name "*.log" -delete
printf "${GREEN}SUCCESS${NORMAL}, clean up complete. Exiting runr.sh.\n\n"