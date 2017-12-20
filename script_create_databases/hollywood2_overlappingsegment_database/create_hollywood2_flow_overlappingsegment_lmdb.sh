#!/usr/bin/env bash
# Create the flow lmdb inputs

SCRIPT_NAME="$0"
if [ $# != 2 ]; then
  printf 'Usage: %s dataset_folder result_database_folder\n' $SCRIPT_NAME
  exit
fi

if [ ! -d $1 ] || [ ! -d $2 ]; then
  echo 'Arguments must be directory'
  exit
fi

TOOLS=/home/tranlaman/Desktop/caffe-workspace/my-very-deep-caffe/cmake-build-c3d/tools/

DATASET_FOLDER=$1
DATABASE_FOLDER=$2
SPLIT=1

# some options variable
TIME_STAMP=$(date +%d.%H%M%S)
GRAY=true
IS_FLOW=true
PRESERVE_TEMPORAL=true
NEW_LENGTH=16
SHUFFLED_TRAIN_FILE=$(printf "shuffled_train_list_frm_split%02d_%s.txt" $SPLIT $TIME_STAMP)
SHUFFLED_TEST_FILE=$(printf "shuffled_test_list_frm_split%02d_%s.txt" $SPLIT $TIME_STAMP)
TRAIN_DATABASE='train_flow_lmdb'
VAL_DATABASE='val_flow_lmdb'
IN_FOLDER_LINK=$(printf 'in_%s' $TIME_STAMP)

# start timing
start=$(date +%s)

if [ -L $IN_FOLDER_LINK ]; then
  rm $IN_FOLDER_LINK
fi
ln -s $DATASET_FOLDER $IN_FOLDER_LINK

# Set RESIZE=true to resize the images to 256x256. Leave as false if images have
# already been resized using another tool.
RESIZE=false
if $RESIZE; then
  RESIZE_HEIGHT=128
  RESIZE_WIDTH=171
else
  RESIZE_HEIGHT=0
  RESIZE_WIDTH=0
fi

# generate shuffled train/test files
python generate_shuffled_flow_overlappingsegment_train_test_list.py --dataset_folder=$IN_FOLDER_LINK \
  --split=$SPLIT --new_length=$NEW_LENGTH \
  --shuffled_train_list_file=$SHUFFLED_TRAIN_FILE --shuffled_test_list_file=$SHUFFLED_TEST_FILE

echo "Creating train lmdb..."

$TOOLS/convert_segment_data \
    --resize_height=$RESIZE_HEIGHT \
    --resize_width=$RESIZE_WIDTH \
    --new_length=$NEW_LENGTH \
    --gray=$GRAY \
    --is_flow=$IS_FLOW \
    --preserve_temporal=$PRESERVE_TEMPORAL \
    $SHUFFLED_TRAIN_FILE \
    $DATABASE_FOLDER/$TRAIN_DATABASE &

sleep 5s
mv train_lmdb_keys.txt $DATABASE_FOLDER/$TRAIN_DATABASE

echo "Creating val lmdb..."

$TOOLS/convert_segment_data \
    --resize_height=$RESIZE_HEIGHT \
    --resize_width=$RESIZE_WIDTH \
    --new_length=$NEW_LENGTH \
    --gray=$GRAY \
    --is_flow=$IS_FLOW \
    --preserve_temporal=$PRESERVE_TEMPORAL \
    $SHUFFLED_TEST_FILE \
    $DATABASE_FOLDER/$VAL_DATABASE &

sleep 5s
mv test_lmdb_keys.txt $DATABASE_FOLDER/$VAL_DATABASE

wait    # for all the process to finish

echo "Compute image mean from database ..."
$TOOLS/compute_flow_image_mean --gray=$GRAY $DATABASE_FOLDER/$TRAIN_DATABASE hollywood2_mean.binaryproto hollywood2_mean.jpg

mv hollywood2_mean.binaryproto $DATABASE_FOLDER/$TRAIN_DATABASE
mv hollywood2_mean.jpg $DATABASE_FOLDER/$TRAIN_DATABASE

rm $IN_FOLDER_LINK
rm $SHUFFLED_TRAIN_FILE
rm $SHUFFLED_TEST_FILE

echo "Done."

# measuring time
end=$(date +%s)
let deltatime=end-start
let hours=deltatime/3600
let minutes=(deltatime/60)%60
let seconds=deltatime%60
printf "Time spent: %d:%02d:%02d\n" $hours $minutes $seconds
echo "Experiments finished at $(date)"

exit