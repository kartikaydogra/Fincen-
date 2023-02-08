###############################################################################
# Name:
#   StartupUtilities - Perl package that provides commonly used functions for
#                      program start-up -- run-time help, option parsing, file
#                      opening, etc.
# Notes:
#   Be sure to set PERL5LIB (colon-separated) appropriately to ensure that Perl
#   can find all of the modules used below.
################################################################################
package StartupUtilities;
use strict;
use File::Basename;                     # fileparse()
use FileUtilities;                      # AbsolutePathname(), OpenInStream()
use Getopt::Long;                       # GetOptions()
use Logger;                             # Logger->new()
use StringUtilities;                    # ParseDateRange(), Trim()

require Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(HelpAndExit
             HelpGetOptions
             OpenInStreamOrExit
             OpenOutStreamOrExit
             ParseRange
             ParseDateRangeOption
             ProcessCLArgs
             ProgramFinished);

################################################################################
# Name:
#   HelpAndExit- Write a help message to STDERR that explains correct program
#                invocation and exit the program.
# Synopsis:
#   HelpAndExit(\%CLOptionSpec, [$ExtraArguments]);
# Example:
#   unless (GetOptions(%CLOptionSpec)) { HelpAndExit(\%CLOptionSpec, 'file') }
# Explicit arguments:
#   \%CLOptionSpec      Reference to the hash containing the Getopt::Long
#                       options specification.
#   $ExtraArguments     Extra arguments that the program accepts after the
#                       named options.
# Notes:
#   Exits the program with code 1 after displaying usage.
################################################################################
sub HelpAndExit {
    HelpGetOptions(@_);
    exit(1);                                                        # Error code
}

################################################################################
# Name:
#   HelpGetOptions - Write a help message to STDERR that explains correct
#                    program invocation.
# Synopsis:
#   HelpGetOptions(\%OptionsRef, [$ExtraArguments]);
# Example:
#   HelpGetOptions(\%OptionsRef, 'file');
# Explicit arguments:
#   \%OptionsRef        Reference to the hash containing the Getopt::Long
#                       options specification.
#   $ExtraArguments     Extra arguments that the program accepts after the
#                       named options.
# Return:
#   None.
################################################################################
sub HelpGetOptions {
    my $OptionsRef = shift;
    my $ExtraArguments = shift || '';

    my %Types = ('CF' => 'ConfigFile',
                 'ID' => 'InputDir',
                 'IF' => 'InputFile',
                 'IL' => 'InputFileListFile',
                 'LF' => 'LogFile',
                 'M'  => 'Comment',
                 'OD' => 'OutputDir',
                 'OF' => 'OutputFile',
                 'f'  => 'float',
                 'i'  => 'integer',
                 's'  => 'string');
    my ($ScriptBase, $ScriptDir, $ScriptExt) = fileparse($0, '');
    my $Key;

    if (exists($OptionsRef->{'verbose'})) {
        # Print help based on the program header
        if ($ {$OptionsRef->{'verbose'}}) {
            my $InfoRef = ProgramHeaderInfo();
            if ($InfoRef->{Info}) {
                print(STDERR $InfoRef->{Info});
                return;
            }
        }
    }

    # Print help based on the contents of the options hash
    print(STDERR "Usage: \n");
    print(STDERR "    $ScriptBase [options] $ExtraArguments\n");
    print(STDERR "Where options include\n");
    foreach $Key (sort(keys(%$OptionsRef))) {
        my $Default = '';
        my $KeyWithoutType;
        my $Mandatory = 0;
        my $Type = '';
        my $TypeStr = '';
        my $Value;
        if ($Key =~ /^(.*)([=:|])(\w+)(@?)$/) {
            $KeyWithoutType = $1;
            if ($2 eq '=' || $2 eq '|') { $Mandatory = 1 }
            $Type = $3;
        }
        if (exists($Types{$Type})) {
            $TypeStr = $Types{$Type};
        }
        if (exists($OptionsRef->{$Key})) {
            if (ref($OptionsRef->{$Key}) eq 'ARRAY') {
                foreach $Value (@{$OptionsRef->{$Key}}) {
                    if ($Type eq 'f' || $Type eq 'i') {
                        $Default .= "\n\t\t\t\t$Value";
                    } else {
                        $Default .= "\n\t\t\t\t'$Value'";
                    }
                }
            } else {
                if (defined($ {$OptionsRef->{$Key}})) {
                    if ($Type eq 'f' || $Type eq 'i') {
                        $Default = $ {$OptionsRef->{$Key}};            # Numeric
                    } else {
                        $Default = "'" . $ {$OptionsRef->{$Key}} . "'"; # String
                    }
                }
            }
        }
        if ($TypeStr) {
            print(STDERR "    -$KeyWithoutType ");
            if (!$Mandatory) { print(STDERR '[') }
            print(STDERR $TypeStr);
            if (!$Mandatory) { print(STDERR ']') }
            if (ref($OptionsRef->{$Key}) eq 'ARRAY') {
                print(STDERR ".  Multiple invocations allowed.");
                if ($Default ne '') { print(STDERR "  Default: $Default.") }
            } else {
                if ($Default ne '') { print(STDERR ".  Default: $Default.") }
            }
            print(STDERR "\n");
        } else {
            print(STDERR "    -$Key\n");
        }
    }
}

