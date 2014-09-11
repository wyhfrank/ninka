#!/usr/bin/env perl
#
#***************************************************************************************************
#       SENTENCE SPLITTER
# Author:   Paul Clough     {cloughie@dcs.shef.ac.uk}
#

#    This program is originally based on the sentence splitter program
#    published by Paul Clough. Version 1.0, available from
#    http://ir.shef.ac.uk/cloughie/software.html (splitter.zip)
#    The original program is without a license.
#
#    It was mostly rewritten.
#    His ideas, however, linger in here (and his file of abbreviations)
#
#    Modifications to the original by Daniel M German and Y. Manabe,
#    which are under the following license:
#
#    This patch is free software; you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as
#    published by the Free Software Foundation, either version 3 of the
#    License, or (at your option) any later version.
#
#    This patch is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this patch.  If not, see <http://www.gnu.org/licenses/>.
#

#
# splitter.pl
#
# This script breaks comments into sentences.
#

use strict;
use warnings;
use Getopt::Std;

my $INPUT_FILE_EXTENSION = 'comments';

# parse cmdline parameters
if (!getopts('') || scalar(@ARGV) == 0 || $ARGV[0] !~ /\.$INPUT_FILE_EXTENSION$/) {
    print STDERR "Usage $0 <filename>.$INPUT_FILE_EXTENSION\n";
    exit 1;
}

my $path = get_my_path($0);

my $input_file = $ARGV[0];
my $abbreviations_file = "$path/splitter.abv";

my $output_file = $input_file; $output_file =~ s/\.$INPUT_FILE_EXTENSION$/\.sentences/;

my $text = read_file_as_string($input_file);
my %abbreviations = load_abbreviations($abbreviations_file);

open my $output_fh, '>', $output_file or die "can't create output file [$output_file]: $!";

# append a newline just in case
$text .= "\n";

# - is used to create lines
# = is used to create lines
$text =~ s@\+?\-{3,1000}\+?@ @gmx;
$text =~ s@={3,1000}@ @gmx;
$text =~ s@:{3,1000}@ @gmx;
$text =~ s@\*{3,1000}@ @gmx;

# some characters are used for pretty-printing but never appear in sentences
$text =~ s@\|+@ @gmx;
$text =~ s@\\+@ @gmx;

# let us deal with /* before we do anything
$text =~ s@^[ \t]*/\*@@gmx;
$text =~ s/\*\/[ \t]*$//gmx;
$text =~ s@([^:])// @$1@gmx;

# replace /\r\n/ with \n only
$text =~ s/\r\n/\n/g;

