#!/usr/bin/env perl
################################################################################
# Name:
#   FindEntities - Do OFAC (www.treasury.gov/ofac/downloads/sdn.xml) or
#                  314a (www.fincen.gov/statutes_regs/patriot/section314a.html)
#                  matching.  Match each LoanHero entity against each input list
#                  record.  Return the "true positive" records as well as the
#                  number of matching records for each field and other "false
#                  positive" stats.
# Synopsis:
#   FindEntities.pl [Options]
# Example:
#   FindEntities.pl -in InFile
# Options:
#   -Entities string    Name of file containing entity records to match against
#                       -- the FinCEN or OFAC SDN list.
#   -Format string      Name of file containing format spec for the -in files.
#                       Default: ./FindEntitiesInputFileFormat.txt.
#   -Loans string       Pipe-delimited list of loan IDs to process.
#                       Default: process all loans in the specified input files.
#   -Separator string   Field delimiter in the input and output files.
#                       Default: "\t".
#   -config string      Name of configuration file containing any of these
#                       options.  Default: none.
#   -help               Display usage information.
#   -in string          Name of file listing input files/records to process --
#                       LoanHero's entities.  Default: STDIN.
#   -log string         File to which to write run-time messages.  Specify
#                       "AUTONAME" to auto-generate the name. Default: none.
#   -loglevel int       Log level.  Messages whose level is greater than this
#                       will not be generated.  Default: 5.
#   -out string         Output file name.  Specify "AUTONAME" to auto-generate
#                       the file name.  Default: STDOUT.
#   -verbose            Enable verbose messages.  '-help -verbose' prints this
#                       header.
# Exit:
#   0 => everything OK, else 1.
# Notes:
#   * Be sure to set PERL5LIB (colon-separated) appropriately to ensure that
#     Perl can find all of the modules used below.
#   * cat ../analytics_git/config/StreetSuffixExpansions.txt | perl -e 'while (<>) { s/\r?\n//; unless (/^(.*?)\s+([A-Z]+)$/) { print("$_ What?\n") }; $Term = lc($1); $Abbr = lc($2); $Terms->{$Abbr}{$Term} = 1; $Terms->{$Abbr}{$Abbr} = 1 }; foreach $Abbr (sort(keys(%$Terms))) { $Values = $Terms->{$Abbr}; @aOut = (); foreach $Term (sort(keys(%$Values))) { push(@aOut, $Term) }; print(join(",", @aOut), "\n") }'
################################################################################
use strict;

# Enable warnings.  Same as -w, which fails with /usr/bin/env on some machines.
BEGIN { $^W = 1 }

use AddressProcessor;
use ArrayUtilities;
use FileUtilities;
use Logger;
use StartupUtilities;           # HelpAndExit(), OpenInStreamOrExit(), ....
use StringUtilities;            # DateMDY4SlashToStd(), StdDate()

