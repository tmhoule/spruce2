#!/bin/sh
#Todd Houle
#Feb2016
#This script will build an ugly html page with unused scripts and groups in your JSS


########### EDIT THESE ##################################
JSSURL="https://jss.school.edu:8443"
user="apiusername"
pass="sekretz"
############################################################


JSS="$JSSURL/JSSResource"
outFile="/private/tmp/UnUsed.html"

mkdir /tmp/JSSCleanup 2>/dev/null

#Get Scripts
curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/scripts" -X GET | xmllint --format - > /private/tmp/JSSCleanup/scripts.xml
#get policies
curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/policies" -X GET | xmllint --format - > /private/tmp/JSSCleanup/policies.xml
#get SmartGroups
curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/computergroups" -X GET | xmllint --format - > /private/tmp/JSSCleanup/groups.xml
#get Configurations
curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/computerconfigurations" -X GET | xmllint --format - > /private/tmp/JSSCleanup/configurations.xml
#get ExtensionAttributes
curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/computerextensionattributes" -X GET | xmllint --format - > /private/tmp/JSSCleanup/extnAttrbutes.xml
#copy online names to 0 file for later scanning
cat /tmp/JSSCleanup/extnAttrbutes.xml |grep "<name>" > /private/tmp/JSSCleanup/extnAttrbutes0.xml
#Get all Packages in the JSS
curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/packages" -X GET | xmllint --format - > /private/tmp/JSSCleanup/packages.xml



#empty lists (to use later)
SCRIPTSUSED=()
GROUPSUSED=()
EASUSED=()
PKGUSED=()

#used at end to compare content used and not
scriptList=`cat /tmp/JSSCleanup/scripts.xml |grep "<id>"| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
scriptListArray=($scriptList)

groupsList=`cat /tmp/JSSCleanup/groups.xml |grep "<id>"| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
groupListArray=($groupsList)

