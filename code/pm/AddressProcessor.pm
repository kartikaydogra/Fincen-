################################################################################
# Name:
#   AddressProcessor - Perl package for parsing and normalizing street
#                      addresses.
# Notes:
#   Be sure to set PERL5LIB (colon-separated) appropriately to ensure that Perl
#   can find all of the modules used below.
################################################################################
package AddressProcessor;
use strict;

# The following four lines are not needed for non-OO Perl classes
require Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(); 

use FileUtilities;              # ReadHashFromFile()
use Logger;                     # Logger->new()

my %Postfixes =
    (n => 'n',
     e => 'e',
     s => 's',
     w => 'w',
     north => 'n',
     east => 'e',
     south => 's',
     west => 'w',
     ne => 'ne',
     se => 'se',
     sw => 'sw',
     nw => 'nw',
     northeast => 'ne',
     southeast => 'se',
     southwest => 'sw',
     northwest => 'nw');

my %UnitTypes =
    ('apartment' => 'apartment',
     'apt' => 'apartment',
     'basement' => 'basement',
     'bldg' => 'building',
     'bsmt' => 'basement',
     'building' => 'building',
     'department' => 'department',
     'dept' => 'department',
     'dpt' => 'department',
     'fl' => 'floor',
     'floor' => 'floor',
     'flr' => 'floor',
     'frnt' => 'front',
     'front' => 'front',
     'hangar' => 'hangar',
     'hngr' => 'hangar',
     'key' => 'key',
     'lbby' => 'lobby',
     'lobby' => 'lobby',
     'lot' => 'lot',
     'lower' => 'lower',
     'lowr' => 'lower',
     'm s' => 'mailstop',
     'm.s' => 'mailstop',
     'mail stop' => 'mailstop',
     'mailstop' => 'mailstop',
     'ms' => 'mailstop',
     'ofc' => 'office',
     'office' => 'office',
     'penthouse' => 'penthouse',
     'ph' => 'penthouse',
     'pier' => 'pier',
     'rear' => 'rear',
     'rm' => 'room',
     'room' => 'room',
     'side' => 'side',
     'slip' => 'slip',
     'space' => 'space',
     'spc' => 'space',
     'ste' => 'suite',
     'stop' => 'mailstop',
     'suiete' => 'suite',
     'suite' => 'suite',
     'trailer' => 'trailer',
     'trlr' => 'trailer',
     'unit' => 'unit',
     'upper' => 'upper',
     'uppr' => 'upper',
     '#' => '');

