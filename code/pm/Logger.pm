################################################################################
# Name:
#   Logger - Perl class for run-time output of log messages.
# Notes:
#   * Logging types include:
#     + LMessage(): Log only if message level <= log level.
#     + MessageC(): Log count of identical messages (at end of program run).
#     + MessageK(): Log only first occurrence of message with specified key.
#     + MessageU(): Log only one copy of identical messages.
#   * Be sure to set PERL5LIB (colon-separated) appropriately to ensure that
#     Perl can find all of the modules used below.
################################################################################
package Logger;
use strict;

use FileUtilities;              # OpenOutStream()

################################################################################
# Name:
#   DESTROY - Destructor.
# Synopsis:
#   DESTROY();
# Example:
#   $Log->DESTROY();
# Arguments:
#   None.
# Return:
#   None.
# Notes:
#   Typically automatically called when the last reference to the object is
#   deleted.
################################################################################
sub DESTROY {
    my $self = $_[0];

    if (defined($self->{STREAM})) {
        $self->{STREAM}->close();
        delete($self->{STREAM});
    }
}

################################################################################
# Name:
#   EPrint - Output the specified information to STDERR and the log stream (if
#            defined) via print().
# Synopsis:
#   EPrint(misc @_);
# Examples:
#   $Logger->EPrint("This is the message.\n");
# Explicit arguments:
#   misc @_     Set of strings to print.
# Return:
#   None.
################################################################################
sub EPrint {
    my $self = shift();

    my $OutStr = join('', @_);
    if (defined($self->{PREFIX})) {
        $OutStr =~ s/(\r?\n)(?=.)/$1$self->{PREFIX}/g;
        $OutStr = $self->{PREFIX} . $OutStr;
    }
    print(STDERR $OutStr);
    unless (defined($self->{STREAM})) { return }
    $self->{STREAM}->print($OutStr);
}

################################################################################
# Name:
#   EPrintf - Output the specified information to the log stream (if defined)
#             and STDERR via printf().
# Synopsis:
#   EPrintf(misc @_);
# Examples:
#   $Logger->EPrintf("This is the message number: %d\n", $iMessage);
# Explicit arguments:
#   string $Format      EPrintf() format spec.
#   misc @_             Set of values to print -- passed through to printf().
# Return:
#   None.
################################################################################
sub EPrintf {
    my $self = shift();

    my $Format = shift();
    my $OutStr = sprintf($Format, @_);
    print(STDERR $OutStr);
    unless (defined($self->{STREAM})) { return }
    $self->print($OutStr);
}

################################################################################
# Name:
#   LEPrint - Print the specified message to STDERR and the log stream
#             if the message level is less than or equal to the log level.
# Synopsis:
#   LEPrint(int $Level, misc @_);
# Examples:
#   $Logger->LEPrint(3, "This is the message.\n");
# Explicit arguments:
#   int $Level          Message level.
#   misc @_     Set of strings to print.
# Return:
#   None.
################################################################################
sub LEPrint {
    my $self = shift();
    my $Level = shift();

    unless ($Level <= $self->{LEVEL}) { return }
    $self->EPrint(@_);
}

################################################################################
# Name:
#   LMessage - Print the specified message to the log stream (if defined) if the
#              message level is less than or equal to the log level.
# Synopsis:
#   LMessage(int $Level, [string @Values], string $Message);
# Examples:
#   $Logger->LMessage(3, 'This is the message');
#   $Logger->LMessage(3, 'OK', $FileName, $LineNum, 'This is the message');
# Explicit arguments:
#   int $Level          Message level.
#   string $Message     Message to print.
#   string @Values      Additional values to print preceding the message.
# Return:
#   None.
################################################################################
sub LMessage {
    my $self = shift();
    my $Level = shift();

    unless ($Level <= $self->{LEVEL}) { return }
    $self->Message(@_);
}

################################################################################
# Name:
#   LMessageK - Print the specified message to the log stream (if defined) if
#               the message level is less than or equal to the log level and
#               this is the first time this value of the specified key is seen.
# Synopsis:
#   LMessageK(int $Level, string $Key, [string @Values], string $Message);
# Examples:
#   $Logger->LMessageK(3, $Key, 'This is the message');
# Explicit arguments:
#   int $Level          Message level.
#   string $Key         Matching key.
#   string $Message     Message to print.
#   string @Values      Additional values to print preceding the message.
# Return:
#   None.
################################################################################
sub LMessageK {
    my $self = shift();
    my $Level = shift();

    unless ($Level <= $self->{LEVEL}) { return }
    $self->MessageK(@_);
}

################################################################################
# Name:
#   LPrint - Print the specified message to the log stream (if defined) via
#            print() if the message level is less than or equal to the log
#            level.
# Synopsis:
#   LPrint(int $Level, misc @_);
# Examples:
#   $Logger->LPrint(3, "This is the message\n");
# Explicit arguments:
#   int $Level          Message level.
#   misc @_             Set of strings to print.
# Return:
#   None.
################################################################################
sub LPrint {
    my $self = shift();
    my $Level = shift();

    unless ($Level <= $self->{LEVEL}) { return }
    $self->print(@_);
}

################################################################################
# Name:
#   LPrintf - Print the specified message to the log stream (if defined) via
#             printf() if the message level is less than or equal to the log
#             level.
# Synopsis:
#   LPrintf(int $Level, misc @_);
# Examples:
#   $Logger->LPrintf(3, "This is the message number: %d\n", $iMessage);
# Explicit arguments:
#   int $Level          Message level.
#   string $Format      printf() format spec.
#   misc @_             Set of values to print -- passed through to printf().
# Return:
#   None.
################################################################################
sub LPrintf {
    my $self = shift();
    my $Level = shift();

    unless ($Level <= $self->{LEVEL}) { return }
    $self->printf(@_);
}

