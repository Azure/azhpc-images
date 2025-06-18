#!/bin/bash

# Get the absolute path of the directory containing the script
script_directory=$(dirname "$(realpath "$0")")
parent_directory=$(realpath "$script_directory/..")

# Set execute permission recursively for all files with .sh or .py extension in the directory and subdirectories
find "$script_directory" -type f \( -name "*.sh" -o -name "*.py" -o -name "*.cfg" \) -exec chmod u+rx {} \; -o -name "*.env" -exec chmod u+rwx {} \;

####### Global ENV variables assignments ########
script_file_to_trigger_nhc="run-health-checks.sh" 
health_log_file_name="./health.log" 
fault_code_config_file_path="./config/nhc_fault_dictionary.cfg"
trigger_ghr_log_file="triggerGHRlog.txt"
env_file_path="./config/user.env"
failure_report_file="" 
file_path="" 
script_path="" 
file_mode_custom_rule_path=""
usage_color_code="\e[94m"
object_id=""
impact_category=""
impact_description=""
user_defined_fault_code=""
user_defined_fault_code_value=""
nhc_error=""
script_to_execute=""
getopt_error=""
output=""
user_defined_impact=""
fault_code_in_logfile=""
config_file=""
fault_code_value=""
fault_code=""
#Generic Fault_code
generic_fault_code="NHC2001"
generic_fault_code_value="The reported issue do not fall under any other HPC categories"

#Source ENV file data
source $env_file_path
object_id=$OBJECT_ID
additional_options=$ADDITIONAL_OPTIONS_FOR_NHC

####### Supporting functions ########

#Usage information to run triggerGHR.sh script.
usage() { 
echo -e "${usage_color_code} Usage: $0 can be run by using the option [-s <script_path>] or [-f <file_path>]." 
echo   
echo "Please provide appropriate Options:" 
echo " -f <file_path>     Use -f option to trigger GHR through ImpactRP. Specify the path of health.log file as input"
echo " -c <file_mode_custom_rule_path>     (Optional, with -f or -s) Specify an additional fault code detection rule file for ImpactRP processing" 
echo " -s <script_path>   Use -s option to trigger NHC. Specify the path of azurehpc-health-checks folder as input" 
echo " -r                 Use -r option to trigger the Impact reporting with user defined scenerio"
echo -e "\e[0m" 
exit 1
}

#Parse command-line arguments
while getopts "f:s:c:r" opt; do 
    case $opt in 
	s) 
    script_path=$OPTARG 
	nhc="true"       
	;;
    f) 
    file_path=$OPTARG 
	impact_rp="true"
    ;;
    c)
    file_mode_custom_rule_path="$OPTARG"
    ;;
    r)  
	report_impact="true"
    ;;
    *) 
    echo -e "\e[91m Option not recognised, please check the provided options again \e[0m"
	usage
    ;;
    esac
done

# If no options are provided, then display the script usage message
if [[ -z $file_path && -z $script_path && "$report_impact" != "true" ]]; then 
	echo 
    echo -e "\e[91m No options provided. Please provide appropriate options. \e[0m" 
 	usage
fi

if [[ -n "$file_mode_custom_rule_path" ]]; then
    if [[ -n $report_impact ]]; then
        echo
        echo -e "\e[91m Error: -c can only be used with -f or -s option. \e[0m" 
        usage
    fi
fi

# Function to log messages
log() { 
echo "$@" >> $trigger_ghr_log_file
}

# Function to output log header
log_header() { 
cat << EOF >> $trigger_ghr_log_file
    ##########################################
    Log started on $(date '+%Y-%m-%d %H:%M:%S')
    ##########################################
EOF
}
log_header

# Check to see if file_path is not empty and also check file exists in the path provided 
#File exists, then set the failure_report_file to file provided by the user
use_file_to_triggerGHR() {
    #File dosent exist, then exit
    if ! [ -f "$file_path" ]; then 
        echo -e "\e[91m File does not exist in the path provided \e[0m" 
        exit 0    
    fi 
    failure_report_file=$file_path
    log "$FUNCNAME:Log file set to $failure_report_file "    
    if [ -n "$file_mode_custom_rule_path" ]; then
        if [ ! -f "$file_mode_custom_rule_path" ]; then
            echo -e "\e[91m File mode custom rule path is specified, but does not exist \e[0m" 
            exit 0    
        else
            log "$FUNCNAME: Additional custom rule path set to $file_mode_custom_rule_path " 
        fi    
    fi 
}

