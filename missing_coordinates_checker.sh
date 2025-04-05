#!/bin/zsh
#
# Checks the sub-directories within the input directory for any images with missing location data
#

# Check if a directory path is provided
if [[ -z "$1" ]]; then
  echo "Usage: $0 <directory_path>"
  exit 1
fi

INPUT_DIR="$1"

# Check if exiftool is installed
if ! command -v exiftool &>/dev/null; then
  echo "Error: exiftool is not installed. Please install it to use this script."
  exit 1
fi

# Verify that the input is a directory
if [[ ! -d "$INPUT_DIR" ]]; then
  echo "Error: '$INPUT_DIR' is not a valid directory."
  exit 1
fi

# Iterate over each subdirectory
find "$INPUT_DIR" -type d -mindepth 1 | while read -r SUBDIR; do

  echo "Checking: $(basename $SUBDIR)"
  
  # Flag to determine if the subdirectory should be skipped
  SKIP=false
  IMAGE_FILES_COUNT=0

  # Iterate over each file in the subdirectory
  find "$SUBDIR" -type f ! -name '*_original' | while read -r FILE; do
    # Check if the file is an image file
    MIME_TYPE=$(file --mime-type -b "$FILE")
    if [[ "$MIME_TYPE" =~ ^image/ ]]; then
      # Check if the image has location data
      LOCATION_DATA=$(exiftool -gpslatitude -gpslongitude "$FILE" | grep -i "GPS Latitude\|GPS Longitude")
      if [[ -z "$LOCATION_DATA" ]]; then
        # Missing location data
        print -P "%F{red}Error:%f Missing location data in subdirectory: $SUBDIR"
        SKIP=true
        break
      fi

      ((IMAGE_FILES_COUNT++))
    fi
  done

  # Skip further processing of this subdirectory
  if [[ "$SKIP" == false ]]; then
    print -P "%F{green}Success:%f All $IMAGE_FILES_COUNT images have location data"
  fi
done
