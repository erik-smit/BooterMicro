#!/usr/bin/perl -W
#
#

use HTML::TableExtract;
use WWW::Mechanize;

use HTML::Strip;
use Date::Format;
use Data::Dumper;
use Getopt::Std;
my  %opt;
getopts('df:hv',\%opt);

# CONF: Options available to configure.
#       Sometimes this URL changes as well as the table structure.
my $url = "https://www.supermicro.com/support/resources/bios_ipmi.php?vendor=1";
no warnings qw{qw uninitialized}; 
my @tableheaders = qw ( Model Rev "Download Zip" "Release Notes" "Part#" Description Name);


# ---
my $o_filter	= $opt{'f'} || 0;
my $o_debug	= $opt{'d'} || 0;
my $o_verbose	= $opt{'v'} || 0;
my $o_help	= $opt{'h'} || 0;


if( $o_help )
{
	print "$0 [-dvh] [-f <bios name>]\n";
	exit(0);

}


# -----------------------------------------------------------------------------
# SUB: Subroutines to assist in different aspects of the code
#
#
my %logLevel    = (
	'ERROR'		=> 1,
	'WARN'		=> 2,
	'INFO'		=> 3,
	'VERBOSE'	=> 4,
	'DEBUG'		=> 5
);

sub Log
{
	my( $level, @msg ) = @_;
	my $tag         = undef;
	$level          = $logLevel{$level};
	# Error = 1, Warn = 2, Info = 3, Verbose = 4, Debug = 5
	SWITCH: {
	 if( $level == 1 )      { $tag = "!";   last SWITCH; }
	 if( $level == 2 )      { $tag = "*";   last SWITCH; }
	 if( $level == 3 )      { $tag = "-";   last SWITCH; }
	 if( $level == 4 )      { $tag = " ";   last SWITCH; }
	 if( $level == 5 )      { $tag = "D";   last SWITCH; }
	}

	if( $level == 1 || $level == 2 )
	{
		 printf STDOUT ( " %s %s\n", $tag, join( '', @msg ) );
	}
	if( ($o_verbose == 1 || $o_debug == 1) && ($level == 3 || $level == 4) )
	{
		printf STDOUT ( " %s %s\n", $tag, join( '', @msg ) );
	}
	if( $o_debug == 1 && $level == 5 )
	{
		printf STDOUT ( " %s %s\n", $tag, join( '', @msg ) );
	}

	return undef;
}


sub trim($)
{
	my $string =  shift;
	   $string =~ s/^\s+//;
	   $string =~ s/\s+$//;
	return $string;
}

# ---------------------------------------------------------------------


chdir "Firmware" or die "Cannot chdir(\"Firmware\"): $!";
Log(INFO,"BIOS: Looking only for items which match $o_filter") if( $o_filter );

my $hs = HTML::Strip->new();

Log(VERBOSE,"Attemping to connect to $url");
my $agent = WWW::Mechanize->new();
$agent->get($url);

if( $agent->status() != 200 ) # HTTP code 200, page OK
{
	Log(ERROR, "Cannot access URL $url");
	exit(1);
}


Log(DEBUG,"HTML TableExtracting on class biosipmiTable");
Log(DEBUG,"HTML Table headers to match: " . join(',', @tableheaders));
my $te = new HTML::TableExtract(
	keep_headers	=> 0,
	keep_html	=> 1,
	attribs		=> {
				class => 'biosipmiTable'
			   }
   );

Log(DEBUG,"HTML: Parse content");
$te->parse( $agent->content() );


Log(DEBUG,"HTML: Table states - loop");
my $i = 0;

foreach $ts ($te->tables)
{
    foreach $row ($ts->rows)
    {
	$i++;

	# PROG: Parse through items in the table
	#       [0] Model
	#       [1] Revision of BIOS
	#       [2] Download ZIP file name
	#       [3] Release Notes
	#       [4] Part #
	#       [5] Description of item
	#       [6] Name of Motherboard
	#if( $i == 5 ) { exit (); }

	#Log(DEBUG, "DEBUG ROW RAW   => @{$row}");
	my @Models	= split(/\s+/, trim($hs->parse( @$row[0]) ));
			# i^-- split required due to non-whitespace parse from cpan module
	my $Model	= join("_", @Models); 		# C9X299-PGF_C9X299-RPGF
	my $Rev	= trim($hs->parse( @$row[1]) );		# R_1.2a
   	   $Rev	=~ s/\ /_/;

	my $ZipText	= trim($hs->parse( @$row[2]) );	# C7Q2708_329.zip
	my $Type	= trim($hs->parse( @$row[5]) );	# BIOS#
	my $BIOS	= trim($hs->parse( @$row[6]) );	# C9X299-PGF/RPGF
	my ($ZipLink)	= @$row[2] =~ /(SoftwareItemID=\d+)\".*\"\>(.*)\<\/a\>/;
	   $ZipLink	= 0 if( not $ZipLink );

	if( $o_filter )
	{
		next if( $Model !~ /$o_filter/ );
	}

	Log(DEBUG, "PARSE => Model  : $Model / Rev: $Rev ");
	Log(DEBUG, "         Type   : $Type / BIOS: $BIOS");
	Log(DEBUG, "         ZipLink: $ZipLink / ZipText: $ZipText");
	Log(DEBUG, "--");
	Log(DEBUG, "--");

	# PROG: If the type isn't BIOS then skip the entry move to next.
	next unless ( $Type eq "BIOS" );
	Log(DEBUG, "DEBUG ROW PARSE => $Model / $Rev / $ZipLink / $ZipText / $Type / $BIOS");

	# PROG: If the ZipLink isn't a valid softwareItemId then skip it as well.
	next unless ( "$ZipLink" =~ /SoftwareItemID=/ );

	# PROG: 
	my $BIOSPath = "$Model/$Type/$Rev/$ZipText";

	if( ! -e $BIOSPath )
	{
		Log(INFO,"BIOS: Creating path $BIOSPath");
		mkdir("$Model", 0755);
		mkdir("$Model/$Type", 0755);
		mkdir("$Model/$Type/$Rev", 0755);

		open CL,  '>>', "$Model/ChangeLog";
		open CL2, '>>', "ChangeLog";
		$Logline = time2str("%Y-%m-%d %H:%M:%S", time) . ": $Model/$Type/$Rev/$ZipText\n";
		print CL $Logline;
		print CL2 $Logline;
		# print $Logline;

		$BIOSURI = "http://www.supermicro.com/support/resources/getfile.php?$ZipLink";

		Log(VERBOSE, "FILE: Downloading $BIOS -> $ZipText");
		$agent->get( $BIOSURI, ':content_file' => $BIOSPath );

		if( $agent->status() != 200 )
		{
			Log(WARN,"WARN: Can't download $ZipLink / $ZipText, HTTP error: " . $agent->status());
			exit;
		} else {
			Log(INFO,"FILE: Complete, size(bytes) " . -s $BIOSPath );
			if( -s $BIOSPath < 4194304 )
			{
				Log(ERROR,"FILE: Size is less than 4 MBytes");
			}
		}

		# PROG: Build BIOS Image
		Log(INFO,"BIOS: Building BIOS --> Firmware/$BIOSPath");
		system("../mkbiosimg.sh", "Firmware/$BIOSPath");
	} else {
		Log(ERROR, "File already exists: $BIOSPath");
	}

   } # foreach: ts->row
} # foreach: te->table
exit;

chdir ".."; 

system("./mkpxecfg.sh");