# Check if the script file exists and is executable from the path provided, otherwise exit the script
# Incase script exists, then set the script_to_execute to the script path provided by the user 
execute_nhc_to_triggerGHR(){ 
    script_to_execute="$script_path/$script_file_to_trigger_nhc" 
    if ! [ -x "$script_to_execute" ];  then
      echo -e "\e[91m Script does not exist or not executable in the provided path \e[0m" 
	  exit 0 
    fi 
    if [ -n "$file_mode_custom_rule_path" ]; then
        if [ ! -f "$file_mode_custom_rule_path" ]; then
            echo -e "\e[91m File mode custom rule path is specified, but does not exist \e[0m" 
            exit 0    
        else
            log "$FUNCNAME: Additional custom rule path set to $file_mode_custom_rule_path " 
        fi    
    fi     
    echo "NHC script is being executed...."
    #Set the log file to the health.log file present in the current folder
    failure_report_file=$(realpath -m "$health_log_file_name")
    log "Log file to fetch NHC error msg is set to $failure_report_file "
    echo -e "${usage_color_code} NHC script can be run with the following option" 
    eval bash "$script_to_execute" "-h" 
    echo -e "\e[0m"
    #Additional options are provided in the user.env file, then trigger NHC with the options provided
    #No options are provided, then trigger NHC without any options
    case "$additional_options" in
    "")
        echo "No options provided to trigger NHC, so triggering with default option" 
        bash "$script_to_execute" 
        ;;
    *"-o"*)
        failure_report_file=$(echo "$additional_options" | awk '{print $2}') 
        log "$FUNCNAME: Path provided in the -o option: $failure_report_file" 
        bash "$script_to_execute" "$additional_options" 
        ;;
    *)
        # If any other options are provided, then trigger NHC with the options provided. 
        # Capture the output of the NHC script into output variable as well as display it to the console
        output=$(bash "$script_to_execute" "$additional_options" 2>&1 > >(tee /dev/tty)) 
        ;;
    esac
    #If NHC script completed without errors, then exit the script
    if [ $? -eq 0 ]; then 
        echo "NHC script executed successfully. No NHC errors to report" 
        exit 0
    fi
    #If NHC script has errors realted to getopt,like incase of invalid options, then display the error and exit the script
    if echo "$output" | grep -q "getopt" ; then 
        getopt_error=$(echo "$output" | head -n 1) 
        echo -e "\e[91m $getopt_error, please check the provided options \e[0m" 
        exit 1
	fi 
}


#If the user tries to trigger the script with -r option, then this block will be called
#User has to provide FAILURE_SCENARIO and FAILURE_DETAILS in the user.env file to trigger impact using -r option
user_defined_failure_to_triggerGHR() {
    #User uses -r option, but dosen't provide the FAILURE_SCENARIO, then exit the script
    if [ -z "$FAILURE_SCENARIO" ]; then
        echo -e "\e[91m There is no FAILURE_SCENARIO provided by user in config/user.env file to trigger GHR \e[0m" 
        exit 1
    fi  

    #User provided FAILURE_SCENARIO is matched to nhc_fault_dictionary config file
    user_defined_impact=$(grep -Ei ".*$FAILURE_SCENARIO.*" $fault_code_config_file_path)

    #There is no match for the provided FAILURE_SCENARIO in nhc_fault_dictionary config file, then exit the script
    if [ -z "$user_defined_impact" ]; then
        echo -e "\e[91m The provide fault scenerio, is not supported by GHR \e[0m"
        exit 0
    fi   

    # user_defined_fault_code eventually maps to get fault code
    user_defined_fault_code=$(echo $user_defined_impact | awk -F ' =' '{print $1}')

    # user_defined_fault_code_value will have the FAILURE_DETAILS provided by the user
    user_defined_fault_code_value=$FAILURE_DETAILS
}

