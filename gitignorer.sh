#!/bin/bash
usage()
{
    # Print the usage and exit
    echo "usage: gitignoremaker [-vh] [-o outfile] language1 [language2] ... [languageN]"
    echo "           -v:    verbose mode"
    echo "           -h:    display this message"
    echo "   -o outfile:    output file (will check if file exists)"
    echo "    languageN:    programming language(s)/IDE(s) to omit from git (e.g. python sass)"
    exit 1
}

# If no arguments are passed, print usage and exit
if [[ $# -eq 0 ]]; then
  usage
fi

# Default file is .gitignore, but a check whether this
# exists or not is performed later
OPTIND=1
output_file=".gitignore"
verbose=false

# Use getopts to perform arg parsing
while getopts "hvo:" opt; do
  case "$opt" in
  h)
    usage
    exit 0
    ;;
  v)
    verbose=true
    ;;
  o)
    output_file=$OPTARG
    ;;
  esac
done
# Get the remaining arguments on the command line (i.e. the IDEs)
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Replace spaces in the string with commas and print out the 
# string to be passed to the API if the -v flag is used
str=$@
str="${str// /,}"
if $verbose ; then
  echo "==> Passing string: '$str' to API";
fi

# Get the available gitignore types into a string variable
# use -s flag with curl to prevent output
types=$(curl -s https://www.gitignore.io/api/list)
new_str=""
found_error=false # to be used as a flag to trigger output later

IFS=',' # Set comma as delimeter
read -ra ADDR <<< "$str" # Read str into array
if [[ ${#ADDR[@]} -eq 0 ]]; then
  # If the user passes a flag but fails to provide any other input
  # print the usage and exit
  usage
fi
# Loop over the arguments and if they are in the 'types' string
# append them to the 'new_str' variable, otherwise notify the user
# that a given type is not understood by the API
for i in "${ADDR[@]}"; do
  if [[ ! $types == *$i* ]]; then
    echo "!!! NotRecognisedByAPIError: '$i'"
    found_error=true
  else
    new_str="$i,${new_str}"
  fi
done
IFS=' ' # reset IFS to space

# Remove trailing comma from 'new_str'
new_str=${new_str::-1}
if $found_error ; then
  echo "==> Passing '$new_str' to API instead"
fi

# Poll the API with the new string and store the result 
# in 'gitignore' variable, again with the -s flag to 
# prevent output
gitignore=$(curl -s "https://www.gitignore.io/api/$new_str")

# Function called once it has been deemed whether a file exists
# and should be overwritten or not (in while loop below)
write_to_file()
{
  echo # newline
  echo $gitignore > $1
  echo "==> gitignore written to '$1'"
}

# Check whether 'output_file' already exists and prompt the user
# to either provide a new file name or to overwrite the file
while [[ -f $output_file ]]
do
  read -p "!!! '$output_file' already exists, overwrite? [y/N]: " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    break
  else
    if [[ ! $REPLY == "" ]]; then
      echo # newline
    fi
    read -p "==> New file name: " -r
    output_file=$REPLY
  fi
done
write_to_file $output_file
