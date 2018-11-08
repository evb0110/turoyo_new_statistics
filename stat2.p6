#!/usr/bin/perl6

my %easywords =
     šuġl  => <šuġl>.any,
     šuġlayḏ  => <šuġlayḏ>.any,
     ;


my Regex %words =
     šuġl  => / << šuġl [e|a|ux|ax|i|ayye|ayxu|an] >>  /,
     šuġlayḏ  => / << šuġlayḏ  /,
     ;

my Regex $tobold ;          # assigned in BEGIN block
my Regex $tobold_contexts;  # assigned in BEGIN block

my constant $color_switch = 1;
use Colorize;

my constant $corpora_dir =
    '/home/evb/MAILRU/Linguae/Turoyo/National_corpus';
my $current_dir = $*CWD;

my @dirs;            # directories of corpora
my Array
    %corpus_files;   # @filenames for each corpus
my Array %text;      # file contents for every file
my %village_name;    # corpfile => village_name
my %speaker_name;    # corpfile => speaker_name
my %file_words;      # wordcount for each file
my %speaker_words;   # wordcount for each speaker
my %village_words;   # wordcount for each speaker
my %village_speaker; # list of speakers for every village

sub mapper_speaker($file) {
    return ~ ($file ~~ / \S + '_' <[\S]-[.]> + /);
}

multi sub mapper_village($speaker where $speaker.contains: (0..9).none) {
    return $speaker.split('_', 2)[1];
}

multi sub mapper_village($file where defined $file ~~ / \.txt $ /) {
    my $speaker = mapper_speaker($file);
    return mapper_village($speaker);
}

print "Reading and processing the corpus... ";
chdir $corpora_dir;
@dirs = dir.sort.grep: not *.starts-with('.');
@dirs = @dirs.grep: *.d;

for @dirs -> $dir {
    my $corpus = $dir.substr(0,2).uc; # siglum
    chdir $dir;
    NEXT { chdir $*CWD.parent; }
    my @filenames = dir.sort>>.Str.grep: *.ends-with('.txt');
    %corpus_files{$corpus} = @filenames;
    for @filenames -> $file {
        my $text = $file.IO.slurp;
        my @lines = $text.lc.lines;
        my $village = mapper_village($file) ~ '_' ~ $corpus;
        my $speaker = mapper_speaker($file) ~ '_' ~ $corpus;
        my $corpfile = $corpus ~ $file;
        %text{$corpfile} = @lines;
        %village_name{$corpfile} = $village;
        %speaker_name{$corpfile} = $speaker;
    }
}

chdir $*CWD.parent;

for %corpus_files.kv -> $corpus, @files {
    for @files -> $file {
        my $corpfile = $corpus ~ $file;
        my $village = %village_name{$corpfile};
        my $speaker = %speaker_name{$corpfile};
        my @text = @( %text{$corpfile} );
        my $size =  @text.words.elems - @text.elems;
        %village_words{$village} += $size;
        %speaker_words{$speaker} += $size;
    }
}

say "Done!";
chdir $current_dir;

say "Begin matching...";

%village_speaker = classify &mapper_village, %speaker_words.keys;

