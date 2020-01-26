#!/usr/bin/env python3
#thilina [[AT]] learn.ac.lk
#Usage:
#
#python3 converter.py -i <inputfile> -o <outputfile> -b <baseDN>
#
#eg:
#python3 converter.py -i data.csv -o data.ldif -b ou=dept,ou=people,dc=inst,dc=ac,dc=lk
#
#Data csv should contain: uid,uidNumber,gidNumber,givenName,sn,Password,mobile,email,eduPersonAffiliation  as the head row
#and Case sensitive
#value for email should be from another domain / a personal email and mobile should be in full with country code
#Values for baseDN should match your user database and values for uidNumber and gidNumber should be decided.
#Eg:
#uid,uidNumber,gidNumber,givenName,sn,Password,mobile,email,eduPersonAffiliation
#kamal,1000,2000,kamal,perera,test123,+94777777777,kamal123@gsmail.com,staff
#nimal,1001,2000,nimal,costa,tt123s,+94777777771,nimal123@gsmail.com,faculty
#wimal,1002,2000,wimal,silva,jjdh123,+94777777772,wimaldhf@gsmail.com,student
#
import csv
import getopt
import io
import sys

objClass = "objectClass: person\nobjectClass: organizationalPerson\nobjectClass: inetOrgPerson\nobjectClass: " \
           "eduPerson\nobjectClass: extensibleObject\nobjectClass: posixAccount\nobjectClass: top\nobjectClass: " \
           "shadowAccount "


def mydomain(domain):
    y = ""
    d1 = domain.split(",")
    for x in d1:
        if x[:2] == "dc":
            y += x
    return (y[3:].replace("dc=", "."))


def main(argv):
    infile = ""
    outfile = ""
    domain = ""

    try:
        opts, args = getopt.getopt(argv, "hi:o:b:", ["ifile=", "ofile=", "basedn="])
    except getopt.GetoptError:
        print('python3 converter.py -i <inputfile> -o <outputfile> -b <baseDN>')
        sys.exit(2)
    for opt, arg in opts:
        if opt == '-h':
            print('python3 converter.py -i <inputfile> -o <outputfile> -b <baseDN>')
            sys.exit()
        elif opt in ("-i", "--ifile"):
            infile = arg
        elif opt in ("-o", "--ofile"):
            outfile = arg
        elif opt in ("-b", "--basedn"):
            domain = arg

    maildomain = mydomain(domain)

    with open(infile, newline='', encoding='utf-8') as csv_file:
        csv_reader = csv.DictReader(csv_file, delimiter=',')
        with io.open(outfile, 'a', encoding='utf-8') as outf:
            for row in csv_reader:
                x = "#" + row['uid']
                x += "\ndn: " + row['uid'] + domain + "\n"
                x += objClass
                x += "\ncn: " + row['givenName'] + " " + row['sn']
                x += "\nuid: " + row['uid']
                x += "\nuidNumber: " + row['uidNumber']
                x += "\ngidNumber: " + row['gidNumber']
                x += "\ngivenName: " + row['givenName']
                x += "\nhomeDirectory: /dev/null"
                x += "\nhomePhone: none"
                x += "\nsn: " + row['sn']
                x += "\nmobile: " + row['mobile']
                x += "\nuserPassword: " + row['Password']
                x += "\nmail: " + row['uid'] + "@" + maildomain
                x += "\nemail: " + row['email']
                x += "\neduPersonPrincipalName: " + row['uid'] + "@" + maildomain
                x += "\neduPersonAffiliation: " + row.setdefault('eduPersonAffiliation', 'none')
                x += "\neduPersonOrgUnitDN: " + domain
                x += "\neduPersonEntitlement: urn:mace:dir:entitlement:common-lib-terms\n"
                x += "\n"
                outf.write(x)


if __name__ == "__main__":
    main(sys.argv[1:])