################################################################################
# Main
################################################################################
Main: {
    my $AuxDataDir;
    my @OrigArgs = @ARGV;                                           # Array copy
    my $ConfigFile;
    my $EntitiesFile;
    my $FormatFile = './FindEntitiesInputFileFormat.txt';
    my $Help = 0;
    my $FilenamesFile = '-';                                  # Default is STDIN
    my $LogFile;
    my $LogLevel = 5;
    my $OutFile = '-';                                       # Default is STDOUT
    my $Separator = '\t';
    my $Verbose = 0;
    my $sLoanIDs;
    my %CLOptionSpec = ('Entities=IF'       => \$EntitiesFile,
                        'AuxDataDir=ID' => \$AuxDataDir,
                        'Format=IF'         => \$FormatFile,
                        'Loans=s'           => \$sLoanIDs,
                        'Separator=s'       => \$Separator,
                        'config|CF'         => \$ConfigFile,
                        'help'              => \$Help,
                        'in=IF'             => \$FilenamesFile,
                        'log=LF'            => \$LogFile,
                        'loglevel=i'        => \$LogLevel,
                        'out=OF'            => \$OutFile,
                        'verbose'           => \$Verbose);

    # Get and process values of command-line options
    ProcessCLArgs(\%CLOptionSpec);
    if ($Separator eq '\t') { $Separator = "\t" }
    
    my ($Key, %LoanIDs);
    if ($sLoanIDs) {
        foreach $Key (split(/\|/, $sLoanIDs)) {
            $LoanIDs{$Key} = 1;
        }
    }
    
    # Get data filenames
    my $Filenames = ReadArrayFromFile($FilenamesFile) || exit(1);
    for (my $iFile = 0; $iFile < @$Filenames; ++$iFile) {
        $Filenames->[$iFile] =~ s/\*$//;       # Remove "executable" flag if any
    }
    
    # Configure logger
    my ($CommandLine, $Log);
    my $FileType = '314aMatch';
    my $sToday = StdDate();
    my $sTodayHyphens = $sToday;
    $sTodayHyphens =~ s/^(\d{4})(\d{2})(\d{2})$/$1-$2-$3/;
    if (defined($LogFile)) {
        if ($LogFile eq 'AUTONAME') {
            $LogFile = "$FileType.$sToday.log";
        }
        $Log = Logger->new($LogFile);
        if ($FilenamesFile eq '-') {
            $CommandLine = join(' ', 'ls', @$Filenames, '|', $0, @OrigArgs);
        } else {
            $CommandLine = join(' ', $0, @OrigArgs);
        }
        $Log->Message($CommandLine);             # Log the program name and args
    } else {
        $Log = Logger->new();       # No-op logger if log filename not specified
    }
    $Log->SetLogLevel($LogLevel);

    # Configure address processor
    my $AddrProc;
    if (defined($AuxDataDir)) {
        $AddrProc = AddressProcessor->new({AUXDATADIR => $AuxDataDir,
                                           LOG        => $Log});
    } else {
        $AddrProc = AddressProcessor->new({LOG        => $Log});
    }
    
    # Convert AUTONAME to actual output file name
    if ($OutFile eq 'AUTONAME') {
        $OutFile = "$FileType.$sToday.csv";
    }

    # Define point values for match/mismatch
    my $Points = {};
    my $NegPoints = {};
    $Points->{BusinessName} = 3;
    $Points->{FirstLast} = 3;
    $Points->{FirstMLast} = 1;                                     # Incremental
    $Points->{FullName} = 1;                                       # Incremental
    $Points->{BaseAddress} = 2;
    $Points->{CityAddress} = 1;                                    # Incremental
    $Points->{StreetAddress} = 1;                                  # Incremental
    $Points->{UnitAddress} = 2;                                    # Incremental
    $Points->{SSN} = 8;
    $Points->{Phone} = 3;
    $Points->{DriverLicense} = 8;
    $Points->{EmailAddress} = 8;
    $Points->{YOB} = 1;
    $Points->{DOB} = 1;                                            # Incremental
    $NegPoints->{FirstLast} = 3;
    $NegPoints->{SSN} = 2;
    $NegPoints->{YOB} = 2;

    # Create data structures that associate each key with the "tracking number":
    # $Cases->{$Element}{$Key}{$TN} = 1, where:
    # $Element = FirstLast      $Key = "$First|$Last"
    # $Element = FirstMLast     $Key = "$First|$MInitial|$Last"
    # $Element = FullName       $Key = "$First|$Middle|$Last"
    # $Element = BaseAddress    $Key = "$ST|$Strt"
    # $Element = CityAddress    $Key = "$ST|$City|$Strt"
    # $Element = StreetAddress  $Key = "$ST|$City|$Strt|$Sfx|$Pfx"
    # $Element = UnitAddress    $Key = "$ST|$Strt|$Unit"
    # $Element = SSN            $Key = "$SSN"
    # $Element = DriverLicense  $Key = "$DriverLicense"
    # $Element = EmailAddress   $Key = "$EmailAddress"
    # $Element = DOB            $Key = "$DOB"
    # $Element = YOB            $Key = "$YOB"
    # $Element = Phone          $Key = "$Phone"
    my $Cases;
    if ($EntitiesFile =~ /business/i) {
        $Cases = ReadFinCENBusinesses($EntitiesFile, $AddrProc, $Log);
    } else {
        $Cases = ReadFinCENPersons($EntitiesFile, $AddrProc, $Log);
    }

    # Read the LoanHero entities file format specification
    my ($Default, $Filename, $Format, $Name, $Record, $Records, $iAccountIDFld,
        $iCityFld, $iDOBFld, $iEmailFld, $iFirstNameFld, $iIDNumberFld,
        $iLastNameFld, $iMiddleNameFld, $iNameSuffixFld, $iPhone1Fld,
        $iPhone2Fld, $iPhone3Fld, $iSSNFld, $iStateFld, $iUnitFld, $iStreetFld,
        $iZipCodeFld, $iField, @FieldFormat, @FieldNames);
    my $nFields = 0;
    my $aFormats = ReadArrayFromFile($FormatFile);
    foreach $Record (@$aFormats) {
        $Record =~ s/=$/= \n/;
        ($Name, $Format, $Default) = split(/ = /, $Record);
        $FieldNames[$nFields] = $Name;
        $FieldFormat[$nFields] = $Format;
        if ($Name eq 'AccountID' || $Name eq 'LoanID' || $Name eq 'UUID') {
            $iAccountIDFld = $nFields;
        } elsif ($Name eq 'BorrowerLastName' || $Name eq 'LastName') {
            $iLastNameFld = $nFields;
        } elsif ($Name eq 'BorrowerFirstName' || $Name eq 'FirstName') {
            $iFirstNameFld = $nFields;
        } elsif ($Name eq 'BorrowerMiddleName' || $Name eq 'MiddleName') {
            $iMiddleNameFld = $nFields;
        } elsif ($Name eq 'BorrowerNameSuffix' || $Name eq 'NameSuffix') {
            $iNameSuffixFld = $nFields;
        } elsif ($Name eq 'BorrowerDLNumber' || $Name eq 'BorrowerIDNumber' ||
                 $Name eq 'IDNumber') {
            $iIDNumberFld = $nFields;
        } elsif ($Name eq 'BorrowerEmail' || $Name eq 'Email') {
            $iEmailFld = $nFields;
        } elsif ($Name eq 'BorrowerSSN' || $Name eq 'SSN') {
            $iSSNFld = $nFields;
        } elsif ($Name eq 'BorrowerDOB' || $Name eq 'DOB') {
            $iDOBFld = $nFields;
        } elsif ($Name eq 'BorrowerStreetAddress' || $Name eq 'StreetAddress') {
            $iStreetFld = $nFields;
        } elsif ($Name eq 'BorrowerStreetAddress2' ||
                 $Name eq 'StreetAddress2') {
            $iUnitFld = $nFields;
        } elsif ($Name eq 'BorrowerCity' || $Name eq 'City') {
            $iCityFld = $nFields;
        } elsif ($Name eq 'BorrowerState' || $Name eq 'State') {
            $iStateFld = $nFields;
        } elsif ($Name eq 'BorrowerZipCode' || $Name eq 'ZipCode') {
            $iZipCodeFld = $nFields;
        } elsif ($Name eq 'BorrowerHomePhone' || $Name eq 'Phone1') {
            $iPhone1Fld = $nFields;
        } elsif ($Name eq 'BorrowerMobilePhone' || $Name eq 'Phone2') {
            $iPhone2Fld = $nFields;
        } elsif ($Name eq 'BorrowerWorkPhone' || $Name eq 'Phone3') {
            $iPhone3Fld = $nFields;
        }
        ++$nFields;
    }

    # Open the output file and print the file header
    my $OutStream = OpenOutStreamOrExit($OutFile);

    # Process the -in files one LoanHero data record at a time
    my %Matches = ();
    my $hEmpty = {};
    my ($EntityIDs, $Header, $Line, $MiddleInitial, $Postfix, $StreetSfx, $UnitNum, $UnitType,
        $city, $dob, $first_name, $iRecord, $last_name, $middle_name, $number, $phone, $sIn, $state, $street, $suffix, $tracking_number, $zip,
        @Fields);
  FILE:
    foreach $Filename (@$Filenames) {
        $sIn = OpenInStreamOrExit($Filename);
        my @Records = ();
        while (defined($Line = $sIn->getline())) {
            push(@Records, split(/[\r\n]+/, $Line));
        }
        $sIn->close();

        # Process header
        $Header = shift(@Records);
        @Fields = split(/$Separator/o, $Header);
        for ($iField = 0; $iField < $nFields; ++$iField) {
            unless ($Fields[$iField] eq $FieldNames[$iField]) {
                printf(STDERR "Header mismatch file %s field %d: %s vs. %s\n",
                       $Filename, $iField,
                       $Fields[$iField], $FieldNames[$iField]);
                next FILE;
            }
        }

        # Process data records
        $iRecord = 0;
        foreach $Record (@Records) {
            ++$iRecord;
            @Fields = ();
            while ($Record =~ s/^(\".*?\"|.*?)$Separator//o) {
                push(@Fields, $1);
            }
            push(@Fields, $Record);

            if ($sLoanIDs) {
                unless (defined($LoanIDs{$Fields[$iAccountIDFld]})) { next }
                $LoanIDs{$Fields[$iAccountIDFld]} = 0;
            }
            my $Scores = {};

            my %MatchingItems = ();
            
            # UUID	90d24035-78ae-31b9-8c07-c9a4e5f86bfd
            # FirstName	BARBARA
            # LastName	HERNANDEZ
            # MiddleName	
            # NameSuffix	
            # SSN	555-55-5555
            # DOB	1999-09-19
            # IDNumber	d01234567
            # Phone1	505-206-6919
            # Phone2	555-555-5555
            # Phone3	
            # StreetAddress	14444 W PIMA ST
            # StreetAddress2	
            # City	TOLLESON
            # State	AZ
            # ZipCode	85353
            $last_name = $Fields[$iLastNameFld];
            NormalizeAlphanum($last_name);
            $first_name = $Fields[$iFirstNameFld];
            NormalizeAlphanum($first_name);
            $middle_name = $Fields[$iMiddleNameFld];
            NormalizeAlphanum($middle_name);
            $suffix = $Fields[$iNameSuffixFld];
            NormalizeAlphanum($suffix);
            if ($first_name eq 'business') {
                $Key = StripBusinessType($last_name);
                $EntityIDs = $Cases->{BusinessName}{$Key} || $hEmpty;
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{BusinessName};
                    $MatchingItems{$tracking_number} .= " _0_ $Key";
                    if ($Verbose) { print("$Key\n") }
                }
            } else {
                $Key = "$first_name|$last_name";
                if ($Key eq '|') {
                    $EntityIDs = $hEmpty;
                } else {
                    $EntityIDs = $Cases->{FirstLast}{$Key} || $hEmpty;
                }
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{FirstLast};
                    $MatchingItems{$tracking_number} .= " _1_ $Key";
                    if ($Verbose) { print("$Key\n") }
                }
                if ($middle_name) {
                    $MiddleInitial = substr($middle_name, 0, 1);
                    $Key = "$first_name|$MiddleInitial|$last_name";
                    $EntityIDs = $Cases->{FirstMLast}{$Key} || $hEmpty;
                    foreach $tracking_number (keys(%$EntityIDs)) {
                        $Scores->{$tracking_number} += $Points->{FirstMLast};
                        $MatchingItems{$tracking_number} .= " _2_ $Key";
                        if ($Verbose) { print("$Key\n") }
                    }
                    if (length($middle_name) > 1) {
                        $Key = "$first_name|$middle_name|$last_name";
                        $EntityIDs = $Cases->{FullName}{$Key} || $hEmpty;
                        foreach $tracking_number (keys(%$EntityIDs)) {
                            $Scores->{$tracking_number} += $Points->{FullName};
                            $MatchingItems{$tracking_number} .= " _3_ $Key";
                            if ($Verbose) { print("$Key\n") }
                        }
                    }
                }
            }
            
            $number = $Fields[$iSSNFld];
            NormalizeAlphanum($number); $number =~ s/ //g;
            unless ($number eq '') {
                $EntityIDs = $Cases->{SSN}{$number} || $hEmpty;
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{SSN};
                    $MatchingItems{$tracking_number} .= " _4_ $number";
                    if ($Verbose) { print("$number\n") }
                }
            }
            
            $number = $Fields[$iIDNumberFld];
            NormalizeAlphanum($number); $number =~ s/ //g;
            unless ($number eq '') {
                $EntityIDs = $Cases->{DriverLicense}{$number} || $hEmpty;
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{DriverLicense};
                    $MatchingItems{$tracking_number} .= " _5_ $number";
                    if ($Verbose) { print("$number\n") }
                }
            }
            $number = lc($Fields[$iEmailFld]);
            $EntityIDs = $Cases->{EmailAddress}{$number} || $hEmpty;
            foreach $tracking_number (keys(%$EntityIDs)) {
                $Scores->{$tracking_number} += $Points->{EmailAddress};
                $MatchingItems{$tracking_number} .= " _6_ $number";
                if ($Verbose) { print("$number\n") }
            }
            $dob = $Fields[$iDOBFld];
            $dob =~ s/-//g;
            unless ($dob eq '') {
                $EntityIDs = $Cases->{DOB}{$dob} || $hEmpty;
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{DOB};
                    $MatchingItems{$tracking_number} .= " _7_ $dob";
                    if ($Verbose) { print("$dob\n") }
                }
                $Key = substr($dob, 0, 4);
                $EntityIDs = $Cases->{YOB}{$Key} || $hEmpty;
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{YOB};
                    $MatchingItems{$tracking_number} .= " _8_ $Key";
                    if ($Verbose) { print("$Key\n") }
                }
            }
            if ($Fields[$iUnitFld] && $Fields[$iUnitFld] ne '""') {
                $street = lc("$Fields[$iStreetFld], $Fields[$iUnitFld]");
                ($street, $UnitType, $UnitNum) = $AddrProc->StreetUnit($street);
                unless ($UnitNum || $UnitType) {
                    $Log->EPrint("Parsing unit failed: \"$Fields[$iStreetFld]\", \"$Fields[$iUnitFld]\" ($Fields[$iZipCodeFld])\n");
                }
            } else {
                $street = lc($Fields[$iStreetFld]);
                ($street, $UnitType, $UnitNum) = $AddrProc->StreetUnit($street);
                if ($UnitNum || $UnitType) {
                    $Log->LEPrint(8, "Found unit in Addr1: \"$Fields[$iStreetFld]\"\n");
                }
            }
            ($street, $StreetSfx, $Postfix) = $AddrProc->StreetSuffix($street);
            NormalizeAlphanum($street);
            $city = $Fields[$iCityFld]; NormalizeAlphanum($city);
            $state = $Fields[$iStateFld]; Trim($state);
            $zip = $Fields[$iZipCodeFld]; Trim($zip);
            $zip =~ s/^(\d{5})[- ]*\d{4}$/$1/;
            if ($street eq '') {
                $EntityIDs = $hEmpty;
            } else {
                $Key = "$state|$street";
                $EntityIDs = $Cases->{BaseAddress}{$Key} || $hEmpty;
            }
            foreach $tracking_number (keys(%$EntityIDs)) {
                $Scores->{$tracking_number} += $Points->{BaseAddress};
                $MatchingItems{$tracking_number} .= " _9_ $Key";
                if ($Verbose) { print("$Key\n") }
            }
            if ($street eq '' || $city eq '') {
                $EntityIDs = $hEmpty;
            } else {
                $Key = "$state|$city|$street";
                $EntityIDs = $Cases->{CityAddress}{$Key} || $hEmpty;
            }
            foreach $tracking_number (keys(%$EntityIDs)) {
                $Scores->{$tracking_number} += $Points->{CityAddress};
                $MatchingItems{$tracking_number} .= " _A_ $Key";
                if ($Verbose) { print("$Key\n") }
            }
            if ($street eq '' || ($StreetSfx eq '' && $Postfix eq '')) {
                $EntityIDs = $hEmpty;
            } else {
                $Key = "$state|$city|$street|$StreetSfx|$Postfix";
                $EntityIDs = $Cases->{StreetAddress}{$Key} || $hEmpty;
            }
            foreach $tracking_number (keys(%$EntityIDs)) {
                $Scores->{$tracking_number} += $Points->{StreetAddress};
                $MatchingItems{$tracking_number} .= " _B_ $Key";
                if ($Verbose) { print("$Key\n") }
            }
            if (defined($UnitNum)) {
                NormalizeAlphanum($UnitNum); $UnitNum =~ s/ //g;
                $Key = "$state|$street|$UnitNum";
            } elsif (defined($UnitType)) {
                $Key = "$state|street|$UnitType";
            } else {
                $Key = '';
            }
            if ($Key) {
                $EntityIDs = $Cases->{UnitAddress}{$Key} || $hEmpty;
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{UnitAddress};
                    $MatchingItems{$tracking_number} .= " _C_ $Key";
                    if ($Verbose) { print("$Key\n") }
                }
            }
            my %Phones = ();
            foreach $iField ($iPhone1Fld, $iPhone2Fld, $iPhone3Fld) {
                $phone = $Fields[$iField];
                NormalizeAlphanum($phone); $phone =~ s/ //g;
                if ($phone) { $Phones{$phone} = 1 }
            }
            foreach $Key (keys(%Phones)) {
                $EntityIDs = $Cases->{Phone}{$Key} || $hEmpty;
                foreach $tracking_number (keys(%$EntityIDs)) {
                    $Scores->{$tracking_number} += $Points->{Phone};
                    $MatchingItems{$tracking_number} .= " _D_ $Key";
                    if ($Verbose) { print("$Key\n") }
                }
            }
            
            foreach $tracking_number (keys(%$Scores)) {
                if ($Scores->{$tracking_number} > 1) {
                    $Matches{"$Fields[$iAccountIDFld]\t$tracking_number"} =
                        sprintf('%03d %s',
                                $Scores->{$tracking_number},
                                $MatchingItems{$tracking_number});
                }
            }
        }
    }
    foreach $Key (sort({ $Matches{$b} cmp $Matches{$a} } keys(%Matches))) {
        $OutStream->print("$Key\t$Matches{$Key}\n");
    }
    $OutStream->close();
}

