#!/usr/bin/perl -w
use strict;

my $DEBUG = 0;

my $prefix = 'oscon2006';

my( @infiles ) = glob("$prefix-*.dv");

chomp(@infiles);

foreach my $infile( @infiles) {

    $infile =~ /$prefix-(.*?)\.dv/;
    my( $datetime ) = $1;

    print("infile: $infile$/");
    print("datetime: $datetime$/");

    my( $mkv_file, $mp4_file ) =
      ("$prefix-${datetime}.mkv",
       "$prefix-${datetime}.mp4" );

    if( -f $mp4_file ){
      print("mp4 file exists.  next.$/");
      next;
    }

    # Store dv data in mkv container
    print("Converting DV [$infile] to mkv [${mkv_file}]$/");
    my $cmd = qq{ffmpeg -threads 4 -i ${infile} -c:v copy -c:a copy ./${mkv_file}};
    $cmd .= ' 2>&1 > /dev/null' unless $DEBUG;
    print( scalar( localtime ), $/);
    my $output = qx($cmd);
    print( scalar( localtime ), $/);

    print("Converting mkv to mp4$/");

    # Thanks go to the #ffmpeg freenode channel for the following
    $cmd = 'ffmpeg'.
      ' -threads   4'.
      " -i         ${mkv_file}".
      ' -vf        yadif=0:-1'.
      ' -pix_fmt   yuv420p'.
      ' -vcodec    libx264'.
      ' -preset    slow'.
      ' -profile:v high'.
      ' -level     4.1'.
      ' -r         30000/1001'.
      ' -crf       21'.
      ' -x264opts  force-cfr=1'.
      ' -acodec    aac '.
      ${mp4_file};
    $cmd .= ' 2>&1 > /dev/null' unless $DEBUG;
    print("Converting mkv [${mkv_file}] to mp4 [${mp4_file}]$/");
    print( scalar( localtime ), $/);
    $output = qx($cmd);
    print( scalar( localtime ), $/);

    print("Removing mkv file$/");

    $output = qx(rm ${mkv_file});
}
