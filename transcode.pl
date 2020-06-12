#!/usr/bin/perl -w
use strict;
use DateTime::Duration;
use DateTime::Format::DateParse;
use Data::Dumper;

my $DEBUG = 0;

my $prefix = 'oscon2006';

my( @infiles ) = sort glob("$prefix-*.dv");

chomp(@infiles);

foreach my $infile( @infiles) {
    $infile =~ /$prefix-(.*?)\.dv/;
    my( $datetime ) = $1;
    # 2006.07.26_09-55-14
    my(@date) = split(/[\._-]/, $datetime);
    my $iso_datetime = sprintf('%04i-%02i-%02iT%02i:%02i:%02i', @date);

    my $start_dt = my $dt = DateTime::Format::DateParse->parse_datetime( $iso_datetime );
    print("iso_datetime: $iso_datetime$/") if $DEBUG;

    my( $mkv_file, $mp4_file ) =
      ("$prefix-${datetime}.mkv",
       "$prefix-${datetime}.mp4" );

    my $dv_duration = qx(ffmpeg -i ${infile} 2>&1 | grep "Duration");
    $dv_duration =~ s/^\s+(\S.+?\S)\s+$/$1/;

    # Duration: 00:14:55.46, start: 0.000000, bitrate: 28771 kb/s
    my %dv_duration = map {
      split(': ', $_);
    } split(', ', $dv_duration);

    my @dv_duration = split( /[:\.]/, $dv_duration{Duration} );
    my $dv_dur = DateTime::Duration->new(
                                         hours       => $dv_duration[0],
                                         minutes     => $dv_duration[1],
                                         seconds     => $dv_duration[2],
                                         nanoseconds => $dv_duration[3] * 100000,
                                        );

    my $dv_dt = $start_dt->clone->add_duration($dv_dur);

    my $short_dv = 0;
    if( $dv_dur->hours == 0
        && $dv_dur->minutes == 0
        && $dv_dur->seconds < 10
      ){
      $short_dv = 1;
    }

    my $mp4_path = '';
    if( -f "done/$mp4_file" ){
      $mp4_path = "done/$mp4_file";
    } elsif( "done/short/$mp4_file" ){
      $mp4_path = "done/short/$mp4_file";
    }

    if( -f $mp4_path ){
      print("mp4 file [$mp4_path] exists$/");

      my $mp4_duration = qx(ffmpeg -i ${mp4_path} 2>&1 | grep "Duration");
      $mp4_duration =~ s/^\s+(\S.+?\S)\s+$/$1/;

      print("mp4: [$mp4_duration]$/");
      # Duration: 00:14:55.50, start: 0.000000, bitrate: 2269 kb/s
      my %mp4_duration = map {
        split(': ', $_);
      } split(', ', $mp4_duration);

      my @mp4_duration = split( /[:\.]/, $mp4_duration{Duration} );

      my $mp4_dur = DateTime::Duration->new(
                                            hours       => $mp4_duration[0],
                                            minutes     => $mp4_duration[1],
                                            seconds     => $mp4_duration[2],
                                            nanoseconds => $mp4_duration[3] * 100000,
                                           );

      my $mp4_dt = $start_dt->clone->add_duration($mp4_dur);
      my $stream_delta = abs( $dv_dt->epoch - $mp4_dt->epoch );

      if( $dv_duration{Duration} eq $mp4_duration{Duration} ){
        if ( $mp4_path !~ m{^done/short}
             && $short_dv
           ) {
          print("moving short mp4 to done/short",$/);
          qx(mv $mp4_path done/short);
        }
        next;
      }elsif( $stream_delta < 5 ){
        print("delta between video lengths is $stream_delta seconds.  Next.$/") if $DEBUG;
        if ( $mp4_path !~ m{^done/short}
             && $short_dv
           ) {
          print("moving short mp4 [$mp4_file] to done/short",$/);
          qx(mv $mp4_path done/short);
        }
        next;
      }else{
        print("DV and mp4 data differ.  re-encoding$/") if $DEBUG;
        unlink ${mp4_path};
      }
    }

    print($/,
          "#",$/,
          "# infile: $infile",$/,
          "#",$/,
         );
    print(" dv: [$dv_duration]$/");
    print("    datetime: $datetime$/") if $DEBUG;

    # make the completed directory if it doesn't exist
    qx{mkdir -p done/short };

    # Store dv data in mkv container
    print("Converting DV  [$infile]  to mkv [${mkv_file}] @ ", scalar( localtime ), $/);
    my $cmd = qq{ffmpeg -threads 4 -i ${infile} -c:v copy -c:a copy ./${mkv_file}};
    $cmd .= ' 2>&1 > /dev/null' unless $DEBUG;
    my $output = qx($cmd);
    print("done       DV  [$infile]  to mkv [${mkv_file}] @ ", scalar( localtime ), $/);

    # Thanks go to the #ffmpeg freenode channel for the following
    $cmd = 'ffmpeg'.
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
    print("Converting mkv [${mkv_file}] to mp4 [${mp4_file}] @ ", scalar( localtime ), $/);

    $output = qx($cmd);
    print("done       mkv [${mkv_file}] to mp4 [${mp4_file}] @ ", scalar( localtime ), $/);

    if( $? == 0 ){
      if ( $short_dv ) {
        print("moving short mp4 [$mp4_file] to done/short",$/);
        qx(mv $mp4_file done/short);
      }else{
        print("moving mp4 [$mp4_file] to done/$/") if $DEBUG;
        $output = qx(mv ${mp4_file} done/);
      }

      print("Removing mkv file$/") if $DEBUG;
      $output = qx(rm ${mkv_file});
    }
}
