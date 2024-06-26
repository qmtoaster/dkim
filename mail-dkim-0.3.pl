#!/usr/bin/perl
#
# Copyright (C) 2007 Manuel Mausz (manuel@mausz.at)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either
# version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 
use strict;
use warnings;
our $VERSION = '0.3';
 
use Mail::DKIM 0.29;
use Mail::DKIM::Signer;
 
# enable support for "pretty" signatures, if available
eval 'require Mail::DKIM::TextWrap';
 
=head
config file structure
 - missing settings will be merged from the global-node
 - domain-entry will also match its subdomains
 - create empty domain-node to omit signing (or specify "none" as id)
 
<dkimsign>
  <!-- per default sign all mails using dkim -->
  <global algorithm="rsa-sha256" domain="/var/qmail/control/me" keyfile="/var/qmail/control/dkim/global.key" method="simple" selector="beta">
    <types id="dkim" />
  </global>
 
  <!-- use dkim + domainkey for example.com -->
  <example.com selector="beta2">
    <types id="dkim" />
    <types id="domainkey" method="nofws" />
  </example.com>
 
  <!-- no signing for example2.com -->
  <example2.com />
</dkimsign>
=cut
 
my $configfile = undef;
$configfile    = '/var/qmail/control/dkim/signconf.xml';
my $debugfile  = undef;
#$debugfile    = '/tmp/dkim.debug';
my $qremote    = '/var/qmail/bin/qmail-remote.orig';
my $rcpthosts  = '/var/qmail/control/rcpthosts';
my $binary     = 0;
our $config;
$config->{'global'} = {
  types     => { dkim => {} },
  keyfile   => '/var/qmail/control/dkim/global.key',
  algorithm => 'rsa-sha256',
  method    => 'simple',
  selector  => 'beta',
  # either undefined (=sender), string or file (first line of file will be used)
  #domain   => '/var/qmail/control/me'
};
 
#-------------------------------------------------------------------------------
 
# read config file. safely
if (defined($configfile) && -r $configfile)
{
  eval 'use XML::Simple';
  if (!$@)
  {
    my $xmlconf;
    eval { $xmlconf = XMLin($configfile, ForceArray => ['types'], KeyAttr => ['id']); };
    qexit_deferral('Unable to read config file: ', $@)
      if ($@);
    ConfigMerge::merge($config, $xmlconf);
  }
}
 
# open debug file
my $debugfh = undef;
if (defined($debugfile))
{
  open($debugfh, '>', $debugfile)
    or qexit_deferral('Unable to open ', $debugfile, ' to writing: ', $!);
}
 
# generate signatures
my $dkim;
my $mailbuf = '';
eval
{
  my $conf = $config->{'global'};
  $dkim =  Mail::DKIM::Signer->new(
    Policy => 'MySignerPolicy',
    Debug_Canonicalization => $debugfh
  );
 
  if ($binary)
  {
    binmode STDIN;
  }
 
  while (<STDIN>)
  {
    $mailbuf .= $_;
    unless ($binary)
    {
      chomp $_;
      s/\015?$/\015\012/s;
    }
    $dkim->PRINT($_);
  }
  $dkim->CLOSE();
};
qexit_deferral('Error while signing: ', $@)
  if ($@);
 
# close debug file
close($debugfh)
  if (defined($debugfh));
 
# execute qmail-remote
unshift(@ARGV, $qremote);
open(QR, '|-') || exec { $ARGV[0] } @ARGV
  or qexit_deferral('Unable to run qmail-remote: ', $!);
foreach my $dkim_signature ($dkim->signatures)
{
  my $sig = $dkim_signature->as_string;
  $sig =~ s/\015\012\t/\012\t/g;
  print QR $sig."\012";
}
print QR $mailbuf;
close(QR);
 
#-------------------------------------------------------------------------------
 
sub qexit
{
  print @_, "\0";
  exit(0);
}
 
sub qexit_deferral
{
  return qexit('Z', @_);
}
 
sub qexit_failure
{
  return qexit('D', @_);
}
 
sub qexit_success
{
  return qexit('K', @_);
}
 
#-------------------------------------------------------------------------------
 
package ConfigMerge;
 
