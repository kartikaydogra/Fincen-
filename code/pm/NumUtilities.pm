################################################################################
# Name:
#   NumUtilities - Utilities for dealing with numbers.
# Notes:
#   * Be sure to set PERL5LIB (colon-separated) appropriately to ensure that
#     Perl can find all of the modules used below.
#
# Copyright Matthias Blume 2002-2012, All Rights Reserved.
################################################################################
package NumUtilities;
use strict;
use Scalar::Util qw(looks_like_number);

require Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(Digits2
             LoanPayment
             Round
             SafeDivide);

################################################################################
# Name:
#   Digits2 - Round a number to two digits after the decimal point.
# Synopsis:
#   num $Result = Digits2(num $Input);
# Example:
#   $MonthlyPayment = Digits2(0.0999);                                    # 0.10
# Arguments:
#   $Input        The value to round.
# Return:
#   The rounded value.
################################################################################
sub Digits2 {
    if (looks_like_number($_[0])) {
        my $String = sprintf('%.2f', $_[0]);
        if ($String eq '0.00') {
            return 0;
        } else {
            return $String;
        }
    } else {
        return $_[0];
    }
}

################################################################################
# Name:
#   LoanPayment - Calculate the payment amount for a loan, like Excel's PMT().
# Synopsis:
#   num $Result = LoanPayment(num $RatePP, int $nPayments, num $Principal);
# Example:
#   $MonthlyPayment = LoanPayment(0.0999/12, 48, 4500);  # 9.99% annual interest
# Arguments:
#   $RatePPP      The interest rate /per payment period/ for the loan.
#   $nPayments    The total number of payments for the loan.
#   $Principal    The loan amount.  Represented as a positive number vs. a
#                 negative number in Excel's PMT().
# Return:
#   The payment amount.
################################################################################
sub LoanPayment {
    my ($RatePPP, $nPayments, $Principal) = @_;

    my $tmp = (1 + $RatePPP) ** -$nPayments;
    my $Payment = 0;
    if ($tmp < 1) {
        $Payment = ($Principal * $RatePPP) / (1 - $tmp);
    } else {
        $Payment = $Principal / $nPayments;
    }
    return $Payment
}

################################################################################
# Name:
#   Round - Round a number to an integer.
# Synopsis:
#   int $Result = Round(num $Num);
# Example:
#   print(Round(-0.1), "\n");
# Arguments:
#   $Num        The number to round.
# Return:
#   The integer result.
################################################################################
sub Round {
    my $Num = $_[0];
    if ($Num < 0) {
        $Num -= 0.5;
    } else {
        $Num += 0.5;
    }
    return(int($Num));
}

################################################################################
# Name:
#   SafeDivide - Divide two numbers, returning the quotient or 'INF' if the
#                second number is zero.
# Synopsis:
#   string $Result = SafeDivide(num $Dividend, num $Divisor, [string $Format]);
# Example:
#   print(SafeDivide($X, $Y) . "\n");
# Arguments:
#   $Dividend   The number to divide.
#   $Divisor    The number to divide by.
#   $Format     sprintf() format specification (optional).
# Return:
#   Optionally formatted quotient or 'INF' if the divisor is zero.
################################################################################
sub SafeDivide {
    my ($Dividend, $Divisor, $Format) = @_;

    my $Quotient;
    if ($Divisor) {
        $Quotient = $Dividend / $Divisor;
    } else {
        if ($Dividend) {
            return 'INF';
        } else {
            $Quotient = 0;
        }
    }
    if ($Format) {
        return sprintf($Format, $Quotient);
    } else {
        return $Quotient;
    }
}

1;