packageList=`cat /tmp/JSSCleanup/packages.xml |grep "<id>"| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
packageListArray=($packageList)

##a comment block.
#: <<EOF
#EOF

#loop through Policies
policyList=`cat /tmp/JSSCleanup/policies.xml |grep -i \<id\>|awk -F\> '{print $2}'|awk -F\< '{print $1}'`
arr=($policyList)

#get all policies from JSS and build a list of scripts used
for thisPolicy in "${arr[@]}"; do
#    break
    echo "
       ############################"
    echo "Working on Policy $thisPolicy"
    curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/policies/id/$thisPolicy" -X GET | xmllint --format - > /private/tmp/JSSCleanup/policy$thisPolicy.xml

    scriptsInPol=`xpath /tmp/JSSCleanup/policy$thisPolicy.xml '/policy/scripts' 2>/dev/null|grep "<id>"| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    scrarr=($scriptsInPol)
    for oneScript in "${scrarr[@]}"; do
	echo "script ID $oneScript used in policy number $thisPolicy"

	#Add scripts from policy to array of scripts in use
	if [[ " ${SCRIPTSUSED[@]} " =~ " ${oneScript} " ]]; then
            # whatever you want to do when arr contains value
	    echo "script $oneScript is already listed in use"
	else
            # whatever you want to do when arr doesn't contain value
	    echo "adding script $oneScript to SCRIPTSUSED array"
	    SCRIPTSUSED+=($oneScript)
	fi
    done

    #look for unused smartGroups
    smrtGrpInPol=`xpath /tmp/JSSCleanup/policy$thisPolicy.xml '/policy/scope/computer_groups' 2>/dev/null|grep "<id>"| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    smrtGrpArr=($smrtGrpInPol)
    for oneGrp in "${smrtGrpArr[@]}"; do
	echo "group ID $oneGrp used in policy number $thisPolicy"
	if [[ " ${GROUPSUSED[@]} " =~ " ${oneGrp} " ]]; then
            # whatever you want to do when arr contains value
            echo "script $oneGrp is already listed in use"
        else
            # whatever you want to do when arr doesn't contain value
            echo "adding grp $oneGrp to GRPUSED array"
            GROUPSUSED+=($oneGrp)
        fi
    done



    #Look for unused packages
    ##########3
    pkgGrpInPol=`xpath /tmp/JSSCleanup/policy$thisPolicy.xml '/policy/package_configuration' 2>/dev/null|grep "<id>"| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    pkgGrpArr=($pkgGrpInPol)
    for onePkg in "${pkgGrpArr[@]}"; do
	echo "package $onePkg used in policy number $thisPolicy"
	if [[ " ${PKGUSED[@]} " =~ " ${onePkg} " ]]; then
            echo "package $onePkg is already listed in use"
        else
            echo "adding package $onePkg to PKGUSED array"
            PKGUSED+=($onePkg)
        fi
    done


    #look for unused smartgroupsExcludedInPolicies
    smrtGrpInPolEx=`xpath /tmp/JSSCleanup/policy$thisPolicy.xml '/policy/scope/exclusions/computer_groups' 2>/dev/null|grep "<id>"| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    smrtGrpArr2=($smrtGrpInPolEx)
    for oneGrp in "${smrtGrpArr2[@]}"; do
	echo "group exclusion $oneGrp used in policy number $thisPolicy"
        if [[ " ${GROUPSUSED[@]} " =~ " ${oneGrp} " ]]; then
            # whatever you want to do when arr contains value 
            echo "script $oneGrp is already listed in use"
        else
            # whatever you want to do when arr doesn't contain value 
            echo "adding grp $oneGrp to GRPUSED array"
            GROUPSUSED+=($oneGrp)
        fi
    done
done


#Get all configurations from JSS 
configurationList=`cat /tmp/JSSCleanup/configurations.xml |grep -i \<id\>|awk -F\> '{print $2}'|awk -F\< '{print $1}'`
arrConfig=($configurationList)
for thisConfig in "${arrConfig[@]}"; do
    echo "
    ##############"
    echo "Working on Configuration $thisConfig"
    curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/computerconfigurations/id/$thisConfig" -X GET | xmllint --format - > /private/tmp/JSSCleanup/config$thisConfig.xml
    scriptsInConfig=`xpath /tmp/JSSCleanup/config$thisConfig.xml '/computer_configuration/scripts/script/id' 2>/dev/null| awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    confiArr=($scriptsInConfig)
    for oneConScript in "${confiArr[@]}"; do
	echo "script ID $oneConScript used in config $thisConfig"
	#Add scripts from policy to array of scripts in use                                                                                                                                               
	if [[ " ${SCRIPTSUSED[@]} " =~ " ${oneConScript} " ]]; then
            # whatever you want to do when arr contains value
            echo "script $oneConScript is already listed in use in config"
	else
            echo "adding script $oneConScript to SCRIPTSUSED array for config"
            SCRIPTSUSED+=($oneConScript)
	fi
    done
done


#get all Smart Groups and look for unused EAs
echo "GETTING GROUPS TO LOOK FOR EAS"
smartGroupList=`cat /tmp/JSSCleanup/groups.xml |grep -i \<id\>|awk -F\> '{print $2}'|awk -F\< '{print $1}'`
arrGrp=($smartGroupList)
loopCounterEA=1
loopCounterLess=0

for thisGroup in "${arrGrp[@]}"; do
    echo "pulling group $thisGroup"
    curl -H "Accept: application/xml" -sfku "$user:$pass" "$JSS/computergroups/id/$thisGroup" -X GET | xmllint --format - > /private/tmp/JSSCleanup/group$thisGroup.xml
    easTocheck=$(xpath /tmp/JSSCleanup/group$thisGroup.xml '/computer_group/criteria' 2>/dev/null|grep name)
#    easToCheckArr=($easTocheck)

    while read -r line || [[ -n "$line" ]]; do
	echo "Removing EA $line: from extnAttrbutes$loopCounterLess.xml to extnAttrbutes$loopCounterEA.xml"
	if [ ! -z "$line" ]; then
	    cat /private/tmp/JSSCleanup/extnAttrbutes$loopCounterLess.xml |grep -v "$line" > /private/tmp/JSSCleanup/extnAttrbutes$loopCounterEA.xml
	    ((loopCounterEA++))
	    ((loopCounterLess++))
	    echo "loopCounterEA is now $loopCounterEA and loopCounterLess is now $loopCounterLess"
	else
	    echo "##### Group $thisGroup has NULL criteria"
	fi
    done <<< "$easTocheck"
done    


echo "Moving to part two now..."
echo ""

