############################################################
# Description: dependencies to use for the hic contact map pipeline
# Date: 2023/02
# Author: Matheo LESNE
###################################################################

export BWA="/opt/bwa/bwa"
export FASTQC="/opt/FastQC/fastqc"
export AFTERQC="/opt/AfterQC/after.py"
export TRIMMOMATIC="java -jar /opt/Trimmomatic-0.39/trimmomatic-0.39.jar"

# There is more configs in /opt/distiller to bind paths for example
export DISTILLER="nextflow /opt/distiller-nf/distiller.nf -with-singularity"
export JUICER="/opt/juicer/CPU"
export JUICER_TOOL_PATH="/opt/juicer/CPU/common/juicer_tools.jar"
export JUICER_TOOLS="java -Xms50000m -Xmx50000m -jar /opt/juicer/CPU/common/juicer_tools.jar"
export MOTIF_FINDER="java -Xms50000m -Xmx50000m -jar /home/math/juicer_tools_1.11.04_jcuda.0.8.jar motifs"
#Important to use a different version of motif finder, others are bugged
export HICEXPLORER="/opt/Venvpython3.9/hiCexplorer/bin"
export GEN_SITE_POS="python /opt/juicer/misc/generate_site_positions.py"