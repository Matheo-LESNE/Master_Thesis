###################################################################
# Description: call loops from contact matrix
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
  This script process contact map to detect loops.\n
\n
Options:\n
  -h, --help                      Display this help and exit\n
  -i, --input_file <input_file>   Specify the contact map containing the resolutions\n
  -o, --output_folder <folder>    Specify the output folder\n
  -r, --resolutions <string>      String representing all the resolutions to process (ex: 5000,10000,25000)\n
  -c, --chrom_sizes <file>        Path to the file containing chromosome sizes\n
  -p, --protein_file <file>       Path to the file containing the ChIP-seq used for optimisation\n
\n
example: \n
  bash ./loop_callers.sh -i <PATH/TO/CONTACT_MAP> -o <PATH/TO/OUTPUT> -r <RESOLUTIONS> -p <PATH/TO/CHIP-SEQ> -c <PATH/TO/CHROM-SIZES>\n
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
	-i|--input)
	input_file="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-o|--output)
	output_folder="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-r|--resolutions)
	resolutions="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-c|--chrom_sizes)
	chrom_sizes="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-p|--protein_file)
	protein_file="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
esac
done

### ====================
##    CHECK ARGUMENTS
# ======================

if [ ! -e "$input_file" ]; then
	echo "Warning: Input file doesn't exist"
	exit 1
fi

if [ ! -e "$protein_file" ]; then
	echo "Warning: protein file doesn't exist"
	exit 1
fi

if [ ! -e "$chrom_sizes" ]; then
	echo "Warning: chrom sizes file doesn't exist"
	exit 1
fi

if [[ ! $input_file =~ \.(cool|hic)$ ]]; then
    echo "Error: Input file must be in format .hic or .cool"
	exit 1
fi

if [[ ! -n $resolutions ]] && [[ ! $resolutions =~ ^([0-9]+,)*[0-9]+$ ]]; then
	echo "Error: The resolutions variable is either empty or does not match the specified format."
	exit 1
fi

### ====================
##    MAIN
# ======================

mkdir $output_folder
input_file=$(realpath $input_file)
chrom_sizes=$(realpath $chrom_sizes)
protein_file=$(realpath $protein_file)
output_folder=$(realpath $output_folder)

run_hiccups() {
	if [[ ! $input_file == *.hic ]]; then
		return
	fi

	hiccups_folder=${output_folder}/hiccups/
	logfile=${hiccups_folder}hiccups_log.txt
	mkdir $hiccups_folder
	echo "Starting hiccups ($logfile) ..."
	
	# extracting parameters from optimiser 

	IFS=',' read -ra nums <<< "$resolutions"
	for res in "${nums[@]}"; do
		config_file=$output_folder/hyperopt_result_${res}_hic.txt
		echo $config_file
		if [ ! -e "$config_file" ]; then 
			continue
		fi
		parameters=$(cat $config_file | grep -v '^#' | sed "s/'//g" | cut -d' ' -f2-)

		fdr=$fdr,$(echo "$parameters" | grep -oP "(?<=f: ).*?(?=,)")
		peakWidth=$peakWidth,$(echo "$parameters" | grep -oP "(?<=p: ).*?(?=,)")
		window=$window,$(echo "$parameters" | grep -oP "(?<=i: ).*?(?=,)")

	done

	fdr="-f ${fdr#,}"
	peakWidth=" -p ${peakWidth#,}"
	window=" -i ${window#,}"
	parameters=$fdr$peakWidth$window

	echo $parameters

	# running hiccups

	$JUICER_TOOLS hiccups -r $resolutions $parameters $input_file $hiccups_folder --ignore-sparsity > $logfile
}

