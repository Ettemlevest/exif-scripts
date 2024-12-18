#!/bin/zsh

#
# GPS location updater using exiftool
#

process_arguments() {
    while [ -n "$1" ]
    do
        case $1 in
            -h|--help) echo "GPS location updater script.\nCall with long,lat locations as arguments to update location data for image files in the images subdirectory."; exit 1;;
        esac
        shift
    done
}

process_arguments "$@"

IMAGE_FOLDER="images"
if [ ! -d "$IMAGE_FOLDER" ]; then
    mkdir $IMAGE_FOLDER
fi

# Processing coordinates and getting altitude
RAW_LONGITUDE_ARG=${1:?"missing arg 1 for LONGITUDE"}
LATITUDE_DEC=${2:?"missing arg 2 for LATITUDE"}
LONGITUDE_DEC="${RAW_LONGITUDE_ARG//,/}"

JSON=`curl -L -X GET "https://api.opentopodata.org/v1/test-dataset?locations=$LONGITUDE_DEC,$LATITUDE_DEC" --no-progress-meter`
ALTITUDE=`jq -r -n --argjson data $JSON '$data.results[0].elevation'`
echo "Altitude for the given coordinates: $ALTITUDE"

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

# Enable nullglob to avoid errors if no files match
setopt NULL_GLOB

# Loop through and add GPS data if the file is an image
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
  else
    echo "$FILE is not a supported image file."
  fi
done
