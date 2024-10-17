#!/usr/bin/bash
#
# Simple check that any animations for FG1000HardKeyPushed have the correct elements

echo "Checking for notification element"
for i in *.xml;
do
    foo=$(xmllint --xpath "PropertyList/animation//binding[command[text()=\"FG1000HardKeyPushed\"]][not(notification)]" $i 2>&1)
    if [[ $? -eq 0 ]]
    then
        echo "$i : FG1000HardKeyPushed animation missing \<name\> element."
    else
        echo "$i : OK"
    fi
done

echo "Checking for device element"
for i in *.xml;
do
    foo=$(xmllint --xpath "PropertyList/animation//binding[command[text()=\"FG1000HardKeyPushed\"]][not(device)]" $i 2>&1)
    if [[ $? -eq 0 ]]
    then
        echo "$i : FG1000HardKeyPushed animation missing \<device\> element.  (Should match \"N\" in GDUXXXX.N.xml"
    else
        echo "$i : OK"
    fi
done

# This checks for offset, which should be present for anything other than a "knob" animation.
echo "Checking for offset element"
for i in *.xml;
do
    foo=$(xmllint --xpath "PropertyList/animation[type[text()!=\"knob\"]]//binding[command[text()=\"FG1000HardKeyPushed\"]][not(offset)]" $i 2>&1)
    if [[ $? -eq 0 ]]
    then
        echo "$i : FG1000HardKeyPushed pick animation missing \<offset\>1\</offset\>"
    else
        echo "$i : OK"
    fi
done

