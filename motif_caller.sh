###################################################################
# Description: call motifs from loop lists
# Date: 2023/06
# Author: Matheo LESNE
###################################################################

SCRIPT_DIRECTORY=$(realpath $( dirname -- "$0"; ))

# load dependencies file
echo ${SCRIPT_DIRECTORY}"/dependencies.sh"
. ${SCRIPT_DIRECTORY}"/dependencies.sh"

# load config file
echo ${SCRIPT_DIRECTORY}"/config.sh"
. ${SCRIPT_DIRECTORY}"/config.sh"

### ================
##    ARGUMENTS
# ==================

HELP="
Usage: ./script.sh [OPTIONS]\n
\n
Description:\n
  This script process loop files to detect CTCF motifs from a ChIP-seq file.\n
\n
Options:\n
  -h, --help                      Display this help and exit\n
  -l, --loops_path <input_file>   Specify the loops, can be a folder or a path to multiple files\n
  -o, --output_folder <folder>    Specify the output folder\n
  -g, --genome_name <string>      Genome name (ex: hg19)\n
  -c, --chip_seq <file>           Path to the file containing the ChIP-seq\n
\n
example: \n
  bash ./motif_caller.sh -l <PATH/TO/LOOPS> -o <PATH/TO/OUTPUT> -g <GENOME_NAME> -c <PATH/TO/CHIP-SEQ>\n
"

index=0

for i in "$@"
do
index=$((index + 1))
case $i in
	-h*|--help*)
	echo -e ${HELP};
	exit 0
	;;
	-o|--output_folder)
	output_folder="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-l|--loops_path)
	loops_path="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-c|--chip_seq)
	chip_seq="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-g|--genome_name)
	genome_name="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
esac
done

### ====================
##    CHECK ARGUMENTS
# ======================

if [ -z ${loops_path+x} ]
then
	echo "Error: mandatory argument -i is not provided"
	check=0
else
	LoopFiles=$loops_path*
	LoopDir=$(dirname "$LoopFiles")
	if ! compgen -G "${loops_path}*" > /dev/null
	then
		echo "Error: the provided input folder file do not exist. Please verify"
		echo "You provided "${loops_path}
		check=0
	fi
fi


if [ -z ${chip_seq+x} ]
then
	echo "Error: mandatory argument -c is not provided"
	check=0
else
	if [ ! -f ${chip_seq} ]
	then
		echo "Error: the provided ChIP_seq file do not exist. Please verify"
		echo "You provided "${chip_seq}
		check=0
	fi
fi


if [ ! -z ${genome_name+x} ]
then
	echo "Error: mandatory argument -g is not provided"
	check=0
fi

## FINAL CHECK

if [[ ${check} == 0 ]]
then
	exit 1
fi

### ====================
##    MAIN
# ======================

run_motiffinder() {
	last_extension=$(basename "$1" | rev | cut -d '.' -f 1 | rev)
	basename=${1%.$last_extension}

	# Running motif finder

    echo "$MOTIF_FINDER $genome_name $bed_folder $1"
	$MOTIF_FINDER $genome_name $bed_folder $1

	basename=${basename}_with_motifs
	motifs_output=${basename}.bedpe

	# Applying soft filter

	soft_filter=${basename}.soft_filter.bedpe
	soft_filter_start_tmp=${basename}.soft_filter_start_tmp.bedpe
	soft_filter_start=${basename}.soft_filter_start.bedpe
	soft_filter_end_tmp=${basename}.soft_filter_end_tmp.bedpe
	soft_filter_end=${basename}.soft_filter_end.bedpe
	soft_filter_all=${basename}.soft_filter_all.bedpe

	while IFS= read -r line; do
		count=$(echo "$line" | tr '[:upper:]' '[:lower:]' | awk -F'na' '{print NF-1}')
		if [ "$count" -lt 8 ]; then
			echo "$line" >> "$soft_filter"
		fi
	done < "$motifs_output"

	awk -F'\t' 'BEGIN {OFS=FS} NR==1 {print "chr", "motif_start", "motif_end"; next } NR>1 {print $1, $(NF-9), $(NF-8)}' $soft_filter > $soft_filter_start_tmp
	awk -F'\t' 'BEGIN {OFS=FS} NR==1 {print "chr", "motif_start", "motif_end"; next } NR>1 {print $4, $(NF-4), $(NF-3)}' $soft_filter > $soft_filter_end_tmp
	awk -F'\t' 'NR==1 { print } NR>1 && !/na|NA/ { print }' $soft_filter_start_tmp > $soft_filter_start
	awk -F'\t' 'NR==1 { print } NR>1 && !/na|NA/ { print }' $soft_filter_end_tmp > $soft_filter_end
	cat $soft_filter_start >> $soft_filter_all
	tail -n +2 $soft_filter_end | cat >> $soft_filter_all
	rm $soft_filter_start_tmp
	rm $soft_filter_end_tmp

	# Applying strict filter
	
	strict_filter=${basename}.strict_filter.bedpe
	strict_filter_start=${basename}.strict_filter_start.bedpe
	strict_filter_end=${basename}.strict_filter_end.bedpe
	strict_filter_all=${basename}.strict_filter_all.bedpe

	awk -F'\t' 'NR==1 { print } NR>1 && !/na|NA/ { print }' $motifs_output > $strict_filter
	awk -F'\t' 'BEGIN {OFS=FS} NR==1 {print "chr", "motif_start", "motif_end"; next } NR>1 {print $1, $(NF-9), $(NF-8)}' $strict_filter > $strict_filter_start
	awk -F'\t' 'BEGIN {OFS=FS} NR==1 {print "chr", "motif_start", "motif_end"; next } NR>1 {print $4, $(NF-4), $(NF-3)}' $strict_filter > $strict_filter_end
	cat $strict_filter_start >> $strict_filter_all
	tail -n +2 $strict_filter_end | cat >> $strict_filter_all
	#rm ${basename}_start_motifs.bedpe
	#rm ${basename}_end_motifs.bedpe
}

# setting up the ChIP-seq folder

bed_folder=${output_folder}/bed_folder/
mkdir ${bed_folder}
mkdir ${bed_folder}unique
mkdir ${bed_folder}inferred

ChipName=$(basename "$chip_seq" | cut -d. -f1)

ln -s $chip_seq ${bed_folder}unique/CTCF.bed
ln -s $chip_seq ${bed_folder}inferred/CTCF.bed

for LoopFile in $LoopFiles
do
    run_motiffinder $LoopFile
done

echo Done !