################################################################################
# Name:
#   OpenInStreamOrExit - Open a file or display a message and exit.
# Synopsis:
#   OpenInStreamOrExit(string $FileName, [string $Mode], [string $Layer]);
# Example:
#   OpenInStreamOrExit($FileName, 'r');
# Arguments:
#   $FileName   Name of the file to open.  '-' => STDIN.  Compressed files are
#               automatically recognized by their extensions and uncompressed
#               on-the-fly.
#   $Mode       Read mode, e.g. '<' or 'r' to read.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
# Return:
#   IO object.
################################################################################
sub OpenInStreamOrExit {
    my $InStream = OpenInStream(@_);
    unless(defined($InStream)) { exit(1) }
    return($InStream);
}

################################################################################
# Name:
#   OpenOutStreamOrExit - Open a file or display a message and exit.
# Synopsis:
#   OpenOutStreamOrExit(string $FileName, [string $Mode], [string $Layer]);
# Example:
#   OpenOutStreamOrExit($FileName, 'w');
# Arguments:
#   $FileName   Name of the file to open.  '-' => STDOUT.  Compressed file types
#               are automatically recognized by their extensions and compressed
#               on-the-fly.
#   $Mode       Write mode, e.g. 'a' to append, '>' or 'w' to overwrite.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
# Return:
#   IO object.
################################################################################
sub OpenOutStreamOrExit {
    my $OutStream = OpenOutStream(@_);
    unless(defined($OutStream)) { exit(1) }
    return($OutStream);
}

################################################################################
# Name:
#   OptionInvoked - Check whether a command-line option was invoked.
# Synopsis:
#   int OptionInvoked(ref $Value);
# Example:
#   if (OptionInvoked($Value)) {}
# Arguments:
#   $Value      A reference to a string or an array (depending on whether
#               multiple invocations of the option are allowed) from the
#               GetOptions() hash.
# Return:
#   1 if the option was invoked, else 0.
################################################################################
sub OptionInvoked {
    my $Value = $_[0];

    if (ref($Value) eq 'ARRAY') {
        if (scalar(@$Value)) { return 1 }
    } else {
        if (defined($$Value)) { return 1 }
    }
    return 0;
}

################################################################################
# Name:
#   OptionNonBlank - Check whether a command-line option is non-blank string,
#                    non-zero number, or non-empty array.
# Synopsis:
#   int OptionNonBlank(ref $Value);
# Example:
#   if (OptionNonBlank($Value)) {}
# Arguments:
#   $Value      A reference to a string or an array (depending on whether
#               multiple invocations of the option are allowed) from the
#               GetOptions() hash.
# Return:
#   1 if the option is non-blank, else 0.
################################################################################
sub OptionNonBlank {
    my $Value = $_[0];

    if (ref($Value) eq 'ARRAY') {
        if (@$Value) { return 1 }
    } else {
        if ($$Value) { return 1 }
    }
    return 0;
}

