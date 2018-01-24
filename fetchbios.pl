#!/usr/bin/perl

use HTML::TableExtract;
use WWW::Mechanize;

use HTML::Strip;
use Date::Format;
use Data::Dumper;

my $o_debug = 1;


sub trim($)
{
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

sub start { 
  my ($self, $tagname, $attr, $attrseq, $origtext) = @_;
  if ($tagname eq 'a') {
  print "URL found: ", $attr->{ href }, "\n";
  }
}

chdir "Firmware" or die "Cannot chdir(\"Firmware\"): $!";

my $hs = HTML::Strip->new();

#my $url = "http://www.supermicro.nl/support/bios/";
my $url = "https://www.supermicro.com/support/resources/bios_ipmi.php?vendor=1";
# my @tableheaders = qw ( Model Name Type Rev "ZIP File" Description );
my @tableheaders = qw ( Model Rev "Download Zip" "Release Notes" "Part#" Description Name);

my $agent = WWW::Mechanize->new();
$agent->get($url);


print join(',', @tableheaders), "\n";

# $te = new HTML::TableExtract( keep_html => 1, attribs => { id => 'ctl00_ctl00_ContentPlaceHolderMain_ContentPlaceHolderSupportMiddle_GridView1' } );
$te = new HTML::TableExtract( keep_html => 1, attribs => { class => 'biosipmiTable' } );


$te->parse( $agent->content() );

foreach $ts ($te->table_states) {
   foreach $row ($ts->rows) {
     @Models = 
       sort(
         grep(!/[^\w\s-+]/, 
           split(/\ /, 
             trim(
               $hs->parse(@$row[0])
             )
           )
         )
       );

	
     $Model = join('_', @Models);
     $BIOS  = trim($hs->parse( @$row[6])); # Name field
     $Type  = trim($hs->parse( @$row[5]));
     $Rev   = trim($hs->parse( @$row[1]));
     $Rev   =~ s/\ /_/;
     ($ZipLink, $ZipText) = @$row[2] =~ /(SoftwareItemID=\d+)\".*\"\>(.*)\<\/a\>/;

     if( $Type eq "BIOS"  && $o_debug == 1 )
     {
    	printf "DEBUG: Model %10s / TYPE %10s / REV %10s / ZIP-ID %15s / File %15s\n", $Model, $Type, $Rev, $ZipLink, $ZipText;
     }

     next unless "$ZipLink" =~ /SoftwareItemID=/;
     $BIOSPath = "$BIOS/$Type/$Rev/$ZipText";


     if (! -e $BIOSPath) {
       mkdir "$BIOS"; # was $Model
       mkdir "$BIOS/$Type";
       mkdir "$BIOS/$Type/$Rev";
       open CL, '>>', "$BIOS/ChangeLog";
       open CL2, '>>', "ChangeLog";
       $Logline = time2str("%Y-%m-%d %H:%M:%S", time) . ": $BIOS/$Type/$Rev/$ZipText\n";
       print CL $Logline;
       print CL2 $Logline;
       print $Logline;
       $BIOSURI = "http://www.supermicro.nl/support/resources/getfile.aspx?$ZipLink";
       $agent->get( $BIOSURI, ':content_file' => $BIOSPath );
       if ($Type eq "BIOS") { 
         system("../mkbiosimg.sh", "Firmware/$BIOSPath");
       }
     } else {
	print "[!] File already exists: $BIOSPath\n";
     }
   }
}

chdir ".."; 

system("./mkpxecfg.sh");
