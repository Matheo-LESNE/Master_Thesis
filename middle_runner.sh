#!/bin/bash

# Script to generate a file presenting the middle of the loops detected, the extend value can be selected as well as specific files to process

# Specify the folders to process, add or remove additional folder command lines at the end of the script
folder1="/home/math/previous_result_safe/JUICER/loops_results/hiccups_kr_norm"
folder2="/NANO/Data/Matheo/Juicer_pipeline/MCF7/Loops_10kb"
file_pattern="postprocessed_pixels_500*"
extend="5000"

# Function to process a single file and create the formatted output
process_file() {
    input_file=$1
    output_file="${input_file%.*}_loop_middle.bedpe"

    echo "Processing file: $input_file"

    # Create the formatted file
    while IFS=$'\t' read -r chr1 x1 x2 chr2 y1 y2 rest; do
        # Calculate the middle points using bc
        x_mid=$(echo "scale=2; ($x1 + $x2) / 2" | bc)
        y_mid=$(echo "scale=2; ($y1 + $y2) / 2" | bc)
        z_mid=$(echo "scale=2; ($x_mid + $y_mid) / 2" | bc)

        # Calculate the new start and end positions
        start_pos=$(echo "$z_mid - $extend" | bc | awk '{printf "%.0f", $1}')
        end_pos=$(echo "$z_mid + $extend" | bc | awk '{printf "%.0f", $1}')

        # Output the new line
        echo -e "$chr1\t$start_pos\t$end_pos\t$rest"
    done < "$input_file" > "$output_file"

    echo "Formatted file created: $output_file"
}

# Function to process files in a folder
process_folder() {
  local folder_path="$1"

  # Use find with -name to process files ending with cool.bedpe or hic.bedpe
  find "$folder_path" -maxdepth 1 -type f \( -name "$file_pattern" \) -print0 | while IFS= read -r -d '' input_file; do
    process_file "$input_file"
  done
}

# Main script

# Process files in the first folder
process_folder "$folder1"

# Process files in the second folder
#process_folder "$folder2"
