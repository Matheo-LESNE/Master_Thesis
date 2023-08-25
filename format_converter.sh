###################################################################
# Description: hic to cool / cool to hic format converter
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
Usage: converter.sh [OPTIONS]\n
\n
Description:\n
  This script converts Hi-C data between .cool and .hic formats.\n
\n
Options:\n
  -h, --help                 Display this help and exit\n
  -i, --input <input_file>   Specify the input file\n
  -o, --output <output_file> Specify the output file\n
  -c, --chr-sizes <sizes>    Specify the chromosome sizes file\n
  -r, --resolutions <values> Specify the resolutions for format conversion, default resolutions are used if not specified\n
\n
example:\n
  bash ./format_converter.sh -i <PATH/TO/CONTACT_MAP> -o <PATH/TO/CONTACT_MAP_CONVERTED> -r <RESOLUTIONS> -c <PATH/TO/CHROM-SIZES>\n
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
	output_file="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-c|--chr-sizes)
	chr_sizes="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-r|--resolutions)
	resolutions="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
esac
done

### ====================
##    CHECK ARGUMENTS
# ======================

if [ ! -e "$input_file" ]; then
	echo "Error: Input file doesn't exist"
	exit 1
fi

if [ ! -d "$(dirname "$output_file")" ]; then
	echo "Error: The path of the output file doesn't exist"
	exit 1
fi

if [[ "$input_file" == *.cool ]]; then
    echo "conversion detected: cool to hic"
    cool_file=$input_file
    hic_file=$output_file
    conversion="cool_to_hic"
    
    if [ ! -e "$chr_sizes" ]; then
        echo "Error: Chromosome sizes file doesn't exist"
        exit 1
    fi

    if [[ -n $resolutions ]] && [[ $resolutions =~ ^([0-9]+,)*[0-9]+$ ]]; then
        echo "Resolutions selected for format conversion: $resolutions"
    else
        if [[ -z "$resolutions" ]]; then
            resolutions=$default_resolutions
            echo "Resolutions selected for format conversion: $resolutions"
        else
            echo "Error: The resolutions variable is either empty or does not match the specified format."
            exit 1
        fi
    fi

elif [[ "$input_file" == *.hic ]]; then
    echo "conversion detected: hic to cool"
    cool_file=$output_file
    hic_file=$input_file
    conversion="hic_to_cool"

else
	echo "Error: Input file must be .cool or .hic"
	exit 1
fi

### =========
##    MAIN
# ===========

if [[ $conversion == "cool_to_hic" ]]; then

    final_name=${hic_file}
    hic_file=${hic_file}.ginteractions

    cd $HICEXPLORER
    source activate
    echo "Converting to .ginteractions ..."
    python $HICEXPLORER/hicConvertFormat -m ${cool_file} -o ${hic_file} --inputFormat cool --outputFormat ginteractions
    deactivate

    hic_file=${hic_file}.tsv

    echo "Selecting useful components from .ginteractions ..."
    awk -F "\t" '{print 0, $1, $2, 0, 0, $4, $5, 1, $7}' ${hic_file} > ${hic_file}.short

    hic_file=${hic_file}.short

    echo "Sorting data ..."
    sort -k2,2d -k6,6d ${hic_file} > ${hic_file}.sorted

    hic_file=${hic_file}.sorted

    echo "Converting to .hic ..."
    $JUICER_TOOLS pre -r ${resolutions} ${hic_file} ${final_name} ${chr_sizes}

else

    cd $HICEXPLORER
    source activate
    echo "Converting to .cool ..."
    python $HICEXPLORER/hicConvertFormat -m ${hic_file} -o ${cool_file} --inputFormat hic --outputFormat cool
    deactivate

fi

echo "Done !"