# Read FinCEN business file
# 0       tracking_number
# 1       business_name
# 2       dba_name
# 3       number
# 4       number_type
# 5       incorporated
# 6       street
# 7       city
# 8       state
# 9       zip
# 10      country
# 11      phone
sub ReadFinCENBusinesses {
    my ($FileName, $AddrProc, $Log) = @_;
    
    my @Fields;
    my ($Cases, $Key, $Line, $RawLine, $sLog);
    my $iRecord = 0;
    my $sIn = OpenInStreamOrExit($FileName);
    my $Header = $sIn->getline();
    my ($Postfix, $StreetSfx,
        $tracking_number, $business_name,
        $number, $number_type, $street, $city, $state, $zip, $country,
        $phone, $UnitNum, $UnitType);
    while (defined($Line = $sIn->getline())) {
        ++$iRecord;
        $Line =~ s/\r?\n//;
        if ($Line =~ /^\s*$/) { next }
        $RawLine = $Line;
        @Fields = ();
        while ($Line =~ s/^(\".*?\"|.*?),//) {
            push(@Fields, $1);
        }
        push(@Fields, $Line);
        unless (scalar(@Fields) == 12) {
            printf(STDERR "Incorrect nFields %d vs. 12 in %s record %d.\n",
                   scalar(@Fields), $FileName, $iRecord);
            next;
        }
        $tracking_number = $Fields[0]; Trim($tracking_number);

        # Name
        $business_name = $Fields[1]; NormalizeAlphanum($business_name);
        $business_name = StripBusinessType($business_name);
        $Key = $business_name;
        $Cases->{BusinessName}{$Key}{$tracking_number} = 1;

        # DBA
        $business_name = $Fields[2]; NormalizeAlphanum($business_name);
        if ($business_name) {
            $business_name = StripBusinessType($business_name);
            $Key = $business_name;
            $Cases->{BusinessName}{$Key}{$tracking_number} = 1;
        }

        $number = $Fields[3];
        $number_type = $Fields[4]; Trim($number_type);
        if ($number_type eq "EIN") {
            NormalizeAlphanum($number);
            $number =~ s/ //g;
            $Key = $number;
            $Cases->{EIN}{$Key}{$tracking_number} = 1;
        } elsif ($number_type eq "TIN") {
            NormalizeAlphanum($number);
            $number =~ s/ //g;
            $Key = $number;
            $Cases->{SSN}{$Key}{$tracking_number} = 1;
        } elsif ($number_type eq "Email Address") {
            $number = lc($number);
            $Key = $number;
            $Cases->{EmailAddress}{$Key}{$tracking_number} = 1;
        }

        # Address
        ($street, $UnitType, $UnitNum) = $AddrProc->StreetUnit(lc($Fields[6]));
        ($street, $StreetSfx, $Postfix) = $AddrProc->StreetSuffix($street);
        NormalizeAlphanum($street);
        $city = $Fields[7]; NormalizeAlphanum($city);
        $state = uc($Fields[8]); Trim($state);
        $zip = $Fields[9]; Trim($zip);
        $Key = "$state|$street";
        $Cases->{BaseAddress}{$Key}{$tracking_number} = 1;
        $Key = "$state|$city|$street";
        $Cases->{CityAddress}{$Key}{$tracking_number} = 1;
        $Key = "$state|$city|$street|$StreetSfx|$Postfix";
        $Cases->{StreetAddress}{$Key}{$tracking_number} = 1;
        if (defined($UnitNum)) {
            NormalizeAlphanum($UnitNum);
            $UnitNum =~ s/ //g;
            $Key = "$state|$street|$UnitNum";
            $Cases->{UnitAddress}{$Key}{$tracking_number} = 1;
        } elsif (defined($UnitType)) {
            # E.g. "basement" or "penthouse" or "rear"
            $Key = "$state|$street|$UnitType";
            $Cases->{UnitAddress}{$Key}{$tracking_number} = 1;
        }
        if ($zip eq '' || $zip =~ /^\d{5}$/) {
            # Do nothing
        } elsif ($zip =~ /^\d{3,4}$/) {
            $zip = sprintf('%05d', $zip);
        } elsif ($zip =~ /^(\d{5})[- ]\d{4}$/) {
            $zip = $1;
        } else {
            $sLog = "Incorrect ZIP format $Fields[9] in $FileName record $iRecord.\n";
            $Log->EPrint($sLog);
        }
        $country = $Fields[10]; NormalizeAlphanum($country);

        # Phone
        $phone = $Fields[11]; NormalizeAlphanum($phone);
        if ($phone) {
            $Key = $phone;
            $Cases->{Phone}{$Key}{$tracking_number} = 1;
        }
    }
    return $Cases;
}

# Read FinCEN persons file
# 0       tracking_number 260824
# 1       last_name       Barrow
# 2       first_name      Juana
# 3       middle_name     Lachelle
# 4       suffix
# 5       alias_last_name Dale
# 6       alias_first_name        Juana
# 7       alias_middle_name       Lachelle
# 8       alias_suffix
# 9       number  259334351
# 10      number_type     SSN/ITIN
# 11      dob     11/30/1966
# 12      street  2621 Liverpool Court
# 13      city    Toledo
# 14      state   OH
# 15      zip     43617
# 16      country US
# 17      phone
sub ReadFinCENPersons {
    my ($FileName, $AddrProc, $Log) = @_;
    
    my @Fields;
    my ($Cases, $Key, $Line, $MiddleInitial, $RawLine, $sLog);
    my $iRecord = 0;
    my $sIn = OpenInStreamOrExit($FileName);
    my $Header = $sIn->getline();
    my ($Postfix, $StreetSfx,
        $tracking_number, $last_name, $first_name, $middle_name, $suffix,
        $alias_last_name, $alias_first_name, $alias_middle_name, $alias_suffix,
        $number, $number_type, $dob, $street, $city, $state, $zip, $country,
        $phone, $UnitNum, $UnitType);
    while (defined($Line = $sIn->getline())) {
        ++$iRecord;
        $Line =~ s/\r?\n//;
        if ($Line =~ /^\s*$/) { next }
        $RawLine = $Line;
        @Fields = ();
        while ($Line =~ s/^(\".*?\"|.*?),//) {
            push(@Fields, $1);
        }
        push(@Fields, $Line);
        unless (scalar(@Fields) == 18) {
            printf(STDERR "Incorrect nFields %d vs. 18 in %s record %d.\n",
                   scalar(@Fields), $FileName, $iRecord);
            next;
        }
        $tracking_number = $Fields[0]; Trim($tracking_number);

        # Name
        $last_name = $Fields[1]; NormalizeAlphanum($last_name);
        $first_name = $Fields[2]; NormalizeAlphanum($first_name);
        $middle_name = $Fields[3]; NormalizeAlphanum($middle_name);
        $suffix = $Fields[4]; NormalizeAlphanum($suffix);
        $Key = "$first_name|$last_name";
        $Cases->{FirstLast}{$Key}{$tracking_number} = 1;
        if ($middle_name) {
            $MiddleInitial = substr($middle_name, 0, 1);
            $Key = "$first_name|$MiddleInitial|$last_name";
            $Cases->{FirstMLast}{$Key}{$tracking_number} = 1;
            if (length($middle_name) > 1) {
                $Key = "$first_name|$middle_name|$last_name";
                $Cases->{FullName}{$Key}{$tracking_number} = 1;
            }
        }
        $alias_last_name = $Fields[5]; NormalizeAlphanum($alias_last_name);
        $alias_first_name = $Fields[6]; NormalizeAlphanum($alias_first_name);
        $alias_middle_name = $Fields[7]; NormalizeAlphanum($alias_middle_name);
        $alias_suffix = $Fields[8]; NormalizeAlphanum($alias_suffix);
        if ($alias_first_name || $alias_last_name) {
            $Key = "$alias_first_name|$alias_last_name";
            $Cases->{FirstLast}{$Key}{$tracking_number} = 1;
            if ($alias_middle_name) {
                $MiddleInitial = substr($alias_middle_name, 0, 1);
                $Key = "$alias_first_name|$MiddleInitial|$alias_last_name";
                $Cases->{FirstMLast}{$Key}{$tracking_number} = 1;
                if (length($alias_middle_name) > 1) {
                    $Key =
                        "$alias_first_name|$alias_middle_name|$alias_last_name";
                    $Cases->{FullName}{$Key}{$tracking_number} = 1;
                }
            }
        }

        # Number types: "Driver's License", "Passport", "SSN/ITIN",
        #               "Email Address"
        $number = $Fields[9];
        $number_type = $Fields[10]; Trim($number_type);
        if ($number_type eq "SSN/ITIN") {
            NormalizeAlphanum($number);
            $number =~ s/ //g;
            $Key = $number;
            $Cases->{SSN}{$Key}{$tracking_number} = 1;
        } elsif ($number_type eq "Driver's License") {
            NormalizeAlphanum($number);
            $number =~ s/ //g;
            $Key = $number;
            $Cases->{DriverLicense}{$Key}{$tracking_number} = 1;
        } elsif ($number_type eq "Email Address") {
            $number = lc($number);
            $Key = $number;
            $Cases->{EmailAddress}{$Key}{$tracking_number} = 1;
        }

        # DOB
        $dob = $Fields[11];
        if ($dob) {
            $dob = DateMDY4SlashToStd($dob);
            if (defined($dob)) {
                $Key = $dob;
                $Cases->{DOB}{$Key}{$tracking_number} = 1;
                $Key = substr($dob, 0, 4);
                $Cases->{YOB}{$Key}{$tracking_number} = 1;
            } else {
                $sLog = "Incorrect DOB format $Fields[11] in $FileName record $iRecord.\n";
                $Log->EPrint($sLog);
            }
        }

        # Address
        ($street, $UnitType, $UnitNum) = $AddrProc->StreetUnit(lc($Fields[12]));
        ($street, $StreetSfx, $Postfix) = $AddrProc->StreetSuffix($street);
        NormalizeAlphanum($street);
        $city = $Fields[13]; NormalizeAlphanum($city);
        $state = uc($Fields[14]); Trim($state);
        $zip = $Fields[15]; Trim($zip);
        $Key = "$state|$street";
        $Cases->{BaseAddress}{$Key}{$tracking_number} = 1;
        $Key = "$state|$city|$street";
        $Cases->{CityAddress}{$Key}{$tracking_number} = 1;
        $Key = "$state|$city|$street|$StreetSfx|$Postfix";
        $Cases->{StreetAddress}{$Key}{$tracking_number} = 1;
        if (defined($UnitNum)) {
            NormalizeAlphanum($UnitNum);
            $UnitNum =~ s/ //g;
            $Key = "$state|$street|$UnitNum";
            $Cases->{UnitAddress}{$Key}{$tracking_number} = 1;
        } elsif (defined($UnitType)) {
            # E.g. "basement" or "penthouse" or "rear"
            $Key = "$state|$street|$UnitType";
            $Cases->{UnitAddress}{$Key}{$tracking_number} = 1;
        }
        if ($zip eq '' || $zip =~ /^\d{5}$/) {
            # Do nothing
        } elsif ($zip =~ /^\d{3,4}$/) {
            $zip = sprintf('%05d', $zip);
        } elsif ($zip =~ /^(\d{5})[- ]\d{4}$/) {
            $zip = $1;
        } else {
            $sLog = "Incorrect ZIP format $Fields[15] in $FileName record $iRecord.\n";
            $Log->EPrint($sLog);
        }
        $country = $Fields[16]; NormalizeAlphanum($country);

        # Phone
        $phone = $Fields[17]; NormalizeAlphanum($phone);
        if ($phone) {
            $Key = $phone;
            $Cases->{Phone}{$Key}{$tracking_number} = 1;
        }
    }
    return $Cases;
}