################################################################################
# Name:
#   StreetUnit - Separate a street address into the actual street address and a
#                 unit (e.g. apartment) type and number.
# Synopsis:
#   (string, string, string) StreetUnit(string $Str);
# Example:
#   ($Street, $UnitType, $UnitNum) = $Instance->StreetUnit($Street);
# Explicit arguments:
#   $Street     Input string to process -- must be lower case.
# Return:
#   Array of actual street address (always defined), unit type, and unit number.
#   If there is a unit type, the long form (not the abbreviation) is returned.
################################################################################
sub StreetUnit {
    my $self = shift();
    my $Street = $_[0];
    my ($UnitType, $UnitNum);
    
    # Unit numbers:
    #   123 Elm St Apt. 314 B
    #   123 Elm St. Unit B 314
    #   123 Elm St M.S. AX47C
    #   1234 Regents Rd D -- not currently detected
    #   1234 Regents Rd 203D -- not currently detected
    #   1234 Regents Rd, D203
    #   123 Elm St, Basement
    #   220 Newport Center Drive, 11 228
    # No unit numbers:
    #   1600 Hangar Pl
    #   777 Space St NW
    #   123 13th
    #   256 Rural Route 400
    #   1234 Highway 1
    # So require:
    #   Common & definitive designator
    #     Alternating num {1,5} & letter {1,2} groups with optional space
    #   Uncommon designator, not obvious designator
    #     Alternating num groups & single letter no space
    #   Designators that usually do not have a number
    #     Delimiter, e.g. ', Basement' or ' (Basement)'
    #   No designator
    #     Delimiter, then alternating num groups & single letter.
    #     Delimiter, then two num groups.
    if ($Street =~ s/^(.*?[a-z]{2}.*?)(?:\s*[\-\,\:\/]+\s*|\s+)(apartment|apt|bldg|dept|dpt|m\.s|rm|ste|suite|suiete|unit|mail\s*stop|#)[\-\,\:\/\.\# ]*(\d{1,5}(?:[\-\:\/\. ]*[a-z]{1,2}(?:[\-\:\/\. ]*\d{1,5})?)?|[a-z]{1,2}(?:[\-\:\/\. ]*\d{1,5}(?:[\-\:\/\. ]*[a-z]{1,2})?)?)\s*$/$1/) {
        $UnitType = $UnitTypes{$2};
        $UnitNum = $3;
    } elsif ($Street =~ s/^(.*?[a-z]{2}.*?)(?:\s*[\-\,\:\/]+\s*|\s+)(apartment|apt|bldg|dept|dpt|m\.s|rm|ste|suite|suiete|unit|mail\s*stop|#)[\-\,\:\/\.\# ]*$/$1/) {
        $UnitType = $UnitTypes{$2};
        $self->{LOG}->LEPrint(1, "Missing unit number: $Street, $2\n");
    } elsif ($Street =~ s/^(.*?[a-z]{2}.*?)(?:\s*[\-\,\:\/]+\s*|\s+)(building|department|fl|floor|flr|hangar|hngr|key|lot|m\s*s|ofc|office|penthouse|ph|pier|room|slip|space|spc|stop|trailer|trlr)[\-\,\:\/\.\# ]*(\d{1,5}(?:[\-\:\/\. ]*[a-z](?:[\-\:\/\. ]*\d{1,5})?)?|[a-z](?:[\-\:\/\. ]*\d{1,5}(?:[\-\:\/\. ]*[a-z]{1,2})?)?)\s*$/$1/) {
        $UnitType = $UnitTypes{$2};
        $UnitNum = $3;
    } elsif ($Street =~ s/^(.*?[a-z]{2}.*?)(?:\s*[\-\,\:\/]+\s*)(basement|bsmt|frnt|front|lbby|lobby|lower|lowr|ofc|office|penthouse|ph|rear|side|upper|uppr)\s*$/$1/) {
        $UnitType = $UnitTypes{$2};
    } elsif ($Street =~ s/^(.*?[a-z]{2}.*?)[\-\,\:\/ ]+((?:1st|2nd|3rd|4th|first|second|third|fourth)\s+floor)\s*$/$1/) {
        $UnitType = $UnitTypes{$2};
    } elsif ($Street =~ s/^(.*?[a-z]{2}.*?)(?:\s*[\-\,\:\/]+\s*)(\d{1,5}(?:[\-\:\/\. ]*[a-z](?:[\-\:\/\. ]*\d{1,5})?)?|[a-z](?:[\-\:\/\. ]*\d{1,5}(?:[\-\:\/\. ]*[a-z]{1,2})?)?|[a-z]{1,2}[\-\:\/\. ]*\d{1,3})\s*$/$1/) {
        $UnitNum = $2;
    } elsif ($Street =~ s/^(.*?[a-z]{2}.*?)(?:\s*[\-\,\:\/]+\s*)(\d{1,3}[\-\:\/\. ]+\d{1,3})\s*$/$1/) {
        $UnitNum = $2;
    }        
    return ($Street, $UnitType, $UnitNum);
}

################################################################################
# Name:
#   StreetSuffix - Parse and normalize the suffix of a street address, e.g.
#                  "avenue" -> "ave".
# Synopsis:
#   (string, string, string) StreetSuffix(string $Street);
# Example:
#   ($Street, $Suffix, $Postfix) = $Instance->StreetSuffix($Street);
# Explicit arguments:
#   $Street    Street name, lowercase, unit number stripped.
# Return:
#   The stripped street number & name, normalize suffix, and normalized postfix.
################################################################################
sub StreetSuffix {
    my ($self, $Street) = @_;

    my $Suffixes = $self->{STREETSUFFIXES};
    my $Postfix = '';
    my $Suffix = '';
    if ($Street =~
        s/^(.*?)\s+(n|e|s|w|north|east|south|west|ne|se|sw|nw|northeast|southeast|southwest|northwest)$/$1/) {
        $Postfix = $Postfixes{$2};
    }
    my $ModStreet = $Street;
    if ($ModStreet =~ s/^(.*?)\s+([a-z]+)\.?$/$1/) {
        if (exists($Suffixes->{$2})) {
            $Suffix = $Suffixes->{$2};
            $Street = $ModStreet;
        } else {
            $self->{LOG}->LEPrint(6, "Not suffix: $Street\n");
        }
    }
    return ($Street, $Suffix, $Postfix);
}

################################################################################
# Name:
#   new - Constructor.  Creates and initializes a new object instance.
# Synopsis:
#   new(misc %$Args);
# Example:
#   $NewInstance = AddressProcessor->new({LOG => $Logger});
# Explicit arguments:
#   Hash of named arguments.
# Return:
#   Reference to the object hash, or undef if there was an error.
################################################################################
sub new {
    my ($this, $Args) = @_;
    my $class = ref($this) || $this;
    my $self = bless({}, $class);

    my %KnownArgs = (AUXDATADIR => '/cygdrive/c/Programs/auxdata',
                     LOG => '');
    my ($Key, $Value);
    while (($Key, $Value) = each(%KnownArgs)) {
        if ($Value ne '') {
            $self->{$Key} = $Value;
        }
    }
    while (($Key, $Value) = each(%$Args)) {
        if (exists($KnownArgs{$Key})) {
            $self->{$Key} = $Value;
        } else {
            print(STDERR "ERROR: Unknown arg to AddressProcessor->new()\n");
            exit(1);
        }
    }

    unless (exists($self->{LOG})) {
        $self->{LOG} = Logger->new();                             # No-op logger
    }

    $self->{STREETSUFFIXES} =
        ReadHashFromFile({}, "$self->{AUXDATADIR}/StreetSuffixes.txt");
    
    return $self;
}

1;
