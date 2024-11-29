#! /bin/bash

set -e                              # Errors will exit script

IFS=''                              # Ensure spaces don't break file parsing

file="sampleContainerData.txt"      # file for the container database
configFile="config.txt"             # file for config.txt, MUST be in same directory as the .sh script

totalContainerCtr=0                 # counter for the total number of containers present in the data file

nameArray=()                        # array to be generated of the container names
runCmdArray=()                      # array to be generated of the container run parameters
imageArray=()                       # array to be generated of the container images

configCtr=1

printf "\nWelcome to Runr, the complete 'docker run' container updater and deployment tool.\n\nEasily keep your containers up to date and deployed.\n\nKeep downtime to a minimum with Runr's smart update service that only shuts\ncontainers down if they are out of date.\n\nAvoid lengthy and confusing documents with your run commands.\n\nRunr keeps things simple and gives you peace of mind. Set, and forget.\n\n"
printf "\n\nSTARTING"

while IFS='' read -r || [ -n "$REPLY" ]                 # read 'config.txt' file line by line
do
    numberOfPipes=$(echo "$REPLY" | tr -cd '|' | wc -c) # count the number of pipes present to properly import config variables
    IFS='|' read -ra tmpArray <<<"$REPLY"               # create arrays by '|' separator
    if [ $numberOfPipes -eq 1 ] && [ $configCtr -eq 1 ]                         # check if config file has the proper amount of '|' separators per line
    then
        printf "\n\nSUCCESS, 'config.txt' properly configured.\n\n"
    elif [ $numberOfPipes -ge 2 ]
    then
        printf "ERROR, 'config.txt' is incorrectly formatted. Please refer to github or example_config.txt for more information on setting up config.txt\n\n"
        exit 1
    fi
    if [ $configCtr -eq 1 ]                             # add container data file location
    then
        printf "Adding container data file '%s'\n\n" ${tmpArray[1]}
        file=${tmpArray[1]}
    elif [ $configCtr -eq 2 ]                           # add custom flags
    then
        printf "Adding custom flags to every run command:\n'%s'\n" ${tmpArray[1]}
        customFlags=${tmpArray[1]}
    else
        printf "ERROR, too many lines detected in config.txt. Refer to github or to the exampleconfig.txt for a proper config.txt\n\n"
        exit 1
    fi
    configCtr=$(($configCtr+1))
done <"$configFile"

lastChar=$(tail -c 1 $file)         # check if the file is properly formatted without an empty line at the bottom
if [ -z $lastChar ]
then
    printf "\nERROR, file has a blank line as the last line. Please correct and refer to example configuration file on github for formatting.\n"
    exit 1                          # exit if blank line detected at end of file
else
    printf "\nFile passed last line check.\n\n"
fi

printf "File loaded is: %s\n\n" $file
cat -n $file                        # display container data file

printf "\n\n------------------------------------------------------------\n| Generating arrays based on 'containerConfigurations.txt' |\n------------------------------------------------------------\n"

while IFS='' read -r || [ -n "$REPLY" ]                 # read file line by line
do
    numberOfPipes=$(echo "$REPLY" | tr -cd '|' | wc -c) # count the number of pipes present to properly create arrays for containers
    IFS='|' read -ra tmpArray <<<"$REPLY"               # create arrays by '|' separator
    if [ $numberOfPipes -eq 0 ]
    then
        printf "ERROR, container %i formatted incorrectly. You need at least the image repo and the container's name.\nPlease use '|' to separate the image, name, and run parameters.\nSee example config file on github for more information.\n\n" $(($totalContainerCtr+1))
        exit 1                                          # exit if missing image or name of the container or using improper separator
    elif [ $numberOfPipes -eq 1 ]                       # missing run command, fill tmpArray run parameter position with empty string
    then
        tmpArray[2]=""
    elif [ $numberOfPipes -ge 3 ]                       # check for too many '|' separators
    then
        printf "ERROR, too many '|' separators found in container %i!! Please review example file on github.\n" $totalContainerCtr
    fi
    for ((arrayLineCtr = 0; arrayLineCtr <= 2; arrayLineCtr++)) # iterate through the line by the number of pipes present
    do
        if [ -z "${tmpArray[$arrayLineCtr]}" ]          # check if array content is empty
        then
            printf "\nWARNING, empty line detected for container "
            if [ $arrayLineCtr -eq 0 ]
            then        # Image field is empty
                printf "\n\nERROR\n\nContainer %s has a blank image repo!! Please add an image repository. Exiting.\n\n" "${nameArray[$totalContainerCtr - 1]}"
                exit 1  # missing image repo found
            elif [ $arrayLineCtr -eq 1 ]
            then        # Name field is empty
                printf "\n\nERROR\n\nContainer on line %i has a blank name field!! Please add a name in the configuration file. Exiting.\n\n" "$((totalContainerCtr + 1))"
                exit 1  # missing name found
            elif [ $arrayLineCtr -eq 2 ]
            then        # Run command is empty
                printf "%i\n" "$((totalContainerCtr + 1))"
                runCmdArray+=("")
                printf "Blank run command detected! Container will run with only set custom flags:\n'%s'\n" "${customFlags:-none}"
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