################################################################################
# Name:
#   Message - Print the specified message to the log stream (if defined).
# Synopsis:
#   Message([string @Values], string $Message);
# Examples:
#   $Logger->Message('This is the message');
#   $Logger->Message('OK', $FileName, $LineNum, 'This is the message');
# Explicit arguments:
#   string $Message     Message to print.
#   string @Values      Additional values to print preceding the message.
# Return:
#   None.
################################################################################
sub Message {
    my $self = shift();
    my $Message = pop();

    unless (defined($self->{STREAM})) { return }
    
    my $OutStr;
    if (@_) {
        $OutStr = join(' ', @_) . ': ' . $Message;
    } else {
        $OutStr = $Message;
    }
    if (defined($self->{PREFIX})) {
        $OutStr =~ s/(\r?\n)/$1$self->{PREFIX}/g;
        $OutStr = $self->{PREFIX} . $OutStr;
    }
    $self->{STREAM}->print($OutStr . "\n");
}

################################################################################
# Name:
#   MessageK - Print the specified message to the log stream (if defined), but
#             only the first time for the specified key .
# Synopsis:
#   MessageK(string $Key, [string @Values], string $Message);
# Examples:
#   $Logger->MessageK($Key, 'This is the message');
# Explicit arguments:
#   string $Key         Matching key.
#   string @Values      Additional values to print preceding the message.
#   string $Message     Message to print.
# Return:
#   None.
################################################################################
sub MessageK {
    my $self = shift();
    my $Key = shift();

    if (defined($self->{KEYS}{$Key})) { return }
    $self->{KEYS}{$Key} = 1;
    $self->Message(@_);
}

################################################################################
# Name:
#   SetLogLevel - Set the log level.  Messages whose level is greater than this
#                 will not be generated.
# Synopsis:
#   SetLogLevel(int $Level);
# Examples:
#   $Logger->SetLogLevel(3);
# Explicit arguments:
#   int $Level          New log level.
# Return:
#   None.
################################################################################
sub SetLogLevel {
    my $self = $_[0];
    $self->{LEVEL} = $_[1];
}

################################################################################
# Name:
#   SetPrefix - Specify a string to output at the beginning of each line of a
#               log message.
# Synopsis:
#   SetPrefix(string $Prefix);
# Examples:
#   $Logger->SetPrefix("    Log -- ");
# Explicit arguments:
#   $Prefix     String to output at the beginning of each log message line.
# Return:
#   None.
# Note:
#   SetPrefix(undef) to stop adding a prefix.
################################################################################
sub SetPrefix {
    my $self = $_[0];
    $self->{PREFIX} = $_[1];
}

################################################################################
# Name:
#   new - Constructor.  Creates and initializes a new Logger object.
# Synopsis:
#   new(string $LogFile, [string $Mode], [string $Layer]);
#   new(stream $LogStream);
# Example:
#   $NewInstance = Logger->new($LogStream);
# Explicit arguments:
#   $LogFile    File to which to write log messages.
#   $Mode       Read mode, e.g. 'a' to append.  Default: '>'.
#   $Layer      I/O "layer" directive, e.g. ':bytes', ':crlf', ':utf8'
#       - or -
#   $LogStream  Stream to which to write log messages.
# Return:
#   Reference to the object hash.  If $LogStream is undefined, subsequent
#   messages will not be logged, but a valid Logger object will still be
#   created.
################################################################################
sub new {
    my $this = shift();
    my $class = ref($this) || $this;
    my $self = bless({}, $class);
    
    unless (defined($_[0])) { return $self }

    my $LogStream;
    if (ref($_[0])) {
        $LogStream = $_[0];
    } else {
        $LogStream = OpenOutStream(@_);
        unless (defined($LogStream)) { return $self }
    }

    $LogStream->autoflush(1);           # Write output right away, not in blocks
    $self->{LEVEL} = 0;
    $self->{STREAM} = $LogStream;                               # Save in object

    return $self;
}

################################################################################
# Name:
#   print - Output the specified information to the log stream (if defined)
#           via print().
# Synopsis:
#   print(misc @_);
# Examples:
#   $Logger->print("This is the message.\n");
# Explicit arguments:
#   misc @_     Set of strings to print.
# Return:
#   None.
################################################################################
sub print {
    my $self = shift();

    unless (defined($self->{STREAM})) { return }
    
    if (defined($self->{PREFIX})) {
        my $OutStr = join('', @_);
        $OutStr =~ s/(\r?\n)(?=.)/$1$self->{PREFIX}/g;
        $OutStr = $self->{PREFIX} . $OutStr;
        $self->{STREAM}->print($OutStr);
    } else {
        $self->{STREAM}->print(@_);
    }
}

################################################################################
# Name:
#   printf - Output the specified information to the log stream (if defined)
#            via printf().
# Synopsis:
#   printf(misc @_);
# Examples:
#   $Logger->printf("This is the message number: %d\n", $iMessage);
# Explicit arguments:
#   string $Format      printf() format spec.
#   misc @_             Set of values to print -- passed through to printf().
# Return:
#   None.
################################################################################
sub printf {
    my $self = shift();

    unless (defined($self->{STREAM})) { return }

    my $Format = shift();
    my $OutStr = sprintf($Format, @_);
    $self->print($OutStr);
}

1;
