#!/usr/bin/perl

use HTML::TableExtract;
use WWW::Mechanize;

use HTML::Strip;
use Date::Format;
use Data::Dumper;

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

my $url = "http://www.supermicro.nl/support/bios/";
my @tableheaders = qw ( Model Name Type Rev "ZIP File" Description );

my $agent = WWW::Mechanize->new();
$agent->get($url);

print join(',', @tableheaders), "\n";

$te = new HTML::TableExtract( keep_html => 1, attribs => { id => 'ctl00_ctl00_ContentPlaceHolderMain_ContentPlaceHolderSupportMiddle_GridView1' } );
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
     $BIOS  = trim($hs->parse( @$row[1]));
     $Type  = trim($hs->parse( @$row[2]));
     $Rev   = trim($hs->parse( @$row[3]));
     $Rev   =~ s/\ /_/;
     ($ZipLink, $ZipText) = @$row[4] =~ /(ID=\d+)\".*\"\>(.*)\<\/font\>/;
     next unless "$ZipLink" =~ /ID=/;
     $BIOSPath = "$Model/$Type/$Rev/$ZipText";
     if (! -e $BIOSPath) {
       mkdir "$Model";
       mkdir "$Model/$Type";
       mkdir "$Model/$Type/$Rev";
       open CL, '>>', "$Model/ChangeLog";
       open CL2, '>>', "ChangeLog";
       $Logline = time2str("%Y-%m-%d %H:%M:%S", time). " \"$Model/$Type/$Rev/$ZipText\"\n";
       print CL $Logline;
       print CL2 $Logline;
       print $Logline;
       $BIOSURI = "http://www.supermicro.nl/support/resources/getfile.aspx?$ZipLink";
       $agent->get( $BIOSURI, ':content_file' => $BIOSPath );
       if ($Type eq "BIOS") { 
         system("../mkbiosimg.sh", "Firmware/$BIOSPath");
       }
     }
   }
}

chdir ".."; 

system("./mkpxe.cfg.sh");
