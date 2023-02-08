#!/usr/bin/env perl
################################################################################
# Name:
#   SalesforceToEntities - 
# Synopsis:
#   SalesforceToEntities.pl [Options]
# Example:
#   SalesforceToEntities.pl -in InFile
# Options:
#   -config string      Name of configuration file containing any of these
#                       options.  Default: none.
#   -help               Display usage information.
#   -in string          Input file listing CSV files to process. Default: STDIN.
#   -log string         File to which to write run-time messages.
#                       Default: none.
#   -loglevel int       Log level.  Messages whose level is greater than this
#                       will not be generated.  Default: 5.
#   -out string         Output file name.  Compressed file types are
#                       automatically recognized by their extensions and
#                       compressed on-the-fly.  Default: STDOUT.
#   -verbose            Enable verbose messages.  '-help -verbose' prints this
#                       header.
# Exit:
#   0 => everything OK, else 1.
# Notes:
#   Be sure to set PERL5LIB (colon-separated) appropriately to ensure that Perl
#   can find all of the modules used below.
################################################################################
use strict;

# Enable warnings.  Same as -w, which fails with /usr/bin/env on some machines.
BEGIN { $^W = 1 }

use FileUtilities;              # ReadArrayFromFile()
use Logger;
use StartupUtilities;           # HelpAndExit(), OpenInStreamOrExit(), ....
use StringUtilities;            # Trim()

