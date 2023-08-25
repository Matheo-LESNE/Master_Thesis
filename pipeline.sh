###################################################################
# Description: Fastq to hic contact map pipeline
# Date: 2023/02
# Author: Matheo LESNE
###################################################################

### ======================
##    Default parameters
# ========================

SCRIPT_DIRECTORY=$(realpath $( dirname -- "$0"; ))
DISTILLER_TEMPLATE=${SCRIPT_DIRECTORY}"/DISTILLER_TEMPLATE.yml"

# load dependencies file
echo ${SCRIPT_DIRECTORY}"/dependencies.sh"
. ${SCRIPT_DIRECTORY}"/dependencies.sh"

# load config file
echo ${SCRIPT_DIRECTORY}"/config.sh"
. ${SCRIPT_DIRECTORY}"/config.sh"

### ==============
##    Functions
# ================

run_cmd() {
		echo $1
		$1
}

clean_output() {
		echo $1
		echo "+-+-+-+-"
		echo ""
}

setup_runfile() {
		echo "echo ${2}" >> ${1}
		echo ${2} >> ${1}
}

qc_it() {
        if [[ ${FLAG_QUALITY} == 1 ]]
        then	
			run_cmd "${FASTQC} $1 -t ${NB_PROC_EXE} -o $2"
        fi
}


### ================
##    ARGUMENTS
# ==================

HELP="
Usage: ./script.sh [OPTIONS]\n
\n
Description:\n
  This script process fastq files to extract hic contact map.\n
\n
Options:\n
  -h, --help                 Display this help and exit\n
  -i, --input <input_file>   Specify the input file\n
  -o, --output <output_file> Specify the output file\n
  -g, --genome-ref <file>    Path to the genome reference file\n
  -c, --chr-sizes <sizes>    Path to the file containing chromosome sizes\n
  -bw, --bwa-index <path>    Path to the BWA index wildcard\n
\n
example: \n
  bash ./pipeline.sh -i <PATH/TO/FASTQ> -o <PATH/TO/OUTPUT> -g <PATH/TO/GENOME> -c <PATH/TO/CHROM_SIZE>\n
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
	pathFASTQ="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-o|--output)
	pathOut="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-g|--genome-ref)
	genome_ref="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-c|--chr-sizes)
	ChrSizes="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
	-bw|--bwa-index)
	BwaIndex="${@:$index+1:1}"
    echo "The value of $i is: ${@:$index+1:1}"
	;;
esac
done


### ====================
##    CHECK ARGUMENTS
# ======================

echo "Start checking arguments..."
check=1

## MANDATORY ARGUMENTS
##-i|--input

if [ -z ${pathFASTQ+x} ]
then
	echo "Error: mandatory argument -i is not provided"
	check=0
else
	FastqFiles=$pathFASTQ*
	FastqDir=$(dirname "$FastqFiles")
	if ! compgen -G "${pathFASTQ}*" > /dev/null
	then
		echo "Error: the provided input folder file do not exist. Please verify"
		echo "You provided "${pathFASTQ}
		check=0
	fi
fi


#-o|--output
if [ -z ${pathOut+x} ]
then
	echo "Error: mandatory argument -o is not provided"
	check=0
else
	if [ ! -d ${pathOut} ]
	then
		echo "Error: the provided output folder file do not exist. Please verify"
		echo "You provided "${pathOut}
		check=0
	fi
fi


#-c|--chr-sizes
if [ -z ${ChrSizes+x} ]
then
	echo "Error: mandatory argument -c is not provided"
	check=0
else
	if [ ! -f ${ChrSizes} ]
	then
		echo "Error: the provided chromosomes sizes file do not exist. Please verify"
		echo "You provided "${ChrSizes}
		check=0
	fi
fi


#-g|--genome-ref)
if [ -z ${genome_ref+x} ]
then
	echo "Error: mandatory argument -g is not provided"
	check=0
