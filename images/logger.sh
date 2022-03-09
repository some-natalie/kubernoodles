#!/bin/sh
# Logger from this post http://www.cubicrace.com/2016/03/log-tracing-mechnism-for-shell-scripts.html

INFO(){
    _info_function_name="${FUNCNAME[1]}"
    _info_msg="$1"
    timeAndDate=$(date)
    echo "[$timeAndDate] [INFO] [${0}] $_info_msg"
}


DEBUG(){
    _debug_function_name="${FUNCNAME[1]}"
    _debug_msg="$1"
    timeAndDate=$(date)
    echo "[$timeAndDate] [DEBUG] [${0}] $_debug_msg"
}

ERROR(){
    _error_function_name="${FUNCNAME[1]}"
    _error_msg="$1"
    timeAndDate=$(date)
    echo "[$timeAndDate] [ERROR]  $_error_msg"
}