for %words.kv -> $word, $reg_word { # BEGIN WORDS LOOP
  my $easyword = %easywords{$word};
  printf "- %-15s", "word: $word; ";
  printf " %-15s", "easyword: {$easyword.gist}... ";

  my Int %speaker_matches;
  my Int %village_matches;
  my Int $total_matches;
  my Str @output;
  my Str @output_stat;

  for %corpus_files.kv -> $corpus, @filenames {
    for @filenames -> $file {
      my $number = ~ ( $file ~~ / \d + / );
      my $corpfile = $corpus ~ $file;
      my $village = %village_name{$corpfile};
      my $speaker = %speaker_name{$corpfile};
      my @lines := %text{$corpfile};
      for @lines -> $line {
        next unless $line.contains($easyword);
        my $n_matches =
           +($line ~~ m:g/ $reg_word /);
        next unless $n_matches > 0;
        %speaker_matches{$speaker} += $n_matches;
        %village_matches{$village} += $n_matches;
        $total_matches             += $n_matches;
        push @output,
          join '',
          "---\n",
          "corpus: $corpus; ",
          "village: $village; ",
          "speaker: $speaker",
          ;
        push @output,
          "$number: $line";
      }
    }
  }

  my $outfile =
     $color_switch
        ?? "$word.color"
        !! "$word.txt"
     ;
  my $fh = open $outfile, :w;

  push @output_stat, "WORD: $word";
  push @output_stat, "REGEX: {$reg_word.gist}";
  push @output_stat, "easyword: {$easyword.gist}";
  push @output_stat, '';
  push @output_stat, "TOTAL: $total_matches times in corpus";
  push @output_stat, '';
  push @output_stat, '---------';
  push @output_stat, "STATISTICS BY VILLAGES AND SPEAKERS";
  push @output_stat, '---';

  for %village_speaker.keys.sort -> $village {
    my @speakers = %village_speaker{$village}<>.sort;
    my $village_words = %village_words{$village} // 0;
    my $village_matches = %village_matches{$village} // 0;
    my $report_vfreq = '';
    if $village_matches > 0 {
      my $vfreq = $village_words div $village_matches;
      $report_vfreq = ": every $vfreq words";
    }
    push @output_stat, join '',
                      "$village: ",
                      "$village_matches ",
                      "from $village_words ",
                      "words$report_vfreq";
    for @speakers -> $speaker {
      my $speaker_words = %speaker_words{$speaker} // 0;
      my $speaker_matches = %speaker_matches{$speaker} // 0;
      my $report_sfreq = '';
      if $speaker_matches > 0 {
        my $sfreq = $speaker_words div $speaker_matches;
        $report_sfreq = ": every $sfreq words";
      }
      push @output_stat, "- $speaker: $speaker_matches from $speaker_words words$report_sfreq";
    }
  }

  push @output_stat, "---------\n\n";
  push @output_stat, "CONTEXTS";

  if $color_switch {
    my $reg_word_with_end = / $reg_word \S * /;
    for @output <-> $line {
      color( / <-[_]> <( <:Lu> ** 2 )> <-[_]>  /,
                              $normal, $filled, $blue, $line);
      color( $reg_word_with_end, $bold, $filled, $red, $line);
      color( / \S * '_' \S * /, $normal, $filled, $blue, $line);
      color( $tobold_contexts, $bold, $filled, $black, $line);

    }
    for @output_stat <-> $line {
      color( $tobold, $bold, $filled, $black, $line);
      color( $reg_word_with_end, $bold, $filled, $red, $line);
    }

  }


  { # BEGIN $*OUT TO FILE
    my $*OUT = $fh;
    .say for @output_stat;
    .say for @output;
    $*OUT.flush;
  } # END $*OUT TO FILE
  say "Done!";



} # END WORDS LOOP



# START CONVERTING TO HTM AND DOCX
if $color_switch {
  print "Converting to pdf... ";
  for dir(test => /:i '.' color $/) {
    (my $base = $_)
         ~~ s/ \.color //
         ;
    shell "cat $_ | aha | sed '1,3d' > $base.htm";
    shell "lowriter --convert-to  pdf $base.htm";
#    shell "lowriter --convert-to docx $base.htm";
    "$base.htm".IO.unlink;
    .unlink;
  }
  say "Done!";
}
# END CONVERTING TO HTM AND DOCX





BEGIN {

$tobold = /
        [
         | WORD
         | REGEX
         | TOTAL
         | STAT \N *
         | CONTEXTS
        ]
          \S *
         | ^ \S + '_' [ <-[_:]> * ]
         | \d
      /;

$tobold_contexts = /
        [
         | corpus
         | village
         | speaker
        ]
      /;

}