################################################################################
# Name:
#   ParseDateRangeOption - Parse a string consisting of two dates (YYYYMMDD
#                          format) separated by a hyphen into start and end
#                          time() values, or provide an error message and exit
#                          if the format is incorrect.
# Synopsis:
#   ParseDateRangeOption(string $Option, string $Range, string \%CLOptionSpec);
# Example:
#   (Start, Length) =
#       ParseDateRangeOption('Stuff', $StuffRange, \%CLOptionSpec);
# Arguments:
#   $Option         Name of the option.
#   $Range          String to parse.
#   %CLOptionSpec   Option spec for help message.
# Return:
#   List of two Perl time integers (start and end), both zero if the range
#   argument is empty (not specified on the command line).
################################################################################
sub ParseDateRangeOption {
    my ($Option, $Range, $CLOptionSpec) = @_;

    unless ($Range) { return (0, 0) }
    my ($Start, $End) = ParseDateRange($Range);
    if (defined($Start)) { return ($Start, $End) }
    print(STDERR "Format of option -$Option must be 'YYYYMMDD-YYYYMMDD'.\n");
    HelpAndExit($CLOptionSpec);
}

################################################################################
# Name:
#   ParseRange - Parse a string consisting of two integers separated by a hyphen
#                into start and length values, or provide an error message and
#                exit if the format is incorrect.
# Synopsis:
#   ParseRange(string $Option, string $Range, string \%CLOptionSpec);
# Example:
#   (Start, Length) = ParseRange('Stuff', $StuffRange, \%CLOptionSpec);
# Arguments:
#
# Return:
#   List of two integers (start and end), both zero if the range argument is
#   empty (not specified on the command line).  Counting starts at 1 (not 0) for
#   the start and end values
################################################################################
sub ParseRange {
    my ($Option, $Range, $CLOptionSpec) = @_;
    my $Start = 0;
    my $Length = 0;

    if ($Range) {
        if ($Range =~ m/(\d+)-(\d+)/) {
            $Start = $1 - 1;
            $Length = $2 - $1 + 1;
        } else {
            print(STDERR
                  "Format of option -$Option must be 'm-n', " .
                  "where m and n are integers.\n");
            HelpAndExit($CLOptionSpec);
        }
    }
    return ($Start, $Length);
}

