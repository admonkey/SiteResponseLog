#!/bin/bash
# script in development to check website repsonse statistics

# reporting options
  log_text=true
  log_html=true
  log_mysql=true

  notify_log_text=true
  notify_log_html=true
  notify_log_mysql=true

  notify_email_text=true
  notify_email_html=true

# environment variables
  site="example.com"
  
  # see man curl --writeout for more options
  curl_options=( "http_code" "time_total" "size_download" )
  
  # log length 
  # example: 300 entries = 50 hours @ 1 every 10 minutes
  log_length=300

  mysql_hostname="localhost"
  mysql_username="user"
  mysql_password="C0mpl3xP@55w0rd"
  mysql_database="example"

  email_to="webmaster@example.com"

# exit if curl not installed
if ! $(command -v curl >/dev/null 2>&1); then
  echo "curl required, please install and try again"
  exit 1
fi

# move to working directory
cd $( dirname "${BASH_SOURCE[0]}" )

# overwrite environment variables from a separate file
if [ -f credentials.bash ]; then
  source credentials.bash
fi

# prepare curl option statement
curl_opts=""
for option in ${curl_options[@]}; do
  curl_opts=$curl_opts"%{$option} "
done

# ping server
result_string=$(curl -sL -w "$curl_opts\\n" "$site" -o /dev/null)

# time stamp
text=$(date +"%Y-%m-%d %H:%M:%S")
html="<tr><td>"$text"</td>"

# split result into array
IFS=' ' read -a result_array <<< "${result_string}"

# iterate through array to build a record entry in multiple formats
index=0
cols=""
vals=""
html_table_header="<table border=1><thead><tr><th>timestamp</th>"
for value in "${result_array[@]}"
do
	# sql add comma between values
	  if [[ $index > 0 ]]; then
	    cols="$cols,"
	    vals="$vals,"
	  fi

	# sql column name
	  cols=$cols"${curl_options[$index]}"

	# sql column value
	  # validate decimal number greater than zero
	  if [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]] && [[ $value > 0.000 ]]; then
	    vals=$vals"$value"
	  else
	    vals=$vals"NULL"
	  fi
	
	# plain text
	text="$text"$'\t'"$value"

	# html
	html_table_header="$html_table_header<th>${curl_options[$index]}</th>"
	html="$html<td>$value</td>"

	((index++))
done

# end of row data
html_table_header="$html_table_header</tr></thead><tbody>"
html="$html</tr>"

# prepend log file with last "log_length" entries

  # plain text
  # TODO: validate column match
  log=""
  if $log_text; then
    if [ -f $site.log.txt ]; then
      log=$(head -$log_length $site.log.txt)
    fi
    (echo "$text" && echo "$log") > $site.log.txt
  fi

  # html table
  log=""
  if $log_html; then
    if [ -f $site.log.html ]; then
      # validate matching header
      if [[ $html_table_header == $(head -1 $site.log.html) ]]; then
	# remove header, footer, and pick top "log_length" of records
	log=$(tail -n +2 $site.log.html | head -n -1 | head -$log_length)
      else
	echo "WARNING: operation will overwrite existing html table with new columns"
	rm -i $site.log.html
	if [ -f $site.log.html ]; then
	  exit 0
	fi
      fi
    fi
    (echo $html_table_header && echo $html && echo $log) > $site.log.html
    echo "</tbody></table>" >> $site.log.html
  fi

# insert record into database
# mysql --host=$mysql_hostname --user=$mysql_username --password=$mysql_password --database=$mysql_database << EOF
# $query
# EOF

# notify if server code is not 200 (normal)
# if [[ "${result_array[0]}" != "200" ]]; then
# 	text="$text</tbody></table><br/><a href='"$site"'>View "$site"</a>"
# 	(cat header.txt && echo "$text") |  /usr/sbin/sendmail -t
# fi
