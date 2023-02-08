#!/usr/bin/env perl
################################################################################
# Name:
#   OFACtoCSV - Convert OFAC XML file to CSV in the same format as 314(a) files.
# Synopsis:
#   OFACtoCSV.pl [Options]
# Example:
#   OFACtoCSV.pl -in InFile
# Options:
#   -AuxDataDir string  Auxiliary data files (StreetSuffixes.txt) directory.
#   -config string      Name of configuration file containing any of these
#                       options.  Default: none.
#   -help               Display usage information.
#   -in string          Input OFAC XML file name.
#   -log string         File to which to write run-time messages.
#                       Default: none.
#   -loglevel int       Log level.  Messages whose level is greater than this
#                       will not be generated.  Default: 5.
#   -out string         Output CSV file name.
#   -verbose            Enable verbose messages.  '-help -verbose' prints this
#                       header.
# Exit:
#   0 => everything OK, else 1.
################################################################################
use strict;

# Enable warnings.  Same as -w, which fails with /usr/bin/env on some machines.
BEGIN { $^W = 1 }

use AddressProcessor;
use Logger;
use StartupUtilities;           # HelpAndExit(), OpenInStreamOrExit(), ....
use StringUtilities;            # DateDMonY4ToStd()
use XML::LibXML;

################################################################################
# Main
################################################################################
Main: {
    my $AuxDataDir;
    my $ConfigFile;
    my $Help = 0;
    my $InFile = '-';                                         # Default is STDIN
    my $Log;
    my $LogLevel = 5;
    my $OutStream = '-';                                     # Default is STDOUT
    my $Verbose = 0;

    my %CLOptionSpec = ('AuxDataDir=ID' => \$AuxDataDir,
                        'config|CF'     => \$ConfigFile,
                        'help'          => \$Help,
                        'in=IF'         => \$InFile,
                        'log|LF'        => \$Log,
                        'loglevel=i'    => \$LogLevel,
                        'out|OF'        => \$OutStream,
                        'verbose'       => \$Verbose);

    # Get and process values of command-line options
    ProcessCLArgs(\%CLOptionSpec);

    my %IDTypes = ("Driver's License No." => "Driver's License",
                   'Email Address' => 'Email Address',
                   'SSN' => 'SSN/ITIN',
                   'Tax ID No.' => 'SSN/ITIN',
                   'US FEIN' => 'SSN/ITIN');

    # Configure address processor
    my $AddrProc;
    if (defined($AuxDataDir)) {
        $AddrProc = AddressProcessor->new({AUXDATADIR => $AuxDataDir,
                                           LOG        => $Log});
    } else {
        $AddrProc = AddressProcessor->new({LOG        => $Log});
    }

    OutputRecord($OutStream,
                 'tracking_number', 'last_name', 'first_name', 'middle_name',
                 'suffix', 'alias_last_name', 'alias_first_name',
                 'alias_middle_name', 'alias_suffix', 'number', 'number_type',
                 'dob', 'street', 'city', 'state', 'zip', 'country', 'phone');

    my $XC = XML::LibXML::XPathContext->new();
    $XC->registerNs(NS => 'http://tempuri.org/sdnList.xsd');
    my $Parser = XML::LibXML->new();
    my $Tree = $Parser->parse_file($InFile);
    my $Root = $Tree->getDocumentElement();

    # XPath notes
    # @Records = $Tree->findnodes('//sdnEntry');    # If there were no namespace
    # $sdnType = $Record->findvalue('sdnType');     # If there were no namespace
    # $Node->textContent()                                # Get text of the node

    # Process one record of the input file at a time
    my ($AKA, $Address, $DOBElement, $ID,
        $RawNumber, $Record, $ThisCountry, $UnitNum, $UnitType,
        $address2, $iAKA, $iAddress, $iDOB, $iID,
        $nAKAs, $nAddresses, $nDOBs, $nIDs, $num, $num_type, $sDOB, $sdnType,
        $title,
        @AKAs, @Addresses, @DOBs, @IDs, @OutputIDs, @Records);
    my ($tracking_number, $last_name, $first_name, $middle_name, $suffix,
        $alias_last_name, $alias_first_name, $alias_middle_name, $alias_suffix,
        $number, $number_type, $dob, $street, $city, $state, $zip, $country,
        $phone);
    @Records = $XC->findnodes('/NS:sdnList/NS:sdnEntry', $Tree);
    foreach $Record (@Records) {
        $sdnType = $XC->findvalue('NS:sdnType', $Record);
        unless ($sdnType eq 'Individual') { next }
        $middle_name = $suffix = $alias_last_name =
            $alias_first_name = $alias_middle_name = $alias_suffix = $number =
            $number_type = $dob = $street = $city = $state = $zip = $country =
            $phone = $title = '';
        $tracking_number = $XC->findvalue('./NS:uid', $Record);
        $last_name = $XC->findvalue('./NS:lastName', $Record);
        if ($last_name =~ s/[, ]+(jr|sr|2nd|ii|3rd|iii|4th|iv)\s*$//i) {
            $suffix = $1;
        }
        $first_name = $XC->findvalue('./NS:firstName', $Record);
        if ($first_name =~ s/[, ]+(jr|sr|2nd|ii|3rd|iii|4th|iv)\s*$//i) {
            $suffix = $1;
        }
        if ($first_name =~ s/^([a-zA-Z]+\.) //) {
            $title = $1;
        }
        if ($first_name =~ s/^(.*?[a-zA-Z].*?) (.*)$/$1/) {
            $middle_name = $2;
        }

        # Deal with DOBs
        @DOBs = $XC->findnodes('./NS:dateOfBirthList/NS:dateOfBirthItem',
                               $Record);
        $nDOBs = scalar(@DOBs);
        $iDOB = 0;
        foreach $DOBElement (@DOBs) {
            $sDOB = $XC->findvalue('./NS:dateOfBirth', $DOBElement);
            if ($sDOB =~ /^(?:circa )?(?:\d{4} to )?(\d{4})$/) {
                $dob = "01/01/$1";
            } elsif ($sDOB =~ /^(?:circa )?([A-Z][a-z]{2}) (\d{4})$/) {
                $dob = DateDMonY4ToStd("01 $1 $2");
                if (defined($dob) && $dob =~ /^(\d{4})(\d{2})(\d{2})$/) {
                    $dob = "$2/$3/$1";
                } else {
                    $dob = '';
                    $Log->EPrint("Parsing DOB failed: $sDOB\n");
                    next;
                }
            } elsif ($sDOB =~ /^(?:circa )?(?:\d{2} [A-Z][a-z]{2} \d{4} to )?(\d{2}) ([A-Z][a-z]{2}) (\d{4})$/) {
                $dob = DateDMonY4ToStd("$1 $2 $3");
                if (defined($dob) && $dob =~ /^(\d{4})(\d{2})(\d{2})$/) {
                    $dob = "$2/$3/$1";
                } else {
                    $dob = '';
                    $Log->EPrint("Parsing DOB failed: $sDOB\n");
                    next;
                }
            } else {
                $Log->EPrint("Parsing DOB failed: $sDOB\n");
                next;
            }
            if (++$iDOB < $nDOBs) {
                OutputRecord($OutStream,
                             $tracking_number, $last_name, $first_name,
                             $middle_name, $suffix, $alias_last_name,
                             $alias_first_name, $alias_middle_name,
                             $alias_suffix, $number, $number_type, $dob,
                             $street, $city, $state, $zip, $country, $phone);
            }
        }

        # Deal with IDs
        @OutputIDs = ();
        @IDs = $XC->findnodes('./NS:idList/NS:id', $Record);
        $nIDs = scalar(@IDs);
        $iID = 0;
        foreach $ID (@IDs) {
            $num_type = $XC->findvalue('./NS:idType', $ID);
            unless (exists($IDTypes{$num_type})) { next }
            $ThisCountry = $XC->findvalue('./NS:idCountry', $ID);
            if ($ThisCountry ne '' && $ThisCountry ne 'United States') { next }
            $num = $RawNumber = $XC->findvalue('./NS:idNumber', $ID);
            if ($IDTypes{$num_type} eq 'SSN/ITIN') {
                $num =~ s/-//g;
                unless ($num =~ /^(?:.* )?(\d{9})$/) {
                    $Log->EPrint("Parsing SSN/ITIN failed: $RawNumber\n");
                }
                $num = $1;
            }
            push(@OutputIDs, $IDTypes{$num_type}, $num);
        }
        while (@OutputIDs) {
            $number_type = shift(@OutputIDs);
            $number = shift(@OutputIDs);
            if (@OutputIDs) {
                OutputRecord($OutStream,
                             $tracking_number, $last_name, $first_name,
                             $middle_name, $suffix, $alias_last_name,
                             $alias_first_name, $alias_middle_name,
                             $alias_suffix, $number, $number_type, $dob,
                             $street, $city, $state, $zip, $country, $phone);
            }
        }

        # Deal with AKAs
        @AKAs = $XC->findnodes('./NS:akaList/NS:aka', $Record);
        $nAKAs = scalar(@AKAs);
        $iAKA = 0;
        foreach $AKA (@AKAs) {
            $alias_suffix = '';
            $alias_last_name = $XC->findvalue('./NS:lastName', $AKA);
            if ($alias_last_name =~
                s/[, ]+(jr|sr|2nd|ii|3rd|iii|4th|iv)\s*$//i) {
                $alias_suffix = $1;
            }
            $alias_first_name = $XC->findvalue('./NS:firstName', $AKA);
            if ($alias_first_name =~
                s/[, ]+(jr|sr|2nd|ii|3rd|iii|4th|iv)\s*$//i) {
                $alias_suffix = $1;
            }
            if ($alias_first_name =~ s/^([a-zA-Z]+\.) //) {
                $title = $1;
            }
            if ($alias_first_name =~ s/^(.*?[a-zA-Z].*?) (.*)$/$1/) {
                $alias_middle_name = $2;
            } else {
                $alias_middle_name = '';
            }
            if (++$iAKA < $nAKAs) {
                OutputRecord($OutStream,
                             $tracking_number, $last_name, $first_name,
                             $middle_name, $suffix, $alias_last_name,
                             $alias_first_name, $alias_middle_name,
                             $alias_suffix, $number, $number_type, $dob,
                             $street, $city, $state, $zip, $country, $phone);
            }
        }

        # Deal with addresses
        @Addresses = $XC->findnodes('./NS:addressList/NS:address', $Record);
        $nAddresses = scalar(@Addresses);
        $iAddress = 0;
        foreach $Address (@Addresses) {
            $ThisCountry = $XC->findvalue('./NS:country', $Address);
            if ($ThisCountry eq 'United States') {
                $street = $XC->findvalue('./NS:address1', $Address);
                $address2 = $XC->findvalue('./NS:address2', $Address);
                if ($address2) {
                    my $TestStreet = lc("$street, $address2");
                    ($TestStreet, $UnitType, $UnitNum) =
                        $AddrProc->StreetUnit($TestStreet);
                    if ($UnitNum || $UnitType) {
                        $street = "$street, $address2";
                    } else {
                        $Log->EPrint("Parsing unit failed: $address2\n");
                    }
                }
                $city = $XC->findvalue('./NS:city', $Address);
                $state = $XC->findvalue('./NS:stateOrProvince', $Address);
                $zip = $XC->findvalue('./NS:postalCode', $Address);
                if ($zip eq '') {
                    # Do nothing
                } elsif ($zip =~ /^\d{1,5}$/) {
                    $zip = sprintf('%05d', $zip);
                } else {
                    $Log->EPrint("Odd ZIP $zip in record $tracking_number\n");
                }
                $country = $ThisCountry;
                if (++$iAddress < $nAddresses) {
                    OutputRecord($OutStream,
                                 $tracking_number, $last_name, $first_name,
                                 $middle_name, $suffix, $alias_last_name,
                                 $alias_first_name, $alias_middle_name,
                                 $alias_suffix, $number, $number_type, $dob,
                                 $street, $city, $state, $zip, $country,
                                 $phone);
                }
            }
        }

        # As of 2016-04-16, the SDN list contains no US phone numbers, so ignore
        # the few phone numbers stored in Remarks fields.

        # Output the last record for this entity with the last ID, address, etc.
        OutputRecord($OutStream,
                     $tracking_number, $last_name, $first_name,
                     $middle_name, $suffix, $alias_last_name,
                     $alias_first_name, $alias_middle_name,
                     $alias_suffix, $number, $number_type, $dob,
                     $street, $city, $state, $zip, $country, $phone);
    }

    $OutStream->close();
}

sub OutputRecord {
    my $OutStream = shift();

    my @Values = ();
    my $Value;
    foreach $Value (@_) {
        if ($Value =~ /,/) {
            push(@Values, "\"$Value\"");
        } else {
            push(@Values, $Value);
        }
    }

    $OutStream->print(join(',', @Values), "\n");
}