################################################################################
# Name:
#   ProcessCLArgs - Process command-line arguments.
# Synopsis:
#   ProcessCLArgs(ref \%OptionDesc);
# Example:
#   ProcessCLArgs(\%CLOptionSpec);
# Arguments:
#   %OptionDesc  Hash exactly like Perl's GetOptions() option-descriptions hash
#                but extended as documented below.
#                Argument types include:
#                    CF      Configuration file for this program.
#                    ID      Input directory.
#                    IF      Input file.
#                    IL      File listing input files.
#                    LF      Normal program log file.
#                    M       A comment ("message") to be logged.
#                    OD      Output directory.
#                    OF      Output file.
#                    f       Floating point number.
#                    i       Integer.
#                    s       String.
#                '=' => argument is required.
#                ':' => argument is optional.
#                '|' => open the specified input or output file (argument is
#                       required), or exit on failure.
# Return:
#   None.
# Notes:
#   * This is basically a wrapper around Getopt::Long's GetOptions().
################################################################################
sub ProcessCLArgs {
    my $OptionsRef = $_[0];      # Hash passed in with extended type definitions

    # Tables for translating the ProcessCLArgs() (extended) options specifiers
    # to the GetOptions() (basic) format
    my %BasicLinkage = ('' => '',
                        '=' => '=',
                        ':' => ':',
                        '|' => '=');
    my %BasicType = ('CF'   => 's',
                     'ID'   => 's',
                     'IF'   => 's',
                     'IL'   => 's',
                     'LF'   => 's',
                     'M'    => 's',
                     'OD'   => 's',
                     'OF'   => 's',
                     'f'    => 'f',
                     'i'    => 'i',
                     's'    => 's',
                     ''     => '');

    my %FileTypes =     ('CF'   => 'in',
                         'ID'   => '',
                         'IF'   => 'in',
                         'IL'   => 'in',
                         'LF'   => 'log',
                         'M'    => '',
                         'OD'   => '',
                         'OF'   => 'out',
                         'f'    => '',
                         'i'    => '',
                         's'    => '',
                         ''     => '');

    # Fill the Basic, ExtType, FileType, and Name hashes
    # This subroutine uses three separate hashes in the GetOptions() format:
    # * $OptionsRef  is the input to and output from the subroutine.
    # * $Basic       is the same as $OptionsRef, except that extended keys are
    #                replaced with the corresponding basic key types
    #                (e.g. 'in|IF' -> 'in=s').
    # * $OptionVals  is the same as $Basic, except in the case of streams that
    #                are opened, the name of the stream is retained as the hash
    #                value rather than the reference to the stream.
    my $Basic = {};       # Hash for GetOptions() -- basic type specs and values
    my $ExtLinkage = {};                        # Hash of linkage specifications
    my $ExtType = {};                              # Hash of type specifications
    my $FileType = {};                                  # Hash of file type info
    my $Name = {};                                  # Hash of option (key) names
    my $OptionVals = {};       # Option values including filenames (not streams)
    my ($BasicKey, $ConfigParam, $Key, $KeyWithoutType, $Linkage,
        $Multiple, $String, $Type, $Value, $iEl, $rConfigFile);
    while (($Key, $Value) = each(%$OptionsRef)) {
        if ($Key =~ /^(.*)([=:|])(\w+)(@?)$/) {
            $KeyWithoutType = $1;
            $Linkage = $2;
            $Type = $3;
            $Multiple = $4 || '';
            if ($Linkage eq '|' && $Type eq 'CF' && !$Multiple) {
                $rConfigFile = $Value;
                $ConfigParam = '-' . $KeyWithoutType;
            }
        } else {
            $KeyWithoutType = $Key;
            $Linkage = '';
            $Type = '';
            $Multiple = '';
        }
        unless (exists($BasicType{$Type})) {
            die("Type $Type is not supported");                  # Program error
        }
        unless (exists($BasicLinkage{$Linkage})) {
            die("Linkage $Linkage is not supported");            # Program error
        }
        $BasicKey = $KeyWithoutType .
            $BasicLinkage{$Linkage} . $BasicType{$Type} . $Multiple;
        $Basic->{$BasicKey} = $Value;
        $ExtLinkage->{$BasicKey} = $Linkage;
        $ExtType->{$BasicKey} = $Type;
        $FileType->{$BasicKey} = $FileTypes{$Type};
        $Name->{$BasicKey} = $KeyWithoutType;
    }

    # Store the commands line in order to log it after options parsing.
    # If there is a configuration file, delete that option key and value.
    my @OrigArgs = @ARGV;                                           # Array copy
    my $FoundConfigParam = 0;
    for (my $iArg = 0; $iArg < @OrigArgs; ++$iArg) {
        # Attempt to restore quotes stripped by operating system
        if ($OrigArgs[$iArg] =~ /\s/) {
            if (index($OrigArgs[$iArg], "'") >= 0) {
                $OrigArgs[$iArg] = "\"$OrigArgs[$iArg]\"";
            } else {
                $OrigArgs[$iArg] = "'$OrigArgs[$iArg]'";
            }
        }

        if (defined($ConfigParam) &&
            !$FoundConfigParam &&
            $ARGV[$iArg] eq $ConfigParam &&
            defined($ARGV[$iArg + 1])) {
            $$rConfigFile = $ARGV[$iArg + 1];
            splice(@ARGV, $iArg, 2);                 # Delete these two elements
            $FoundConfigParam = 1;  # Don't access @ARGV anymore -- it's changed
        }
    }
    my $CommandLine = join(' ', $0, @OrigArgs);

    # Parse (i) the configuration file  and (ii) the command-line arguments
    $Getopt::Long::autoabbrev = 1;           # Allow abbreviated parameter names
    $Getopt::Long::ignorecase = 1;              # Ignore case in parameter names
    if (defined($rConfigFile) &&
        defined($$rConfigFile) &&
        $$rConfigFile ne '') {
        ReadConfigFile($$rConfigFile, $Basic) || HelpAndExit($OptionsRef);
    }
    if (!GetOptions(%$Basic) ||
        (exists($Basic->{'help'}) && $ {$Basic->{'help'}})) {
        if (@ARGV && $ARGV[0] eq 'wiki') {
            my $rInfoStr = ProgramHeaderToWiki();
            print(STDOUT "$$rInfoStr\n");
            exit(1);
        } else {
            HelpAndExit($OptionsRef);
        }
    }

    # Open specified files, but save filenames in a separate %$OptionVals hash
    while (($BasicKey, $Value) = each(%$Basic)) {
        $OptionVals->{$BasicKey} = $Value;                 # Copy key-value pair

        # Open no-op logger if log filename not specified
        if ($FileType->{$BasicKey} eq 'log' &&
            $ExtLinkage->{$BasicKey} eq '|' &&
            !defined($$Value)) {
            $$Value = Logger->new();
            next;
        }
        
        unless (OptionNonBlank($Value)) { next }
        unless ($ExtLinkage->{$BasicKey} eq '|') { next }      # No need to open
        unless ($FileType->{$BasicKey}) {
            die("Bad option spec for $Name->{$BasicKey}");       # Program error
        }

        # Create new filename strings and overwrite the old ones with
        # references to the corresponding streams
        if (ref($Value) eq 'ARRAY') {
            $OptionVals->{$BasicKey} = [];                    # Ref to new array
            for ($iEl = 0; $iEl < @$Value; ++$iEl) {
                $OptionVals->{$BasicKey}[$iEl] = $Value->[$iEl];
                if ($FileType->{$BasicKey} eq 'in') {
                    $Value->[$iEl] = OpenInStreamOrExit($Value->[$iEl]);
                } elsif ($FileType->{$BasicKey} eq 'log') {
                    my $Log = Logger->new($Value->[$iEl], '>', ':utf8');
                    if (defined($Basic->{'loglevel=i'})) {
                        my $rLevel = $Basic->{'loglevel=i'};
                        $Log->SetLogLevel($$rLevel);
                    }
                    $Value->[$iEl] = $Log;
                } else {
                    if ($Value->[$iEl] eq '-') {
                        # STDOUT does not support encodings
                        $Value->[$iEl] = OpenOutStreamOrExit($Value->[$iEl]);
                    } else {
                        $Value->[$iEl] = OpenOutStreamOrExit($Value->[$iEl],
                                                             '>',
                                                             ':encoding(utf8)');
                    }
                }
            }
        } else {
            $OptionVals->{$BasicKey} = \ "$$Value";          # Ref to new string
            if ($FileType->{$BasicKey} eq 'in') {
                if ($$Value eq '-') {
                    $$Value = OpenInStreamOrExit($$Value);
                } else {
                    $$Value = OpenInStreamOrExit($$Value,
                                                 '<', ':encoding(utf8)');
                }
            } elsif ($FileType->{$BasicKey} eq 'log') {
                my $Log = Logger->new($$Value, '>', ':utf8');
                if (defined($Basic->{'loglevel=i'})) {
                    my $rLevel = $Basic->{'loglevel=i'};
                    $Log->SetLogLevel($$rLevel);
                }
                $Log->Message($CommandLine);     # Log the program name and args
                $$Value = $Log;
            } else {
                if ($$Value eq '-') {
                    # STDOUT does not support encodings
                    $$Value = OpenOutStreamOrExit($$Value);
                } else {
                    $$Value = OpenOutStreamOrExit($$Value,
                                                  '>', ':encoding(utf8)');
                }
            }
        }
    }
}

