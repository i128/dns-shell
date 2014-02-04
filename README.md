dns-shell
=========

Shell over DNS protocol

Setup:
Before you can start you must own/register a domain name.  When you register your domain, you must setup an NS record for a subdomain and point it to your server.  For example, if you registered foo.com with godaddy, you must configure a ns record of bar.foo.com and point it to your server's IP.

This repo contains three files.  client.pl, server.pl and server-shell.pl.  The client.pl is deployed to the remote system you wish to have a remote shell on.  Once launched (with the proper --domain=bar.foo.com), it will make TXT dns query back to a domain that you have registered.  It'll utilize the clients DNS server settings and traverse its way out to the greater internet towards your server.

On your server, as root, launch server.pl (optionally with a -d switch for more verbose debugging info).  Once a client joins the server, the client will inform the server what its client id is. (a random number between 1-65535).  To interact with the client, in a new windows, launch server-shell --id=[client_id].

Due to the nature of DNS, there's no true bi-directional communication.  Instead the client.pl will poll the server every 60 seconds by default.  Any command entered in server-shell is queued up in the server.pl in a sqlite db dedicated for each client id and will be sent back to the client the next time it calls home.  Simillarly any responses sent from the client to the server is queued in the sqlite db and polled by the server shell.  The frequency in which the client calls home can be adjusted by the client-shell by using the sleep command.  Type help inside the server-shell prompt for more information or to see a list of available commandss.


=======================
Repo contails 3 files:
client.pl - install on remote system
server.pl - run once on the server
server-shell.pl - run once for each shell that client that successfully calls back to client.pl

=======================
Requirements:
client:

Net::DNS
MIME::Base32
IO::CaptureOutput
Threads;

To install use cpan or ppm
$ cpan install Net-DNS MIME-Base32 IO-CaptureOutput threads
$ ppm install Net-DNS MIME-Base32 IO-CaptureOutput threads

Server & Server-Shell:
Net::DNS::Nameserver
use MIME::Base32
use DBI

To install use cpan or ppm
$ cpan install Net-DNS-Nameserver MIME-Base32 DBI
$ ppm install Net-DNS-Server MIME-Base32 DBI

sqlite3:
$apt-get install sqlite3 on debian/ubuntu/kali, etc.

=========================
To compile for windows (optional)

To compile the client.pl into a window's exe, just install par packer:
$ cpan install Par-Packer
or
$ ppm install Par-Packer

To compile:

$ pp client.pl -o client.exe

=========================
To use: Before you start
To use this application, you must do the following:
1) Register a domain
2) Setup NS pointer to your server that will run server.pl


To Use: client.pl

Client.pl has two switches, one of which is required.  The first (required) switch is --domain=[domain], this is tells the client which domain to query for when calling back to the server. The second switch, which is optional is -d.  It enables debugging to the console and is quite noisy.

To Use: server.pl

server.pl has one optional switch which is -d.  This enables debugging on the console and is quite noisy.

To use: server-shell.pl
server-shell.pl has two switches one of which is required.  The first (required) switch is --id=[client_id], this tells the server-shell which client to attach too.  The second switch, which is optional is -d.  It enables debugging to the console and is quite noisy.

