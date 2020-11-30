Global key (default for all domains)
# yum install perl-XML-Simple perl-Mail-DKIM perl-XML-Parser
# wget https://raw.githubusercontent.com/qmtoaster/dkim/master/qmail-remote
# wget https://raw.githubusercontent.com/qmtoaster/dkim/master/signconf.xml
# mkdir /var/qmail/control/dkim
# mv signconf.xml /var/qmail/control/dkim/
# chown -R qmailr:qmail /var/qmail/control/dkim/
CentOS 7
# dknewkey /var/qmail/control/dkim/global.key 1024 > /var/qmail/control/dkim/public.txt
# perl -pi -e 's/global.key._domainkey/dkim1/' /var/qmail/control/dkim/public.txt
CentOS 8
# cd /var/qmail/control/dkim
# openssl genrsa -out ./global.key 2048 && openssl rsa -in ./global.key -pubout -out ./temp.txt
# cat ./temp.txt | grep -v - | tr -d '\n' | sed '1s/^/dkim1 IN TXT "k=rsa; p=/' &> ./public.txt && echo "\"" >> ./public.txt && rm ./temp.txt
# qmailctl stop
# mv /var/qmail/bin/qmail-remote /var/qmail/bin/qmail-remote.orig
# mv qmail-remote /var/qmail/bin
# chmod 777 /var/qmail/bin/qmail-remote
# chown root:qmail /var/qmail/bin/qmail-remote
# qmailctl start
# cat /var/qmail/control/dkim/public.txt
   dkim1._domainkey      IN      TXT     "k=rsa; p=******************************"
Create DNS TXT record for your domain using the output from public.txt above
   Host                                Text
   dkim1._domainkey       	v=DKIM1; k=rsa; p=************************* 
Your DKIM setup is done.
To test send mail to any yahoo email id and check headers. If errors show in headers then wait for changes to reflect in DNS.
DKIM key (other than default)
Centos 7
# dknewkey /var/qmail/control/dkim/otherdomain.com.key 1024 > /var/qmail/control/dkim/otherdomain.com.txt
# perl -pi -e 's/^.*\.key/dkim1/' /var/qmail/control/dkim/otherdomain.com.txt
CentOS 8
# cd /var/qmail/control/dkim
# openssl genrsa -out ./otherdomain.key 2048 && openssl rsa -in ./otherdomain.key -pubout -out ./temp.txt
# cat ./temp.txt | grep -v - | tr -d '\n' | sed '1s/^/dkim1 IN TXT "k=rsa; p=/' &> ./otherdomain.txt && echo "\"" >> ./otherdomain.txt && rm ./temp.txt

# cat /var/qmail/control/dkim/otherdomain.com.txt
   dkim1._domainkey       IN      TXT     "k=rsa; p=******************************"
Create DNS TXT record for otherdomain.com using the output from the text file 'otherdomain.com.txt'
   Host                                Text
   dkim1._domainkey       	v=DKIM1; k=rsa; p=*************************
# vi /var/qmail/control/dkim/signconf.xml (Add)
  <otherdomain.com domain="otherdomain.com" keyfile="/var/qmail/control/dkim/otherdomain.com.key" selector="dkim1">
    <types id="dkim" />
    <types id="domainkey" method="nofws" />
  </otherdomain.com>

So file looks like this:

<dkimsign>
  <!-- per default sign all mails using dkim -->
  <global algorithm="rsa-sha1" domain="/var/qmail/control/me" keyfile="/var/qmail/control/dkim/global.key" method="simple" selector="dkim1">
    <types id="dkim" />
  </global>
  <otherdomain.com domain="otherdomain.com" keyfile="/var/qmail/control/dkim/otherdomain.com.key" selector="dkim1">
    <types id="dkim" />
    <types id="domainkey" method="nofws" />
  </otherdomain.com>
</dkimsign>
Prevent DKIM signing for a domain
# vi /var/qmail/control/dkim/signconf.xml (Add)
  <nonsigneddomain.com />

So file looks like this:

<dkimsign>
  <!-- per default sign all mails using dkim -->
  <global algorithm="rsa-sha1" domain="/var/qmail/control/me" keyfile="/var/qmail/control/dkim/global.key" method="simple" selector="dkim1">
    <types id="dkim" />
  </global>
  <otherdomain.com domain="otherdomain.com" keyfile="/var/qmail/control/dkim/otherdomain.com.key" selector="dkim1">
    <types id="dkim" />
    <types id="domainkey" method="nofws" />
  </otherdomain.com>
  <nonsigneddomain.com />
</dkimsign>
DKIM verification (no patch):
Assumes 'QMAILQUEUE="/var/qmail/bin/simscan"' defined in /etc/tcprules.d/tcp.smtp
&& /var/qmail/bin/qmail-queue is a link.
Note: Spamassassin has DKIM verification making this unnecessary.
# qmailctl stop
Add 'export DKVERIFY=1' to /var/qmail/supervise/smtp/run
Increase softlimit to 128000000 in /var/qmail/supervise/smtp/run
# cd /var/qmail/bin
# wget http://www.qmailtoaster.org/dkimverify.pl
# wget http://www.qmailtoaster.org/qmail-queue.pl.sh
# chown root:root dkimverify.pl
# chown qmailq:qmail qmail-queue.pl.sh
# chmod 755 dkimverify.pl
# chmod 4777 qmail-queue.pl.sh
# unlink qmail-queue
# ln -s qmail-queue.pl.sh qmail-queue
# qmailctl start
Send email to user on the host
Check email header dkim verification
   Notes: 
          1) In order to test your settings, simply send an email to: check-auth@verifier.port25.com and/or check-auth2@verifier.port25.com
             with the suject of "test" (without the quotes) and "Just testing" in the body (also without quotes). It is best but not required
             to have a subject and body because this service will also show you how spamassassin rated your email. If you have a GMAIL or Yahoo
             email account sending to either or both accounts DKIM signatures could be verified.
             Click to test
          2) To test your DKIM signature wiith OpenDKIM's 'opendkim-testkey' utility install opendkim and run the utility:
             a) # yum install epel-release opendkim
             b) # opendkim-testkey -vvvv -d otherdomain.com  -k /var/qmail/control/dkim/otherdomain.com.key -s dkim1

                  opendkim-testkey: using default configfile /etc/opendkim.conf
                  opendkim-testkey: /var/qmail/control/dkim/otherdomain.com.key: WARNING: unsafe permissions
                  opendkim-testkey: key loaded from /var/qmail/control/dkim/otherdomain.com.key
                  opendkim-testkey: checking key 'dkim1._domainkey.otherdomain.com'
                  opendkim-testkey: key OK

          3) dknewkey creates by default a 384 bit key. For a larger key use the following syntax :
             # dknewkey domain.tld.key 1024 > domain.tld.txt
          4) Testing DKIM signatures sending from Roundcube webmail I found that plain text formatted email caused DKIM failure sending
             to port25.com and GMAIL recipients, but when sending the same email in Roundcube's html format the DKIM signature was verified
             and passed. The same email DKIM signature passed with Squirrelmail, Thunderbird, and OpenDKIM's 'opendkim-testkey' program. It 
             seems that certain email clients will add or subtract characters in the email header causing DKIM to fail. This may be happening 
             in Roundcube while other clients do not affect the email header adversely. I have a help request in the Roundcube user's list
             for this issue. Hopefully, this issue is  merely a configuration setting, if not, that it is resolved soon.
