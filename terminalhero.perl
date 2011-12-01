#!/usr/bin/perl

use strict;
# not in protoduction mode:)
# use warnings;

use POSIX;
use IO::Handle;
use Term::ReadKey;
use Term::TermKey;
use POE;
use POE::Wheel::TermKey;
use Time::HiRes;

########################################################################

# display help
if ($#ARGV >= 0) {
  
  if ($#ARGV > 1) {
    print "To many options. \n"
  }
  else {
    if (($ARGV[0] ne "--help") and ($ARGV[0] ne "-h")) {
      print "Unknown argument " . $ARGV[0] . ".\n";
    }
  }
  
  print "\nTerminal Hero\n";
  print "Linux society's response to Microsoft's Guitar Hero. :)\n\n";
  print "Usage: terminalhero.perl [options]\n\n";
  print "Options:\n";
  print "-h, --help\t\t display this help\n\n";
  print "Shortcuts:\n";
  print "Ctrl+D or Esc\t\t exit\n\n";
  print "Rules:\n";
  print "Press keys with letters which are in the green area.\n";
  print "Your score will increase if you do it well and decrease \n";
  print "if you press wrong key. You can also lose health points \n";
  print "and lifes if the letters turns red. \n\n";
  print "Levels:\n";
  print "You will reach new levels every 64 points.\n";
  print "Each level is a new line, so it is going harder.\n\n";
  print "Now go and play! :)\n\n";
  
  exit;
}

########################################################################

# terminal features (calling tput is slow... don't use it in a loop)
my %esc = (
  "hide_cursor" => `tput civis`,
  "show_cursor" => `tput cnorm`,
  "clear_scr" => `tput ed`,
  "font_white" => `tput setf 7`,
  "font_green" => `tput setf 2`,
  "font_red" => `tput setf 4`,
  "font_black" => `tput setf 0`,
  "reset" => `tput sgr0`,
  "bg_green" => `tput setb 2`,
  "bg_black" => `tput setb 0`,
  "bg_white" => `tput setb 7`,
  "bold" => `tput bold`,
  "line_up" => `tput cuu1`
);

# game levels
my @levels = (
  "n00b", 
  "user", 
  "root", 
  "geek", 
  "hacker", 
  "God", 
  "cheater"
);
  
# lines with letters to shoot
my @lines = ();
my @letters = ('a'..'z');

my $HEALTH = 32;
my $NEXT_LEVEL_POINTS = 64;
my $LIFES = 4;

# we need a framerate and a timestamp, the game should be smooth
my $FRAMERATE = 0.08;
my $timestamp = 0;

# state of the game
my %game_stat = (
  "lifes" => $LIFES,
  "health" => $HEALTH,
  "level" => 0,
  "score" => 0
);

# terminal width
my ($width) = GetTerminalSize();

# range of hit area
my %hit_range = (
  "start" => floor(($width) / 4) - 5,
  "end" => floor(($width) / 4) + 5 
);

# states of letters with their colors
my %sign_states = (
  "normal" => $esc{"font_white"},
  "shooted" => $esc{"font_green"},
  "missed" => $esc{"font_red"}
);

########################################################################

