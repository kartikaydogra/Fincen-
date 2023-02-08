################################################################################
# Name:
#   FileUtilities - Generic utility functions for accessing files.
# Notes:
#   Be sure to set PERL5LIB (colon-separated) appropriately to ensure that Perl
#   can find all of the modules used below.
################################################################################
package FileUtilities;

use strict;
use Cwd;                                # cwd()
use IO::File;                           # new()
use ArrayUtilities;                     # UniqueE()
use StringUtilities;
require Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(AbsolutePathname
             FileDate
             FixFilename
             GetFileList
             MakeDirs
             OpenInFile
             OpenInStream
             OpenOutStream
             ReadAHFromFile
             ReadAoA
             ReadArrayFromFile
             ReadFile
             ReadHashFromFile
             ReadHashKeysFromFile
             ReadQueryList
             UnzipSingleFile
             UnzipSingleFileName
             WriteAoA
             WriteHashKeysToFile
             WriteHashToFile
             WriteStringToFile);

my %p_sortfn = ('klex'  => \&sortfn_klex,
                'knum'  => \&sortfn_knum,
                'krlex' => \&sortfn_krlex,
                'krnum' => \&sortfn_krnum);

################################################################################
# Name:
#   AbsolutePathname - Determine the absolute pathname of the specified file.
# Synopsis:
#   string AbsolutePathname(string $Filename);
# Example:
#   $Pathname = AbsolutePathname($Filename);
# Arguments:
#   $Filename   Name of the file to process.  The file need not exist.
# Return:
#   The pathname, made absolute via cwd() and suitable removal of '.' and '..'.
# Notes:
#   Path separators should be UNIX-style ('/' vs '\').
################################################################################
sub AbsolutePathname {
    my $Filename = $_[0];

    unless ($Filename =~ /^(\/|[A-Z]\:[\/\\])/) {
        # This is a relative path
        $Filename =~ s/^\.\///;                            # Remove leading './'
        $Filename = cwd() . '/' . $Filename;             # Prepend absolute path
    }
    # Get rid of any '???/../' in the path (UNIX prohibits '/' in the filename).
    while ($Filename =~ s/[^\/]+\/\.\.\///) {}
    return $Filename;
}

################################################################################
# Name:
#   FileDate - Get a string representing the file modification date.
# Synopsis:
#   string FileDate(string $Filename, [string $Format]);
# Example:
#   $Date = FileDate($Filename, 'Excel');
# Arguments:
#   $Filename   Name of the file to process.
# Return:
#   The modification date.
################################################################################
sub FileDate {
    my $Filename = $_[0];
    my $Format = $_[1] || 'Std';

    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
        $atime, $mtime, $ctime, $blksize, $blocks)
        = stat($Filename);
    unless (defined($dev)) {
        print(STDERR "ERROR: $Filename not found in FileDate().\n");
        if ($Format eq 'Excel') {
            return '0000-00-00'
        } else {
            return '00000000'
        }
    }
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        localtime($mtime);
    if ($Format eq 'Excel') {
        return sprintf('%04d-%02d-%02d', $year + 1900, $mon + 1, $mday);
    } else {
        return sprintf('%04d%02d%02d', $year + 1900, $mon + 1, $mday);
    }
}

################################################################################
# Name:
#   FixFilename - Convert file name for compatibility with functions that expect
#                 a file name instead of a glob or IO::file
# Synopsis:
#   FixFilename(string $FileName, [string $Mode], [string $Layer]);
# Example:
#   FixFilename($FileName, 'r');
# Arguments:
#   $FileName   Name of the file to open.  '-' => STDIN.  The following file
#               suffixes are automatically recognized and treated appropriately:
#                   .tar.gz  => 'tar' file passed through 'gzip'
#                   .gz  => 'gzip' compressed file
#                   .bz2 => 'bzip2' compressed file
#                   .zip => 'pkzip' compressed file
#                   .Z   => 'compress' compressed file
# Return:
#   Filename or undef on error.
# Notes:
#   * The $Layer specification may not work with STDIN.
################################################################################
sub FixFilename {
    my $FileName = $_[0];
    
    my $InStream = $FileName;
    if ($FileName eq '-') {
        $InStream = fileno(STDIN);
    } elsif ($FileName =~ /\.tar\.gz$/) {
        $InStream = "tar -xOzf $FileName |";
    } elsif ($FileName =~ /\.gz$/) {
        $InStream = "gzip -d -c $FileName |";
    } elsif ($FileName =~ /\.bz2$/) {
        $InStream = "bzcat $FileName |";
    } elsif ($FileName =~ /\.zip$/i) {
        $InStream = "unzip -pq $FileName |";
    } elsif ($FileName =~ /\.Z$/) {
        $InStream = "uncompress -c $FileName |";
    }
    return $InStream;
}