else
	if [ ! -f ${genome_ref} ]
	then
		echo "Error: the provided genome reference file do not exist. Please verify"
		echo "You provided "${genome_ref}
		check=0
	fi
fi


## OPTIONAL ARGUMENTS

if [ ! -z ${BwaIndex+x} ]
then
	if ! compgen -G "${BwaIndex}" > /dev/null
	then
		echo "Error: the provided bwa index wildcard path do not exist. Please verify."
		echo "You provided "${BwaIndex}
		check=0
	fi
fi


## FINAL CHECK

if [[ ${check} == 0 ]]
then
	exit 1
fi


clean_output "All arguments passed the checking."


### ============================
##    GENERATE OUTPUT FOLDERS
# ==============================

run_cmd "mkdir ${pathOut}CONTACT_MAPS/"

if test -v contact_maps; then
	contact_maps=$contact_maps*
	for contact_map in $contact_maps
	do
		run_cmd "ln -s $contact_map ${pathOut}CONTACT_MAPS/$(basename $contact_map)"
	done
fi


create_folders() {
	echo "Generating output folders:"

	run_cmd "mkdir ${1}"

	if [[ ${FLAG_QUALITY} == 1 ]]
	then
		run_cmd "mkdir ${1}FASTQC/"
		run_cmd "mkdir ${1}FASTQC/PRE/"
		run_cmd "mkdir ${1}FASTQC/POST/"
	fi

	if [[ ${FLAG_TRIMMOMATIC} == 1 ]]
	then
		run_cmd "mkdir ${1}TRIMMOMATIC/"
	fi

	if [[ ${FLAG_AFTERQC} == 1 ]]
	then
		run_cmd "mkdir ${1}AFTERQC/"
		run_cmd "mkdir ${1}AFTERQC/BAD/"
		run_cmd "mkdir ${1}AFTERQC/GOOD/"
	fi

	if [[ ${FLAG_DISTILLER} == 1 ]]
	then
		run_cmd "mkdir ${1}DISTILLER/"
	fi

	if [[ ${FLAG_JUICER} == 1 ]]
	then
		run_cmd "mkdir ${1}JUICER/"
	fi

	clean_output "done."
}

### =========
##    MAIN
# ===========

pathOut=$(realpath $pathOut)"/"
genome_ref=$(realpath $genome_ref)
ChrSizes=$(realpath $ChrSizes)


