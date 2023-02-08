################################################################################
# Name:
#   ArrayUtilities - Utilities for dealing with Perl arrays.
# Notes:
#   * Be sure to set PERL5LIB (colon-separated) appropriately to ensure that
#     Perl can find all of the modules used below.
#   * Naming conventions:
#       E       Arbitrary elements.
#       GE      Grouped elements.
#       GN      Grouped numbers.
#       N       Numbers.
#       SN      Sorted numbers.
#       UE      Elements are unique (occur only once) in each input array.
#       _IP     In place.
################################################################################
package ArrayUtilities;
use strict;
require Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(AverageN
             BinarySearchString
             DifferenceSN
             DoIntersectE
             DoIntersectSN
             FilterE
             FSSPush
             IntersectSN
             IntersectUE
             MaxFreqE
             MaxN
             MinN
             MinS
             SumN
             SortUniqueN
             StringPermutations
             Union
             UnionSN
             UnionSN_IP
             UniqueE
             UniqueGE
             UniqueGN);

################################################################################
# Name:
#   AverageN - Compute average of an array of numbers.
# Synopsis:
#   float $Result = AverageN(num @Array1);
# Example:
#   $Mean = AverageN(@Array1);
# Arguments:
#   @Array1     Array to process.
# Return:
#   Floating point mean value or 0 for a zero-length array.
################################################################################
sub AverageN {
    if (scalar(@_) == 0) {
        return 0;
    } else {
        return SumN(@_) / scalar(@_);
    }
}

################################################################################
# Name:
#   BinarySearchString - Finds the string in the sorted array that is closest
#                        to (less than or equal to) the query.
# Synopsis:
#   int $Index = BinarySearchString(string \@Array, string $Query);
# Example:
#   $Index = BinarySearchString(\@Array, $Query);
# Arguments:
#   \@Array     Reference to the array to search.
#   $Query      Query string.
# Return:
#   -1 => the search string is less than all strings in the array, else the
#   index of the nearest (less than or equal) element.
################################################################################
sub BinarySearchString {
    my ($Array, $Query) = @_;

    my $First = 0;
    my $Mid;
    my $Last = $#$Array;
    while ($First <= $Last) {
        $Mid = int(($First + $Last) / 2);
        if ($Query gt $Array->[$Mid]) {
            $First = $Mid + 1;
        } elsif ($Query lt $Array->[$Mid]) {
            $Last = $Mid - 1;
        } else {
            return $Mid;
        }
    }
    return $Last;
}

################################################################################
# Name:
#   DoIntersectE - Checks whether two arrays of arbitrary elements contain any
#                  shared values.
# Synopsis:
#   int $Result = DoIntersectE(string \@Array1, string \@Array2);
# Example:
#   $Unique = DoIntersectE(\@Array1, \@Array2);
# Arguments:
#   \@Array1    Reference to the first array.
#   \@Array2    Reference to the second array.
# Return:
#   1 => there are shared elements, else 0.
# Note:
#   n*m comparisons -- only best if one of the arrays is small.
################################################################################
sub DoIntersectE {
    my ($Array1, $Array2) = @_;

    my ($i, $j);
    for ($i = 0; $i < @$Array1; ++$i) {
        for ($j = 0; $j < @$Array2; ++$j) {
            if ($Array1->[$i] eq $Array2->[$j]) { return 1 }
        }
    }
    return 0;
}

################################################################################
# Name:
#   DoIntersectSN - Checks whether two arrays of sorted numbers contain any
#                   shared values.
# Synopsis:
#   int $Result = DoIntersectSN(num \@Array1, num \@Array2);
# Example:
#   $Unique = DoIntersectSN(\@Array1, \@Array2);
# Arguments:
#   \@Array1    Reference to the first array.
#   \@Array2    Reference to the second array.
# Return:
#   1 => there are shared elements, else 0.
################################################################################
sub DoIntersectSN {
    my ($Array1, $Array2) = @_;

    my $i1 = 0;
    my $i2 = 0;
    my $Result;
    if (@$Array1 == 0 || @$Array2 == 0) { return 0 }
    while (1) {
        $Result = ($Array1->[$i1] <=> $Array2->[$i2]);
        if ($Result == 0) {
            return 1;
        } elsif ($Result == -1) {
            ++$i1;
            if ($i1 >= @$Array1) { return 0 }
        } else {
            ++$i2;
            if ($i2 >= @$Array2) { return 0 }
        }
    }
}