#build array of script id's that are not used in any policies
Array3=()
for i in "${scriptListArray[@]}"; do
    skip=
    for j in "${SCRIPTSUSED[@]}"; do
        [[ $i == $j ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || Array3+=("$i")
done
declare -p Array3



ArrayGrp=()
for x in "${groupListArray[@]}"; do
    skip=
    for y in "${GROUPSUSED[@]}"; do
	[[ $x == $y ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || ArrayGrp+=("$x")
done
declare -p ArrayGrp


#buildArrayOfPackagesNotUsed
Array4=()
for z in "${packageListArray[@]}"; do
    skip=
    for z1 in "${PKGUSED[@]}"; do
	[[ $z == $z1 ]] && { skip=1; break; }
    done
    [[ -n $skip ]] || Array4+=("$z")
done


scriptCount=0
echo ""  > $outFile

for unusedScript in "${Array3[@]}"; do
    ((scriptCount=scriptCount+1))
done
echo "There are $scriptCount unused Scripts in your JSS"

echo "<h2>Unused Scripts: $scriptCount</h2>" >> $outFile
echo "<ul>" >> $outFile
for unusedScript in "${Array3[@]}"; do
    scriptName=`grep -A1 "<id>$unusedScript</id>" /tmp/JSSCleanup/scripts.xml |grep "<name>" |awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    echo "<li><a target=\"_blank\" href=\"$JSSURL/view/settings/computer/scripts/$unusedScript\">Script: $scriptName</a><BR>" >> $outFile
done
echo "</ul>" >> $outFile



grpCount=0
for unusedGroup in "${ArrayGrp[@]}"; do
    ((grpCount=grpCount+1))
done
echo "There are $grpCount unused Groups in your JSS"

pkgCount=0
for unusedPKG in "${Array4[@]}"; do
    ((pkgCount=pkgCount+1))
done
echo "There are $pkgCount unused Groups in your JSS"




echo "<h2>Unused Groups: $grpCount</h2>" >> $outFile
echo "<ul>" >> $outFile
for unusedgroup in "${ArrayGrp[@]}"; do
    groupType=`grep -A2 "<id>$unusedgroup</id>" /tmp/JSSCleanup/groups.xml |grep "<is_smart>" |awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    
    groupName=`grep -A1 "<id>$unusedgroup</id>" /tmp/JSSCleanup/groups.xml |grep "<name>" |awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    if [ "$groupType" == "true" ]; then
	echo "<li><a target=\"_blank\" href=\"$JSSURL/smartComputerGroups.html?id=$unusedgroup\">Smart Group: $groupName</a><BR>" >> $outFile
    else
	echo "<li><a target=\"_blank\" href=\"$JSSURL/staticComputerGroups.html?id=$unusedgroup\">Static Group: $groupName</a><BR>" >> $outFile
    fi
done
echo "</ul>" >> $outFile

unusedEACount=$(wc -l /private/tmp/JSSCleanup/extnAttrbutes$loopCounterLess.xml |awk '{print $1}')
echo "<h2>Unused EAs: $unusedEACount</h2>" >> $outFile
echo "<h2>Caution! EA's may not be scoped to any groups but still be used.</h2>" >> $outFile
echo "<ul>" >> $outFile
    while read -r line; do 
        echo "**** EA is $line ****"
        EAID=$(cat /private/tmp/JSSCleanup/extnAttrbutes.xml | grep -B 1 "$line" | grep -v "$line" | sed 's/[^0-9*]//g')
        echo "**** EAID is $EAID ***"
        echo "<li><a target=\"_blank\" href=\"$JSSURL/computerExtensionAttributes.html?id=$EAID\">EA: $line</a><BR>" >> $outFile
    done < "/private/tmp/JSSCleanup/extnAttrbutes$loopCounterLess.xml"
echo "</ul>" >> $outFile

echo "<h2>Unused Packages: $pkgCount</h2>" >> $outFile
echo "<ul>" >> $outFile
for unusedPKG in "${Array4[@]}"; do
    pkgName=`grep -A1 "<id>$unusedPKG</id>" /tmp/JSSCleanup/packages.xml |grep "<name>" |awk -F\> '{print $2}'|awk -F\< '{print $1}'`
    echo "<li><a target=\"_blank\" href=\"$JSSURL/packages.html?id=$unusedPKG\">Package: $pkgName</a><BR>" >> $outFile
done
echo "</ul>" >> $outFile

open $outFile



