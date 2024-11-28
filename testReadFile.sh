#! /bin/bash

set -e

IFS=''

file="containerConfigurations.txt"

customFlags='-e TZ=America/Chicago --restart=unless-stopped'  # Custom flags for all containers to use

arrayLineCtr=1
lineCtr=1
totalLines=$(sed -n '$=' $file)

if [ $(( $totalLines % 3 )) -eq 0 ]
then
    printf "File properly configured."
elif ! [ $(( $totalLines % 3 )) -eq 0 ]
then
    printf "\n-----ERROR-----\n\nYour 'containerConfigurations.txt' file is missing lines.\nALL lines must be present, EVEN EMPTY ONES!!\n\nLine 1: Container Name\nLine 2: Run command parameters, such as -e, -p, etc. that are not already included in your custom flags variable.\nLine 3: Image repo, such as docker.io/hello-world\n\nLines 1 and 2 can be left blank, the program will auto-generate a name for you if you don't have one (although it\nis highly recommended you make your own, easy to remember and type one).\n\n***If line 3 is blank the program will exit and give an error,\nas an image repo is required to run a docker container.***\n"
    printf "\n\nExample config file layout:\n\nLine 1 (container name): helloWorld\nLine 2 (run parameters): -e TZ=America/Chicago -p 1111:1111 -v /path/to/data:/data\nLine 3 (image repo/location): docker.io/hello-world\nLine 4 (next container's name): myContainer\nLine 5: -e TZ=America/NewYork -p 3333:33 -e var=value --network=host -v /path/to/my/data/config:/config\nLine 6: ghcr.io/myAwesomeImageRepo\nLine 7: (OK to leave empty, program will auto-generate name.)\nLine 8: (Also ok to leave empty, if you just need the custom flags used.)\nLine 9: docker.io/image (Never leave empty, will cause Docker to error.)\netc...\n\n"
    printf "\nTo see an example configuration file, please visit the github repo.\n"
    exit 1
else
    echo "Something went wrong."
fi

nameArray=()
runCmdArray=()
imageArray=()

printf "\n\n-----------------------------------------------------------\n| Generating arrays based on 'containerConfigurations.txt' |\n-----------------------------------------------------------\n\n"

while read -r || ([ -z "$REPLY" ] && [ $(($totalLines)) -ge $(($lineCtr-1)) ])
do
    sed -n "${lineCtr}p" $file
    if [ -z "$REPLY" ]
    then
        echo "Empty line"
        if [ $arrayLineCtr -lt 3 ]
        then
            if [ $arrayLineCtr -eq 1 ] # if line is name
            then
                printf "\nBlank name detected! Auto-generating a name for it.\n"
                nameArray+=("$(echo $RANDOM | md5sum | head -c 10; echo)")
                printf "\nThe generated name of the container is ${nameArray[${#nameArray[@]}-1]}\n\n"
                nameTmp="${nameArray[${#nameArray[@]}-1]}"
                printf "Adding name '%s' to "containerConfiguration.txt" file.\n\n" $nameTmp

                printf "Replacing line %i with generated name.\n" $(($lineCtr+1))
                sed -i.backup "${lineCtr}c $nameTmp" $file

                echo "New container name added as: ${nameArray[${#nameArray[@]}-1]}"
                arrayLineCtr=$(($arrayLineCtr+1))
            elif [ $arrayLineCtr -eq 2 ] # if line is run command
            then
                runCmdArray+=("")
                printf "Blank run command detected! Container will run with only set custom flags: '%s'\n" ${customFlags}
                arrayLineCtr=$(($arrayLineCtr+1))
            fi
        elif [ $arrayLineCtr -eq 3 ] # If line is image
        then
            printf "\n\nERROR\n\nContainer %s has a blank image repo!! Please add an image repository. Exiting.\n\n" ${nameArray[$arrayLineCtr-1]}
            exit 1
        fi
    else
        if [ $arrayLineCtr -lt 3 ]
        then
            if [ $arrayLineCtr -eq 1 ] # if line is name
            then
                nameArray+=("${REPLY}")
                arrayLineCtr=$(($arrayLineCtr+1))
            elif [ $arrayLineCtr -eq 2 ] # if line is run command
            then
                runCmdArray+=("${REPLY}")
                arrayLineCtr=$(($arrayLineCtr+1))
            fi
        elif [ $arrayLineCtr -eq 3 ] # If line is image
        then
            imageArray+=("${REPLY}")
            arrayLineCtr=1
        fi
    fi
    lineCtr=$(($lineCtr+1))
done < $file

echo "${nameArray[@]}"
echo "${runCmdArray[@]}"
echo "${imageArray[@]}"

unset IFS

printf "\n\n--------------------------------------------------------------------------------------------\n| Successfully built arrays with container information. Moving to deploy and update phase! |\n--------------------------------------------------------------------------------------------\n\n\n"

for ((i = 0; i < ${#nameArray[@]}; i++)); do
	if [ $(docker pull ${imageArray[i]} | grep -cim1 -i 'Image is up to date') -eq 1 ]; then  # Image is up to date
		echo "${nameArray[i]} is up to date. Checking if it is running."  # Checking if it is running

		if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]; then  # it is running
			echo "${nameArray[i]} is up to date and running. Moving to next container."
		else  # it is not running
			if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]; then  # it does exist
				docker start ${nameArray[i]}  # Start container
				echo "${nameArray[i]} is now started, and is already up-to-date. Moving to next container."
			else  # it does not exist
				echo "${nameArray[i]} container does not exist. Running new container with name ${nameArray[i]}"
				docker run -d --name=${nameArray[i]} ${customFlags} ${runCmdArray[i]} ${imageArray[i]}
				echo "${nameArray[i]} is now running and up-to-date. Moving to next container."
			fi
		fi
	else  # Image is not up to date
		echo "${nameArray[i]} is not up to date."
		echo "Pulling new image for ${nameArray[i]}."  # If not up to date, shut down and remove, then redeploy with updated container
		docker pull ${imageArray[i]}

		if [ $(docker ps -a | grep -cim1 "${nameArray[i]}$") -eq 1 ]; then # does it exist?
			if [ $(docker ps | grep -cim1 "${nameArray[i]}$") -eq 1 ]; then  # it is running?
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