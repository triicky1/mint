function undocleanpdfs() {
	local LOGFILE=".cleanpdfs_rename.log"
	if [[ ! -f $LOGFILE ]]; then
		echo "No rename log file found ($LOGFILE). Cannot revert."
		return 1
	fi

	while IFS="|" read -r newname oldname; do
		if [[ -f $newname ]]; then
			echo "Reverting $newname -> $oldname"
			mv "$newname" "$oldname"
		fi
	done < $LOGFILE

	echo "Revert complete."
}