run_hicdetectloop_res() {

	res=$1
	logfile=${hicDetectLoops_folder}/hicDetectLoops_log_${res}_cool.txt

	# extracting parameters from optimiser 

	config_file=$output_folder/hyperopt_result_${res}_cool.txt

	if [ -e "$config_file" ]; then 
		echo $config_file

		peakWidth=$(grep -oP "'peakWidth': \K[^,}]*" "$config_file")
		windowSize=$(grep -oP "'windowSize': \K[^,}]*" "$config_file")
		pValuePreselection=$(grep -oP "'pp': \K[^,}]*" "$config_file")
		peakInteractionsThreshold=$(grep -oP "'pit': \K[^,}]*" "$config_file")
		obsExpThreshold=$(grep -oP "'oet': \K[^,}]*" "$config_file")
		pValue=$(grep -oP "'p': \K[^,}]*" "$config_file")
		maxLoopDistance=$(grep -oP "'maxLoopDistance': \K[^,}]*" "$config_file")

		parameters="-pw $peakWidth -w $windowSize -pp $pValuePreselection -pit $peakInteractionsThreshold -oet $obsExpThreshold -p $pValue --maxLoopDistance $maxLoopDistance"
	fi

	# if cool file for resolution doesn't exist yet, creating it

	if [ ! -e "${input_file%.*}_$res.cool" ]; then
		echo "Creating .cool file for resolution $res ..."
		hicConvertFormat -m $input_file -o ${input_file%.*}_$res.cool --inputFormat cool --outputFormat cool -r $res
	fi

	echo "Detecting loops for resolution $res (parameters: $parameters) ..."

	# running hicdetectloops

	hicDetectLoops -m $input_file -o $hicDetectLoops_folder/hicDetectLoops_result_${res}_cool.bedgraph $parameters > $logfile

}

run_hicdetectloop() {
	if [[ ! $input_file =~ \.(cool)$ ]]; then
		return
	fi

	hicDetectLoops_folder=${output_folder}/hicDetectLoops
	mkdir $hicDetectLoops_folder
	
	cd $HICEXPLORER
	source activate

	# processing all resolutions

	max_res=-9999999
	files=""
	IFS=',' read -ra nums <<< "$resolutions"
	for res in "${nums[@]}"; do
		run_hicdetectloop_res $res &
		if [[ $res -gt $max_res ]]; then
			max_res=$res
		fi
		files="$hicDetectLoops_folder/hicDetectLoops_result_${res}_cool.bedgraph ${files}"
	done

	wait

	# merging loop results

	echo "Merging loops for resolutions $resolutions ..."
	echo "hicMergeLoops -i $files-o $hicDetectLoops_folder/merged_loops.bedgraph -r $max_res > $hicDetectLoops_folder/merged_loops_log.txt"
	hicMergeLoops -i $files-o $hicDetectLoops_folder/merged_loops.bedgraph -r $max_res > $hicDetectLoops_folder/merged_loops_log.txt
	
	deactivate
}

run_optimiser_res() {
	res=$1
	logfile=$output_folder/hyperopt_$res$ext.log
	resultfile=$output_folder/hyperopt_result_$res$ext.txt
	file_to_process=$input_file

	# creating a cool file for the specific resolution if it doesn't exist (ONLY for .cool files)

	if [[ $input_file == *.cool ]]; then
		if [ ! -e "${input_file%.*}_$res.cool" ]; then
			echo "Creating .cool file for resolution $res ..."
			hicConvertFormat -m $input_file -o ${input_file%.*}_$res.cool --inputFormat cool --outputFormat cool -r $res
			
		fi
		file_to_process=${input_file%.*}_$res.cool
	fi

	# runnin optimiser

	echo "Starting Hyperopt for resolution $res ($logfile) ..."
	$tool $res -m $file_to_process -p $protein_file -ml 1000 -o $resultfile > $logfile
}

run_optimiser() {
	

	if [[ $input_file == *.hic ]]; then
		tool="hicHyperoptDetectLoopsHiCCUPS -j $JUICER_TOOL_PATH -k KR -r"
		ext="_hic"
	else
		tool="hicHyperoptDetectLoops -re"
		ext="_cool"
	fi
	
	cd $HICEXPLORER
	source activate

	# processing all resolutions

	IFS=',' read -ra nums <<< "$resolutions"
	for res in "${nums[@]}"; do
		run_optimiser_res $res &
	done

	wait
	
	deactivate
}

# MAIN

run_optimiser

run_hiccups &
run_hicdetectloop &

wait

echo Done !