################################################################################
# Main
################################################################################
Main: {
    my $ConfigFile;
    my $Help = 0;
    my $FilenamesFile = '-';                                  # Default is STDIN
    my $Log;
    my $LogLevel = 5;
    my $OutFile = '-';                                       # Default is STDOUT
    my $Verbose = 0;

    my %CLOptionSpec = ('config|CF'     => \$ConfigFile,
                        'help'          => \$Help,
                        'in=IF'         => \$FilenamesFile,
                        'log|LF'        => \$Log,
                        'loglevel=i'    => \$LogLevel,
                        'out=OF'        => \$OutFile,
                        'verbose'       => \$Verbose);

    # Get and process values of command-line options
    ProcessCLArgs(\%CLOptionSpec);
    my $Filenames = ReadArrayFromFile($FilenamesFile) || exit(1);

    my $sOut = OpenOutStreamOrExit($OutFile);
    $sOut->print(join("\t",
                      'AccountID', 'FirstName', 'MiddleName', 'LastName',
                      'NameSuffix', 'StreetAddress', 'StreetAddress2', 'City',
                      'State', 'ZipCode', 'Phone1', 'Phone2', 'Phone3', 'Email',
                      'SSN', 'DOB', 'IDType', 'IDNumber', 'IDState'), "\n");

    my ($Field, $Filename, $Line, $OutRecord, $iField, $iRecord, $sIn, @Fields);
    foreach $Filename (@$Filenames) {
        $Filename =~ s/\*$//;
        $sIn = OpenInStreamOrExit($Filename);

        # Process header
        my ($iAccountIDFld, $iFirstNameFld, $iMiddleNameFld, $iLastNameFld,
            $iNameSuffixFld, $iStreetAddressFld, $iStreetAddress2Fld, $iCityFld,
            $iStateFld, $iZipCodeFld, $iPhone1Fld, $iPhone2Fld, $iPhone3Fld,
            $iEmailFld, $iSSNFld, $iDOBFld, $iIDTypeFld, $iIDNumberFld,
            $iIDStateFld, $iFirstNameFld2, $iMiddleNameFld2, $iLastNameFld2,
            $iNameSuffixFld2, $iStreetAddressFld2, $iStreetAddress2Fld2,
            $iCityFld2, $iStateFld2, $iZipCodeFld2, $iPhone1Fld2, $iPhone2Fld2,
            $iPhone3Fld2, $iEmailFld2, $iSSNFld2, $iDOBFld2, $iIDTypeFld2,
            $iIDNumberFld2, $iIDStateFld2, $iBusinessNameFld, $iDBAFld,
            $iFederalIDFld) = (-1) x 40;
        my @FieldNames = ();
        my %iFld = ();
        my $nFields = 0;
        $Line = $sIn->getline();
        $Line =~ s/\r?\n/,/;
        while ($Line =~ s/^(\".*?\"|.*?),//) {
            $Field = $1;
            $Field =~ s/^\"(.*)\"$/$1/;
            $FieldNames[$nFields] = $Field;
            $iFld{$Field} = $nFields;
            if ($Field eq "Account Name") {
                $iAccountIDFld = $nFields;
            } elsif ($Field eq "DBA Doing Business As") {
                $iDBAFld = $nFields;
                $iBusinessNameFld = $iAccountIDFld;
            } elsif ($Field eq "Federal ID") {
                $iFederalIDFld = $nFields;
            } elsif ($Field eq "First Name" ||
                     $Field eq "Owner #1 First Name" ||
                     $Field eq "Principal First Name") {
                $iFirstNameFld = $nFields;
            } elsif ($Field eq "Last Name" ||
                     $Field eq "Owner #1 Last Name" ||
                     $Field eq "Principal Last Name") {
                $iLastNameFld = $nFields;
            } elsif ($Field eq "Mailing Street" ||
                     $Field eq "Owner #1 Home Address") {
                $iStreetAddressFld = $nFields;
            } elsif ($Field eq "Mailing City" ||
                     $Field eq "Owner #1 City") {
                $iCityFld = $nFields;
            } elsif ($Field eq "Mailing State/Province" ||
                     $Field eq "Owner #1 State") {
                $iStateFld = $nFields;
            } elsif ($Field eq "Mailing Zip/Postal Code" ||
                     $Field eq "Owner #1 Zip") {
                $iZipCodeFld = $nFields;
            } elsif ($Field eq "Phone" ||
                     $Field eq "Owner #1 Phone" ||
                     $Field eq "Principal Home Phone") {
                $iPhone1Fld = $nFields;
            } elsif ($Field eq "Mobile" ||
                     $Field eq "Principal's Moble Phone") {
                $iPhone2Fld = $nFields;
            } elsif ($Field eq "Account: Phone") {
                $iPhone3Fld = $nFields;
            } elsif ($Field eq "Email" || $Field eq "Owner #1 Email") {
                $iEmailFld = $nFields;
            } elsif ($Field eq "Birthdate" ||
                     $Field eq "Owner #1 DOB" ||
                     $Field eq "Principal's DOB") {
                $iDOBFld = $nFields;
            } elsif ($Field eq "SSN #" || $Field eq "Owner #1 SSN") {
                $iSSNFld = $nFields;
            } elsif ($Field eq "Driver's License Issue State" ||
                     $Field eq "Principal's Driver License State") {
                $iIDStateFld = $nFields;
            } elsif ($Field eq "Driver's License Number" ||
                     $Field eq "Principal's Driver License #") {
                $iIDNumberFld = $nFields;
            } elsif ($Field eq "Owner #2 First Name") {
                $iFirstNameFld2 = $nFields;
            } elsif ($Field eq "Owner #2 Last Name") {
                $iLastNameFld2 = $nFields;
            } elsif ($Field eq "Owner #2 Address") {
                $iStreetAddressFld2 = $nFields;
            } elsif ($Field eq "Owner #2 City") {
                $iCityFld2 = $nFields;
            } elsif ($Field eq "Owner #2 State") {
                $iStateFld2 = $nFields;
            } elsif ($Field eq "Owner #2 Zip") {
                $iZipCodeFld2 = $nFields;
            } elsif ($Field eq "Owner #2 Phone") {
                $iPhone1Fld2 = $nFields;
            } elsif ($Field eq "Owner #2 Email") {
                $iEmailFld2 = $nFields;
            } elsif ($Field eq "Owner #2 DOB") {
                $iDOBFld2 = $nFields;
            } elsif ($Field eq "Owner #2 SSN") {
                $iSSNFld2 = $nFields;
            } 
            ++$nFields;
        }

        # Process data records
        $iRecord = 0;
        while (defined($Line = $sIn->getline())) {
            if ($Line =~ /^\r?\n$/) { last }   # Start of Salesforce file footer
            while ($Line !~ /\"\r?\n/) {
                # Newline within a field -- continue on next line
                $Line =~ s/\r?\n/ /;
                $Line .= $sIn->getline();
            }
            $Line =~ s/\r?\n/,/;
            @Fields = ();
            while ($Line =~ s/^(\".*?\"|.*?),//) {
                $Field = $1;
                $Field =~ s/^\"(.*)\"$/$1/;
                Trim($Field);
                push(@Fields, $Field);
            }

            # Clean up bad Salesforce data
            $Fields[$iStateFld] =~ s/^([A-Z]{2})\s+[A-Z]{2}$/$1/;
            if ($iDOBFld >= 0 && $Fields[$iDOBFld]) {
                if ($Fields[$iDOBFld] =~ /^\d{1,2}\/\d{1,2}\/\d{4}$/) {
                    $Fields[$iDOBFld] =
                        DateMDY4SlashToY4MDDash($Fields[$iDOBFld]);
                } else {
                    $Fields[$iDOBFld] = '';
                }
            }

            # Output a record
            $OutRecord = "$Fields[$iAccountIDFld]";
            foreach $iField ($iFirstNameFld, $iMiddleNameFld, $iLastNameFld,
                             $iNameSuffixFld, $iStreetAddressFld,
                             $iStreetAddress2Fld, $iCityFld, $iStateFld,
                             $iZipCodeFld, $iPhone1Fld, $iPhone2Fld,
                             $iPhone3Fld, $iEmailFld, $iSSNFld, $iDOBFld,
                             $iIDTypeFld, $iIDNumberFld, $iIDStateFld) {
                if ($iField >= 0) {
                    $OutRecord .= "\t$Fields[$iField]";
                } else {
                    $OutRecord .= "\t";
                }
            }
            $sOut->print("$OutRecord\n");

            # Output the record for the 2nd business owner, if any
            if ($iLastNameFld2 >= 0 && $Fields[$iLastNameFld2]) {
                # Clean up bad Salesforce data
                $Fields[$iStateFld2] =~ s/^([A-Z]{2})\s+[A-Z]{2}$/$1/;
                if ($Fields[$iDOBFld2]) {
                    if ($Fields[$iDOBFld2] =~ /^\d{1,2}\/\d{1,2}\/\d{4}$/) {
                        $Fields[$iDOBFld2] =
                            DateMDY4SlashToY4MDDash($Fields[$iDOBFld2]);
                    } else {
                        $Fields[$iDOBFld2] = '';
                    }
                }
                
                $OutRecord = "$Fields[$iAccountIDFld]";
                foreach $iField ($iFirstNameFld2, $iMiddleNameFld2,
                                 $iLastNameFld2, $iNameSuffixFld2,
                                 $iStreetAddressFld2, $iStreetAddress2Fld2,
                                 $iCityFld2, $iStateFld2, $iZipCodeFld2,
                                 $iPhone1Fld2, $iPhone2Fld2, $iPhone3Fld2,
                                 $iEmailFld2, $iSSNFld2, $iDOBFld2,
                                 $iIDTypeFld2, $iIDNumberFld2, $iIDStateFld2) {
                    if ($iField >= 0) {
                        $OutRecord .= "\t$Fields[$iField]";
                    } else {
                        $OutRecord .= "\t";
                    }
                }
                $sOut->print("$OutRecord\n");
            }

            # Output record for business name and EIN, if available
            if ($iDBAFld >= 0) {
                $Fields[$iFirstNameFld] = 'business';
                $OutRecord = "$Fields[$iAccountIDFld]";
                foreach $iField ($iFirstNameFld, -1, $iBusinessNameFld, -1,
                                 $iStreetAddressFld, $iStreetAddress2Fld,
                                 $iCityFld, $iStateFld, $iZipCodeFld,
                                 $iPhone1Fld, $iPhone2Fld, $iPhone3Fld,
                                 $iEmailFld, $iFederalIDFld, -1, -1, -1, -1) {
                    if ($iField >= 0) {
                        $OutRecord .= "\t$Fields[$iField]";
                    } else {
                        $OutRecord .= "\t";
                    }
                }
                $sOut->print("$OutRecord\n");
            }
            if ($iDBAFld >= 0 && $Fields[$iDBAFld]) {
                $Fields[$iFirstNameFld] = 'business';
                $OutRecord = "$Fields[$iAccountIDFld]";
                foreach $iField ($iFirstNameFld, -1, $iDBAFld, -1,
                                 $iStreetAddressFld, $iStreetAddress2Fld,
                                 $iCityFld, $iStateFld, $iZipCodeFld,
                                 $iPhone1Fld, $iPhone2Fld, $iPhone3Fld,
                                 $iEmailFld, $iFederalIDFld, -1, -1, -1, -1) {
                    if ($iField >= 0) {
                        $OutRecord .= "\t$Fields[$iField]";
                    } else {
                        $OutRecord .= "\t";
                    }
                }
                $sOut->print("$OutRecord\n");
            }
        }

        $sIn->close();
    }

    $sOut->close();
}
