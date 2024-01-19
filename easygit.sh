#!/bin/bash

function easygit {
	case $1 in
		init)
			initialize_repo $2
			;;
		add) 
			add_file $2
			;;
		checkout)
			checkout $2
			;;
		commit)
			commit $2
			;;
		delete)
			delete $2
			;;
		rollback)
			if [ $# -eq 2 ]
			then
				rollback $2
			elif [ $# -eq 3 ]
			then
				rollback $2 $3
			else
				echo "Invalid number of parameters"
		        	return 1
			fi
			;;
		history)
			history_commit
			;;
		checkfiles)
			check_files
			;;
		checklog)
			checklog $2
			;;
		zip)
			zip_repo $2
			;;
		lookintozip)
			lookintozip $2
			;;
		compile)
			compile $2
			;;
		editfile)
			editfile $2
			;;
		help)
			easygit_help
			;;
		*)
			echo "Unknown conmand. Use 'easygit help' for further information."
 	esac
}

# Initialize a repository
function initialize_repo {
	# Check for the number of parameters
	if [ $# -ne 1 ]
	then 
		echo "Invalid number of parameters"
		return 1
	fi
	
	name=$1
	
	# Check for the existence of the folder
	if [ -d $name ]
	then
		if [ -d $name/.easygit ]
		then
			echo "This directory is already controlled by easygit."
			return 1
		else
			mkdir $name/.easygit
			touch $name/.easygit/filelist
			touch $name/.easygit/commitlist
			mkdir $name/.easygit/commitlog
			return 0
		fi
	else
		# If not there, create the folder
		mkdir $name
		# Check if the directory was created successfully
        	if [ $? -eq 0 ]
        	then
        		mkdir $name/.easygit
			touch $name/.easygit/filelist
			touch $name/.easygit/commitlist
			mkdir $name/.easygit/commitlog
        		return 0
        	else
        		echo "An unknown error occured when creating new directory."
        		return 2
		fi
	fi
	
	
}

# Add a file
function add_file {
	# Check for the number of parameters
    	if [ $# -ne 1 ]
    	then 
    		echo "Invalid number of parameters"
        	return 1
    	fi

	# Check if the directory is a repository under control
    	if [ ! -d ./.easygit ]
    	then 
		echo "This directory is not under control." 
		return 2
    	fi

    	file=$1
	
	# Check for the existence of the file
    	if [ ! -f ./$file ]
    	then
		echo "Warning: File '$file' is not existed."
		return 3
    	else
		if [ -d ./.easygit/$file ]
		then
			# Already added
			echo "This file was already added to repository."
			return 4
		fi
		# Add recording in the filelist,
		# record the name and the current time stamp in .easygit
		echo "$file 0" >> "./.easygit/filelist"
		mkdir "./.easygit/$file"
		time_stamp=$(date +%s)
		cp "./$file" "./.easygit/$file/${time_stamp}_$file"
    		echo "File '$file' added to the repository."
	
		return 0  
    	fi
}

# Delete a file
function delete {
	# Check for the number of parameters
	if [ $# -ne 1 ]
    	then 
    		echo "Invalid number of parameters"
        	return 1
    	fi

	# Check if the directory is a repository under control
	if [ ! -d ./.easygit ]
    	then 
		echo "This directory is not under control." 
		return 2
    	fi
	
	file=$1

	# Check for the existence of the file
	if [ ! -f ./$file ]
    	then
		echo "Warning: File '$file' is not existed."
		return 3
    	else
		read -n 1 -p "Are you sure to delete this file $file? (y/n)" option
		echo ""
		if [ "$option" = "y" ]
		then
			# Remove: the file in the repository, in the hidden folder .easygit
			# add remove the recording of it in filelist
			rm -f ./$file
			rm -rf ./.easygit/$file
			sed -i "/^$file /d" ./.easygit/filelist
			echo "Delete successful!"
		else
			echo "Operation cancelled."
		fi
	fi
	
	return 0  
}

# Check out a file
function checkout {
	# Check for the number of parameters
	if [ $# -ne 1 ]
	then
		echo "Invalid number of parameters."
		return 1
	fi

	# Check if the directory is a repository under control
	if [ ! -d ./.easygit ]
	then
		echo "This directory is not under control."
		return 2
	fi

	# Check if the file is under management
	if grep -q "$1" "./.easygit/filelist"
	then
		# Check if the file's remark in .easygit/filelist is 0 (not occupied)
		status=$(grep "$1" "./.easygit/filelist" | cut -d' ' -f2)
		if [ $status -eq 0 ]
		then
			# Copy the file to temp folder
			sed -i "/^$1/s/ 0$/ 1/" ./.easygit/filelist

			if [ ! -d "./.easygit/${USER}tmp" ]
			then
				mkdir "./.easygit/${USER}tmp"
			fi

			cp "$1" "./.easygit/${USER}tmp/$1"
			# Let the user edit the file
			editfile "./.easygit/${USER}tmp/$1"

		elif [ $status -eq 1 ]	# Already checked out
		then	
			echo "The file has been checked out!"
			return 4
		fi
    	else
   		echo "This file is not under control."
		return 3
	fi

	
}

# Commit a file
function commit {
	# Check the number of parameters
	if [ $# -ne 1 ]
	then
		echo "Invalid number of parameters."
		return 1
	fi
	
	# Check if the directory is under control
	if [ ! -d ./.easygit ]
    	then 
		echo "This directory is not under control."
		return 2
    	fi

	# Look for ./.easygit/${USER}tmp
	if [ -d ./.easygit/${USER}tmp ]	# if found
	then
		# Record this commit in commitlist
		time_stamp=$(date +%s)
		echo "$time_stamp:$1:${USER}" >> ./.easygit/commitlist

		# Cover every file from ./.easygit/${USER}tmp in the directory
		# And move them to the corresponding folder in the hidden folder .easygit
		# The difference will be compared and the result will be recorded in ./.easygit/commitlog

		touch temp_log.txt
		echo "difference:" >> temp_log.txt
		for new_file in "./.easygit/${USER}tmp"/*; do
			base_name=$(basename "$new_file")
			org_file="./$base_name"
			diff=$(diff -u $new_file $org_file)
			cp -f "$new_file" "$org_file"

			echo "$base_name:" >> temp_log.txt
			echo "$diff" >> temp_log.txt
			echo "" >> temp_log.txt
				
			cp "$new_file" "./.easygit/$base_name/${time_stamp}_$base_name"
			sed -i "/^$base_name/s/ 1$/ 0/" ./.easygit/filelist
		done

		touch "./.easygit/commitlog/commit_$time_stamp"
		mv temp_log.txt "./.easygit/commitlog/commit_$time_stamp"
		
		rm -rf "./.easygit/${USER}tmp"
		
		echo "Files were committed successfully."

		return 0
	else	# if not found
		echo "Error: You don't have any file to commit!"
		return 3
	fi
	
}

# Rollback operation
function rollback {
	# If 1 parameter, display all the history version of the file
	if [ $# -eq 1 ]
    	then 
		# If found or not
    		if [ ! -d ./.easygit/$1 ]
		then	
			echo "Can not find any old version for file $1"
		else
			echo "Here are old versions of this file, please use 'easygit rollback <filename> <committime>' to decide which version to rollback to."
			# Show all the versions
			for file in `ls ./.easygit/$1`
			do 
				OLD_IFS="$IFS"
				IFS="_"
				read -ra tmparr <<< "$file"
				time=${tmparr[0]}
				TZ="Asia/Shanghai"
				formattedtime=$(date -d "@$time" '+%Y-%m-%d %H:%M:%S')
				echo "Version: $time, Version commit time: $formattedtime"
			done
			IFS="$OLD_IFS"
		fi
	# If 2 parameters, directly find the version with specified time stamp, and cover the file in repository with it
	elif [ $# -eq 2 ]
	then
		# Look for the version
		if [ ! -f ./.easygit/$1/$2_$1 ]
		then	
			echo "Can not find version of commit $2 for file $1"
		else
			read -n 1 -p "Are you sure to do rollback $1 to the version of commit $2? (y/n)" option
			echo ""
			if [ "$option" = "y" ]
			then
				cp ./.easygit/$1/$2_$1 ./$1
				if [ $? -eq 0 ]
        			then
        				echo "Rollback successfully!"
        				return 0
        			else
        				echo "An unknown error occured when doing rollback."
        				return 2
				fi
			else
				echo "Operation cancelled."
			fi
		fi
	fi
}

# View the history of commit
function history_commit {
	printf "%-15s %-15s %-15s\n" "Time Stamp" "User" "Comment"
    	echo "---------------------------------------------"
	
	while IFS= read -r line
    	do
        
        time_stamp=$(echo "$line" | cut -d':' -f1)
        user=$(echo "$line" | cut -d':' -f3)
        comment=$(echo "$line" | cut -d':' -f2)

        printf "%-15s %-15s %s\n" "$time_stamp" "$user" "$comment"
    done < "./.easygit/commitlist"
}

# Check for the current status of the file
function check_files {
	printf "%-15s %s\n" "Status" "File"
    	echo "---------------------------------------------"
	
	while IFS= read -r line
    	do
        
        file_name=$(echo "$line" | cut -d' ' -f1)
        status_num=$(echo "$line" | cut -d' ' -f2)
        
	if [ "$status_num" -eq 1 ]
	then
            status="Occupied"
        elif [ "$status_num" -eq 0 ]
	then
            status="Available"
        else
            status="Unknown" 
        fi

        printf "%-15s %s\n" "$status" "$file_name"
    done < "./.easygit/filelist"
}

# View commitlog by time stamp
function checklog {
	# Check for the number of parameters
	if [ $# -ne 1 ]
	then
		echo "Invalid number of parameters."
		return 1
	fi
	
	# If found or not
	if [ -f ./.easygit/commitlog/commit_$1 ]
	then
		echo "Commit log found, the following is the content:"
		cat ./.easygit/commitlog/commit_$1
	else
		echo "Sorry, no commit log with time stamp $1 found."
	fi
	
	return 0
}

# Compress a repository
function zip_repo {
	# Check for the number of parameters
	if [ $# -ne 1 ]; 
	then
  		echo "Invalid number of parameters."
  		exit 1
	fi

	target_zip="$1"

	# Compress
	zip -r "$target_zip" "./" -x ".easygit/*"

	echo "Repository was compressed successfully to $target_zip"
}

# View inside a zip package
function lookintozip {
    	# Check for the number of parameters
    	if [ $# -ne 1 ]; 
    	then
  		echo "Invalid number of parameters."
  		exit 1
   	fi

    	tmp_dir=".unzip_tmp"
    	zip_file="$1"

    	# Decompress to a temp directory
    	unzip -q "$zip_file" -d "$tmp_dir"

    	# Enter the directory
    	cd "$tmp_dir" || exit

    	while true; do

  		# Display the content
  		echo "Files:"
  		find . -maxdepth 1 -type f | sed "s/\.\//  /" 
  		echo "Folders:" 
  		find . -maxdepth 1 -type d ! -name ".*" | sed "s/\.\//  /" 

  		read -p "Enter (check <name>) to view content of a file or enter folder, q to exit: " input

  		case $input in

    		check*)
      			name="${input#check }" # Take out name after check
      			if [ -f "$name" ]; then 
        			cat "$name"
      			elif [ -d "$name" ]; then
        			cd "$name" || exit
      			else
        			echo "Invalid fi le or folder name"
      			fi  
      			;;

    		q)
      			break;;

    		*) 
      			echo "Invalid input"
      			;;

  		esac
	done 

	# Delete the temporary directory
	cd ..
	rm -rf "$tmp_dir"
}

# Edit a file
function editfile {
	# Check for the number of parameters
	if [ $# -ne 1 ]
	then
		echo "Invalid number of parameters!"
		return 1
	fi
	
	# Get the file name and its basename
	filename=$1
	base_name=$(basename "$filename")
	
	# Check if the file is there or not
	if [ ! -f $filename ]
	then
		echo "Error: File not found!"
		return 2
	fi
	
	# Get line, word and character count of the file
	line_num=$(wc -l < "$filename")
	word_num=$(wc -w < "$filename")
	char_num=$(wc -m < "$filename")

	# Get file size
	file_size=$(du -h "$filename" | cut -f1)

	# Get file type
	file_type=$(file "$filename" | cut -d: -f2)
	
	# Display the menu
	echo ""
	echo "*************************** File Edit ***************************"
	echo ""
	echo "------ Attributes ------"
	echo "  File Name: $base_name"
	echo "       Size: $file_size"
	echo "       Type:$file_type"
	echo "      Lines: $line_num"
	echo "      Words: $word_num"
	echo " Characters: $char_num"
	echo ""
	
	# Decide the way for displaying it
	# Smaller file (no more than 10 lines) - Show all the contents
	# Larger file - Show only the first 10 lines
	if [ $line_num -eq 0 ]
	then
		large_file=false
		echo "The file is currently empty."	
	elif [ $line_num -le 10 ]
	then
		large_file=false
		echo "--------------------- Content ---------------------"
		cat "$filename"
	else
		large_file=true
		echo "---------- Content of the first 10 lines ----------"
		head -n 10 "$filename"
		echo "......"
	fi
	echo ""
	
	# Ask for the option
	while true; do
		echo "Use option 'n' to edit in Nano, 'v' to edit in Vi;"
		echo "or use quick options:"
		echo ""
		echo "1: Insert a line"
		echo "2: Update a line"
		echo "3: Replace a string"
		echo "4: Replace a word"
		echo "5: Delete line(s)"
		echo "6: View attributes"
		echo "7: View all lines"
		if $large_file
		then
			echo "8: View specified lines"
		fi
		echo "0: Quit"
		read -p "Enter your option: " option
		
		case $option in
			N)
				# Edit in Nano
				if command -v nano >/dev/null 2>&1; 
				then
    					nano $filename
				else
   					echo "It seems that Nano is not installed."
				fi
				echo ""
				;;
			n)
				# Edit in Nano
				if command -v nano >/dev/null 2>&1; 
				then
    					nano $filename
				else
   					echo "It seems that Nano is not installed."
				fi
				echo ""
				;;
			V)
				# Edit in Vi
				vi $filename
				echo ""
				;;
			v)
				# Edit in Vi
				vi $filename
				echo ""
				;;
			1)
				# Insert into a line

				read -p "Enter the No. of the line to insert: " line
				if ! [[ $line =~ ^[0-9]+$ ]]
				then
					echo ""
					echo "Error: Not a number!"
				elif [ $line -le 0 ]
				then
					echo ""
					echo "Invalid operation: The file starts from line 1."
				else
					read -p "Enter the content in the new line: " content
					echo ""
					if [ $line -le $line_num ]
					then
						sed -i "$line i $content" "$filename"
					else
						empty_line=$(($line - $line_num - 1))
						for ((i=1; i<=empty_line; i++))
						do
							echo "" >> $filename
						done
						echo $content >> $filename
					fi
					echo "Insert done!"
				fi
				echo ""
				;;
			2)
				# Update a line
				read -p "Enter the No. of the line: " line
				if ! [[ $line =~ ^[0-9]+$ ]]
				then
					echo ""
					echo "Error: Not a number!"
				elif [ $line -gt $line_num ]
				then
					echo ""
					echo "Invalid operation: Currently this file contains only $line_num lines."
				elif [ $line -le 0 ]
				then
					echo ""
					echo "Invalid operation: The file starts from line 1."
				else
					echo ""
					echo "The original content in line $line: "
					sed -n "${line}p" "$filename"
					read -p "Enter the new content for this line: " content
    			        	sed -i "${line}s/.*/$content/" "$filename"
					
					echo "Update done!"
					echo ""
				fi
				;;
			3)	
				# Replace a string given with another
				read -p "Enter the string that you'd like to replace: " old_string
				read -p "Enter the new string: " new_string
				echo ""
				
				string_count=$(grep -o "$old_string" "$filename" | wc -l)
				sed -i "s/$old_string/$new_string/g" "$filename"
				
				echo "Replace done! Number of replacements: $string_count"
				echo ""
				;;
			4)
				# Replace a word given with another
				read -p "Enter the word that you'd like to replace: " old_word
				read -p "Enter the new word: " new_word
				echo ""
				
				word_count=$(grep -ow "$old_word" "$filename" | wc -l)
				sed -i "s/\b$old_word\b/$new_word/g" "$filename"
				
				echo "Replace done! Number of replacements: $word_count"
				echo ""
				;;
			5)
				# Delete from one line to another
				read -p "Enter the No. of the line that deleting starts: " start
				read -p "Enter the No. of the line that deleting ends: " end
				echo ""
				
				if [[ ! $start =~ ^[0-9]+$ ]] || [[ ! $end =~ ^[0-9]+$ ]]
				then
					echo ""
					echo "Error: Not a number!"
				elif [ $start -le $end ]
				then
					if [ $end -gt $line_num ]
					then
						echo "Invalid operation: Currently this file contains only $line_num lines."
					elif [ $start -le 0 ]
					then
						echo "Invalid operation: The file starts from line 1."
					else
						sed -i "$start, $end d" "$filename"
						echo "Delete done!"
					fi
				else
					echo "Invalid operation: The end line should not be smaller than the start line."
				fi
				
				echo ""					
				;;
			6)
				# See all the attributes
				echo ""
				echo "----- Attributes -----"
				echo "  File Name: $base_name"
				echo "       Size: $file_size"
				echo "       Type:$file_type"
				echo "      Lines: $line_num"
				echo "      Words: $word_num"
				echo " Characters: $char_num"
				echo ""
				;;
			7)
				# View all the content
				if [ $line_num -eq 0 ]
				then
					echo "The file is currently empty."
				else
					echo "---------------------------------------------------"
					cat $filename
					echo "---------------------------------------------------"
				fi
				echo ""
				;;
			8)
				# View from one line to another
				# This option only applies to larger file
				# Do a check to see if the current file is a large file
				if $large_file
				then
					# If this is a large file
					read -p "Enter the No. of the start line: " start
					read -p "Enter the No. of the end line: " end
					echo ""
					
					if [[ ! $start =~ ^[0-9]+$ ]] || [[ ! $end =~ ^[0-9]+$ ]]
					then
						echo ""
						echo "Error: Not a number!"
					elif [ $start -le $end ]
					then
						if [ $end -gt $line_num ]
						then
							echo "Invalid operation: Currently this file contains only $line_num lines."
						elif [ $start -le 0 ]
						then
							echo "Invalid operation: The file starts from line 1."
						else
							echo "---------------------------------------------------"
							sed -n "$start, $end p" "$filename"
							echo "---------------------------------------------------"
						fi
					else
						echo "Invalid operation: The end line should not be smaller than the start line."
					fi
				else
					# Not a large file, so this is an invalid option input
					echo "Invalid option, try again!"
				fi
				echo ""
				;;
			0)
				# Quit
				return 0
				;;
			*)
				# Invalid option input
				echo "Invalid option, try again!"
				echo ""
				;;
		esac
		
		# Update attributes of the file
		line_num=$(wc -l < "$filename")
		word_num=$(wc -w < "$filename")
		char_num=$(wc -m < "$filename")
		file_size=$(du -h "$filename" | cut -f1)
		file_type=$(file "$filename" | cut -d: -f2)

		if [ $line_num -le 10 ]
		then
			large_file=false
		else
			large_file=true
		fi
	done
	
	return 3
}