################################################################################
# Name:
#   ProgramFinished - End-of-run processing -- obsolete, END() does this now.
# Synopsis:
#   ProgramFinished([ref \%OptionDesc], string $Code);
# Example:
#   ProgramFinished(\%CLOptionSpec, 0);
# Arguments:
#   %OptionDesc  Hash like Perl's GetOptions() option-descriptions hash -- see
#                the header comment for ProcessCLArgs() for details.
#   $Code        Code indicating program completion status.
#                Typically, 0 => everything OK, else 1.
# Return:
#   None.
# Notes:
#   Exits program.
################################################################################
sub ProgramFinished {
    my $OptionsRef = '';
    if (@_ >= 2) { $OptionsRef = shift() }
    my $Code = shift();
    print(STDERR "WARNING: $0 uses obsolete routine ProgramFinished().\n");
    exit($Code);
}

################################################################################
# Name:
#   ProgramHeaderInfo - Get the usage information from the (standard format)
#                       program header.
# Synopsis:
#   ProgramHeaderInfo();
# Example:
#   ProgramHeaderInfo();
# Arguments:
#   Program name.  Default: use the name of the running program.
# Return:
#   Reference to a hash with the following fields:
#     Author
#     Info
#     Version
# Notes:
#   See Template.pl for the header format specification.
################################################################################
sub ProgramHeaderInfo {
    my $ProgramName = $_[0] || $0;
    my $ProgramStream = OpenInStreamOrExit($ProgramName);
    my $InInfoSection = 0;
    my %Info = ();
    $Info{Info} = '';
    my $Line;
    while (defined($Line = $ProgramStream->getline())) {
        if ($Line =~ /^\# Name:/) { $InInfoSection = 1 }
        if ($InInfoSection) {
            if ($Line =~ /^\#{65,}/) { last }
            $Info{Info} .= $Line;
        }
    }
    # Check for Author
    if ($Info{Info} =~ /\n\#\s+Author:\s+\#\s+(.*?)\n/) {
        $Info{Author} = $1;
    }
    # Check for Version
    if ($Info{Info} =~ /\n\#\s+Version:\s+\#\s+(.*?)\n/) {
        $Info{Version} = sprintf('%s', $1);
    }
    # Remove leading '# ' comment indicator from Perl program header
    $Info{Info} =~ s/^\# ?//gm;
    $ProgramStream->close();
    return(\%Info);
}

################################################################################
# Name:
#   ProgramHeaderToWiki - Convert the (standard format) program header to Wiki
#                         text.
# Synopsis:
#   ProgramHeaderToWiki();
# Example:
#   ProgramHeaderToWiki();
# Arguments:
#   Program name.  Default: use the name of the running program.
# Return:
#   Reference to the Wiki text (string).
# Notes:
#   See Template.pl for the header format specification.
################################################################################
sub ProgramHeaderToWiki {
    my $ProgramName = $_[0] || $0;

    # Get the part of .pl sourcecode to parse -- from "# Name:" to "^#######..."
    my $sInfo = '';
    my $InInfoSection = 0;
    my $Line;
    my $ProgramStream = OpenInStreamOrExit($ProgramName);
    while (defined($Line = $ProgramStream->getline())) {
        if ($Line =~ /^\# Name:/) { $InInfoSection = 1 }
        if ($InInfoSection) {
            if ($Line =~ /^\#{65,}/) { last }
            $sInfo .= $Line;
        }
    }
    $ProgramStream->close();

    $sInfo =~ s/^\# ?//gm;               # Remove leading '# ' comment indicator
    $sInfo =~ s/\s*\n {3,}([\w\(\"\'])/ $1/g;      # Merge multi-line paragraphs
    $sInfo =~ s/^(\w.*):\s*$/\'\'\'$1:\'\'\'/gm;            # Make headings bold

    my @Lines = ();
    my $InSection = '';
    foreach $Line (split(/\s*\n/, $sInfo)) {
        if ($Line eq "'''Options:'''") {
            $InSection = 'Options';
            push(@Lines, $Line);
            push(@Lines, '{| style="background:transparent; width:100%"');
            next;
        } elsif ($Line =~ /^\'\'\'(\w+)\:\'\'\'$/) {
            if ($InSection eq 'Options') {
                push(@Lines, '|}');                        # Terminate the table
            }
            $InSection = $1;
        } elsif ($InSection =~ /^Examples?/) {
            if ($Line =~ s/^\s+-/ -/) {
                # Multi-line example -- continuing line starts with option name,
                # e.g. "-in".  Join all the lines together.
                $Lines[$#Lines] .= $Line;
                next;
            }
            if ($InSection eq 'Examples') {
                $Line =~ s/^\s*/:* /;       # Multiple examples => bulleted list
            }
        } elsif ($InSection eq 'Options') {
            # Create a table of option names and descriptions
            if ($Line =~ /^  (\-\S+(?: \w+)?)\s+(\w.*?)\s*$/) {
                push(@Lines, '|- valign="top"');
                push(@Lines, '| style="width:21px" | &nbsp; || ' . "$1 || $2");
                next;
            }
        } elsif ($InSection eq 'Notes') {
            if (index($Line, 'Be sure to set PERL5LIB ') >= 0 ||
                index($Line, 'can find all of the modules used below.') >= 0) {
                next;
            }
            $Line =~ s/^\s+(?:\*\s+)?/:* /;               # Create bulleted list
        }
        $Line =~ s/^\s+/:/;
        push(@Lines, $Line);
    }
    push(@Lines, ':* Be sure to set PERL5LIB (colon-separated) appropriately to ensure that Perl can find all of the needed modules.');
    push(@Lines, '', '[[Category:Analytic Tools]]');
    $sInfo = join("\n", @Lines);

    return(\$sInfo);
}

################################################################################
# Name:
#   ReadConfigFile - Read option names and values from a configuration file.
# Synopsis:
#   int ReadConfigFile(string $ConfigFile, misc \%OptionsSpec);
# Example:
#   ReadConfigFile($ConfigFile, $Basic) || HelpAndExit($OptionsRef);
# Arguments:
#   $Value      A reference to a string or an array (depending on whether
#               multiple invocations of the option are allowed) from the
#               GetOptions() hash.
# Return:
#   1 if success, 0 if any problems.
################################################################################
sub ReadConfigFile {
    my ($fConfig, $OptionsSpec) = @_;

    my $sConfig = ReadFile($fConfig) || return 0;
    my @CLArgs = @ARGV;                                             # Array copy
    @ARGV = ();                                                    # Clear @ARGV
    my ($Line, $Result);
    foreach $Line (split(/\r?\n/, $$sConfig)) {
        Trim($Line);
        if ($Line eq '' || $Line =~ /^#/) {
            next;                                     # Skip blanks and comments
        } elsif ($Line =~ /^(-\S+)\s+(\S.*?)$/) {
            push(@ARGV, $1, $2);
        } elsif ($Line =~ /^(-\S+)$/) {
            push(@ARGV, $1);
        } else {
            @ARGV = @CLArgs;             # Restore original command line options
            return 0;
        }
    }
    $Result = GetOptions(%$OptionsSpec);
    @ARGV = @CLArgs;                     # Restore original command line options
    return $Result;
}
    
################################################################################
# Name:
#   END - Package destructor, called when interpreter is being exited.
# Synopsis:
#   END();
# Arguments:
#   None.
# Return:
#   None.
# Notes:
#   No need to close open %OptionDesc file handles explicitly.  Perl does this
#   automatically.
################################################################################
END {
}

1;
