###################################################################
# Description: Variables to use for the hic contact map pipeline
# Date: 2023/02
# Author: Matheo LESNE
###################################################################


# topHat value
export NB_PROC_EXE=8


# Cleaning
today="230220"


# params
export phred=33
export adapter="?"
export default_resolutions="1000,5000,10000,25000,50000,100000,250000,500000,1000000,2500000"
# The resolutions here do not define the resolutions of the contact map for juicer and distiller, it is only used for the format converter.
# To change the resolutions of the contact map follow these instructions
# - DISTILLER: change the distiller template at line 132
# - JUICER: change the juicer file at line 737 and 739, the variable "resstr"
export juicer_Enzyme=HindIII
# List of available patterns : 
#    'HindIII'     : 'AAGCTT'
#    'DpnII'       : 'GATC'
#    'MboI'        : 'GATC'
#    'Sau3AI'      : 'GATC'
#    'Arima'       : [ 'GATC', 'GANTC' ]


# flags for pre-processing
export FLAG_QUALITY=0
export FLAG_TRIMMOMATIC=0
export FLAG_AFTERQC=0


# flags for processing
export FLAG_DISTILLER=0
export FLAG_JUICER=1