################################################################################
# Name:
#   GetFileList - Get a directory name and list of filenames.
# Synopsis:
#   (string, string \@) GetFileList(string $DirSpec, string $FilenamesFile);
# Example:
#   ($Dir, $FileList) = GetFileList($Dir, undef);
# Arguments:
#   $DirSpec            Name of directory in which to find files.
#   $FilenamesFile      File listing files to process.
# Return:
#   Reference to array of filename strings.
# Notes:
#   * If $DirSpec is not defined, $Dir is set to the current directory.
#   * If $FilenamesFile is undefined, @$FileList consists of all files in $Dir.
#   * In all cases, a file can be accessed by concatenating $Dir and a name from
#     @$FileList with no additional slashes required.
################################################################################
sub GetFileList {
    my ($Dir, $FilenamesFile) = @_;
    
    # Append '/' to $Dir if appropriate
    if (defined($Dir)) {
        $Dir .= '/';
    } elsif (defined($FilenamesFile)) {
        $Dir = '';
    } else {
        $Dir = './';
    }

    my ($File, $FileList);
    if (defined($FilenamesFile)) {
        $FileList = ReadArrayFromFile($FilenamesFile) || exit(1);
    } else {
        $FileList = [];
        opendir(CUR, $Dir);
        foreach $File (readdir(CUR)) {
            if (-f "$Dir$File") {
                push(@$FileList, $File);
            }
        }
        closedir(CUR);
    }
    return ($Dir, $FileList);
}