# merge config hashes. arrays and scalars will be copied.
sub merge
{
  my ($left, $right) = @_;
  foreach my $rkey (keys(%$right))
  {
    my $rtype = ref($right->{$rkey}) eq 'HASH' ? 'HASH'
              : ref($right->{$rkey}) eq 'ARRAY' ? 'ARRAY'
              : defined($right->{$rkey}) ? 'SCALAR'
              : '';
    my $ltype = ref($left->{$rkey}) eq 'HASH' ? 'HASH'
              : ref($left->{$rkey}) eq 'ARRAY' ? 'ARRAY'
              : defined($left->{$rkey}) ? 'SCALAR'
              : '';
    if ($rtype ne 'HASH' || $ltype ne 'HASH')
    {
      $left->{$rkey} = $right->{$rkey};
    }
    else
    {
      merge($left->{$rkey}, $right->{$rkey});
    }
  }
  return;
}
 
#-------------------------------------------------------------------------------
 
package MySignerPolicy;
use Mail::DKIM::SignerPolicy;
use base 'Mail::DKIM::SignerPolicy';
use Mail::DKIM::Signature;
use Mail::DKIM::DkSignature;
use Carp;
use strict;
use warnings;
 
sub apply
{
  my ($self, $signer) = @_;
  my $domain = undef;
  $domain = lc($signer->message_sender->host)
    if (defined($signer) && defined($signer->message_sender)
      && defined($signer->message_sender->host));
  my $sender = $domain;
 
  # merge configs
  while($domain)
  {
    if (defined($config->{$domain}))
    {
      $config->{'global'}->{'types'} = undef;
      ConfigMerge::merge($config->{'global'}, $config->{$domain});
      last;
    }
    (undef, $domain) = split(/\./, $domain, 2);
  }
 
  my $conf = $config->{'global'};
  return 0
    if (!defined($conf->{'types'}) || defined($conf->{'types'}->{'none'}));
 
  # set key file
  $signer->key_file($conf->{'keyfile'});
 
  # parse (signature) domain
  if (!defined($conf->{'domain'}) || $conf->{'domain'} eq 'sender')
  {
    return 0
      if (!defined($sender));
 
    $conf->{'domain'} = undef;
    open(FH, '<', $rcpthosts)
      or croak('Unable to open rcpthosts: '.$!);
    while (my $row = <FH>)
    {
      chomp($row);
      if ($row eq $sender)
      {
        $conf->{'domain'} = $sender;
        last;
      }
    }
    close(FH);
    return 0
      if (!defined($conf->{'domain'}));
  }
  elsif (substr($conf->{'domain'}, 0, 1) eq '/')
  {
    open(FH, '<', $conf->{'domain'})
      or croak('Unable to open domain-file: '.$!);
    my $newdom = (split(/ /, <FH>))[0];
    close(FH);
    croak("Unable to read domain-file. Maybe empty file.")
      if (!$newdom);
    chomp($newdom);
    $conf->{'domain'} = $newdom;
  }
 
  # generate signatures
  my $sigdone = 0;
  foreach my $type (keys(%{$conf->{'types'}}))
  {
    my $sigconf = $conf->{'types'}->{$type};
 
    if ($type eq 'dkim')
    {
      $signer->add_signature(
        new Mail::DKIM::Signature(
          Algorithm  => $sigconf->{'algorithm'}  || $conf->{'algorithm'} || $signer->algorithm,
          Method     => $sigconf->{'method'}     || $conf->{'method'}    || $signer->method,
          Headers    => $sigconf->{'headers'}    || $conf->{'headers'}   || $signer->headers,
          Domain     => $sigconf->{'domain'}     || $conf->{'domain'}    || $signer->domain,
          Selector   => $sigconf->{'selector'}   || $conf->{'selector'}  || $signer->selector,
          Query      => $sigconf->{'query'}      || $conf->{'query'},
          Identity   => $sigconf->{'identity'}   || $conf->{'identity'},
          Expiration => $sigconf->{'expiration'} || $conf->{'expiration'}
        )
      );
      $sigdone = 1;
    }
    elsif ($type eq 'domainkey')
    {
      $signer->add_signature(
        new Mail::DKIM::DkSignature(
          Algorithm  => 'rsa-sha1', # only rsa-sha1 supported
          Method     => $sigconf->{'method'}   || $conf->{'method'}   || $signer->method,
          Headers    => $sigconf->{'selector'} || $conf->{'headers'}  || $signer->headers,
          Domain     => $sigconf->{'domain'}   || $conf->{'domain'}   || $signer->domain,
          Selector   => $sigconf->{'selector'} || $conf->{'selector'} || $signer->selector,
          Query      => $sigconf->{'query'}    || $conf->{'query'}
        )
      );
      $sigdone = 1;
    }
  }
 
  return $sigdone;
}