#Find the fault_code and the NHC error based on first occurrance of fault_code, ignoring the fault_code for NHC setup issue(NHCNA)
get_fault_code() {
    #failure_report_file is set only incase of -s or -f option, so if failure_report_file is empty
    #With user provided FAILURE_SCENARIO we can get the user_defined_fault_code which in turn is mapped to fault_code
    if [ -z $failure_report_file ]; then
        fault_code=$user_defined_fault_code
        log "User defined fault_Code is $user_defined_fault_code"
        return
    fi
    # Read the health.log file in reverse order find the first occurrence of the fault_code and store it in fault_code_in_logfile variable
    fault_code_in_logfile=$(tac $failure_report_file | awk '/FaultCode:/ && !/FaultCode:NHCNA/ {print $NF; exit}')
    #faultcode is empty, then exit because without fault_code cannot trigger GHR  
    if [ -z "$fault_code_in_logfile" ]; then 
        echo -e "\e[91m Fault code not present in log file to trigger ImpactRP. \e[0m"
        if [ -n "$file_mode_custom_rule_path" ]; then
            echo -e "\e[91m Additional custom rule is enabled. Trying to map fault code from it \e[0m"
            flag=0
            while read -r entry; do
                key=$(echo "$entry" | jq -r '.key')
                value=$(echo "$entry" | jq -r '.value')
                if grep -qi "$key" "$failure_report_file"; then
                    fault_code="$value"
                    flag=1
                    break
                fi
            done < <(jq -c 'to_entries[]' "$file_mode_custom_rule_path")
            if [ "$flag" -eq 0 ]; then
                echo -e "\e[91m No failure mapped to the custom rule . Please check the log file provided \e[0m"
                exit 0
            fi
        else
            echo -e "\e[91m Please check the log file provided \e[0m"
            exit 0
        fi
    else
	    fault_code=$fault_code_in_logfile
    fi 
    #Get the entire line of NHC error message from the fault code
    nhc_error=$(grep -m 1 "FaultCode: $fault_code" $failure_report_file | awk '{print}')   
    log "$FUNCNAME:The fault code is not empty: $fault_code" 
    log "$FUNCNAME:The error for faultcode '$fault_code' is '$nhc_error'"
}

# The configuration file is fault_code.cfg file present in the config folder
config_file=$(realpath -m "$fault_code_config_file_path")
log "Configuration file in the $config_file"

# Read the configuration file to find the value of fault_code and store it in fault_code_value. 
# fault_code_value will have fault_code mapped to its impact category eg NHC2001 = Resource.Hpc.Unhealthy.HpcGenericFailure
get_fault_code_value() { 
    while IFS=" = " read -r key value; do 
	if [[ "$key" == "$fault_code" ]]; then 
	log "$FUNCNAME:The value fault code is: $key and its value is ${value//\"/}" 
	fault_code_value="${value//\"/}"        
	fi
    done < $config_file
}

# Find the impact category based on the faultcode_code_value. Impact category is the value in the fault_code.cfg file
get_impact_category() { 
  impact_category=$(echo "$fault_code_value" | awk -F ' #' '{print $1}') 
  log "$FUNCNAME: Impact category is $impact_category"   
   # Check if impact_category was not found in fault_code value, then set it to generic_fault_code_value 
   if [ -z "${impact_category+x}" ]; then 
   log "$FUNCNAME:Impact category is not defined. Setting the Impact category to generic category : Resource.Hpc.Unhealthy.HpcGenericFailure" 
   impact_category="$generic_fault_code_value"
   log "$FUNCNAME:default impact category set '$impact_category'" 
   fi
}