################################################################################
# Name:
#   DifferenceSN - Determine set of elements that occur in one array of sorted
#                  numbers but not in another (set difference operation).
# Synopsis:
#   num \@Result = DifferenceSN(num \@Array1, num \@Array2);
# Example:
#   $Diff = DifferenceSN(\@Array1, \@Array2);
# Arguments:
#   \@Array1    Reference to the first array.
#   \@Array2    Reference to the second array.
# Return:
#   Reference to the resulting array (empty if input arrays do not difference).
# Notes:
#   * Repeated values in the first input array are repeated in the output array
#     to the extent that they are not removed by repeated values in the second
#     input array.
#   * May someday implement the "symmetric difference" operation
#     (union - intersection).
################################################################################
sub DifferenceSN {
    my ($Array1, $Array2) = @_;

    my $i1 = 0;
    my $i2 = 0;
    my @Out = ();
    my $Result;
    while (1) {
        if ($i1 >= @$Array1) { return \@Out }
        if ($i2 >= @$Array2) {
            push(@Out, @$Array1[$i1 .. $#$Array1]);                # Copy values
            return \@Out;
        }
        $Result = ($Array1->[$i1] <=> $Array2->[$i2]);
        if ($Result == 0) {
            ++$i1; ++$i2;
        } elsif ($Result == -1) {
            push(@Out, $Array1->[$i1++]);
        } else {
            ++$i2;
        }
    }
}

################################################################################
# Name:
#   FSSPush - Push values onto a fixed-size stack (array).
# Synopsis:
#   FSSPush(misc \@Array, int $Size, misc @Items);
# Example:
#   FSSPush($rArray, 1000, @Stuff);
# Arguments:
#   \@Array     Reference to array onto which to push.
#   $Size       Size of the stack (number of items to accomodate)
#   @Items      Items to push onto the stack.
# Return:
#   None
################################################################################
sub FSSPush {
    my $rArray = shift();
    my $Size = shift();

    push(@$rArray, @_);
    while (@$rArray > $Size) {
        shift(@$rArray);              # Remove excess records from front of list
    }
}

################################################################################
# Name:
#   FilterE - Remove elements from array that do not occur as keys in a hash.
# Synopsis:
#   type \@OutputArray = FilterE(type \@InputArray, int \%Hash);
# Example:
#   $TFeats = FilterE($TFeats, $hTLegitFeats);
# Arguments:
#   \@InputArray        Reference to the input array.
#   \%Hash              Hash with keys to use for filtering.
# Return:
#   Reference to the (anonymous) output array.
# Note:
#   Repeated values in the input array are repeated in the output array.
################################################################################
sub FilterE {
    my ($InputArray, $Hash) = @_;

    my $iElem;
    my @Out = ();
    for ($iElem = 0; $iElem < @$InputArray; ++$iElem) {
        if (exists($Hash->{$InputArray->[$iElem]})) {
            push(@Out, $InputArray->[$iElem]);
        }
    }
    return \@Out;
}

################################################################################
# Name:
#   IntersectUE - Intersects an array of arrays of scalars, where each element
#                 of the first input array occurs at most once in each input
#                 array.
# Synopsis:
#   scalar \@Result = IntersectUE(Array \@Arrays);
# Example:
#    my $Result = IntersectUE([values %nameCands]);
# Arguments:
#   \@Arrays    Reference to an array of arrays
# Return:
#   Reference to the resulting array (empty if input arrays do not intersect).
# Note:
#   * Values must be valid hash keys (scalars).
#   * The order of elements in the results array is the same as in the first
#     input array.
################################################################################
sub IntersectUE {
    my $Arrays = $_[0];
    my $nArrays = scalar(@$Arrays);
    my %Seen = ();
    my ($Array, $Value);
    foreach $Array (@$Arrays) {
        foreach $Value (@$Array) {
            ++$Seen{$Value};
        }
    }
    return [grep({$Seen{$_} eq $nArrays} @{$Arrays->[0]})];
}

################################################################################
# Name:
#   IntersectSN - Intersects two arrays of sorted numbers.
# Synopsis:
#   num \@Result = IntersectSN(num \@Array1, num \@Array2);
# Example:
#   $Unique = IntersectSN(\@Array1, \@Array2);
# Arguments:
#   \@Array1    Reference to the first array.
#   \@Array2    Reference to the second array.
# Return:
#   Reference to the resulting array (empty if input arrays do not intersect).
# Note:
#   Repeated  values in the input arrays are also repeated in the output array.
################################################################################
sub IntersectSN {
    my ($Array1, $Array2) = @_;

    my $i1 = 0;
    my $i2 = 0;
    my @Out = ();
    my $Result;
    if (@$Array1 == 0 || @$Array2 == 0) { return \@Out }
    while (1) {
        $Result = ($Array1->[$i1] <=> $Array2->[$i2]);
        if ($Result == 0) {
            push(@Out, $Array1->[$i1]);
            if (++$i1 >= @$Array1 || ++$i2 >= @$Array2) { last }
        } elsif ($Result == -1) {
            if (++$i1 >= @$Array1) { last }
        } else {
            if (++$i2 >= @$Array2) { last }
        }
    }
    return \@Out;
}

################################################################################
# Name:
#   MaxFreqE - Returns the most frequent element of the array.
# Synopsis:
#   type $Element = MaxFreqE(type \@InputArray);
# Example:
#   $MaxFreq = MaxFreqE(\@InputArray);
# Arguments:
#   \@InputArray        Reference to the input array.
# Return:
#   Most frequent value in the array.
################################################################################
sub MaxFreqE {
    my $InputArray = $_[0];

    my $Elem;
    my %UniqueHash = ();
    foreach $Elem (@$InputArray) {
        ++$UniqueHash{$Elem};
    }
    my ($Count, $MaxFreqElem);
    my $Max = 0;
    while (($Elem, $Count) = each(%UniqueHash)) {
        if ($Count > $Max) {
            $Max = $Count;
            $MaxFreqElem = $Elem;
        }
    }
    return $MaxFreqElem;
}

################################################################################
# Name:
#   MaxN - Find the maximum value in a list of numbers.
# Synopsis:
#   MaxN(num @Item);
# Example:
#   $MaxVal = MaxN(12, 34, 1);
# Arguments:
#   @Item       List of numbers.
# Return:
#   Largest value from the list.
################################################################################
sub MaxN {
    my $Result = $_[0];
    for (my $i = 1; $i < @_; ++$i) {
        if ($_[$i] > $Result) { $Result = $_[$i] }
    }
    return $Result;
}

################################################################################
# Name:
#   MinN - Find the minimum value in a list of numbers.
# Synopsis:
#   MinN(num @Item);
# Example:
#   $MinVal = MinN(12, 34, 1);
# Arguments:
#   @Item       List of numbers.
# Return:
#   Smallest value from the list.
################################################################################
sub MinN {
    my $Result = $_[0];
    for (my $i = 1; $i < @_; ++$i) {
        if ($_[$i] < $Result) { $Result = $_[$i] }
    }
    return $Result;
}

################################################################################
# Name:
#   MinS - Find the minimum value in a list of strings.
# Synopsis:
#   MinS(string @Item);
# Example:
#   $MinVal = MinS('2004-01-23', '2008-02-22');
# Arguments:
#   @Item       List of strings.
# Return:
#   Smallest value from the list.
################################################################################
sub MinS {
    my $Result = $_[0];
    for (my $i = 1; $i < @_; ++$i) {
        if ($_[$i] lt $Result) { $Result = $_[$i] }
    }
    return $Result;
}

################################################################################
# Name:
#   SortUniqueN - Returns a reference to an array of the unique (and sorted)
#                 values of the input array.
# Synopsis:
#   num \@OutputArray = SortUniqueN(num \@InputArray);
# Example:
#   $Unique = SortUniqueN(\@InputArray);
# Arguments:
#   \@InputArray        Reference to the input array.
# Return:
#   Reference to the (anonymous) output array.
################################################################################
sub SortUniqueN {
    my $InputArray = $_[0];

    my @SortedNumbers = sort({$a <=> $b} @$InputArray);
    return UniqueGN(\@SortedNumbers);
}

################################################################################
# Name:
#   StringPermutations - Create a set of strings.
# Synopsis:
#   StringPermutations(array \@Arrays);
# Example:
#   $A = StringPermutations(['A', 'B'], ['D'], ['A', 'B']);
# Arguments:
#   Array of array references, each defining one dimension.
# Return:
#   Reference to array of strings.
################################################################################
sub StringPermutations {
    my $A0 = [''];                                                 # One element
    my $A1 = [];                                                   # No elements
    foreach my $Dim (@_) {
        foreach my $Key (@$Dim) {
            foreach my $String (@$A0) {
                push(@$A1, $String . $Key);
            }
        }
        $A0 = $A1;
        $A1 = [];
    }
    return $A0;
}

################################################################################
# Name:
#   SumN - Compute sum of an array of numbers.
# Synopsis:
#   float $Result = SumN(num @Array1);
# Example:
#   $Sum = SumN(@Array1);
# Arguments:
#   @Array1     Array to process.
# Return:
#   Sum value or 0 for a zero-length array.
################################################################################
sub SumN {
    my $Sum = 0;
    for (my $i = 0; $i < @_; ++$i) {
        $Sum += $_[$i];
    }
    return $Sum;
}

################################################################################
# Name:
#   Union - Returns the union of a list of lists.
# Synposis:
#   misc \@Union(misc @@lists);
# Example:
#   $union = Union(\@list1, \@list2, \@list3);
# Explicit arguments:
#   @lists      A list of references to lists.
# Return:
#   A reference to a new array containing the union of the input lists.
################################################################################
sub Union {
    my %Seen = ();
    my ($Elem, $rList);
    foreach $rList (@_) {
        foreach $Elem (@$rList) {
            $Seen{$Elem} = 1;
        }
    }
    my @Keys = keys(%Seen);
    return \@Keys;
}

################################################################################
# Name:
#   UnionSN - Computes union of two arrays of sorted numbers.
# Synopsis:
#   num \@Result = UnionSN(num \@Array1, num \@Array2);
# Example:
#   $Unique = UnionSN(\@Array1, \@Array2);
# Arguments:
#   \@Array1    Reference to the first array.
#   \@Array2    Reference to the second array.
# Return:
#   Reference to the resulting array.
# Notes:
#   * Output array is also sorted.
#   * Repeated values in the input arrays are also repeated in the output array.
################################################################################
sub UnionSN {
    my ($Array1, $Array2) = @_;

    my @Out = ();
    if (@$Array1 == 0) {
        @Out = @$Array2;                                           # Copy values
        return \@Out;
    }
    if (@$Array2 == 0) {
        @Out = @$Array1;                                           # Copy values
        return \@Out;
    }
    my $i1 = 0;
    my $i2 = 0;
    my $Result;
    while (1) {
        $Result = ($Array1->[$i1] <=> $Array2->[$i2]);
        if ($Result == 0) {
            push(@Out, $Array1->[$i1]);
            ++$i1;
            ++$i2;
            if ($i1 >= @$Array1) {
                unless ($i2 >= @$Array2) {
                    push(@Out, @$Array2[$i2 .. $#$Array2]);
                }
                last;
            }
            if ($i2 >= @$Array2) {
                push(@Out, @$Array1[$i1 .. $#$Array1]);
                last;
            }
        } elsif ($Result == -1) {
            push(@Out, $Array1->[$i1]);
            if (++$i1 >= @$Array1) {
                push(@Out, @$Array2[$i2 .. $#$Array2]);
                last;
            }
        } else {
            push(@Out, $Array2->[$i2]);
            if (++$i2 >= @$Array2) {
                push(@Out, @$Array1[$i1 .. $#$Array1]);
                last;
            }
        }
    }
    return \@Out;
}

################################################################################
# Name:
#   UnionSN_IP - Computes union of two arrays of sorted numbers, merging
#                additional items from the second into the first ("in place").
# Synopsis:
#   UnionSN_IP(num \@Array1, num \@Array2);
# Example:
#   UnionSN_IP(\@Array1, \@Array2);
# Arguments:
#   \@Array1    Reference to the first array.
#   \@Array2    Reference to the second array.
# Return:
#   None.
# Notes:
#   * Resulting array is also sorted.
#   * Repeated values in the input arrays are also repeated in the output array.
################################################################################
sub UnionSN_IP {
    my ($Array1, $Array2) = @_;

    if (@$Array2 == 0) {
        return;
    }
    if (@$Array1 == 0) {
        splice(@$Array1, 0, 0, @$Array2);
        return;
    }

    my $i1 = 0;
    my $i2 = 0;
    my $Result;
    while (1) {
        $Result = ($Array1->[$i1] <=> $Array2->[$i2]);
        if ($Result == 0) {
            ++$i1;
            ++$i2;
            if ($i2 >= @$Array2) { last }
            if ($i1 >= @$Array1) {
                splice(@$Array1, $i1, 0, @$Array2[$i2 .. $#$Array2]);
                last;
            }
        } elsif ($Result == -1) {
            if (++$i1 >= @$Array1) {
                splice(@$Array1, $i1, 0, @$Array2[$i2 .. $#$Array2]);
                last;
            }
        } else {
            splice(@$Array1, $i1, 0, $Array2->[$i2]);
            ++$i1;
            if (++$i2 >= @$Array2) { last }
        }
    }
}

################################################################################
# Name:
#   UniqueE - Returns a reference to an array of the unique values of the input
#             array (with arbitrary elements), preserving order of the elements.
# Synopsis:
#   type \@OutputArray = UniqueE(type \@InputArray);
# Example:
#   $Unique = UniqueE(\@InputArray);
# Arguments:
#   \@InputArray        Reference to the input array.
# Return:
#   Reference to the (anonymous) output array.
################################################################################
sub UniqueE {
    my $InputArray = $_[0];

    my $iElem;
    my %UniqueHash = ();
    my @UniqueArray = ();
    for ($iElem = 0; $iElem < @$InputArray; ++$iElem) {
        unless (exists($UniqueHash{$InputArray->[$iElem]})) {
            $UniqueHash{$InputArray->[$iElem]} = 1;
            push(@UniqueArray, $InputArray->[$iElem]);
        }
    }
    return \@UniqueArray;
}

################################################################################
# Name:
#   UniqueGE - Returns a reference to an array of the unique elements of the
#              input array, which must already be arranged (e.g. sorted) in such
#              a way that equal values are grouped), preserving the order of the
#              elements.
# Synopsis:
#   string \@OutputArray = UniqueGE(string \@InputArray);
# Example:
#   $Unique = UniqueGE(\@InputArray);
# Arguments:
#   \@InputArray        Reference to the input array.
# Return:
#   Reference to the (anonymous) output array.
################################################################################
sub UniqueGE {
    my $InputArray = $_[0];

    my $iElem;
    my $Prev = $InputArray->[0];
    my @UniqueArray = ();
    for ($iElem = 0; $iElem < @$InputArray; ++$iElem) {
        if ($InputArray->[$iElem] ne $Prev) {
            push(@UniqueArray, $Prev);
            $Prev = $InputArray->[$iElem];
        }
    }
    push(@UniqueArray, $Prev);
    return \@UniqueArray;
}

################################################################################
# Name:
#   UniqueGN - Returns a reference to an array of the unique elements of the
#              input array, which must already be arranged (e.g. sorted) in such
#              a way that equal values are grouped), preserving the order of the
#              elements.
# Synopsis:
#   num \@OutputArray = UniqueGN(num \@InputArray);
# Example:
#   $Unique = UniqueGN(\@InputArray);
# Arguments:
#   \@InputArray        Reference to the input array.
# Return:
#   Reference to the (anonymous) output array.
################################################################################
sub UniqueGN {
    my $InputArray = $_[0];

    my $iElem;
    my $Prev = $InputArray->[0];
    my @UniqueArray = ();
    for ($iElem = 0; $iElem < @$InputArray; ++$iElem) {
        if ($InputArray->[$iElem] != $Prev) {
            push(@UniqueArray, $Prev);
            $Prev = $InputArray->[$iElem];
        }
    }
    push(@UniqueArray, $Prev);
    return \@UniqueArray;
}

1;
