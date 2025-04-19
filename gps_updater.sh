#!/bin/zsh
#
# GPS location updater using exiftool
#

# HELP:
#   - to copy GPS coordinates from a source image to a target image:
#     exiftool -TagsFromFile source.jpg -GPSLatitude -GPSLatitudeRef -GPSLongitude -GPSLongitudeRef -GPSAltitude target.jpg
#     exiftool -TagsFromFile source.jpg -gps:all target.jpg

#
# Default values
#
IMAGE_FOLDER="$(pwd)/images"

while [[ "$#" -gt 0 ]]
do case $1 in
    -c|--gps) GPS_COORDINATES="$2"
    shift;;
    -f|--folder) IMAGE_FOLDER="$2"
    shift;;
    -h|--help)
      echo "Usage:"
      echo "Manually add GPS coordinates to images:"
      echo "  $0 --gps|c \"LAT,LONG\" --folder|-f \"FOLDER_PATH\""
      echo " "
      echo "  $0 --help|-h"
      echo " "
      echo "Supports Google Maps location informations, just copy it from Maps"
      exit 0;
    shift;;
    *) echo "Unknown parameter passed: $1"
    exit 1;;
esac
shift
done

#
# Validations
#
if [[ -z "$GPS_COORDINATES" ]]; then
    echo "Error: No GPS coordinates provided. Use --gps \"LAT,LONG\""
    exit 1
fi

if [ ! -d "$IMAGE_FOLDER" ]; then
    echo "Error: Working folder does not exist! Folder path: $IMAGE_FOLDER"
    exit -1
fi

echo "Working directory: $IMAGE_FOLDER"

#
# Processing coordinates and getting altitude
#
LONGITUDE_DEC=$(echo $GPS_COORDINATES | cut -d ',' -f 2 | xargs)
LATITUDE_DEC=$(echo $GPS_COORDINATES | cut -d ',' -f 1 | xargs)

echo "Parsed coordinates:"
echo "  Longitude: $LONGITUDE_DEC"
echo "  Latitude:  $LATITUDE_DEC"

JSON=`curl -L -X GET "https://api.opentopodata.org/v1/test-dataset?locations=$LONGITUDE_DEC,$LATITUDE_DEC" --no-progress-meter`
ALTITUDE=`jq -r -n --argjson data $JSON '$data.results[0].elevation'`
echo "  Altitude:  $ALTITUDE"

# Function to convert decimal degrees to degrees, minutes, and seconds
convert_to_dms() {
  local DECIMAL=$1
  local REF=$2

  local DEG=$(printf "%.0f" "$DECIMAL")
  local MIN=$(printf "%.0f" "$(bc <<< "scale=6; ($DECIMAL - $DEG) * 60")")
  local SEC=$(printf "%.2f" "$(bc <<< "scale=6; (($DECIMAL - $DEG) * 60 - $MIN) * 60")")

  if (( $(echo "$DECIMAL < 0" | bc -l) )); then
    DEG=$(printf "%.0f" "-$DEG")
  fi

  echo "${DEG},${MIN},${SEC}"
}

# Convert Google Maps coordinates to DMS
LATITUDE_DMS=$(convert_to_dms "$LATITUDE_DEC" "Latitude")
LONGITUDE_DMS=$(convert_to_dms "$LONGITUDE_DEC" "Longitude")

# Determine latitude and longitude reference (N/S/E/W)
LAT_REF=$(awk -v lat="$LATITUDE_DEC" 'BEGIN {print (lat < 0) ? "S" : "N"}')
LON_REF=$(awk -v lon="$LONGITUDE_DEC" 'BEGIN {print (lon < 0) ? "W" : "E"}')


IMAGE_FILES_COUNT=0
for FILE in $IMAGE_FOLDER/*; do
  if [[ $(exiftool -T -FileType "$FILE") =~ ^(JPEG|PNG|TIFF|GIF|WEBP|HEIC)$ ]]; then
    ((IMAGE_FILES_COUNT++))
  fi
done

echo "$IMAGE_FILES_COUNT images found"
echo " "

echo "Do you want to proceed? (y/n): "
read CONFIRMATION

if [[ "$CONFIRMATION" != "y" && "$CONFIRMATION" != "Y" ]]; then
  echo "Operation canceled by the user."
  exit 0
fi

# Enable nullglob to avoid errors if no files match
setopt NULL_GLOB

#
# Loop through and add GPS data if the file is an image
#
UPDATED_FILES_COUNT=0
for FILE in $IMAGE_FOLDER/*; do
  if [[ $(exiftool -T -FileType "$FILE") =~ ^(JPEG|PNG|TIFF|GIF|WEBP|HEIC)$ ]]; then
    exiftool -overwrite_original \
      -GPSLatitude="$LATITUDE_DMS" \
      -GPSLatitudeRef="$LAT_REF" \
      -GPSLongitude="$LONGITUDE_DMS" \
      -GPSLongitudeRef="$LON_REF" \
      -GPSAltitude="$ALTITUDE" \
      "$FILE"
    
    echo "Added GPS data to $FILE"

    ((UPDATED_FILES_COUNT++))

  else
    echo "$FILE is not a supported image file."
  fi
done

echo
echo "$UPDATED_FILES_COUNT images updated"
