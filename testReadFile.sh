#! /bin/bash

set -e

IFS=''

file="test format.txt"

customFlags='-e TZ=America/Chicago --restart=unless-stopped' # Custom flags for all containers to use

totalContainerCtr=0

nameArray=()
runCmdArray=()
imageArray=()

lastChar=$(tail -c 1 $file)

if [ -z $lastChar ]
then
    printf "ERROR, file has a blank line as the last line. Please correct and refer to example configuration file on github for formatting.\n"
    exit 1
else
    printf "File passed last line check. Moving to total line check.\n\n\n"
fi

printf "File loaded is: %s and it contains: \n" $file

cat -n $file

printf "\n\n-----------------------------------------------------------\n| Generating arrays based on 'containerConfigurations.txt' |\n-----------------------------------------------------------\n\n"

while IFS='' read -r || [ -n "$REPLY" ]
do
    numberOfPipes=$(echo "$REPLY" | tr -cd '|' | wc -c)
    IFS='|' read -ra tmpArray <<<"$REPLY"

    for ((arrayLineCtr = 0; arrayLineCtr <= numberOfPipes; arrayLineCtr++))
    do
        if [ -z "${tmpArray[$arrayLineCtr]}" ]
        then
            printf "Empty line detected for container "
            if [ $arrayLineCtr -eq 0 ]
            then
                # Image field is empty
                printf "\n\nERROR\n\nContainer %s has a blank image repo!! Please add an image repository. Exiting.\n\n" "${nameArray[$totalContainerCtr - 1]}"
                exit 1
            elif [ $arrayLineCtr -eq 1 ]
            then
                # Name field is empty
                printf "\n\nERROR\n\nContainer on line %i has a blank name field!! Please add a name in the configuration file. Exiting.\n\n" "$((totalContainerCtr + 1))"
                exit 1
            elif [ $arrayLineCtr -eq 2 ]
            then
                # Run command is empty
                printf "%i\n" "$((totalContainerCtr + 1))"
                runCmdArray+=("")
                printf "Blank run command detected! Container will run with only set custom flags:\n'%s'\n" "${customFlags:-none}"
                totalContainerCtr=$((totalContainerCtr + 1))
            fi
        else
            if [ $arrayLineCtr -eq 0 ]
            then
                # Image field
                imageArray+=("${tmpArray[$arrayLineCtr]}")
            elif [ $arrayLineCtr -eq 1 ]
            then
                # Name field
                nameArray+=("${tmpArray[$arrayLineCtr]}")
            elif [ $arrayLineCtr -eq 2 ]
            then
                # Run command field
                runCmdArray+=("${tmpArray[$arrayLineCtr]}")
                totalContainerCtr=$((totalContainerCtr + 1))
            fi
        fi
    done
done <"$file"

unset IFS

printf "\n\n--------------------------------------------------------------------------------------------\n| Successfully built arrays with container information. Moving to deploy and update phase! |\n--------------------------------------------------------------------------------------------\n\n\n"

for ((i = 0; i < ${#nameArray[@]}; i++))
do
    if [ $(docker pull ${imageArray[i]} | grep -cim1 -i 'Image is up to date') -eq 1 ]
    then # Image is up to date
        echo "${nameArray[i]} is up to date. Checking if it is running."                     # Checking if it is running

        if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]
        then # it is running
            echo "${nameArray[i]} is up to date and running. Moving to next container."
        else                                                                   # it is not running
            if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]
            then # it does exist
                docker start ${nameArray[i]}                                   # Start container
                echo "${nameArray[i]} is now started, and is already up-to-date. Moving to next container."
            else # it does not exist
                echo "${nameArray[i]} container does not exist. Running new container with name ${nameArray[i]}"
                docker run -d --name=${nameArray[i]} ${customFlags} ${runCmdArray[i]} ${imageArray[i]}
                echo "${nameArray[i]} is now running and up-to-date. Moving to next container."
            fi
        fi
    else # Image is not up to date
        echo "${nameArray[i]} is not up to date."
        echo "Pulling new image for ${nameArray[i]}." # If not up to date, shut down and remove, then redeploy with updated container
        docker pull ${imageArray[i]}
        if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]
        then  # does it exist?
            if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]
            then # it is running?
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

echo "All containers up to date!"
