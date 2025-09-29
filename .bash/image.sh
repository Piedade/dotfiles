#!/bin/bash

# Image resizing script using ImageMagick
resize(){
    if [ -z "$1" ]; then
        echo -e "${RED}No resize value defined!$RESET"
    else
        # Define the file pattern to include both JPG and PNG files
        FILES_TO_RESIZE=(*.jpg *.png)
        RESIZE=$1
        ORIGINAL_FOLDER="_original"

        echo -e "${GREEN}A redimensionar as imagens...$RESET"

        # Create the original directory if it doesn't exist
        mkdir -p $ORIGINAL_FOLDER

        # Loop through each file matching the pattern
        for image in "${FILES_TO_RESIZE[@]}"; do
            if [[ -f "$image" ]]; then
                # Copy the original image to the backup folder
                mv "$image" "$ORIGINAL_FOLDER/"

                # Extract the base name of the image (without directory path)
                basename=$(basename -- "$image")
                filename="${basename%%.*}"

                if [ -z "$2" ]; then
                    extension="${basename##*.}"
                    echo $image
                else
                    extension=$2
                    echo "$image => $extension"
                fi

                # Resize the image and save it with the same base name but with a .jpg extension

                # https://stackoverflow.com/questions/11221336/imagemagick-scale-and-image-quality
                # Using -sharpen 0x1.2 with -resize x% with -quality 95 produces good results for me.
                # -density 400 better quality?
                # -quality 80 -adaptive-resize is better for larger photos.
                # If you need to blur the output, use -interpolative-resize instead of -adaptive-resize

                # convert "$ORIGINAL_FOLDER/$image" -sharpen 0x1.2 -resize $RESIZE -quality 95 "${base_name%.*}.jpg"

                convert "$ORIGINAL_FOLDER/$image" -interlace plane -adaptive-resize $RESIZE "$filename.$extension"

                # https://www.smashingmagazine.com/2015/06/efficient-image-resizing-with-imagemagick
                # mogrify -format png -path ./ -filter Triangle -define filter:support=2 -thumbnail $RESIZE -unsharp 0.25x0.08+8.3+0.045 -dither None -posterize 136 -quality 82 -define jpeg:fancy-upsampling=off -define png:compression-filter=5 -define png:compression-level=9 -define png:compression-strategy=1 -define png:exclude-chunk=all -interlace none -colorspace sRGB $ORIGINAL_FOLDER/$image
            fi
        done
    fi
}

create_favicon(){
    local image_file="${1}"
    local iconName="${2:-favicon}"
    if [ -z "$1" ]; then
        echo_error "No image detected!"
    else
        # Check if image exists
        if [[ ! -f "$image_file" ]]; then
            echo_error "❌ $image_file not found."
            return 1
        fi

        convert $image_file -background transparent -trim -gravity center -extent 1:1# -define icon:auto-resize="256,128,64,48,32,24,16" $iconName.ico

        if [ $? -eq 0 ]; then # Check if the last command was successful
            echo_success "Favicon $iconName.ico created!"
        else
            echo_error "❌ Failed to create $iconName.ico."
            return 1
        fi
    fi
}