POE::Session->create(
  inline_states => {
     
    _start => sub {
         
      STDOUT->autoflush(1);
      # hide cursor
      print($esc{"hide_cursor"});
      
      $_[KERNEL]->yield("next_life");
      
      $_[HEAP]{termkey} = POE::Wheel::TermKey->new(
        InputEvent => 'keypressed',
      );
      
    },

    # user pressed a key, he want to hit a letter ######################
    keypressed => sub {
      my $key     = $_[ARG0];
      my $termkey = $_[HEAP]{termkey};

      if (('<C-d>' eq $termkey->format_key( $key, FORMAT_VIM ))
           or ('<Escape>' eq $termkey->format_key( $key, FORMAT_VIM ))) {
        print($esc{"reset"});
        # show cursor
        print($esc{"show_cursor"});
        # clear screen
        print($esc{"clear_scr"});
        exit;
        
      } 

      # check if he hit a letter in the green area
      my $test = 0;
      for (my $j=0; $j <= $game_stat{"level"}; $j++) {
        for (my $i=$hit_range{"start"}; $i<$hit_range{"end"}; $i++) {
          if ( $lines[$j][$i]{"character"} 
               eq $termkey->format_key( $key, FORMAT_VIM ) ) {
            if ("normal" eq $lines[$j][$i]{"state"}) {
              $game_stat{"score"}++;
            }
            $lines[$j][$i]{"state"} = "shooted";
            $test = 1;
          }
        }
      }
      
      if ($test == 0
          and $game_stat{"score"} > $NEXT_LEVEL_POINTS * ($game_stat{"level"})) {
        $game_stat{"score"}--;
      }
 
      # gotta exit somehow
      delete $_[HEAP]{termkey} if $key->type_is_unicode and
                                   $key->utf8 eq "C" and
                                   $key->modifiers & KEYMOD_CTRL;
      },
    
    # game over, clear the screen and write a message ##################
    game_over => sub {
      print($esc{"reset"});
      # show cursor
      print($esc{"show_cursor"});
      # clear screen
      print($esc{"clear_scr"});
      print("\nGame over! You are a "
            . @levels[$game_stat{"level"}] . ". ;)\n\n");
      exit(0);
    },
    
    # win, clear the screen and write a message ########################
    win => sub {
      print($esc{"reset"});
      # show cursor
      print($esc{"show_cursor"});
      # clear screen
      print($esc{"clear_scr"});
      print("\nYou win! Neo, you must be... the choosen one. O_O\n\n");
      exit(0);
    },
    
    # let's start a new level ##########################################
    next_level => sub {
      if ($game_stat{"level"} < scalar(@levels)) {
        $game_stat{"health"} = $HEALTH;
        $_[KERNEL]->yield("next_life");
      }
      else {
        $_[KERNEL]->yield("win");
      }
    },
    
    # let's start a new life, with new letters #########################
    next_life => sub {
      if ($game_stat{"lifes"} < 1) {
        $_[KERNEL]->yield("game_over");
      }
      else {
        $game_stat{"health"} = $HEALTH;
        # prepare an array with empty lines
        @lines = ();
        for (my $j=0; $j <= $game_stat{"level"}; $j++) {
          for (my $i=0; $i<$width; $i++) {
            my %sign = (
              "character" => " ",
              "state" => "empty"
            );
            push @{ $lines[$j] }, \%sign;
          }
        }
        $_[KERNEL]->yield("play");
      }
    },
    
    # this is the main loop (recursion) ################################
    play => sub {
      # frame rate should be stable, this may helps
      $timestamp = [ Time::HiRes::gettimeofday( ) ];
      
      # save cursor position
      print(`tput sc`);
      
      my $output = $esc{"bg_white"};
         $output .= $esc{"font_black"};
      
      # prepare bar with the game's state
      my $bar = "    whoami: " . @levels[$game_stat{"level"}]
                . "    |    "
                . "lifes: " . $game_stat{"lifes"} 
                . "    |    "
                . "health: " . $game_stat{"health"} 
                . "    |    "
                . "score: " . $game_stat{"score"};
      
      if (length($bar)<=$width) {
        # print rest of a bar
        for (my $i=length($bar); $i<$width; $i++) {
          $bar .= " ";
        }
      }
      else {
        # cut it if it's too long
        $bar = substr($bar, 0, $width);
      }
      
      $output .= $bar . "\n" . $esc{"bg_black"}
                             . $esc{"reset"};
      
      # for each line with signs
      for (my $j=0; $j<$game_stat{"level"}+1; $j++) {
        
        # remove first letter
        shift($lines[$j]);
        
        ($width) = GetTerminalSize();
        # generate new letter(s - if someone change terminal size)
        for (my $i=scalar(@{ $lines[$j] }); $i<$width; $i++) {
          my %sign = (
            "character" => " ",
            "state" => "normal"
          );
          if (int(rand(10)) < 1) {
            $sign{"character"} = $letters[int rand @letters];
          }
          push($lines[$j], \%sign);
        }
      
        # iterate over every sign in the line
        for (my $i=0; $i<$width; $i++) {
          
          # check for missed signs
          if ($i < $hit_range{"start"} 
              and ($lines[$j][$i]{"state"} eq "normal") 
              and ($lines[$j][$i]{"character"} ne " ") ) {
            $game_stat{"health"}--;
            $lines[$j][$i]{"state"} = "missed";
          }
          
          # set hit area colors
          if ($i eq $hit_range{"start"}) {
            # green background
            $output .= $esc{"bg_green"};
            # bold font
            $output .= $esc{"bold"};
          }
          
          # set standard area colors 
          if ($i eq $hit_range{"end"}) {
            # black background
            $output .= $esc{"bg_black"};
            # standard text
            $output .= $esc{"reset"};
          }
          
          # print color escape code
          if ($sign_states{$lines[$j][$i]{"state"}}) {
            $output .= $sign_states{$lines[$j][$i]{"state"}};
          }
          # print the letter
          $output .= $lines[$j][$i]{"character"};

        }
        $output .= "\n";
      }
      
      # print the frame
      print($output);
      
      # clear screen to the end (if minified terminal)
      print($esc{"clear_scr"});
      
      # restore cursor position
      # tput rc doesn't work whent cursor is in the last line :(
      # I should find a way to get position of cursor
      # print(`tput rc`);
      # this solution will couse problems after terminal resizing
      for (my $i=0; $i<=$game_stat{"level"}+1; $i++) {
        print($esc{"line_up"});
      }
      
      # if he's good enought;)
      if ($game_stat{"score"} >= $NEXT_LEVEL_POINTS * ($game_stat{"level"} + 1)) {
        $game_stat{"level"}++;
        $_[KERNEL]->yield("next_level");
      }
      else {
        # if he's dead
        if ($game_stat{"health"} < 1) {
          $game_stat{"lifes"}--;
          $_[KERNEL]->yield("next_life");
        }
        else {
          # display next frame 
          # period may be below 0, don't worry, it actually will be 0 :)
          $_[KERNEL]->delay(
            play => $FRAMERATE - Time::HiRes::tv_interval($timestamp)
          );
        }
      }
    },
    
  }
);
 
########################################################################

POE::Kernel->run;
