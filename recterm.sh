#!/bin/bash

# output is the only argument
# Name is for example term_session1
if [ -z $1 ]
then
    echo "Provide the output file"
    exit 1
fi


TEMP_DIR="/tmp/$1"
TTYREC_FNAME="$TEMP_DIR/$1.ttyrec"
GIF_FNAME="tty.gif"
MP4_FNAME="$TEMP_DIR/$1.mp4"
WAV_FNAME="$TEMP_DIR/$1.wav"
NEW_MP4_FNAME="$TEMP_DIR/NEW_$1.mp4"
FINAL_FNAME="$1.mp4"

# Delete current file if you want to overwrite
if [ -f "$FINAL_FNAME" ]
then
    read -p "overwrite file $FINAL_FNAME [y/N]: " answer
    if [ "$answer" = "y" ]
    then
        echo "rm \"$FINAL_FNAME\""
        rm "$FINAL_FNAME"
    else
        echo "Exiting program"
        exit 2
    fi
fi

# Delete the temp directory if it exists
if [ -d "$TEMP_DIR" ]
then
    echo "rm -r \"$TEMP_DIR\""
    rm -r "$TEMP_DIR"
fi
mkdir $TEMP_DIR

################################
#       Start Recording        #
################################
echo "sox -q -d \"$WAV_FNAME\" & ttyrec \"$TTYREC_FNAME\""
# Start audio recording and place in background and then start terminal recording
sox -q -d "$WAV_FNAME" & ttyrec "$TTYREC_FNAME"
# Kill the sox program
echo "ps -ef | grep sox | awk '{print $2}' | head -n 1 | xargs kill -15"
ps -ef | grep sox | awk '{print $2}' | head -n 1 | xargs kill -15


################################
#         Get GIF              #
################################
echo "ttygif $TTYREC_FNAME -f"
# Use ttygif to change the ttyrec into a gif
ttygif $TTYREC_FNAME -f

################################
#  GIF to MP4 (No Audio)       #
################################
echo "ffmpeg -f gif -i $GIF_FNAME -vcodec libx264 -pix_fmt yuv420p $MP4_FNAME"
# Turn that gif into an mp4 file
ffmpeg -f gif -i $GIF_FNAME -vcodec libx264 -pix_fmt yuv420p $MP4_FNAME

echo "rm $GIF_FNAME"
rm $GIF_FNAME 
################################
#  Adjusting MP4 Size          #
##############################
echo "mp4_duration=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $MP4_FNAME`"
# HERE WE NEED TO MAKE SURE THE VIDEO IS THE SAME LENGTH OF THE AUDIO
mp4_duration=`ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $MP4_FNAME`
echo "MP4 Duration: $mp4_duration"
wav_duration=`soxi -D $WAV_FNAME`
echo "WAV Duration: $wav_duration"

int_wav=`echo $wav_duration | awk -F '.' '{print $1}'`
echo "INT WAV: $int_wav"
int_mp4=`echo $mp4_duration | awk -F '.' '{print $1}'`
echo "INT MP4: $int_mp4"

echo "Resizing MP4"
ratio=`bc -l <<< "$int_wav/$int_mp4"`
echo "Ratio: $ratio"

# Trim to 3 decimals
ratio=${ratio:0:4}
echo "New ratio: $ratio"

ffmpeg -i $MP4_FNAME -filter:v "setpts=$ratio*PTS" $NEW_MP4_FNAME

################################
#  Combine WAV with MP4        #
################################
# ffmpeg -i /tmp/test1/NEW_test1.mp4 -i /tmp/test1/test1.wav -c:v copy -c:a aac -strict experimental test1.mp4
echo "ffmpeg -i $NEW_MP4_FNAME -i $WAV_FNAME -c:v copy -c:a aac -strict experimental $FINAL_FNAME"
ffmpeg -i $NEW_MP4_FNAME -i $WAV_FNAME -c:v copy -c:a aac -strict experimental $FINAL_FNAME

echo "Cleaning up temp directory $TEMP_DIR"
rm -r "$TEMP_DIR"
echo "Your MP4 file with audio is ready: $FINAL_FNAME"