# Compile a file (support C/C++/Java)
function compile {
	# Check for the number of parameters
	if [ ! $# -eq 1 ]
	then
        	echo "Invalid number of parameters."
		return 1
	fi

	name=$1
	# Look for it
	if [ ! -f $name ]
	then
		echo "Can not find the file $name"
		return 2
	fi

	OLD_IFS="$IFS"
	IFS="."
	read -ra tmparr <<< "$name"
	file_name="${tmparr[0]}"
	extension_name="${tmparr[1]}"
	IFS="$OLD_IFS"
	# C/C++
	if [ "$extension_name" = "c" ] || [ "$extension_name" = "cpp" ]
	then 
		gcc -v > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			gcc $name
			echo "This file was compiled successfully into '${file_name}.out'."
		else
			echo "This command was implemented with gcc integrated, please use 'apt install gcc' first to install gcc."
		fi
	# Java
	elif [ "$extension_name" = "java" ]
	then
		java -version > /dev/null 2>&1
		if [ $? -eq 0 ]
		then
			javac $name
			echo "This file was compiled successfully into '${file_name}.class'."
		else
			echo "This command was implemented with gcc integrated, please use 'apt install openjdk-17-jdk' first to install jdk."
		fi 
	fi
}

# Output the help message
function easygit_help {
	echo "Welcome to EasyGit Help! "
	echo " "
	echo "1. Command: init "
	echo "	Parameters required: directory name. "
	echo "	This command is the repository initialization function. You should input the directory name as input. If the directory already exists, then join EasyGit directly. If the directory does not exist, then EasyGit will create a new directory with given name and add it to EasyGit. "

	echo " "
	echo "2. Command: add "
	echo "	Parameters required: file name. "
	echo "	This command is the file adding function. You should input the file name as input. If the file exists under the unmanaged directory, warning massage will be given. If the file does not exists, warning massage will be given. If the file already exist in the repository, warning massgae will be given. The file will be recorded with time stamp. "
	
	echo " "
	echo "3. Command: checkout "
	echo "	Parameters required: file name. "
	echo "	This command is the file commiting function. You should input the file name as input. If the file can be found, you can edit it as you want. If the file has been checked out (by anyone), you can not check out again. "
	
	echo " "
	echo "4. Command: commit "
	echo "	Parameters required: commit comment(s). "
	echo "	This command is the commiting function. You should input the comment(s) for commiting. You will commit all files can be commited. EasyGit will automatically logging commit records. "

	echo " "
	echo "5. Command: delete "
	echo "	Parameters required: file name "
	echo "	This command is the file delete function. The file will be deleted and removed from repository. "

	echo " "
	echo "6. Command: rollback "
	echo "	Parameters required: file name (with or without time stamp). "
	echo "	This command is the roll back function. You should input the file name. You can also input the specific timestamps to find the specific file. You will easily find any file you want. "

	echo " "
	echo "7. Command: history "
	echo "	No parameters required "
	echo "	This command is the commit history showing function. You can see all the commit history with information. "

	echo " "
	echo "8. Command: checklog "
	echo "	Parameters required: time stamp "
	echo "	This command is the commit log showing function. You can see all the commit log with information. "

	echo " "
	echo "9. Command: zip "
	echo "	Parameters required: targit address "
	echo "	This command is the zipping function. You can easily compress your repository. "

	echo " "
	echo "10. Command: lookintozip "
	echo "	Parameters required: zip file name "
	echo "	This command is the function to check file(s) in the zip file. You can check all context in the zip file. "

	echo " "
	echo "11. Command: checkfiles "
	echo "	No parameters required "
	echo "	This command is the files checking function. You can see all files with information. "

	echo " "
	echo "12. Command: compile "
	echo "	Parameters required: file name "
	echo "	This command is the code compiling function. You can compile C, C++, and Java code with EasyGit. EasyGit will automatically decide the compiler for you. "

	echo " "
	echo "13. Command: editfile "
	echo "	Parameters required: file name "
	echo "	This command is the text editing function. You can edit the text with the edit file command. "
	return 0
}

easygit $1 $2 $3
