#!/usr/bin/perl -w

# source: https://sveinbjorn.org/get-album-artwork-id3-using-perl

use File::Basename;
use Getopt::Std;
use MP3::Tag;
use Image::Magick;
use strict;
    
# Settings
my $jpeg_quality                    = 90; # Scale is 1-100
my $resize                          = 0;
my $width                           = 300;
my $verbose                         = 0;
my $destdir                         = undef;

my $opt_string = 'hvrj:d:w:e:';
my %opts;

if (!scalar(@ARGV) or $ARGV[0] eq "-h" or $ARGV[0] eq "--help")
{
    usage();
}

getopts( "$opt_string", \%opts ) or usage();
usage() if $opts{h};

if (!scalar(@ARGV))
{
    usage();
}

if(defined($opts{r})) { $resize = 1;                }
if(defined($opts{j})) { $jpeg_quality = $opts{j};   }
if(defined($opts{w})) { $width = $opts{w};          }
if(defined($opts{d})) { $destdir = $opts{d};        }
if(defined($opts{v})) { $verbose = $opts{v};        }

foreach(@ARGV)
{
    my $filepath = $_;
    
    if (! -e $filepath)
    {
        warn("File does not exist: $filepath\n");
        next;
    }
    
    if (-d $filepath)
    {
        warn("Not a file: $filepath\n");
        next;
    }
    
    if ($filepath !~ /\.mp3$/)
    {
        warn("Not an MP3 file: $filepath\n");
        next;
    }

    my $mp3 = MP3::Tag->new($filepath);

    if (!$mp3)
    {
        warn("Couldn't read tags: $filepath\n");
        next;
    }

    $mp3->get_tags();
    
    # Use this to get standard ID3 info
    my ($title, $track, $artist, $album) = $mp3->autoinfo();
    
    # Get base name and suffix
    my($filename, $directories, $suffix) = fileparse($filepath, ".mp3");
    
    if (!exists($mp3->{ID3v2}))
    {
        warn("No ID3v2: $filepath\n");
        next;
    }
    
    # Read APIC frame
    my $id3v2_tagdata   = $mp3->{ID3v2};
    my $info            = $id3v2_tagdata->get_frame("APIC");
    my $imgdata         = $$info{'_Data'};
    my $mimetype        = $$info{'MIME type'};
    
     $mp3->close();
    
    if (!$imgdata) 
    {
        warn("No artwork data found: $filepath\n");
        next;
    }
    
    # If we're not doing anything with the image, we just write it and return
    if (!$resize)
    {    
        # Create destination path w. img mimetype suffix
        my ($m1, $m2) = split(/\//, $mimetype);
        my $dest = $directories . $filename . ".$m2";
        
        # Write image data to file
        open(ARTWORK, ">$dest") or return("Error writing $dest");
        binmode(ARTWORK);
        print ARTWORK $imgdata;
        close(ARTWORK);
        
        print "Wrote '$dest'\n" if $verbose;
        next;       
    }

    # Load data into ImageMagick object
    my ($image, $x, $ret); 
    $image = Image::Magick->new();
    $x = $image->BlobToImage($imgdata);
    warn $x if $x;
    
    # Resize
    if ($resize)
    {
        $x = $image->Scale($width . "x" . $width);
        warn $x if $x;
    }
    
    my $pdir = $directories;
    if ($destdir)
    {
        $pdir = $destdir;
    }
    
    my $dest = $pdir . "/" . $filename . ".jpg";
    
    # Write image to artwork dir
    $x = $image->Write(         magick => 'jpeg', 
                                filename => $dest,
                                quality => $jpeg_quality
                                );
    warn $x if $x;
    print "Wrote '$dest'\n" if $verbose;
}

exit(0);


sub usage
{
    print "Usage: getArtwork.pl [-r resize [-w width] [-j quality]] [-d directory] file1 file2 ...\n";
    print "Defaults to extracting image to same directory as file\n";
    exit(1);
}
