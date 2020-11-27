#!/bin/bash

##
# A BASH Wrapper for the quizapi.io API
# Version: 1.0.0
##

##
# Colors
##
green='\e[32m'
blue='\e[34m'
clear='\e[0m'
orange='\e[33m'
red='\e[31m'

##
# Check if jq is installed
##

if ! [ -x "$(command -v jq)" ] ; then
        echo "The jq command is required! Please install it and then try again"
        exit 1
fi 

##
# API URL
##
url='quizapi.io'
quiz_endpoint='api/v1/questions'

##
# Quiz session file
##
temp_quiz=$(mktemp /tmp/temp-quiz.XXXXXX)

##
# Color Functions
##

ColorGreen(){
        echo -ne $green$1$clear
}
ColorBlue(){
        echo -ne $blue$1$clear
}
ColorRed(){
        echo -ne $red$1$clear
}
ColorOrange(){
        echo -ne $orange$1$clear
}

##
# Help function
##
function usage() {
        echo "Usage: $0 -a API_KEY [-c Category] [-d Difficulty] [-t Tags]" 1>&2; exit 1;
}

##
# Read the arguments with the getopts command
##
while getopts "a:c:d:t:" o; do
    case "${o}" in
        a)
            API_KEY=${OPTARG}
            ;;
        c)
            category=${OPTARG}
            ;;
        d)
            difficulty=${OPTARG}
            ;;
        t)
            tags=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done

shift $((OPTIND-1))

##
# Check if an API key was specified
##
if [ -z "${API_KEY}" ]; then
    usage
fi

##
# Question formatting
##
function get_questions(){
        content=$( curl -s ${url}/${quiz_endpoint} -G -d limit=1 -d category=${category} -d difficulty=${difficulty} -d tags=${tags} -H "X-Api-Key: ${API_KEY}" -o ${temp_quiz}  )
}

##
# Check if the API request was successful
##
function check_error(){
        check_auth=$(cat ${temp_quiz} | jq .error?)

        if [ "$check_auth" == '' ] ; then
                content_check="1"    
        else
                content_check="0"
        fi
}

##
# Check if there are any questions found
##
function check_if_null(){
        question_count=$(cat ${temp_quiz})
        if [ "$question_count" == "No questions found.." ] ; then
                echo "No questions found.."
                echo "Try with different category or tag."
                rm ${temp_quiz}
                exit 1
        fi
}

##
# Parse the Json output
##
function format_question(){
        #jq .[0].question

        question=$( cat ${temp_quiz} | jq .[0].question )
        answer_a=$( cat ${temp_quiz} | jq .[0].answers.answer_a )
        answer_b=$( cat ${temp_quiz} | jq .[0].answers.answer_b )
        answer_c=$( cat ${temp_quiz} | jq .[0].answers.answer_c )
        answer_d=$( cat ${temp_quiz} | jq .[0].answers.answer_d )
        answer_e=$( cat ${temp_quiz} | jq .[0].answers.answer_e )
        answer_f=$( cat ${temp_quiz} | jq .[0].answers.answer_f )
        answer_a_correct=$( cat ${temp_quiz} | jq -r .[0].correct_answers.answer_a_correct )
        answer_b_correct=$( cat ${temp_quiz} | jq -r .[0].correct_answers.answer_b_correct )
        answer_c_correct=$( cat ${temp_quiz} | jq -r .[0].correct_answers.answer_c_correct )
        answer_d_correct=$( cat ${temp_quiz} | jq -r .[0].correct_answers.answer_d_correct )
        answer_e_correct=$( cat ${temp_quiz} | jq -r .[0].correct_answers.answer_e_correct )
        answer_f_correct=$( cat ${temp_quiz} | jq -r .[0].correct_answers.answer_f_correct )
        correct=$( cat ${temp_quiz} | jq -r .[0].correct_answer )
        multiple_correct_answers=$( cat ${temp_quiz} | jq -r .[0].multiple_correct_answers )
        #correct_check=$( echo ${correct} | awk -F'Correct: ' '{ print $2 }' )
        correct_check=$( echo ${correct} )

}

##
# Check if multiple possible
##
function multiple_correct_answers(){
        if [ $multiple_correct_answers == true ] ; then
                echo -ne "$(ColorGreen 'There are multiple answers!')
                "
        else
                echo -ne "$(ColorGreen 'There is only 1 correct answer!' )
                "
        fi
}

##
# Show answers that do not have null values
##
function check_answers_value(){
        options=()
        correct_options=()
        for x in {a..f} ; do
                correct_answers="answer_${x}_correct"
                correct_answers_value=$(eval echo "\$$correct_answers")

                answer_value="answer_${x}"
                answer_value_check=$(eval echo "\$$answer_value")

                if ! [ "$answer_value_check" == null ] ; then
                        #echo $(ColorGreen 'a:)') ${answer_a}
                        options+=("${answer_value_check}")
                        if [ $correct_answers_value == true ] ; then
                                correct_options+=("${answer_value_check}")
                        fi
                fi
        done

} 

##
# Call all functions
##
function main(){
        get_questions > /dev/null
        check_error 2>/dev/null
        check_if_null 2>/dev/null
        format_question 2>/dev/null
        check_answers_value 2>/dev/null
}
main

##
# Check if the answer is correct
##
function check_answer() {
        answer="answer_${answer_str_lower}_correct"
        answer_value=$(eval echo "\$$answer")

        if [ "$answer_value" == "true" ] ; then
                echo -ne "$(ColorGreen 'Correct Answer' )
" ;
        else
                echo -ne "$(ColorRed 'Wrong Answer' )
" ;
        fi
}

menu() {
        echo ""
multiple_correct_answers
        echo -ne "
${question}
"
        for i in ${!options[@]}; do 
                printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
        done
        if [[ "$msg" ]]; then echo "$msg"; fi
}

##
# Print Question if the API call was successful
##
if [ "$content_check" -gt "0" ] ; then
        prompt="Check an option (again to uncheck, ENTER when done): "
        while menu && read -rp "$prompt" num && [[ "$num" ]]; do
                [[ "$num" != *[![:digit:]]* ]] &&
                (( num > 0 && num <= ${#options[@]} )) ||
                { msg="Invalid option: $num"; clear; continue; }
                ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
                [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
                clear
        done

        answer_selected=()
        echo ""
        printf "Selected was: "; msg=" nothing"
        for i in ${!options[@]}; do 
                [[ "${choices[i]}" ]] && { printf " %s" "${options[i]}"; answer_selected+=(${options[i]}) ; msg=""; }
        done
        echo "$msg"
        echo "Correct: is: " ${correct_options[@]}

        correct_ansers_string=${correct_options[@]}
        answers_given_string=${answer_selected[@]}

        if [ "${answers_given_string}" == "$correct_ansers_string" ] ; then
                echo -ne "$(ColorGreen 'Correct Answer' )" ;
                echo ""
        else
                echo -ne "$(ColorRed 'Wrong Answer' )" ;
                echo ""
        fi
else
        echo "An error occured:"
        cat ${temp_quiz}
        echo ""
        rm -f ${temp_quiz}
        exit 1
fi

##
# Clean temp files
##
rm -f ${temp_quiz}