# now, try to replace the leading/ending character of each line #/-, at most 3 heading characters
# and each repeated as many times as necessaary
$text =~ s/^[ \t]{0,3}[\*\#\/\;]+//gmx;
$text =~ s/^[ \t]{0,3}[\-]+//gmx;

$text =~ s/[\*\#\/]+[ \t]{0,3}$//gmx;
$text =~ s/[\-]+[ \t]{0,3}$//gmx;

# now, try to replace the ending character of each line if it is * or #
$text =~ s/[\*\#]+//gmx;

# at this point we have lines with nothing but spaces, let us get rid of them
$text =~ s/^[ \t]+$/\n/gm;

# let us try the following trick
# we first get rid of \t and replace it with ' '
# we then use \t as a "single line separator" and \n as multiple line
# so we can match each with a single character
$text =~ tr/\t/ /;

$text =~ s/\n(?!\n)/\t/g;
$text =~ s/\n\n+/\n/g;
$text .= "\n";

# this gets us in big trouble... licenses that have numeric abbreviations
$text =~ s/v\.\s+2\.0/v<dot> 2<dot>0/g;

while ($text =~ /^([^\n]*)\n/gsm) {
    my $curr = $1;

    # let us count the number of alphabetic chars to check if we are skipping anything we should not
    my $count1 = 0;
    for my $i (0..length($curr)-1) {
        my $c = substr($curr, $i, 1);
        $count1++ if ($c ge 'A' && $c le 'z');
    }

    my @sentences = split_text($curr);

    my $count2 = 0;
    foreach my $sentence (@sentences) {
        for my $i (0..length($sentence)-1) {
            my $c = substr($sentence, $i, 1);
            $count2++ if ($c ge 'A' && $c le 'z');
        }
        my $clean_sentence = clean_sentence($sentence);
        next unless $clean_sentence;
        print $output_fh "$clean_sentence\n";
    }

    if ($count1 != $count2) {
        print STDERR "number of printable chars does not match for [$curr]: [$count1] vs. [$count2]\n";
        foreach my $sentence (@sentences) {
            my $clean_sentence = clean_sentence($sentence);
            print STDERR "cleaned sentence [$clean_sentence]\n";
        }
        exit 1;
    }
}
close $output_fh;

exit 0;

sub get_my_path {
    my ($self) = @_;
    my $path = $self;
    $path =~ s/\/+[^\/]+$//;
    if ($path eq '') {
        $path = './';
    }
    return $path;
}

sub clean_sentence {
    ($_) = @_;

    # check for trailing bullets of different types
    s/^o //;
    s/^\s*[0-9]{1-2}+\s*[\-\)]//;
    s/^[ \t]+//;
    s/[ \t]+$//;

    # remove a trailing -
    s/^[ \t]*[\-\.\s*] +//;

    s/\s+/ /g;

    s/['"`]+/<quotes>/g;

    s/:/<colon>/g;

    s/\.+$/./;

    die if /\n/m;

    return $_;
}

sub split_text {
    my ($text) = @_;
    my $length = 0;
    my $next_word;
    my $last_word;
    my $stuff_after_period;
    my $puctuation;
    my @result;
    my $after;
    my $current_sentence = '';
    # this breaks the sentence into
    # 1. any text before a separator
    # 2. the separator [.!?:\n]
    # 3.
    while ($text =~ /^
                     ([^\.\!\?\:\n]*) #
                     ([\.\!\?\:\n])
                     (?=(.?))
                   /xsm) { #/(?:(?=([([{\"\'`)}\]<]*[ ]+)[([{\"\'`)}\] ]*([A-Z0-9][a-z]*))|(?=([()\"\'`)}\<\] ]+)\s))/sm) {
        $text = $';
        my $sentence_match = $1;
        my $sentence = $1 . $2;
        my $punctuation = $2;
        $after = $3;

        # if next character is not a space, then we are not in a sentence"
        if ($after ne ' ' && $after ne "\t") {
            $current_sentence .= $sentence;
            next;
        }
        # at this point we know that there is a space after
        if ($punctuation eq ':' || $punctuation eq '?' || $punctuation eq '!') {
            # let us consider this right here a beginning of a sentence
            push @result, $current_sentence . $sentence;
            $current_sentence = '';
            next;
        }
        if ($punctuation eq '.') {
            # we have a bunch of alternatives
            # for the time being just consider a new sentence

            # TODO
            # simple heuristic... let us check that the next words are not the beginning of a sentence
            # in our library
            # END TODO

            # is the last word an abbreviation? For this the period has to follow the word
            # this expression might have to be updated to take care of special characters  in names :(
            if ($sentence_match =~ /(.?)([^[:punct:]\s]+)$/) {
                my $before = $1;
                my $last_word = $2;
                #is it an abbreviation

                if (length($last_word) == 1) {
                    # single character abbreviations are special...
                    # we will assume they never split the sentence if they are capitalized.
                    if ($last_word ge 'A' && $last_word le 'Z') {
                        $current_sentence .= $sentence;
                        next;
                    }
                    print "last word an abbrev $sentence_match lastword [$last_word] before [$before]\n";

                    # but some are lowercase!
                    if ($last_word eq 'e' || $last_word eq 'i') {
                        $current_sentence .= $sentence;
                        next;
                    }
                    print "2 last word an abbrev $sentence_match lastword [$last_word] before [$before]\n";
                } else {
                    $last_word = lc $last_word;

                    # only accept abbreviations if the previous char to the abbrev is space or
                    # is empty (beginning of line). This avoids things like .c
                    if (length($before) > 0 && $before eq ' ' && $abbreviations{$last_word}) {
                        $current_sentence .= $sentence;
                        next;
                    } else {
                        # just keep going, we handle this case below
                    }
                }
            }

            push @result, $current_sentence . $sentence;
            $current_sentence = '';
            next;
        }
        die 'We have not dealt with this case';
    }
    push @result, $current_sentence . $text;

    return @result;
}

sub read_file_as_string {
    my $file = shift;

    open my $fh, '<', $file or die "can't open file '$file': $!";
    my $content = do { local $/; <$fh> };
    close $fh or die "can't close file '$file': $!";

    return $content;
}

sub load_abbreviations {
    my ($file) = @_;
    my %abbreviations = ();

    open my $fh, '<', $file or die "can't open file [$file]: $!";

    while (my $line = <$fh>) {
        chomp $line;
        $abbreviations{$line} = $line;
    }

    close $fh;

    return %abbreviations;
}