distiller() {

	echo "RUNNING DISTILLER ..."

	session_name="${PairedName}distiller"
	log_file="${PairedFolder}DISTILLER/screenlog.txt"
	run_file=distiller.sh

	cd ${PairedFolder}DISTILLER/
	echo '#!/bin/bash' > $run_file
	chmod +x $run_file

	# generate bwa indew if not provided

	if [ -z "${BwaIndex+x}" ]
	then

		genome_name=$(basename "$genome_ref" | cut -d. -f1)
		genome_dir=$(dirname "$genome_ref")

		already_indexed=true

		for ext in .amb .ann .bwt .pac .sa
		do
			index_file="${genome_dir}/*${ext}"
			if [ ! -f $index_file ]
			then
				echo "$index_file doesn't exist, need to index the reference"
				already_indexed=false
				break
			fi
		done

		if ! $already_indexed
		then
			setup_runfile $run_file "${BWA} index -a bwtsw ${genome_ref} ${genome_name}"
		fi

		BwaIndex=${genome_ref}".*"
	else
		genome_name=$(basename "$BwaIndex" | cut -d. -f1)
	fi

	# clone and modify template file of distiller for launch

	template=${PairedFolder}"DISTILLER/"${PairedName}"_DISTILLER.yml"
	setup_runfile $run_file "cp ${DISTILLER_TEMPLATE} ${template}"

	setup_runfile $run_file "sed -i s+FASTQ_1+$(realpath $FQ1)+ ${template}"
	setup_runfile $run_file "sed -i s+FASTQ_2+$(realpath $FQ2)+ ${template}"
	setup_runfile $run_file "sed -i s+BWA_INDEX+$(readlink -f "$BwaIndex")+ ${template}"
	setup_runfile $run_file "sed -i s+CHROM_SIZES+$(realpath $ChrSizes)+ ${template}"
	setup_runfile $run_file "sed -i s+REF_NAME+${genome_name}+ ${template}"

	setup_runfile $run_file "chmod 777 ${template}"
	setup_runfile $run_file "cd ${PairedFolder}DISTILLER/"
	setup_runfile $run_file "${DISTILLER} -params-file ${template}"
	setup_runfile $run_file "echo DISTILLER IS DONE"

	# starting distiller in a new screen

	screen  -d -m -L -Logfile $log_file -S $session_name bash $run_file

	session_id=$(screen -ls | awk -v name="$session_name" '$0 ~ name {split($1, a, "."); print a[1]}' | sort -n | tail -1)

	echo "CHECK DISTILLER'S PROGRESS USING 'screen -r ${session_id}.${session_name}'"
	echo "OR CHECK DISTILLER'S LOG FILE AT '${log_file}'"

	# waiting for the screen to disapear

	while true; do
		if grep -q "DISTILLER IS DONE" "$log_file"; then
			clean_output "DISTILLER IS DONE"
			break
		elif ! screen -list | grep -q "${session_id}.${session_name}"; then
			clean_output "Warning: Screen session ${session_id}.${session_name} is not active and DISTILLER was ended abruptly"
			break
		else
			sleep 1
		fi
	done

	contactmap=${PairedFolder}DISTILLER/results/*.mcool
	run_cmd "ln -s $contactmap ${1}CONTACT_MAPS/$(basename $contactmap)"
}


juicer() {

	echo "RUNNING JUICER ..."
	echo ${FQ1} ${FQ2}

	session_name="${PairedName}juicer"
	log_file="${PairedFolder}JUICER/screenlog.txt"
	run_file=run_juicer.sh

	cd ${PairedFolder}JUICER/
	echo '#!/bin/bash' > $run_file
	chmod +x $run_file

	# setting up the folder required by juicer to start

	setup_runfile $run_file "cd ${PairedFolder}JUICER"
	setup_runfile $run_file "ln -s ${JUICER} scripts"

	setup_runfile $run_file "mkdir ${PairedFolder}JUICER/fastq"
	setup_runfile $run_file "cd ${PairedFolder}JUICER/fastq"
	setup_runfile $run_file "ln -s ${FQ1} FASTQ_R1.fastq"
	setup_runfile $run_file "ln -s ${FQ2} FASTQ_R2.fastq"

	setup_runfile $run_file "mkdir ${PairedFolder}JUICER/references"
	setup_runfile $run_file "cd ${PairedFolder}JUICER/references"
	setup_runfile $run_file "ln -s $genome_ref"

	# generate bwa indew if not provided
	
	if [ -z "${BwaIndex+x}" ]
	then
		genome_name=$(basename "$genome_ref" | cut -d. -f1)
		genome_dir=$(dirname "$genome_ref")

		already_indexed=true

		for ext in .amb .ann .bwt .pac .sa
		do
			index_file="${genome_dir}/*${ext}"
			if [ ! -f $index_file ]
			then
				echo "$index_file doesn't exist, need to index the reference"
				already_indexed=false
				break
			fi
		done

		if ! $already_indexed
		then
			setup_runfile $run_file "${BWA} index -a bwtsw ${genome_ref} ${genome_name}"
		fi

		BwaIndex=${genome_ref}".*"
	else
		genome_name=$(basename "$BwaIndex" | cut -d. -f1)
	fi

	bwa_dir=$(dirname "$BwaIndex")
	for ext in .amb .ann .bwt .pac .sa
	do
		index_file="${bwa_dir}/*${ext}"
		setup_runfile $run_file "ln -s $index_file"
	done

	# Creating the restriction file if not present already

	setup_runfile $run_file "mkdir ${PairedFolder}JUICER/restriction_sites"
	setup_runfile $run_file "cd ${PairedFolder}JUICER/restriction_sites"
	
	DigestEnzyme=$juicer_Enzyme
	RestrFrag=${genome_dir}/GEN-SIT-POS_${genome_name}
	if [ ! -e "${RestrFrag}_${DigestEnzyme}.txt" ]
	then
		setup_runfile $run_file "${GEN_SITE_POS} ${DigestEnzyme} ${RestrFrag} ${genome_ref}"
	fi
	setup_runfile $run_file "ln -s ${RestrFrag}_${DigestEnzyme}.txt"
	RestrFrag=${RestrFrag}_${DigestEnzyme}.txt

	# Some versions of jucier require to split the fastq files, leaving it if needed

	# setup_runfile $run_file "mkdir ${PairedFolder}JUICER/splits"
	# setup_runfile $run_file "cd ${PairedFolder}JUICER/splits"
	# setup_runfile $run_file "split -a 3 -l 90000000 -d --additional-suffix=_R2.fastq ${FQ2} &"
	# setup_runfile $run_file "split -a 3 -l 90000000 -d --additional-suffix=_R1.fastq ${FQ1} &"

	setup_runfile $run_file "cd ${PairedFolder}JUICER"
	ChrSizes="${PairedFolder}JUICER/${genome_name}.chrom.sizes"
	command="awk 'BEGIN{OFS="
	command=$command'"\t"'
	command=$command'}{print $1, $NF}'
	command=$command"'"
	command=$command" ${RestrFrag} > ${ChrSizes}"
	setup_runfile $run_file "$command"
	#echo 'awk '\''BEGIN{OFS="\t"}{print $1, $NF}'\'' '"${RestrFrag}"' > '"${ChrSizes}" >> $run_file

	# command to start juicer

	setup_runfile $run_file "${JUICER}/juicer.sh -d ${PairedFolder}JUICER -D ${PairedFolder}JUICER -g ${genome_name} -s ${DigestEnzyme} -z ${genome_ref} -y ${RestrFrag} -p ${ChrSizes} -t 8"

	setup_runfile $run_file "echo JUICER IS DONE"
	setup_runfile $run_file "sleep 1"

	# starting juicer in a new screen

	screen -d -m -L -Logfile $log_file -S $session_name bash $run_file

	session_id=$(screen -ls | awk -v name="$session_name" '$0 ~ name {split($1, a, "."); print a[1]}' | sort -n | tail -1)

	echo "CHECK JUICER'S PROGRESS USING 'screen -r ${session_id}.${session_name}'"
	echo "OR CHECK JUICER'S LOG FILE AT '${log_file}'"

	# waiting for the screen to disapear

	while true; do
		if grep -q "JUICER IS DONE" "$log_file"; then
			clean_output "JUICER IS DONE"
			break
		elif ! screen -list | grep -q "${session_id}.${session_name}"; then
			clean_output "Warning: Screen session ${session_id}.${session_name} is not active and JUICER was ended abruptly"
			break
		else
			sleep 1
		fi
	done

	contactmap=${PairedFolder}JUICER/aligned/inter.hic
	run_cmd "ln -s $contactmap ${1}CONTACT_MAPS/$(basename $contactmap)"
}


for FQ1 in $FastqFiles
do
	FileName1=$(basename "$FQ1")
	FileName2=${FileName1%"1"*}"2"${FileName1##*"1"}
	FQ2=${FastqDir}"/"$FileName2
	
	if [[ "$FLAG_DISTILLER" == 0 && "$FLAG_JUICER" == 0 ]]
	then continue
	fi
	if [ ! -f ${FQ2} ]
	then continue
	fi
	if [ ! "${FileName1%"1"*}" == "${FileName2%"2"*}" ]
	then continue
	fi
	
	PairedName=${FileName1%"1"*}
	PairedFolder="${pathOut}${PairedName}/"
	FQ1=$(realpath $FQ1)
	FQ2=$(realpath $FQ2)
	FileName1=$(basename "$FQ1" | cut -d. -f1)
	FileName2=$(basename "$FQ2" | cut -d. -f1)

	clean_output "There is a pair : R1 = $FQ1; R2 = $FQ2"
	create_folders $PairedFolder
	
    if [[ $FQ1 == *.gz ]]; then
        gunzip -c "$FQ1" > "$PairedFolder$(basename "${FQ1%.gz}")"
		FQ1=$PairedFolder$(basename "${FQ1%.gz}")
		unzipped_file1=$FQ1
    fi
	
    if [[ $FQ2 == *.gz ]]; then
        gunzip -c "$FQ2" > "$PairedFolder$(basename "${FQ2%.gz}")"
		FQ2=$PairedFolder$(basename "${FQ2%.gz}")
		unzipped_file2=$FQ2
    fi

	# QC
	
	if [[ ${FLAG_QUALITY} == 1 ]]
	then
		qc_it ${FQ1} ${PairedFolder}"FASTQC/PRE/"
		qc_it ${FQ2} ${PairedFolder}"FASTQC/PRE/"
		clean_output "pre QC done"
	fi

	# TRIMMOMATIC

	if [[ ${FLAG_TRIMMOMATIC} == 1 ]]
	then
		pathTmp=${PairedFolder}"TRIMMOMATIC/"
		tmp1=${pathTmp}${FileName1}"_trim_R1.fq"
		tmp2=${pathTmp}${FileName2}"_trim_R2.fq"

		param="ILLUMINACLIP:"${adapter}":2:30:10 LEADING:20 TRAILING:20 SLIDINGWINDOW:4:20 MINLEN:18"

		phred_param=""
		if [[ ${phred} == 33 ]]
		then
			phred_param=" -phred33"
		elif [[ ${phred} == 64 ]]
		then
			phred_param=" -phred64"
		fi

		run_cmd "${TRIMMOMATIC} PE -threads ${NB_PROC_EXE}${phred_param} ${FQ1} ${FQ2} ${tmp1} ${pathTmp}${FileName1}_unpaired_1.fq ${tmp2} ${pathTmp}${FileName2}_unpaired_2.fq ${param}"
		clean_output "TRIMMOMATIC done"

		FQ1=$tmp1
		FQ2=$tmp2
	fi

	# AFTERQC

	if [[ ${FLAG_AFTERQC} == 1 ]]
	then
		pathTmp=${PairedFolder}"AFTERQC/"

		run_cmd "${AFTERQC} -1 ${FQ1} -2 ${FQ2} -g ${pathTmp}GOOD/ -b ${pathTmp}BAD/"
		clean_output "AFTERQC done"

		#TODO need to check file name
		FQ1=${pathTmp}"GOOD/${FileName1}*1.g*"
		FQ2=${pathTmp}"GOOD/${FileName2}*2.g*"

	fi

	# QC

	if [[ ${FLAG_QUALITY} == 1 ]]
	then
		qc_it ${FQ1} ${PairedFolder}"FASTQC/POST/"
		qc_it ${FQ2} ${PairedFolder}"FASTQC/POST/"
		clean_output "post QC done"
	fi

	if [[ ${FLAG_DISTILLER} == 1 ]]
	then
		distiller &
	fi

	if [[ ${FLAG_JUICER} == 1 ]]
	then
		juicer &
	fi

	wait

	if [ -n "$unzipped_file1" ]; then
		rm $unzipped_file1
	fi
	
	if [ -n "$unzipped_file2" ]; then
		rm $unzipped_file2
	fi

done


echo "pipeline is done !"