printf "\n---------------------------\n"
printf "Result of array generation:"
printf "\n---------------------------"

tmpCtr=0
for ((i = 1; i <= ${#imageArray[@]+1}; i++))
do
    tmpCtr=$(($i-1))
    printf "\n\nContainer %i:\n\n" $i
    printf "Image:\n%s\n\n" ${imageArray[$tmpCtr]}
    printf "Name:\n%s\n\n" ${nameArray[$tmpCtr]}
    if [ -z ${runCmdArray[$tmpCtr]} ]
    then
        printf "Run parameters:\nLeft blank\n"
    else
        printf "Run parameters:\n%s\n" ${runCmdArray[$tmpCtr]}
    fi
    printf "\n----------------------------------------"
done
unset IFS

printf "\n\n--------------------------------------------------------------------------------------------\n| Successfully built arrays with container information. Moving to deploy and update phase! |\n--------------------------------------------------------------------------------------------\n\n\n"

printf "Checking if docker daemon is running.\n\n"
if ! [ $(docker stats | grep -cim1 -i 'cannot connect') -eq 1 ]
then
    printf "\nERROR, docker daemon not running. Please start and then restart this script.\n\n"
    exit 1
else
    printf "SUCCESS, docker daemon is running.\n\n"
fi

for ((i = 0; i < ${#nameArray[@]}; i++))
do
    if [ $(docker pull ${imageArray[i]} | grep -cim1 -i 'Image is up to date') -eq 1 ]
    then            # Image is up to date
        echo "${nameArray[i]} is up to date. Checking if it is running."       # Checking if it is running
        if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]
        then        # it is running
            echo "${nameArray[i]} is up to date and running. Moving to next container."
        else                                                                   # it is not running
            if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]
            then    # it does exist
                docker start ${nameArray[i]}                                   # Start container
                echo "${nameArray[i]} is now started, and is already up-to-date. Moving to next container."
            else    # it does not exist
                echo "${nameArray[i]} container does not exist. Running new container with name ${nameArray[i]}"
                docker run -d --name=${nameArray[i]} ${customFlags} ${runCmdArray[i]} ${imageArray[i]}
                echo "${nameArray[i]} is now running and up-to-date. Moving to next container."
            fi
        fi
    else            # Image is not up to date
        echo "${nameArray[i]} is not up to date."
        echo "Pulling new image for ${nameArray[i]}."                           # If not up to date, shut down and remove, then redeploy with updated container
        docker pull ${imageArray[i]}
        if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]
        then        # does it exist?
            if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]
            then    # it is running?
                echo "${nameArray[i]} is running and out-of-date. Shutting down out-of-date container."
                docker stop ${nameArray[i]}
                echo "${nameArray[i]} is now stopped."
            fi
            echo "Removing ${nameArray[i]}."
            docker rm ${nameArray[i]}
        fi
        echo "Starting ${nameArray[i]} with new image from ${imageArray[i]}"
        docker run -d --name=${nameArray[i]} ${customFlags} ${runCmdArray[i]} ${imageArray[i]}
        echo "${nameArray[i]} started with updated image. Moving to next container."
    fi
done
echo "All containers up to date and redeployed!"
docker ps
printf "Pruning all old unused images."