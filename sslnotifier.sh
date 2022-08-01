#!/bin/bash
##The script is intended for customers/clients who run their websites on plain Linux servers and has no external or dedicated utility or tool available to inform them prior to the website SSL expiration date.
##Script can set in cron like.
##If you want to run it in every 30 mins:
## `*/30 * * * * bash ssl_checker_and_notifier -d requireddomainname.com -f senderaddress@domain.com -t recipientaddress@domain.com`
## Written by Vipin John Wilson

regex_domain="^[a-zA-Z0-9][a-zA-Z0-9-]{1,61}[a-zA-Z0-9](?:\.[a-zA-Z]{2,})+$"
regex_email="^[a-z0-9!#\$%&'*+/=?^_\`{|}~-]+(\.[a-z0-9!#$%&'*+/=?^_\`{|}~-]+)*@([a-z0-9]([a-z0-9-]*[a-z0-9])?\.)+[a-z0-9]([a-z0-9-]*[a-z0-9])?\$"
date1=$(date +"%b %d %Y")   ##Today's date

mail_or_sendmail()
{
    local SUBJECT="Domain "${DOMAIN}" SSL expires soon";
    local BODY="The current installed SSL certificate expires on "${date2}"";

    if ! which sendmail >/dev/null 2>&1; then
        echo -e "Sendmail not present";
        if ! which mail >/dev/null 2>&1; then
            echo -e "Mail not present";
            echo -e "Cannot send out mail notification since either sendmail or mail function does not present on the server. \nPlease install either one and make sure it is working";
            return;
        else
            echo -e "Mail function present";
            echo -e "${BODY}" | mail -s ""${SUBJECT}"" -- -f $FROM $TO;
            return;
        fi;
    else
        echo -e "Sendmail function present";
        echo -e "SUBJECT: "${SUBJECT}"\n\n"${BODY}"" | sendmail -f $FROM $TO;
        return;
    fi;
}

ssl_check()
{
        date2=$(echo | openssl s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 2>/dev/null | openssl x509 -noout -dates | awk -F"=" '/notAfter/ {print $2}' | awk '{print $1,$2,$4}');
        days_diff=$(echo $(( ($(date --date="$date2" +%s) - $(date --date="$date1" +%s) )/(60*60*24) )));
        echo -e "\nSSL expiry date of domain ${DOMAIN} is $date2 and today's date is $date1";
        if [[ $days_diff -lt 0 ]]; then
                echo -e "SSL of domain $DOMAIN already expired";
                exit 0;
        else
                if [[ $days_diff -le 30 ]]; then
                        echo -e "SSL of domain $DOMAIN expires in $days_diff days";
                        mail_or_sendmail;
                        exit 0;
                fi;
        fi;
}

validate_domain()
{
if echo ${DOMAIN} | grep -P ${regex_domain} > /dev/null 2>&1 ; then
    echo -e "\nDomain name \`${DOMAIN}\` is OK";
    dval=0;
    return;
else
    echo -e "\nDomain name \`${DOMAIN}\` is not valid";
    dval=1;
    return;
fi;
}

domain_resolve_check()
{
    if ping -c1 ${DOMAIN} > /dev/null 2>&1; then
        echo -e "Domain name \`${DOMAIN}\` resolves OK";
        dsval=0;
        return;
    else
        echo -e "Domain name \`${DOMAIN}\` does not resolve to any IP address";
        dsval=1;
        return;
    fi;
}

validate_from_address()
{
if [[ ${FROM} =~ $regex_email ]] ; then
    echo -e "From Email address \`${FROM}\` is OK";
    fval=0;
    return;
else
    echo -e "From address \`${FROM}\` not a valid email address";
    fval=1;
    return;
fi;
}

validate_to_address()
{
if [[ ${TO} =~ $regex_email ]] ; then
    echo -e "To Email address \`${TO}\` is OK";
    tval=0;
    return;
else
    echo -e "To address \`${TO}\` not a valid email address";
    tval=1;
    return;
fi;
}

usage()
{
    echo -e "\nHELP:\n";
    echo -e "\t -d | --domain DOMAIN.COM\n\t -f | --from FROM@emailaddress.com (::Optional Flag and if not specified, the notification mail sends from root@$(hostname)\n\t -t | --to TO@emailaddress.com\n";
    echo -e "\t  Mandatory Flags Required: bash $0 -d|--domain hello.com -t|--to to@test.com\n";
    echo -e "\t  If you want to put valid FROM address instead of sending from root@$(hostname), usage is:\n\n\t  bash $0 -d|--domain hello.com -f|--from from@test.com -t|--to to@test.com\n";
}

options=$(getopt -o d:f:t: -l domain:,from:,to: -n "$0" -- "$@")

[ $? -eq 0 ] || { 
    echo "Incorrect options provided";
    usage;
    exit 1;
}

eval set -- "$options"

while true; do
    case "$1" in
    -d|--domain)
        DOMAIN=$2;
        shift
        ;;
    -f|--from)
        FROM=$2;
        shift
        ;;
    -t|--to)
        TO=$2;
        shift
        ;;
    --)
        shift
        break
        ;;
    *)
        echo "Invalid options!!";
        exit 1
        ;;
    esac
    shift
done

if [ -z "${DOMAIN}" ]; then
    echo -e "\nYou must specify a valid \`Domain Name\`";
fi;

if [ -z "${FROM}" ]; then 
    echo -e "\nYou must specify a valid \`From\` email address";
fi;

if [ -z "${TO}" ]; then
    echo -e "\nYou must specify a valid \`To\` email address";
fi;

if [[ -z "${DOMAIN}" || -z "${FROM}" || -z "${TO}" ]]; then
    usage;
    exit 1;
else
    ###Sanity check
    validate_domain;
    domain_resolve_check
    validate_from_address;
    validate_to_address;
    ###Sanity check ends here
fi;

if [[ ${dval} -eq  0 && ${dsval} -eq 0 && ${fval} -eq 0 && ${tval} -eq 0 ]]; then
    ssl_check;
else
    exit 1;
fi;

echo
echo "Domain is $DOMAIN"
echo "From address is $FROM"
echo "To address is $TO"
echo
exit 0;