################################################################################
# Name:
#   MakeDirs - Create a directory and any parent directories as needed.
# Synopsis:
#   int MakeDirs(string $Dir);
# Example:
#   MakeDirs("NewBasedir/NewSubdir1/NewSubdir2");
# Arguments:
#   $Dir        Name of the directory to create.
# Return:
#   1 (success) or 0 (failure).
# Notes:
#   Path separators should be UNIX-style ('/' vs '\').
################################################################################
sub MakeDirs {
    my $Dir = $_[0];

    my $Path = '';
    if ($Dir =~ s/^(\.{0,2}\/)//) { $Path = $1 };  # Leading '/', './', or '../'
    my @Components = split(/\//, $Dir);                # Append 1st name in path
    while (@Components) {
        $Path .= shift(@Components);
        unless (-d $Path) {
            unless (mkdir($Path)) { return 0 }
        }
        $Path .= '/';
    }
    return 1;
}

################################################################################
# Name:
#   OpenInFile - Open a file (for compatibility with functions that expect a
#                glob)
# Synopsis:
#   OpenInFile(string $FileName, [string $Mode], [string $Layer]);
# Example:
#   OpenInFile($FileName, 'r');
# Arguments:
#   $FileName   Name of the file to open.  '-' => STDIN.  The following file
#               suffixes are automatically recognized and treated appropriately:
#                   .tar.gz  => 'tar' file passed through 'gzip'
#                   .gz  => 'gzip' compressed file
#                   .bz2 => 'bzip2' compressed file
#                   .zip => 'pkzip' compressed file
#                   .Z   => 'compress' compressed file
#   $Mode       Read mode, e.g. '<' or 'r' to read.  Default: '<'.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
#   $Password   Password for decrypting files.
# Return:
#   File glob or undef on error.
# Notes:
#   * $Layer specifications may work with $Mode = '<' but not with $Mode = 'r'.
#   * The $Layer specification may not work with STDIN.
################################################################################
sub OpenInFile {
    my $FileName = $_[0];
    my $Mode = $_[1] || '<';
    my $Layer = $_[2];
    my $Password = $_[3];
    
    my $InStream;
    # Below, use quotes around $FileName to permit whitespace in the name
    if ($FileName eq '-') {
        if ($Layer) { $Mode .= $Layer }
        fdopen($InStream, fileno(STDIN), $Mode);
    } elsif ($FileName =~ /\.tar\.gz$/) {
        open($InStream, "tar -xOzf \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }        
    } elsif ($FileName =~ /\.gpg$/) {
        open($InStream, "gpg --batch --decrypt --no-secmem-warning --no-use-agent --passphrase \"$Password\" --quiet \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.gz$/) {
        open($InStream, "gzip -d -c \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.bz2$/) {
        open($InStream, "bzcat \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.zip$/i) {
        open($InStream, "unzip -pq \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.Z$/) {
        open($InStream, "uncompress -c \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } else {
        open($InStream, $FileName, $Mode);
        if ($Layer) { binmode($InStream, $Layer) }
    }
    unless ($InStream) {
        if ($FileName eq '-' && defined($ENV{OS}) && $ENV{OS} eq 'Windows_NT') {
            print(STDERR
                  "Sorry, Microsoft's cmd.exe does not support piping input \n",
                  "directly to a .pl file, use an actual input file or pipe ",
                  "the input to\n    perl $0\n");
        } else {
            print(STDERR "ERROR: Failed to open input file \"$FileName\".\n");
        }
        return undef;
    }
    return $InStream;
}

################################################################################
# Name:
#   OpenInStream - Open a file.
# Synopsis:
#   OpenInStream(string $FileName, [string $Mode], [string $Layer]);
# Example:
#   OpenInStream($FileName, 'r');
# Arguments:
#   $FileName   Name of the file to open.  '-' => STDIN.  The following file
#               suffixes are automatically recognized and treated appropriately:
#                   .tar.gz  => 'tar' file passed through 'gzip'
#                   .gz  => 'gzip' compressed file
#                   .bz2 => 'bzip2' compressed file
#                   .zip => 'pkzip' compressed file
#                   .Z   => 'compress' compressed file
#   $Mode       Read mode, e.g. '<' or 'r' to read.  Default: '<'.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
#   $Password   Password for decrypting files.
# Return:
#   IO object or undef on error.
# Notes:
#   * The $Layer specification may not work with STDIN.
################################################################################
sub OpenInStream {
    my $FileName = $_[0];
    my $Mode = $_[1] || '<';
    my $Layer = $_[2];
    my $Password = $_[3];
    
    my $InStream = IO::File->new();
    # Below, use quotes around $FileName to permit whitespace in the name
    if ($FileName eq '-') {
        if ($Layer) { $Mode .= $Layer }
        $InStream->fdopen(fileno(STDIN), $Mode);
    } elsif ($FileName =~ /\.tar\.gz$/) {
        $InStream->open("tar -xOzf \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }        
    } elsif ($FileName =~ /\.gpg$/) {
        $InStream->open("gpg --batch --decrypt --no-secmem-warning --no-use-agent --passphrase \"$Password\" --quiet \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.gz$/) {
        $InStream->open("gzip -d -c \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.bz2$/) {
        $InStream->open("bzcat \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.zip$/i) {
        $InStream->open("unzip -pq \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } elsif ($FileName =~ /\.Z$/) {
        $InStream->open("uncompress -c \"$FileName\" |");
        if ($Layer) { binmode($InStream, $Layer) }
    } else {
        $InStream->open($FileName, $Mode);
        if ($Layer) { binmode($InStream, $Layer) }
    }
    unless ($InStream->opened()) {
        if ($FileName eq '-' && defined($ENV{OS}) && $ENV{OS} eq 'Windows_NT') {
            print(STDERR
                  "Sorry, Microsoft's cmd.exe does not support piping input \n",
                  "directly to a .pl file, use an actual input file or pipe ",
                  "the input to\n    perl $0\n");
        } else {
            print(STDERR "ERROR: Failed to open input file \"$FileName\".\n");
        }
        return undef;
    }
    if (defined($Layer) && $Layer eq ':encoding(utf8)') {
        # Unicode file => remove the "byte order mark" character, if present
        my $FirstChar = $InStream->getc();          # undef if the file is empty
        if (defined($FirstChar) && $FirstChar ne "\x{FEFF}") {
            $InStream->ungetc(ord($FirstChar));
        }
    }
    return $InStream;
}

################################################################################
# Name:
#   OpenOutStream - Open a file.
# Synopsis:
#   OpenOutStream(string $FileName, [string $Mode], [string $Layer]);
# Example:
#   OpenOutStream($FileName);
# Arguments:
#   $FileName   Name of the file to open.  '-' => STDOUT, '>-' => STDERR.  The
#               following file suffixes are automatically recognized and treated
#               appropriately:
#                   .gz  => 'gzip' compressed file
#                   .zip => 'pkzip' compressed file
#                   .Z   => 'compress' compressed file
#   $Mode       I/O "mode", e.g. 'a' to append.  Default: '>'.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
# Return:
#   IO object or undef on error.
# Notes:
#   * The $Layer specification may not work with STDOUT.
################################################################################
sub OpenOutStream {
    my $FileName = $_[0];
    my $Mode = $_[1] || '>';
    my $Layer = $_[2];
    
    my $OutStream = IO::File->new();
    # Below, use quotes around $FileName to permit whitespace in the name
    if ($FileName eq '-') {
        if ($Layer) { $Mode .= $Layer }
        $OutStream->fdopen(fileno(STDOUT), $Mode);
    } elsif ($FileName eq '>-') {
        if ($Layer) { $Mode .= $Layer }
        $OutStream->fdopen(fileno(STDERR), $Mode);
    } elsif ($FileName =~ /\.gz$/) {
        $OutStream->open("| gzip > \"$FileName\"");
        if ($Layer) { binmode($OutStream, $Layer) }
    } elsif ($FileName =~ /\.bz2$/) {
        $OutStream->open("| bzip2 -c > \"$FileName\"");
        if ($Layer) { binmode($OutStream, $Layer) }
    } elsif ($FileName =~ /\.zip$/i) {
        $OutStream->open("| zip \"$FileName\" -q -");
        if ($Layer) { binmode($OutStream, $Layer) }
    } elsif ($FileName =~ /\.Z$/) {
        $OutStream->open("| compress > \"$FileName\"");
        if ($Layer) { binmode($OutStream, $Layer) }
    } else {
        $OutStream->open($FileName, $Mode);
        if ($Layer) { binmode($OutStream, $Layer) }
    }
    unless ($OutStream->opened()) {
        print(STDERR "ERROR: Failed to open output file \"$FileName\".\n");
        return undef;
    }

    if (defined($Layer) && $Layer eq ':encoding(utf8)') {
        # Unicode file => output a "byte order mark" character
        $OutStream->print("\x{FEFF}");
    }
    
    return $OutStream;
}

################################################################################
# Name:
#   ReadAHFromFile - Read a file containing key/value pairs and create an array
#                    of the keys (in order) and a hash.
# Synopsis:
#   (\@Keys, \%KeyValues) ReadAHFromFile(hash \%Options, string $FileName,
#                                        [string $Mode], [string $Layer]);
#                             
# Example:
#   ($Array, $Hash) = ReadAHFromFile({}, '/tmp/index.txt');
# Arguments:
#   %Options    Hash of options.  Keys may include:
#                 HASH       Reference to a hash to which to add items from the
#                            specified file.  Default: Create a new empty hash.
#                 REPEAT     If keys repeat, the hash value becomes an array
#                            with the appended (unique) values.  Default:
#                            only last value encountered for each key is kept.
#                 SEPARATOR  Separator between the key and value in the file.
#                            Default: '='.
#   $FileName   Name of the file to read.  Any line in the file that contains a
#               key/value pair separated by the separator is parsed, and the
#               pair is added to the return hash.  Lines beginning with '#' are
#               ignored.
#   $Mode       Read mode, e.g. '<' or 'r' to read.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
# Return:
#   References to the new array and hash or (undef, undef) on error.
################################################################################
sub ReadAHFromFile {
    my $Options = shift(@_);

    my @Array = ();
    my ($Filename, $Hash, $Repeat, $Separator);
    if (exists($Options->{HASH})) {
        $Hash = $Options->{HASH};
    } else {
        $Hash = {};
    }
    if (exists($Options->{REPEAT})) {
        $Repeat = $Options->{REPEAT};
    } else {
        $Repeat = 0;
    }
    if (exists($Options->{SEPARATOR})) {
        $Separator = $Options->{SEPARATOR};
    } else {
        $Separator = '=';
    }
    my $SplitRE = qr/$Separator/;
    
    my $Stream = OpenInStream(@_);
    unless (defined($Stream)) { return (undef, undef) }
    
    my ($Line, $Key, $Value);
    while (defined($Line = $Stream->getline())) {
        if ($Line =~ /^\#/) { next }                           # Ignore comments
        ($Key, $Value) = split($SplitRE, $Line, 2);
        unless (defined($Value)) { next }     # Ignore lines not matching format
        Trim($Key);
        Trim($Value);
        push(@Array, $Key);
        if ($Repeat && exists($Hash->{$Key})) {
            my @aValues;
            if (ref($Hash->{$Key})) {
                @aValues = @{$Hash->{$Key}};                        # Array copy
            } else {
                if ($Value eq $Hash->{$Key}) { next }      # Repeated value, too
                @aValues = ($Hash->{$Key});
            }
            push(@aValues, $Value);
            $Hash->{$Key} = UniqueE(\@aValues);
        } else {
            $Hash->{$Key} = $Value;
        }
    }
    $Stream->close();
    return (\@Array, $Hash);
}

################################################################################
# Name:
#   ReadAoA - Read an array of arrays from a file.
# Synopsis:
#   array \@ReadAoA(string $FileName, [hash \%Options]);
# Example:
#   $ArrayRef = ReadAoA('/tmp/index.txt');
# Arguments:
#   $FileName   Name of the file to read.  Blank lines and lines beginning with
#               '#' are ignored.
#   %Options    Hash of options.  Keys may include:
#                 ARRAY      Reference to an array to which to add items.
#                            Default: Create a new array.
#                 MODE       I/O "mode", e.g. '<' or 'r' to read. Default: '<'.
#                 LAYER      I/O "layer" directive, e.g. ':utf8'. Default: none.
#                 SEPARATOR  Separator between the array elements on each line.
#                            Default: "\t".
# Return:
#   Reference to the new array undef on error.
################################################################################
sub ReadAoA {
    my ($FileName, $Options) = @_;

    unless (defined($Options)) { $Options = {} }
    my ($Array, $Mode, $Separator, $Stream);
    if (exists($Options->{ARRAY})) {
        $Array = $Options->{ARRAY};
    } else {
        $Array = [];
    }
    if (exists($Options->{MODE})) {
        $Mode = $Options->{MODE};
    } else {
        $Mode = '<';
    }
    if (exists($Options->{SEPARATOR})) {
        $Separator = $Options->{SEPARATOR};
    } else {
        $Separator = "\t";
    }
    my $SplitRE = qr/$Separator/;
    
    if (exists($Options->{LAYER})) {
        $Stream = OpenInStream($FileName, $Mode, $Options->{LAYER});
    } else {
        $Stream = OpenInStream($FileName, $Mode);
    }
    unless (defined($Stream)) { return undef }
    
    my ($Line);
    while (defined($Line = $Stream->getline())) {
        if ($Line =~ /^\#/ || $Line =~ /^ *$/) { next } # Skip blanks & comments
        my @Values = split($SplitRE, $Line);
        $Values[$#Values] =~ s/\r?\n//;
        push(@$Array, \@Values);
    }
    $Stream->close();
    return $Array;
}

################################################################################
# Name:
#   ReadArrayFromFile - Create an array from a file, one element per line.
# Synopsis:
#   string \@ReadArrayFromFile(string $FileName,
#                              [string $Mode], [string $Layer]);
# Example:
#   $ArrayRef = ReadArrayFromFile('/tmp/index.txt');
# Arguments:
#   string $FileName    Name of the file to read.  Any non-blank line in the
#                       file becomes an element of the array.  Lines beginning
#                       with '#' are ignored and whitespace is trimmed from
#                       each element.
#   $Mode               Read mode, e.g. '<' or 'r' to read.  Default: '<'.
#   $Layer              I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#                       ':encoding(gb2312)'.
# Return:
#   Reference to the new array or undef on error.
################################################################################
sub ReadArrayFromFile {
    my $Stream = OpenInStream(@_);
    unless (defined($Stream)) { return undef }

    my @Array = ();
    my $Line;
    while (defined($Line = $Stream->getline())) {
        if ($Line =~ /^\#/) { next }                           # Ignore comments
        Trim($Line);
        if (length($Line) > 0) { push(@Array, $Line) }
    }

    $Stream->close();
    return \@Array;
}

################################################################################
# Name:
#   ReadFile - Read an entire file into a string.
# Synopsis:
#   string \ReadFile(string $FileName, [string $Mode], [string $Layer]);
# Example:
#   $StrRef = ReadFile('/tmp/index.txt');
# Arguments:
#   $FileName   Name of the file to read.  '-' => STDIN.  Compressed files are
#               automatically recognized by their extensions and uncompressed
#               on-the-fly.
#   $Mode       Read mode, e.g. '<' or 'r' to read.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
#   $Password   Password for decrypting files.
# Return:
#   Reference to the new string or undef on error.
################################################################################
sub ReadFile {
    my $Stream = OpenInStream(@_);
    unless (defined($Stream)) { return undef }
    
    my $Line;
    my $String = '';
    while (defined($Line = $Stream->getline())) {
        $String .= $Line;
    }
    
    $Stream->close();
    return \$String;
}

################################################################################
# Name:
#   ReadHashFromFile - Create a hash from a file containing key/value pairs.
# Synopsis:
#   string \%ReadHashFromFile(hash \%Options, string $FileName,
#                             [string $Mode], [string $Layer]);
#                             
# Example:
#   $HashRef = ReadHashFromFile({}, '/tmp/index.txt');
# Arguments:
#   %Options    Hash of options.  Keys may include:
#                 HASH       Reference to a hash to which to add items from the
#                            specified file.  Default: Create a new empty hash.
#                 REPEAT     If keys repeat, the hash value becomes an array
#                            with the appended (unique) values.  Default:
#                            only last value encountered for each key is kept.
#                 SEPARATOR  Separator between the key and value in the file.
#                            Default: '='.
#   $FileName   Name of the file to read.  Any line in the file that contains a
#               key/value pair separated by the separator is parsed, and the
#               pair is added to the return hash.  Lines beginning with '#' are
#               ignored.
#   $Mode       Read mode, e.g. '<' or 'r' to read.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
# Return:
#   Reference to the new hash or undef on error.
################################################################################
sub ReadHashFromFile {
    my $Options = shift(@_);
    my ($Filename, $Hash, $Repeat, $Separator);
    if (exists($Options->{HASH})) {
        $Hash = $Options->{HASH};
    } else {
        $Hash = {};
    }
    if (exists($Options->{REPEAT})) {
        $Repeat = $Options->{REPEAT};
    } else {
        $Repeat = 0;
    }
    if (exists($Options->{SEPARATOR})) {
        $Separator = $Options->{SEPARATOR};
    } else {
        $Separator = '=';
    }
    my $SplitRE = qr/$Separator/;
    
    my $Stream = OpenInStream(@_);
    unless (defined($Stream)) { return undef }
    
    my ($Line, $Key, $Value);
    while (defined($Line = $Stream->getline())) {
        if ($Line =~ /^\#/) { next }                           # Ignore comments
        ($Key, $Value) = split($SplitRE, $Line, 2);
        unless (defined($Value)) { next }     # Ignore lines not matching format
        Trim($Key);
        Trim($Value);
        if ($Repeat && exists($Hash->{$Key})) {
            my @aValues;
            if (ref($Hash->{$Key})) {
                @aValues = @{$Hash->{$Key}};                        # Array copy
            } else {
                if ($Value eq $Hash->{$Key}) { next }      # Repeated value, too
                @aValues = ($Hash->{$Key});
            }
            push(@aValues, $Value);
            $Hash->{$Key} = UniqueE(\@aValues);
        } else {
            $Hash->{$Key} = $Value;
        }
    }
    $Stream->close();
    return $Hash;
}

################################################################################
# Name:
#   ReadHashKeysFromFile - Create a hash from a file, where each line becomes
#                          one key whose corresponding value is 1.
# Synopsis:
#   string \%ReadHashKeysFromFile(hash \%Options, string $FileName,
#                                 [string $Mode], [string $Layer]);
# Example:
#   $HashRef = ReadHashKeysFromFile({}, '/tmp/index.txt');
# Arguments:
#   %Options    Hash of options.  Keys may include:
#                 HASH       Reference to a hash to which to add items from the
#                            specified file.  Default: Create a new empty hash.
#                 LC         Convert each key to lowercase before storing it.
#                 SEPARATOR  Separator between the key and value in the file.
#                            Default: use the whole line as the key.
#   $FileName   Name of the file to read.  Any line in the file that contains a
#               key/value pair separated by the separator is parsed, and the
#               pair is added to the return hash.  Lines beginning with '#' are
#               ignored.
#   $Mode       Read mode, e.g. '<' or 'r' to read.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
# Return:
#   Reference to the new hash or undef on error.
################################################################################
sub ReadHashKeysFromFile {
    my $Options = shift(@_);
    my ($Filename, $Hash, $Lc, $Separator, $SplitRE);
    if (exists($Options->{HASH})) {
        $Hash = $Options->{HASH};
    } else {
        $Hash = {};
    }
    if (exists($Options->{LC})) {
        $Lc = $Options->{LC};
    } else {
        $Lc = 0;
    }
    if (exists($Options->{SEPARATOR})) {
        $Separator = $Options->{SEPARATOR};
        $SplitRE = qr/$Separator/;
    } else {
        $Separator = '';
    }

    my $Stream = OpenInStream(@_);
    unless (defined($Stream)) { return undef }

    my ($Key, $Line, $Value);
    if ($Separator eq '') {
        while (defined($Line = $Stream->getline())) {
            if ($Line =~ /^\#/) { next }                       # Ignore comments
            Trim($Line);
            if ($Lc) { $Line = lc($Line) }
            if (length($Line) > 0) { $Hash->{$Line} = 1 }
        }
    } else {
        while (defined($Line = $Stream->getline())) {
            if ($Line =~ /^\#/) { next }                       # Ignore comments
            ($Key, $Value) = split($SplitRE, $Line, 2);
            unless (defined($Value)) { next } # Ignore lines not matching format
            Trim($Key);
            if ($Lc) { $Key = lc($Key) }
            $Hash->{$Key} = 1;
        }
    }

    $Stream->close();
    return $Hash;
}

################################################################################
# Name:
#   ReadQueryList - Read and normalize a list of search queries.
# Synopsis:
#   string \%ReadQueryList(string $FileName, sub \&Normalize);
# Example:
#   $HashRef = ReadQueryList('QueryList.txt', \&NormalizeToGSQR);
# Arguments:
#   $FileName   Name of the file containing the keys.  Any non-blank line in the
#               file becomes a key in the hash.  The corresponding value is
#               always 1.  Lines beginning with '#' are ignored.
# Return:
#   Success => reference to hash, else 0.
################################################################################
sub ReadQueryList {
    my ($FileName, $Normalize) = @_;

    my $Hash = {};
    my $Stream = OpenInStream($FileName, '<', ':encoding(utf8)');
    unless (defined($Stream)) { return 0 }

    my $Line;
    while (defined($Line = $Stream->getline())) {
        Trim($Line);
        if ($Line =~ /^\#/) { next }                           # Ignore comments
        &$Normalize($Line);
        if ($Line eq '') { next }                                   # Blank line
        $Hash->{$Line} = 1
    }
    $Stream->close();
    return $Hash;
}

################################################################################
# Name:
#   UnzipSingleFile - Check whether a ZIP archive contains a single file
#                     and, if so, extract it.
# Synopsis:
#   UnzipSingleFile(string $Archive, string $NewName);
# Example:
#   UnzipSingleFile('Archive.zip', 'Content.txt');
# Arguments:
#   $Archive          Name of the archive file to process.
#   $NewName          New name of the extracted file.
# Return:
#   1 (success) or undef.
################################################################################
sub UnzipSingleFile {
    my ($Archive, $NewName) = @_;

    my $File;
    if (-e $NewName) { return undef }            # Don't overwrite existing file
    my ($StoredName, $Size) = UnzipSingleFileName($Archive);
    if (!defined($StoredName)) { return undef };
    my $Result = `unzip -p $Archive > $NewName`;
    my ($dev, $ino, $mode, $nlink, $uid, $gid, $rdev, $size,
        $atime, $mtime, $ctime, $blksize, $blocks)
        = stat($NewName);
    unless ($size == $Size) {
        print(STDERR "Size mismatch upon expanding $Archive\n");
        return undef;
    }
    unlink($Archive);
    return 1;
}

################################################################################
# Name:
#   UnzipSingleFileName - Check whether a ZIP archive contains a single file
#                         and, if so, return the name of that file.
# Synopsis:
#   (string $Name, int $Size) UnzipSingleFileName(string $Archive);
# Example:
#   ($Name, $Size) = UnzipSingleFileName('Archive.zip');
# Arguments:
#   $Archive          Name of the archive file to check.
# Return:
#   Array of name and size of the file, or undef on failure.
################################################################################
sub UnzipSingleFileName {
    my $Archive = $_[0];

    unless (-f $Archive) {
        print(STDERR "File $Archive not found.\n");
        return undef;
    }
    my $Result = `unzip -l $Archive`;
    unless ($Result =~ /^Archive:.*\n\s*Length\s+Date\s+Time\s+Name\s*\n\s*-+\s+-+\s+-+\s+-+\s*\n(.*)\s*\n\s*-+\s+-+\s*\n/s) {
        print(STDERR "Odd result unzipping $Archive.\n");
        return undef;
    }
    $Result = $1;
    if ($Result =~ /\n/) {
        print(STDERR "Multiple files in $Archive.\n");
        return undef;
    }
    unless ($Result =~ /^\s*(\d+)\s+\d{2}-\d{2}-\d{2}\s+\d{2}:\d{2}\s*(.*)$/) {
        print(STDERR "Odd record format in $Archive:\n    $Result\n");
        return undef;
    }
    return ($2, $1);
}

################################################################################
# Name:
#   WriteAoA - Write an array of arrays to a file.
# Synopsis:
#   int WriteAoA(array \@rAoA, string $FileName, [hash \%Options]);
# Example:
#   WriteAoA(\%Hash, '/tmp/AoA.tsv');
# Arguments:
#   \@rAoA      Reference to the structure to write out.  Required.
#   $FileName   Name of the file to write.  Required.
#   %Options    Hash of options.  Keys may include:
#                 SEPARATOR  Separator between the array elements on each line.
#                            Default: "\t".
#                 MODE       I/O "mode", e.g. 'a' to append. Default: '>'.
#                 LAYER      I/O "layer" directive, e.g. ':utf8'. Default: none.
# Return:
#   Success => 1, error => 0.
################################################################################
sub WriteAoA {
    my ($rAoA, $FileName, $Options) = @_;

    unless (defined($Options)) { $Options = {} }
    my ($Mode, $Separator, $Stream, $rArray);
    if (exists($Options->{MODE})) {
        $Mode = $Options->{MODE};
    } else {
        $Mode = '>';
    }
    if (exists($Options->{LAYER})) {
        $Stream = OpenOutStream($FileName, $Mode, $Options->{LAYER});
    } else {
        $Stream = OpenOutStream($FileName, $Mode);
    }
    unless (defined($Stream)) { return 0 }
    if (exists($Options->{SEPARATOR})) {
        $Separator = $Options->{SEPARATOR};
    } else {
        $Separator = "\t";
    }

    foreach $rArray (@$rAoA) {
        $Stream->print(join($Separator, @$rArray), "\n");
    }
    $Stream->close();
    return 1;
}

################################################################################
# Name:
#   WriteHashKeysToFile - Write a hashes keys to a file, one per line.
# Synopsis:
#   int WriteHashKeysToFile(misc \%Hash, string $FileName, string $Sort);
# Example:
#   WriteHashKeysToFile(\%Hash, '/tmp/keys.txt');
# Arguments:
#   \%Hash            Reference to the hash to write out.  Required.
#   $FileName         Name of the file to write.  Required.
#   $Sort             'klex'  => Sort records by key, standard string order.
#                     'krlex' => Sort records by key, reverse string order.
#                     'knum'  => Sort records by key, standard numeric order.
#                     'krnum' => Sort records by key, reverse numeric order.
#                     Default => don't sort the keys.
# Return:
#   Success => 1, error => 0.
################################################################################
sub WriteHashKeysToFile {
    my ($HashRef, $FileName, $Sort) = @_;
    
    my $Stream = OpenOutStream($FileName);
    unless (defined($Stream)) { return 0 }

    my @Keys;
    my $OutStr;
    if (exists($p_sortfn{$Sort})) {
        my $rSub = $p_sortfn{$Sort};
        $OutStr = join("\n", sort($rSub keys(%$HashRef)));
    } else {
        $OutStr = join("\n", keys(%$HashRef));
    }

    if (length($OutStr)) { $Stream->print($OutStr . "\n") }
    $Stream->close();
    return 1;
}

################################################################################
# Name:
#   WriteHashToFile - Write a hash to a file, one key/value pair per line.
# Synopsis:
#   int WriteHashToFile(misc \%Hash, string $FileName, [string $Separator,
#                       string $Sort);
# Example:
#   WriteHashToFile(\%Hash, '/tmp/index.txt');
# Arguments:
#   \%Hash            Reference to the hash to write out.  Required.
#   $FileName         Name of the file to write.  Required.
#   $Separator        Separator between each key and value in the file.
#                     Default: ' = '.
#   $Sort             'klex'  => Sort records by key, standard string order.
#                     'knum'  => Sort records by key, standard numeric order.
#                     'krlex' => Sort records by key, reverse string order.
#                     'krnum' => Sort records by key, reverse numeric order.
#                     'vlex'  => Sort records by value, standard string order.
#                     'vlexklex'   => Same as above, use key as 2ndary sort key.
#                     'vlexknum'   => Same as above, use key as 2ndary sort key.
#                     'vlexkrlex'  => Same as above, use key as 2ndary sort key.
#                     'vlexkrnum'  => Same as above, use key as 2ndary sort key.
#                     'vnum'  => Sort records by value, standard numeric order.
#                     'vnumklex'   => Same as above, use key as 2ndary sort key.
#                     'vnumknum'   => Same as above, use key as 2ndary sort key.
#                     'vnumkrlex'  => Same as above, use key as 2ndary sort key.
#                     'vnumkrnum'  => Same as above, use key as 2ndary sort key.
#                     'vrlex' => Sort records by value, reverse string order.
#                     'vrlexklex'  => Same as above, use key as 2ndary sort key.
#                     'vrlexknum'  => Same as above, use key as 2ndary sort key.
#                     'vrlexkrlex' => Same as above, use key as 2ndary sort key.
#                     'vrlexkrnum' => Same as above, use key as 2ndary sort key.
#                     'vrnum' => Sort records by value, reverse numeric order.
#                     'vrnumklex'  => Same as above, use key as 2ndary sort key.
#                     'vrnumknum'  => Same as above, use key as 2ndary sort key.
#                     'vrnumkrlex' => Same as above, use key as 2ndary sort key.
#                     'vrnumkrnum' => Same as above, use key as 2ndary sort key.
#                     Default => don't sort the keys.
# Return:
#   Success => 1, error => 0.
################################################################################
sub WriteHashToFile {
    my ($HashRef, $FileName, $Separator, $Sort) = @_;
    
    my $Stream = OpenOutStream($FileName);
    unless (defined($Stream)) { return 0 }

    if (!defined($Separator)) { $Separator = ' = ' }
    
    my ($Key, $Value);
    if (!defined($Sort)) {
        while (($Key, $Value) = each(%$HashRef)) {
            $Stream->print("$Key$Separator$Value\n");
        }
        $Stream->close();
        return 1;
    }
    my @SortedKeys;
    if (exists($p_sortfn{$Sort})) {
        my $rSub = $p_sortfn{$Sort};
        @SortedKeys = sort($rSub keys(%$HashRef));
    } elsif ($Sort eq 'vlex') {
        @SortedKeys = sort({ $HashRef->{$a} cmp $HashRef->{$b} }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vlexklex') {
        @SortedKeys = sort({ $HashRef->{$a} cmp $HashRef->{$b} || $a cmp $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vlexknum') {
        @SortedKeys = sort({ $HashRef->{$a} cmp $HashRef->{$b} || $a <=> $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vlexkrlex') {
        @SortedKeys = sort({ $HashRef->{$a} cmp $HashRef->{$b} || $b cmp $a }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vlexkrnum') {
        @SortedKeys = sort({ $HashRef->{$a} cmp $HashRef->{$b} || $b <=> $a }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vnum') {
        @SortedKeys = sort({ $HashRef->{$a} <=> $HashRef->{$b} }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vnumklex') {
        @SortedKeys = sort({ $HashRef->{$a} <=> $HashRef->{$b} || $a cmp $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vnumknum') {
        @SortedKeys = sort({ $HashRef->{$a} <=> $HashRef->{$b} || $a <=> $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vnumkrlex') {
        @SortedKeys = sort({ $HashRef->{$a} <=> $HashRef->{$b} || $b cmp $a }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vnumkrnum') {
        @SortedKeys = sort({ $HashRef->{$a} <=> $HashRef->{$b} || $b <=> $a }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrlex') {
        @SortedKeys = sort({ $HashRef->{$b} cmp $HashRef->{$a} }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrlexklex') {
        @SortedKeys = sort({ $HashRef->{$b} cmp $HashRef->{$a} || $a cmp $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrlexknum') {
        @SortedKeys = sort({ $HashRef->{$b} cmp $HashRef->{$a} || $a <=> $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrlexkrlex') {
        @SortedKeys = sort({ $HashRef->{$b} cmp $HashRef->{$a} || $b cmp $a }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrlexkrnum') {
        @SortedKeys = sort({ $HashRef->{$b} cmp $HashRef->{$a} || $b <=> $a }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrnum') {
        @SortedKeys = sort({ $HashRef->{$b} <=> $HashRef->{$a} }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrnumklex') {
        @SortedKeys = sort({ $HashRef->{$b} <=> $HashRef->{$a} || $a cmp $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrnumknum') {
        @SortedKeys = sort({ $HashRef->{$b} <=> $HashRef->{$a} || $a <=> $b }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrnumkrlex') {
        @SortedKeys = sort({ $HashRef->{$b} <=> $HashRef->{$a} || $b cmp $a }
                           keys(%$HashRef));
    } elsif ($Sort eq 'vrnumkrnum') {
        @SortedKeys = sort({ $HashRef->{$b} <=> $HashRef->{$a} || $b <=> $a }
                           keys(%$HashRef));
    }
    foreach $Key (@SortedKeys) {
        $Stream->print("$Key$Separator$HashRef->{$Key}\n");
    }
    $Stream->close();
    return 1;
}

################################################################################
# Name:
#   WriteStringToFile - Write a string to file.
# Synopsis:
#   int WriteStringToFile(string \$String, string $FileName,
#                         [string $Mode], [string $Layer]);
# Example:
#   WriteStringToFile(\"Hello\n", '/tmp/index.txt');
# Arguments:
#   $String     Reference to the string to write.
#   $FileName   Name of the file to open.  '-' => STDOUT.  Compressed file types
#               are automatically recognized by their extensions and compressed
#               on-the-fly.
#   $Mode       Write mode, e.g. 'a' to append, '>' or 'w' to overwrite.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8',
#               ':encoding(gb2312)'.
# Return:
#   Success => 1, error => 0.
# Notes:
#   If the file already exists, it will be overwritten.
################################################################################
sub WriteStringToFile {
    my $StringRef = shift();
    
    my $Stream = OpenOutStream(@_);
    unless (defined($Stream)) { return 0 }

    $Stream->print($$StringRef);
    
    $Stream->close();
    return 1;
}

################################################################################
# Sort routines for WriteHashKeysToFile(), WriteHashToFile().  Must be in same
# file (FileUtilities.pm) because sort() "bypasses the normal calling code for
# subroutines".
################################################################################
sub sortfn_klex { $a cmp $b }
sub sortfn_knum { $a <=> $b }
sub sortfn_krlex { $b cmp $a }
sub sortfn_krnum { $b <=> $a }

1;