# Get the impact description from the NHC error message If NHC error message is empty, then set the impact description to generic_fault_code_value
get_impact_description() {
    #Setting the impact description as the error message received from NHC
    impact_description=$(echo "$nhc_error" | awk -F ': ' '{for (i=5; i<=NF; i++) printf (i==5?"":" : ") $i; print ""}')
    # If impact description was not set based on NHC error message, then impact description is set based on generic_fault_code_value HPC Generic error
    if [ -z "$impact_description" ]; then
    #If impact description is empty and there is no user defined fault details, then set the impact description to generic_fault_code_value
        if [ -z "$user_defined_fault_code_value" ]; then
            impact_description="$generic_fault_code_value" 
        else
        #If impact description is empty, then set the impact description to user_defined_fault_code_value    
            impact_description=$user_defined_fault_code_value    
        fi
    fi
    log "$FUNCNAME: The impact description is $impact_description"
}

#Function to get physical host name from kvp_pool registry and save it in variable physical_hostname
# get physical host name
pHostName=$(python3 ${parent_directory}/getPhysHostName.py)
physical_hostname=$(echo $pHostName| awk '{print $4}')
log "Physical hostname is $physical_hostname"

check_empty() { 
    while [ "$#" -gt 0 ]; do 
    key="$1" 
    value="$2" 
    if [ -z "$value" ]; then 
    log "Variable '$key' is empty" 
    else 
    log "Variable' $key' has value" 
    fi 

    shift 2     
    done
}

####### Main script ########
if [[ "$impact_rp" == "true" && ! -z "$file_path" ]]; then 
use_file_to_triggerGHR "$impact_rp" "$file_path" "$file_mode_custom_rule_path"
fi

if [[ "$nhc" == "true" && ! -z "$script_path" ]]; then 
execute_nhc_to_triggerGHR "$nhc" "$script_path" "$file_mode_custom_rule_path"
fi

if [ "$report_impact" == "true" ]; then
user_defined_failure_to_triggerGHR
fi

get_fault_code
get_fault_code_value "$fault_code"
get_impact_category "$fault_code_value" "$generic_fault_code_value"
get_impact_description "$nhc_error" "$generic_fault_code_value"
    
#To trigger GHR get the oauth2 token from the metadata of MSID
#Get the object_id from the user provided object_id in the user.env file.
#Note object_id is mandatory if the Impact Reporter role is assigned as user assigned managed identity
oauth2_token_common_url="http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F"
if [ -z "$object_id" ]; then
oauth2_token_url=$oauth2_token_common_url
else
oauth2_token_url="$oauth2_token_common_url&object_id=$object_id"
fi
oauth2_token=$(curl "$oauth2_token_url" -H Metadata:true -s )

#Extract the access_token from the json response got from oauth2_token
access_token=$(echo "$oauth2_token" | jq -r '.access_token')

#Get the subscription_id from the metadata response
subscriptionId=$(curl -H Metadata:true --max-time 10 -s "http://169.254.169.254/metadata/instance/compute/subscriptionId?api-version=2021-01-01&format=text")

#fetch the resource_id from the metadata response
resourceId=$(curl -H Metadata:true --max-time 10 -s "http://169.254.169.254/metadata/instance/compute/resourceId?api-version=2021-01-01&format=text")

#create a unique string for the workloadimpact name
workloadImpactName=$(uuidgen)

#Set the startdate to current date and time
startdate=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

#This function is used to check if any of the above collected details is empty or not and log the details
check_empty "AccessToken" "$access_token" "SubscriptionId" "$subscriptionId" "ResourceId" "$resourceId" "WorkImpactName" "$workloadImpactName" "Date" "$startdate"

#Trigger the Impact Reporting API with all the collected data

curl -X PUT "https://management.azure.com/subscriptions/${subscriptionId}/providers/Microsoft.Impact/workloadImpacts/${workloadImpactName}?api-version=2023-02-01-preview" \
 -H "Authorization: Bearer $access_token" \
 -H "Content-type: application/json" \
 -d '{
       "properties": { "startDateTime": "'"$startdate"'",
                       "reportedTimeUtc": "'"$startdate"'",
                       "impactCategory": "'"$impact_category"'",
                        "impactDescription": "'"$impact_description"'",
                        "impactedResourceId": "'"$resourceId"'",
                         "additionalProperties": {
                                "PhysicalHostName": "'"$physical_hostname"'"
                        }

                }
    }'

