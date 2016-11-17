# dkim

From: http://wiki.qmailtoaster.com/index.php/How_to_Setup_DKIM_with_Qmail_Toaster

DKIM on QmailToaster

1) yum install perl-XML-Simple perl-Mail-DKIM perl-XML-Parser
2) wget https://raw.githubusercontent.com/qmtoaster/dkim/master/qmail-remote
3) wget https://raw.githubusercontent.com/qmtoaster/dkim/master/signconf.xml
4) mkdir /var/qmail/control/dkim
5) mv signconf.xml /var/qmail/control/dkim/
6) chown -R qmailr:qmail /var/qmail/control/dkim/
7) dknewkey /var/qmail/control/dkim/global.key > /var/qmail/control/dkim/public.txt
8) perl -pi -e 's/global.key._domainkey/dkim1/' /var/qmail/control/dkim/public.txt
9) qmailctl stop
10) mv /var/qmail/bin/qmail-remote /var/qmail/bin/qmail-remote.orig
11) mv qmail-remote /var/qmail/bin
12) chmod 777 /var/qmail/bin/qmail-remote
13) chown root:qmail /var/qmail/bin/qmail-remote
14) qmailctl start
15) cat /var/qmail/control/dkim/public.txt
16) Create a TXT record in DNS settings for the domain you want to set DKIM as shown in the output of step 15.
17) Your DKIM setup is done.
18) Just send test mail on any yahoo email id and check headers. If show error in headers then just wait to reflect DNS.

In order to test your settings, simply send an email to: check-auth@verifier.port25.com and/or check-auth2@verifier.port25.com with the suject of "test" (without the quotes) and "Just testing" in the body (also without quotes). It is best but not required to have a subject and body because this service will also show you how spamassassin rated your email.

You can also use http://www.sendmail.org/dkim/tools to check and confirm you DKIM configuration 
