# sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
# sudo chmod a+rx /usr/local/bin/yt-dlp
# sudo apt install ffmpeg
get_youtube() {
    if [ -z "$1" ]; then
        echo_error "No YouTube URL provided!"
        return 1
    else
        URL="$1"
        echo_info "Downloading YouTube video from ${URL}"
        echo
    fi

    yt-dlp -f bestvideo+bestaudio --merge-output-format mp4 "$URL"
}
