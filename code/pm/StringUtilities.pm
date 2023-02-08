###############################################################################
# Name:
#   StringUtilities - Generic utility functions for manipulating strings.
# Notes:
#   Be sure to set PERL5LIB (colon-separated) appropriately to ensure that Perl
#   can find all of the modules used below.
#
# Copyright Matthias Blume 2002-2012, All Rights Reserved.
################################################################################
package StringUtilities;
use strict;
# use Net::IDN::Punycode qw(decode_punycode);  Haven't installed on this box yet
use Time::Local;                                # timegm()

require Exporter;
use vars qw(@EXPORT @ISA);
@ISA = qw(Exporter);
@EXPORT = qw(ASCIIfy
             AddMonthsToMDY4SlashDate
             AddMonthsToStdDate
             AddMonthsToY4MDDashDate
             AddToStdDate
             AddToY4MDDashDate
             AmpSemiToChar
             AmpSemiToChars
             BinaryToHexStr
             DateDMY4SlashToStd
             DateDMYSlashToStd
             DateDMonY2DashToStd
             DateDMonY4ToStd
             DateExcelNumToStd
             DateMDY2DashToStd
             DateMDY2SlashToStd
             DateMDY4DashToStd
             DateMDY4SlashToStd
             DateMDY4SlashToY4MDDash
             DateMDY4ToStd
             DateMDYSlashToStd
             DateMonDY4ToStd
             DateWdayDMonY4ToStd
             DateWdayMonDTimeY4ToStd
             DateY4MDDashToMDY4Slash
             DateY4MDDashToStd
             DateY4MDTimeDashToStd
             DecodeAmpLtQuot
             EndOfMonthStd
             EndOfWeekStd
             NormalizeAlphanum
             NormalizeMinimal
             NormalizeNone
             NormalizeToGSQR
             NormalizeToGoogleWebSearch
             ParseDateRange
             ParseURL
             StdDate
             StdDateToY4MDDash
             StripBusinessType
             SubtractStdDates
             SubtractY4MDDashDates
             SubtractY4MDDashMonths
             TitleCase
             Trim
             TrimLeft
             TrimRight
             Trimmed
             TrimmedLeft
             TrimmedRight
             UniqueChars
             XMLField
             nOccurrences);

my @MaxDayOfMonth = (0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31);

my %DomainTypeAbbrs = (ac  => 'edu',
                       co  => 'com',
                       com => 'com',
                       ed  => 'edu',
                       edu => 'edu',
                       go  => 'gov',
                       gov => 'gov',
                       mil => 'mil',
                       ne  => 'net',
                       net => 'net');
my %TwoLevelTLDs = ('ar' => 3,
                    'au' => 3,
                    'bd' => 3,
                    'br' => 3,
                    'cn' => 3,
                    'cy' => 3,
                    'do' => 3,
                    'eg' => 3,
                    'gt' => 3,
                    'hk' => 3,
                    'il' => '2+',
                    'in' => '2+',
                    'jo' => '3+',
                    'jp' => 2,
                    'kr' => '2+',
                    'lb' => 3,
                    'ma' => '2+',
                    'mm' => 3,
                    'mx' => 3,
                    'my' => '3+',
                    'np' => 3,
                    'nz' => '2+',
                    'pe' => 3,
                    'ph' => '1+',
                    'pk' => 3,
                    'pl' => '3+',
                    'pr' => '2+',
                    'qa' => 3,
                    'ru' => '2+',
                    'sa' => 3,
                    'sg' => 3,
                    'th' => '2+',
                    'tr' => '2+',
                    'tv' => '2+',
                    'tw' => '3+',
                    'tz' => 2,
                    'uk' => 'TLDT',                   # See %TwoLevelDomainTypes
                    'uy' => 3,
                    'za' => '2+');

my %TwoLevelDomainTypes =
    ('ac.uk' => 'edu',                      # academic (tertiary education, ...)
     'co.uk' => 'com',                        # general use (usually commercial)
     'gov.uk' => 'gov',                         # government (central and local)
     'ltd.uk' => 'com',                                      # limited companies
     'me.uk' => 'ind',                          # general use (usually personal)
     'mod.uk' => 'mil',         # Ministry of Defence and HM Forces public sites
     'net.uk' => 'net',               # restricted to ISPs and network companies
     'nhs.uk' => 'gov',                   # National Health Service institutions
     'nic.uk' => 'net',                          # network use only (Nominet UK)
     'org.uk' => 'org',         # general use (usually non-profit organisations)
     'parliament.uk' => 'gov',        # parliament (UK and Scottish Parliaments)
     'plc.uk' => 'com',                               # public limited companies
     'police.uk' => 'gov',                                       # police forces
     'sch.uk' => 'edu');                  # primary and secondary education, ...

my $SecondsPerDay = 86400;

my %iMo = (Jan => '01',
           Feb => '02',
           Mar => '03',
           Apr => '04',
           May => '05',
           Jun => '06',
           Jul => '07',
           Aug => '08',
           Sep => '09',
           Oct => '10',
           Nov => '11',
           Dec => '12');

# Sources for finding out what these characters are supposed to look like:
#   http://www.jovino.com/entitiesLookup.php
#   http://kobesearch.cpan.org/htdocs/Device-Gsm/Device/Gsm/Charset.pm.html
#   http://www.w3.org/Math/testsuite/testsuite/Characters/EntityNames/a.xml
#   http://www.webopedia.com/quick_ref/asciicode.asp
#   http://www.risd41.org/technology/help/cards/htmlasciientityrefequiv.pdf
my %p_AmpSemiToChar =
    ('&#38;'  =>    '&',            # ampersand
     '&#038;' =>    '&',            # ampersand
     '&#39;'  =>    "'",            # apostrophe / single quote
     '&#039;' =>    "'",            # apostrophe / single quote
     '&#060;' =>    '<',            # less-than sign
     '&#128;' =>    'ECU',          # euro sign                       (&euro;)
     '&#129;' =>    ' ',            #
     '&#130;' =>    "'",            # low left rising single quote  (&lsquor;)
     '&#131;' =>    'f',            # small italic f, florin          (&fnof;)
     '&#132;' =>    '"',            # low left rising double quote  (&ldquor;)
     '&#133;' =>    '...',          # low horizontal ellipsis       (&hellip;)
     '&#134;' =>    '(dag)',        # dagger mark                   (&dagger;)
     '&#135;' =>    '(ddag)',       # double dagger mark            (&Dagger;)
     '&#136;' =>    '^',            # letter modifying circumflex
     '&#137;' =>    'permille',     # per thousand (mille) sign     (&permil;)
     '&#138;' =>    'S',            # capital S caron or hacek      (&Scaron;)
     '&#139;' =>    '<',            # left single angle quote mark  (&lsaquo;)
     '&#140;' =>    'Oe',           # capital OE ligature            (&OElig;)
     '&#141;' =>    ' ',            #
     '&#142;' =>    'Z',            #
     '&#143;' =>    ' ',            #
     '&#144;' =>    ' ',            #
     '&#145;' =>    '`',            # left single quotation mark     (&lsquo;)
     '&#146;' =>    "'",            # right single quote mark        (&rsquo;)
     '&#147;' =>    '"',            # left double quotation mark     (&ldquo;)
     '&#148;' =>    '"',            # right double quote mark        (&rdquo;)
     '&#149;' =>    '*',            # round filled bullet             (&bull;)
     '&#150;' =>    '-',            # en dash                        (&ndash;)
     '&#151;' =>    '--',           # em dash                        (&mdash;)
     '&#152;' =>    '~',            # small spacing tilde accent     (&tilde;)
     '&#153;' =>    '(TM)',         # trademark sign                 (&trade;)
     '&#154;' =>    's',            # small s caron or hacek        (&scaron;)
     '&#155;' =>    '>',            # right single angle quote mark (&rsaquo;)
     '&#156;' =>    'oe',           # small oe ligature              (&oelig;)
     '&#157;' =>    ' ',            #
     '&#158;' =>    'z',            #
     '&#159;' =>    'Y',            # capital Y dieresis or umlaut    (&Yuml;)
     '&#160;' =>    ' ',            # no break (required) space
     '&#161;' =>    '!',            # Inverted exclamation point     (&iexcl;)
     '&#162;' =>    'c',            # cent sign
     '&#163;' =>    'L',            # pound sign
     '&#164;' =>    "\$",           # general currency sign
     '&#165;' =>    'Y',            # yen sign
     '&#166;' =>    '|',            # broken vertical bar
     '&#167;' =>    'S',            # Section symbol                  (&sect;)
     '&#168;' =>    'e',            # Umlaut (Diaeresis)               (&uml;)
     '&#169;' =>    '(Copyright)',  # copyright sign
     '&#170;' =>    '[a]',          # Superscript lowercase a         (&ordf;)
     '&#171;' =>    '<<',           # angle quotation mark, left
     '&#172;' =>    '!',            # Not sign                         (&not;)
     '&#173;' =>    '-',            # soft hyphen
     '&#174;' =>    '(Registered)', # registered sign
     '&#175;' =>    '',             # Macron                          (&macr;)
     '&#176;' =>    'degrees',      # Degree sign                      (&deg;)
     '&#177;' =>    '+/-',          # Plus/minus sign               (&plusmn;)
     '&#178;' =>    '[2]',          # superscript two
     '&#179;' =>    '[3]',          # superscript three
     '&#180;' =>    "'",            # Acute accent
     '&#181;' =>    'u',            # Micro sign                     (&micro;)
     '&#182;' =>    'P',            # Pilcrow sign (paragraph)        (&para;)
     '&#183;' =>    '.',            # Middle dot                    (&middot;)
     '&#184;' =>    '',             # Cedilla                        (&cedil;)
     '&#185;' =>    '[1]',          # superscript one
     '&#186;' =>    '[o]',          # Superscript o                   (&ordm;)
     '&#187;' =>    '>>',           # angle quotation mark, right
     '&#188;' =>    '1/4',          # fraction one-quarter
     '&#189;' =>    '1/2',          # fraction one-half
     '&#190;' =>    '3/4',          # fraction three-quarters
     '&#191;' =>    '?',            # Inverted question mark
     '&#192;' =>    'A',            # capital A, grave accent
     '&#193;' =>    'A',            # capital A, acute accent
     '&#194;' =>    'A',            # capital A, circumflex accent
     '&#195;' =>    'A',            # capital A, tilde
     '&#196;' =>    'Ae',           # capital A, dieresis or umlaut
     '&#197;' =>    'A',            # capital A, ring
     '&#198;' =>    'Ae',           # capital AE diphthong ligature
     '&#199;' =>    'C',            # capital C, cedilla
     '&#200;' =>    'E',            # capital E, grave accent
     '&#201;' =>    'E',            # capital E, acute accent
     '&#202;' =>    'E',            # capital E, circumflex accent
     '&#203;' =>    'E',            # capital E, dieresis or umlaut
     '&#204;' =>    'I',            # capital I, grave accent
     '&#205;' =>    'I',            # capital I, acute accent
     '&#206;' =>    'I',            # capital I, circumflex accent
     '&#207;' =>    'I',            # capital I, dieresis or umlaut
     '&#208;' =>    'D',            # capital Eth, Icelandic
     '&#209;' =>    'N',            # capital N, tilde
     '&#210;' =>    'O',            # capital O, grave accent
     '&#211;' =>    'O',            # capital O, acute accent
     '&#212;' =>    'O',            # capital O, circumflex accent
     '&#213;' =>    'O',            # capital O, tilde
     '&#214;' =>    'Oe',           # capital O, dieresis or umlaut
     '&#215;' =>    '*',            # Multiplication sign            (&times;)
     '&#216;' =>    'O',            # capital O, slash
     '&#217;' =>    'U',            # capital U, grave accent
     '&#218;' =>    'U',            # capital U, acute accent
     '&#219;' =>    'U',            # capital U, circumflex accent
     '&#220;' =>    'Ue',           # capital U, dieresis or umlaut
     '&#221;' =>    'Y',            # capital Y, acute accent
     '&#222;' =>    'P',            # capital THORN, Icelandic
     '&#223;' =>    'ss',           # German sz ligature
     '&#224;' =>    'a',            # small a, grave accent
     '&#225;' =>    'a',            # small a, acute accent
     '&#226;' =>    'a',            # small a, circumflex accent
     '&#227;' =>    'a',            # small a, tilde
     '&#228;' =>    'ae',           # small a, dieresis or umlaut
     '&#229;' =>    'a',            # small a, ring
     '&#230;' =>    'ae',           # small ae diphthong (ligature)
     '&#231;' =>    'c',            # small c, cedilla
     '&#232;' =>    'e',            # small e, grave accent
     '&#233;' =>    'e',            # small e, acute accent
     '&#234;' =>    'e',            # small e, circumflex accent
     '&#235;' =>    'e',            # small e, dieresis or umlaut
     '&#236;' =>    'i',            # small i, grave accent
     '&#237;' =>    'i',            # small i, acute accent
     '&#238;' =>    'i',            # small i, circumflex accent
     '&#239;' =>    'i',            # small i, dieresis or umlaut
     '&#240;' =>    'd',            # small eth, Icelandic
     '&#241;' =>    'n',            # small n, tilde
     '&#242;' =>    'o',            # small o, grave accent
     '&#243;' =>    'o',            # small o, acute accent
     '&#244;' =>    'o',            # small o, circumflex accent
     '&#245;' =>    'o',            # small o, tilde
     '&#246;' =>    'oe',           # small o, dieresis or umlaut
     '&#247;' =>    '/',            # Division symbol               (&divide;)
     '&#248;' =>    'o',            # small o, slash
     '&#249;' =>    'u',            # small u, grave accent
     '&#250;' =>    'u',            # small u, acute accent
     '&#251;' =>    'u',            # small u, circumflex accent
     '&#252;' =>    'ue',           # small u, dieresis or umlaut
     '&#253;' =>    'y',            # small y, acute accent
     '&#254;' =>    'p',            # small thorn, Icelandic
     '&#255;' =>    'y',            # small y, dieresis or umlaut
     '&#402;' =>    'f',            # function/florin symbol
     '&#913;' =>    'ALPHA',        # greek capital letter alpha
     '&#914;' =>    'BETA',         # greek capital letter beta
     '&#915;' =>    'GAMMA',        # greek capital letter gamma
     '&#916;' =>    'DELTA',        # greek capital letter delta
     '&#917;' =>    'EPSILON',      # greek capital letter epsilon
     '&#918;' =>    'ZETA',         # greek capital letter zeta
     '&#919;' =>    'ETA',          # greek capital letter eta
     '&#920;' =>    'THETA',        # greek capital letter theta
     '&#921;' =>    'IOTA',         # greek capital letter iota
     '&#922;' =>    'KAPPA',        # greek capital letter kappa
     '&#923;' =>    'LAMBDA',       # greek capital letter lambda
     '&#924;' =>    'MU',           # greek capital letter mu
     '&#925;' =>    'NU',           # greek capital letter nu
     '&#926;' =>    'XI',           # greek capital letter xi
     '&#927;' =>    'OMICRON',      # greek capital letter omicron
     '&#928;' =>    'PI',           # greek capital letter pi
     '&#929;' =>    'RHO',          # greek capital letter rho
     '&#931;' =>    'SIGMA',        # greek capital letter sigma
     '&#932;' =>    'TAU',          # greek capital letter tau
     '&#933;' =>    'UPSILON',      # greek capital letter upsilon
     '&#934;' =>    'PHI',          # greek capital letter phi
     '&#935;' =>    'CHI',          # greek capital letter chi
     '&#936;' =>    'PSI',          # greek capital letter psi
     '&#937;' =>    'OMEGA',        # greek capital letter omega
     '&#945;' =>    'alpha',        # greek small letter alpha
     '&#946;' =>    'beta',         # greek small letter beta
     '&#947;' =>    'gamma',        # greek small letter gamma
     '&#948;' =>    'delta',        # greek small letter delta
     '&#949;' =>    'epsilon',      # greek small letter epsilon
     '&#950;' =>    'zeta',         # greek small letter zeta
     '&#951;' =>    'eta',          # greek small letter eta
     '&#952;' =>    'theta',        # greek small letter theta
     '&#953;' =>    'iota',         # greek small letter iota
     '&#954;' =>    'kappa',        # greek small letter kappa
     '&#955;' =>    'lambda',       # greek small letter lambda
     '&#956;' =>    'mu',           # greek small letter mu
     '&#957;' =>    'nu',           # greek small letter nu
     '&#958;' =>    'xi',           # greek small letter xi
     '&#959;' =>    'omicron',      # greek small letter omicron
     '&#960;' =>    'pi',           # greek small letter pi
     '&#961;' =>    'rho',          # greek small letter rho
     '&#962;' =>    'sigma',        # greek small letter final sigma
     '&#963;' =>    'sigma',        # greek small letter sigma
     '&#964;' =>    'tau',          # greek small letter tau
     '&#965;' =>    'upsilon',      # greek small letter upsilon
     '&#965;' =>    'upsilon',      # greek small letter upsilon
     '&#966;' =>    'phi',          # greek small letter phi
     '&#967;' =>    'chi',          # greek small letter chi
     '&#968;' =>    'psi',          # greek small letter psi
     '&#969;' =>    'omega',        # greek small letter omega
     '&#977;' =>    'theta',        # greek small letter theta symbol
     '&#978;' =>    'upsilon',      # greek upsilon with hook symbol
     '&#982;' =>    'pi',           # greek pi symbol
     '&#8211;' =>   '-',            # en dash                        (&ndash;)
     '&#8212;' =>   '--',           # em dash                        (&mdash;)
     '&#8216;' =>   "'",            # left single quotation mark
     '&#8217;' =>   "'",            # right single quote mark
     '&#8220;' =>   '"',            # left double quotation mark
     '&#8221;' =>   '"',            # right double quote mark
     '&#8222;' =>   '"',            # low left rising double quote
     '&#8224;' =>   '(dag)',        # dagger mark
     '&#8225;' =>   '(ddag)',       # double dagger mark
     '&#8226;' =>   '*',            # bullet/black small circle
     '&#8230;' =>   '...',          # ellipsis
     '&#8242;' =>   "'",            # prime/minutes/feet
     '&#8243;' =>   '"',            # double prime/seconds/inches
     '&#8250;' =>   '>',            # right single angle quote mark (guillemet)
     '&#8254;' =>   '',             # overline/spacing overscore
     '&#8260;' =>   '/',            # fraction slash
     '&#8465;' =>   'I',            # blackletter capital I/imaginary
     '&#8472;' =>   'P',            # script capital P
     '&#8476;' =>   'R',            # blackletter capital R/real
     '&#8482;' =>   '(TM)',         # trademark sign
     '&#8501;' =>   'alef',         # alef symbol
     '&#8592;' =>   '<-',           # leftwards arrow
     '&#8593;' =>   '(UPARROW)',    # upwards arrow
     '&#8594;' =>   '->',           # rightwards arrow
     '&#8595;' =>   '(DNARROW)',    # downwards arrow
     '&#8596;' =>   '<->',          # left right arrow
     '&#8629;' =>   '(CR)',         # carriage return symbol
     '&#8656;' =>   '<=',           # leftwards double arrow
     '&#8657;' =>   '(UPARROW)',    # upwards double arrow
     '&#8658;' =>   '=>',           # rightwards double arrow
     '&#8659;' =>   '(DNARROW)',    # downwards double arrow
     '&#8660;' =>   '<=>',          # left right double arrow
     '&#8704;' =>   'FOR ALL',      # for all
     '&#8706;' =>   'PARTDIFF',     # partial differential
     '&#8707;' =>   'THERE EXISTS', # there exists
     '&#8709;' =>   'NULL',         # empty set/null set/diameter
     '&#8711;' =>   '(NABLA)',      # nabla/backward difference
     '&#8712;' =>   'ELEMENT',      # element of
     '&#8713;' =>   '!ELEMENT',     # not an element of
     '&#8715;' =>   'CONTAINS',     # contains as member
     '&#8719;' =>   'PRODUCT',      # n-ary product/product sign
     '&#8721;' =>   'SUM',          # n-ary sumation
     '&#8722;' =>   '-',            # minus sign
     '&#8727;' =>   '*',            # asterisk operator
     '&#8730;' =>   'ROOT',         # square root/radical sign
     '&#8733;' =>   'PROPORTIONAL', # proportional to
     '&#8734;' =>   'INF',          # infinity
     '&#8736;' =>   'ANGLE',        # angle
     '&#8743;' =>   'AND',          # logical and/wedge
     '&#8744;' =>   'OR',           # logical or/vee
     '&#8745;' =>   'INTERSECTION', # intersection/cap
     '&#8746;' =>   'UNION',        # union/cup
     '&#8747;' =>   'INTEGRAL',     # integral
     '&#8756;' =>   'THEREFORE',    # therefore
     '&#8764;' =>   '~',            # tilde/varies with/similar
     '&#8773;' =>   '=~',           # approximately equal to
     '&#8776;' =>   '~~',           # almost equal to/asymptotic to
     '&#8800;' =>   '!=',           # not equal to
     '&#8801;' =>   '==',           # identical to
     '&#8804;' =>   '<=',           # less-than or equal to
     '&#8805;' =>   '>=',           # greater-than or equal to
     '&#8834;' =>   'SUBSET',       # subset of
     '&#8835;' =>   'SUPERSET',     # superset of
     '&#8836;' =>   '!SUBSET',      # not a subset of
     '&#8838;' =>   'SUBSET=',      # subset of or equal to
     '&#8839;' =>   'SUPERSET=',    # superset of or equal to
     '&#8853;' =>   '+',            # circled plus/direct sum
     '&#8855;' =>   '*',            # circled times/vector product
     '&#8869;' =>   '(PERP)',       # up tack/orthogonal/perpendicular
     '&#8901;' =>   '*',            # dot operator
     '&#8968;' =>   '(LCEIL)',      # left ceiling/APL upstile
     '&#8969;' =>   '(RCEIL)',      # right ceiling
     '&#8970;' =>   '(LFLOOR)',     # left floor/APL downstile
     '&#8971;' =>   '(RFLOOR)',     # right floor
     '&#9001;' =>   '<',            # left angle bracket/bra
     '&#9002;' =>   '>',            # right angle bracket/ket
     '&#9674;' =>   '(LOZENGE)',    # lozenge symbol
     '&#9824;' =>   '(SPADE)',      # black spade suit
     '&#9827;' =>   '(CLUB)',       # black club suit/shamrock
     '&#9829;' =>   '(HEART)',      # black heart
     '&#9830;' =>   '(DIAMOND)',    # black diamond suit
     '&AElig;' =>   'Ae',           # capital AE diphthong ligature
     '&Aacute;' =>  'A',            # capital A, acute accent
     '&Acirc;' =>   'A',            # capital A, circumflex accent
     '&Agrave;' =>  'A',            # capital A, grave accent
     '&Alpha;' =>   'ALPHA',        # greek capital letter alpha        (&#913;)
     '&Aring;' =>   'A',            # capital A, ring
     '&Atilde;' =>  'A',            # capital A, tilde
     '&Auml;' =>    'Ae',           # capital A, dieresis or umlaut
     '&Beta;' =>    'BETA',         # greek capital letter beta         (&#914;)
     '&Ccedil;' =>  'C',            # capital C, cedilla
     '&Chi;' =>     'CHI',          # greek capital letter chi          (&#935;)
     '&Dagger;' =>  '(ddag)',       # double dagger mark
     '&Delta;' =>   'DELTA',        # greek capital letter delta        (&#916;)
     '&ETH;' =>     'D',            # capital Eth, Icelandic
     '&Eacute;' =>  'E',            # capital E, acute accent
     '&Ecirc;' =>   'E',            # capital E, circumflex accent
     '&Egrave;' =>  'E',            # capital E, grave accent
     '&Epsi;' =>    'EPSILON',      # greek capital letter epsilon      (&#917;)
     '&Epsilon;' => 'EPSILON',      # greek capital letter epsilon      (&#917;)
     '&Eta;' =>     'ETA',          # greek capital letter eta          (&#919;)
     '&Euml;' =>    'E',            # capital E, dieresis or umlaut
     '&Gamma;' =>   'GAMMA',        # greek capital letter gamma        (&#915;)
     '&Gt;' =>      '>',            # greater-than sign (should be '&gt;')
     '&Iacute;' =>  'I',            # capital I, acute accent
     '&Icirc;' =>   'I',            # capital I, circumflex accent
     '&Igrave;' =>  'I',            # capital I, grave accent
     '&Iota;' =>    'IOTA',         # greek capital letter iota         (&#921;)
     '&Iuml;' =>    'I',            # capital I, dieresis or umlaut
     '&Kappa;' =>   'KAPPA',        # greek capital letter kappa        (&#922;)
     '&Lambda;' =>  'LAMBDA',       # greek capital letter lambda       (&#923;)
     '&Lstrok;' =>  'L',            # capital L with stroke
     '&Lt;' =>      '<',            # less-than sign (should be '&lt;')
     '&Mu;' =>      'MU',           # greek capital letter mu           (&#924;)
     '&Ntilde;' =>  'N',            # capital N, tilde
     '&Nu;' =>      'NU',           # greek capital letter nu           (&#925;)
     '&OElig;' =>   'Oe',           # capital OE ligature
     '&Oacute;' =>  'O',            # capital O, acute accent
     '&Ocirc;' =>   'O',            # capital O, circumflex accent
     '&Ograve;' =>  'O',            # capital O, grave accent
     '&Omega;' =>   'OMEGA',        # greek capital letter omega        (&#937;)
     '&Omicron;' => 'OMICRON',      # greek capital letter omicron      (&#927;)
     '&Oslash;' =>  'O',            # capital O, slash
     '&Otilde;' =>  'O',            # capital O, tilde
     '&Ouml;' =>    'Oe',           # capital O, dieresis or umlaut
     '&Phi;' =>     'PHI',          # greek capital letter phi          (&#934;)
     '&Pi;' =>      'PI',           # greek capital letter pi           (&#928;)
     '&Prime;' =>   '"',            # double prime/seconds/inches      (&#8243;)
     '&Psi;' =>     'PSI',          # greek capital letter psi          (&#936;)
     '&Rho;' =>     'RHO',          # greek capital letter rho          (&#929;)
     '&Scaron;' =>   'S',           # capital S caron or hacek
     '&Sigma;' =>   'SIGMA',        # greek capital letter sigma        (&#931;)
     '&THORN;' =>   'P',            # capital THORN, Icelandic
     '&Tau;' =>     'TAU',          # greek capital letter tau          (&#932;)
     '&Theta;' =>   'THETA',        # greek capital letter theta        (&#920;)
     '&Uacute;' =>  'U',            # capital U, acute accent
     '&Ucirc;' =>   'U',            # capital U, circumflex accent
     '&Ugrave;' =>  'U',            # capital U, grave accent
     '&Upsi;' =>    'UPSILON',      # greek capital letter upsilon      (&#933;)
     '&Upsilon;' => 'UPSILON',      # greek capital letter upsilon      (&#933;)
     '&Uuml;' =>    'Ue',           # capital U, dieresis or umlaut
     '&Xi;' =>      'XI',           # greek capital letter xi           (&#926;)
     '&Yacute;' =>  'Y',            # capital Y, acute accent
     '&Yuml;' =>    'Y',            # capital Y dieresis or umlaut
     '&Zeta;' =>    'ZETA',         # greek capital letter zeta         (&#918;)
     '&aacute;' =>  'a',            # small a, acute accent
     '&acirc;' =>   'a',            # small a, circumflex accent
     '&acute;' =>   '',             # acute mark above previous letter
     '&aelig;' =>   'ae',           # small ae diphthong (ligature)
     '&agrave;' =>  'a',            # small a, grave accent
     '&alefsym;' => 'alef',         # alef symbol                      (&#8501;)
     '&alpha;' =>   'alpha',        # greek small letter alpha          (&#945;)
     '&amp;' =>     '&',            # ampersand
     '&and;' =>     'AND',          # logical and/wedge                (&#8743;)
     '&ang;' =>     'ANGLE',        # angle                            (&#8736;)
     '&ap;' =>      '=~',           # approximately equal to
     '&apos;' =>    "'",            # apostrophe
     '&aring;' =>   'a',            # small a, ring
     '&ast;' =>     '*',            # asterisk
     '&asymp;' =>   '~~',           # almost equal to/asymptotic to    (&#8776;)
     '&atilde;' =>  'a',            # small a, tilde
     '&auml;' =>    'ae',           # small a, dieresis or umlaut
     '&beta;' =>    'beta',         # greek small letter beta           (&#946;)
     '&brvbar;' =>  '|',            # broken vertical bar
     '&bsol;' =>    "\\",           # reverse solidus
     '&bull;' =>    '*',            # bullet/black small circle        (&#8226;)
     '&cap;' =>     'INTERSECTION', # intersection/cap                 (&#8745;)
     '&caron;' =>   '',             # caron above previous letter
     '&ccedil;' =>  'c',            # small c, cedilla
     '&cedil;' =>   '',             # cedilla below previous letter
     '&cent;' =>    'c',            # cent sign
     '&chi;' =>     'chi',          # greek small letter chi            (&#967;)
     '&cir;' =>     '(CIRCLE)',     # Circle symbol
     '&circ;' =>    '',		    # cicumflex mark above previous letter
     '&clubs;' =>   '(CLUB)',       # black club suit/shamrock         (&#9827;)
     '&colon;' =>   ':',            # colon
     '&comma;' =>   ',',            # comma
     '&commat;' =>  '@',            # commercial at
     '&cong;' =>    '=~',           # approximately equal to           (&#8773;)
     '&coprod;' =>  'COPRODUCT',    # upside-down product symbol
     '&copy;' =>    '(Copyright)',  # copyright sign
     '&crarr;' =>   '(CR)',         # carriage return symbol           (&#8629;)
     '&cup;' =>     'UNION',        # union/cup                        (&#8746;)
     '&curren;' =>  "\$",           # general currency sign
     '&dArr;' =>    '(DNARROW)',    # downwards double arrow           (&#8659;)
     '&dagger;' =>  '(dag)',        # dagger mark
     '&darr;' =>    '(DNARROW)',    # downwards arrow                  (&#8595;)
     '&deg;' =>     'degrees',      # Degree sign
     '&delta;' =>   'delta',        # greek small letter delta          (&#948;)
     '&diams;' =>   '(DIAMOND)',    # black diamond suit               (&#9830;)
     '&die;' =>     'e',	    # umlaut mark above previous letter
     '&divide;' =>  '/',            # divide sign
     '&dollar;' =>  "\$",           # dollar sign
     '&dot;' =>     '',             # dot above previous letter
     '&eacute;' =>  'e',            # small e, acute accent
     '&ecirc;' =>   'e',            # small e, circumflex accent
     '&egrave;' =>  'e',            # small e, grave accent
     '&empty;' =>   'NULL',         # empty set/null set/diameter      (&#8709;)
     '&emptyv;'=>   'NULL',         # empty set/null set/diameter      (&#8709;)
     '&epsi;' =>    'epsilon',      # greek small letter epsilon        (&#949;)
     '&epsilon;' => 'epsilon',      # greek small letter epsilon        (&#949;)
     '&epsiv;' =>   'epsilon',      # greek small letter epsilon
     '&equals;' =>  '=',            # equals sign
     '&equiv;' =>   '==',           # identical to                     (&#8801;)
     '&eta;' =>     'eta',          # greek small letter eta            (&#951;)
     '&eth;' =>     'd',            # small eth, Icelandic
     '&euml;' =>    'e',            # small e, dieresis or umlaut
     '&euro;' =>    'ECU',	    # euro sign
     '&excl;' =>    '!',            # exclamation mark
     '&exist;' =>   'THERE EXISTS', # there exists                     (&#8707;)
     '&female;' =>  '(FEMALE)',	    # female symbol
     '&fnof;' =>    'f',            # function/florin symbol            (&#402;)
     '&forall;' =>  'FOR ALL',      # for all                          (&#8704;)
     '&frac12;' =>  '1/2',          # fraction one-half
     '&frac14;' =>  '1/4',          # fraction one-quarter
     '&frac18;' =>  '1/8',          # fraction one-eighth
     '&frac34;' =>  '3/4',          # fraction three-quarters
     '&frac38;' =>  '3/8',          # fraction three-eighths
     '&frac58;' =>  '5/8',          # fraction five-eighths
     '&frac78;' =>  '7/8',          # fraction seven-eighths
     '&frasl;' =>   '/',            # fraction slash                   (&#8260;)
     '&gamma;' =>   'gamma',        # greek small letter gamma          (&#947;)
     '&ge;' =>      '>=',           # greater-than or equal to         (&#8805;)
     '&grave;' =>   '',             # grave mark above previous letter
     '&gt;' =>      '>',            # greater-than sign
     '&hArr;' =>    '<=>',          # left right double arrow          (&#8660;)
     '&half;' =>    '1/2',          # fraction one-half
     '&harr;' =>    '<->',          # left right arrow                 (&#8596;)
     '&hearts;' =>  '(HEART)',      # black heart                      (&#9829;)
     '&hellip;' =>  '...',          # ellipsis                         (&#8230;)
     '&hyphen;' =>  '-',            # hyphen
     '&iacute;' =>  'i',            # small i, acute accent
     '&icirc;' =>   'i',            # small i, circumflex accent
     '&iexcl;' =>   '!',            # Inverted exclamation point
     '&igrave;' =>  'i',            # small i, grave accent
     '&image;' =>   'I',            # blackletter capital I/imaginary  (&#8465;)
     '&infin;' =>   'INF',          # infinity                         (&#8734;)
     '&int;' =>     'INTEGRAL',     # integral                         (&#8747;)
     '&iota;' =>    'iota',         # greek small letter iota           (&#953;)
     '&iquest;' =>  '?',	    # inverted question mark
     '&isin;' =>    'ELEMENT',      # element of                       (&#8712;)
     '&iuml;' =>    'i',            # small i, dieresis or umlaut
     '&kappa;' =>   'kappa',        # greek small letter kappa          (&#954;)
     '&lArr;' =>    '<=',           # leftwards double arrow           (&#8656;)
     '&lambda;' =>  'lambda',       # greek small letter lambda         (&#955;)
     '&lang;' =>    '<',            # left angle bracket/bra           (&#9001;)
     '&laquo;' =>   '<<',           # angle quotation mark, left
     '&larr;' =>    '<-',           # leftwards arrow                  (&#8592;)
     '&lceil;' =>   '(LCEIL)',      # left ceiling/APL upstile         (&#8968;)
     '&lcub;' =>    '{',            # left curly bracket
     '&ldquo;' =>   '"',            # double quotation mark, left
     '&ldquor;' =>  '"',            # low left rising double quote
     '&le;' =>      '<=',           # less-than or equal to            (&#8804;)
     '&lfloor;' =>  '(LFLOOR)',     # left floor/APL downstile         (&#8970;)
     '&lowast;' =>  '*',            # asterisk operator                (&#8727;)
     '&lowbar;' =>  '_',            # low line
     '&loz;' =>     '(LOZENGE)',    # lozenge symbol                   (&#9674;)
     '&lpar;' =>    '(',            # left parenthesis
     '&lrarr2;' =>  '<->',	    # left and right arrows above one another
     '&lrarr;' =>   '<->',	    # left and right arrows above one another
     '&lsaquo;' =>  '<',            # left single angle quote mark
     '&lsqb;' =>    '[',            # left square bracket
     '&lsquo;' =>   "'",            # single quotation mark, left
     '&lsquor;' =>  "'",            # low left rising single quote
     '&lstrok;' =>  'l',            # small l with stroke
     '&lt;' =>      '<',            # less-than sign
     '&macr;' =>    '',             # macron mark above previous letter
     '&male;' =>    '(MALE)',	    # male symbol
     '&mdash;' =>   '--',           # em dash
     '&micro;' =>   'u',            # Micro sign
     '&middot;' =>  '.',            # middle-dot symbol
     '&minus;' =>   '-',            # minus sign                       (&#8722;)
     '&mu;' =>      'mu',           # greek small letter mu             (&#956;)
     '&nabla;' =>   '(NABLA)',      # nabla/backward difference        (&#8711;)
     '&nbsp;' =>    ' ',            # no break (required) space
     '&ndash;' =>   '-',            # en dash
     '&ne;' =>      '!=',           # not equal to                     (&#8800;)
     '&nge;' =>     '!>=',          # not greater or equal to
     '&ni;' =>      'CONTAINS',     # contains as member               (&#8715;)
     '&nle;' =>     '!<=',          # not less than or equal to
     '&not;' =>     '!',            # Not sign
     '&notin;' =>   '!ELEMENT',     # not an element of                (&#8713;)
     '&nsim;' =>    '!~',           # tilda with stroke ("not similar")
     '&nsub;' =>    '!SUBSET',      # not a subset of                  (&#8836;)
     '&ntilde;' =>  'n',            # small n, tilde
     '&nu;' =>      'nu',           # greek small letter nu             (&#957;)
     '&num;' =>     '#',            # number sign
     '&oacute;' =>  'o',            # small o, acute accent
     '&ocirc;' =>   'o',            # small o, circumflex accent
     '&oelig;' =>   'oe',           # small oe ligature
     '&ograve;' =>  'o',            # small o, grave accent
     '&oline;' =>   '',             # overline/spacing overscore       (&#8254;)
     '&omega;' =>   'omega',        # greek small letter omega          (&#969;)
     '&omicron;' => 'omicron',      # greek small letter omicron        (&#959;)
     '&oplus;' =>   '+',            # circled plus/direct sum          (&#8853;)
     '&or;' =>      'OR',           # logical or/vee                   (&#8744;)
     '&ordf;' =>    '[a]',          # Superscript lowercase a
     '&ordm;' =>    '[o]',          # Superscript o
     '&oslash;' =>  'o',            # small o, slash
     '&otilde;' =>  'o',            # small o, tilde
     '&otimes;' =>  '*',            # circled times/vector product     (&#8855;)
     '&ouml;' =>    'oe',           # small o, dieresis or umlaut
     '&para;' =>    'P',            # Pilcrow sign (paragraph)
     '&part;' =>    'PARTDIFF',     # partial differential             (&#8706;)
     '&percent;' => '%',            # percent sign
     '&period;' =>  '.',            # full stop, period
     '&permil;' =>  'permille',     # per thousand (mille) sign
     '&perp;' =>    '(PERP)',       # up tack/orthogonal/perpendicular (&#8869;)
     '&phi;' =>     'phi',          # greek small letter phi            (&#966;)
     '&pi;' =>      'pi',           # greek small letter pi             (&#960;)
     '&piv;' =>     'pi',           # greek pi symbol                   (&#982;)
     '&plus;' =>    '+',            # plus sign
     '&plusmn;' =>  '+/-',          # plus-or-minus sign
     '&pound;' =>   'L',            # pound sign
     '&prime;' =>   "'",            # prime/minutes/feet               (&#8242;)
     '&prod;' =>    'PRODUCT',      # n-ary product/product sign       (&#8719;)
     '&prop;' =>    'PROPORTIONAL', # proportional to                  (&#8733;)
     '&psi;' =>     'psi',          # greek small letter psi            (&#968;)
     '&quest;' =>   '?',            # question mark
     '&quot;' =>    '"',            # quotation mark
     '&rArr;' =>    '=>',           # rightwards double arrow          (&#8658;)
     '&radic;' =>   'ROOT',         # square root/radical sign         (&#8730;)
     '&rang;' =>    '>',            # right angle bracket/ket          (&#9002;)
     '&raquo;' =>   '>>',           # angle quotation mark, right
     '&rarr;' =>    '->',           # rightwards arrow                 (&#8594;)
     '&rceil;' =>   '(RCEIL)',      # right ceiling                    (&#8969;)
     '&rcub;' =>    '}',            # right curly bracket
     '&rdquo;' =>   '"',            # double quotation mark, right
     '&real;' =>    'R',            # blackletter capital R/real       (&#8476;)
     '&reg;' =>     '(Registered)', # registered sign
     '&rfloor;' =>  '(RFLOOR)',     # right floor                      (&#8971;)
     '&rho;' =>     'rho',          # greek small letter rho            (&#961;)
     '&ring;' =>    '',		    # ring above previous letter
     '&rpar;' =>    ')',            # right parenthesis
     '&rsaquo;' =>  '>',            # right single angle quote mark
     '&rsqb;' =>    ']',            # right square bracket
     '&rsquo;' =>   "'",            # single quotation mark, right
     '&scaron;' =>  's',            # small s caron or hacek
     '&sdot;' =>    '*',            # dot operator                     (&#8901;)
     '&sect;' =>    'S',            # Section symbol
     '&semi;' =>    ';',            # semicolon
     '&shy;' =>     '-',            # soft hyphen
     '&sigma;' =>   'sigma',        # greek small letter sigma          (&#963;)
     '&sigmaf;' =>  'sigma',        # greek small letter final sigma    (&#962;)
     '&sim;' =>     '~',            # tilde/varies with/similar        (&#8764;)
     '&sime;' =>    '=~',	    # Equal sign with top line squiggly
     '&sol;' =>     '/',            # solidus
     '&spades;' =>  '(SPADE)',      # black spade suit                 (&#9824;)
     '&sub;' =>     'SUBSET',       # subset of                        (&#8834;)
     '&sube;' =>    'SUBSET=',      # subset of or equal to            (&#8838;)
     '&sum;' =>     'SUM',          # n-ary sumation                   (&#8721;)
     '&sup1;' =>    '[1]',          # superscript one
     '&sup2;' =>    '[2]',          # superscript two
     '&sup3;' =>    '[3]',          # superscript three
     '&sup;' =>     'SUPERSET',     # superset of                      (&#8835;)
     '&supe;' =>    'SUPERSET=',    # superset of or equal to          (&#8839;)
     '&szlig;' =>   'ss',           # German sz ligature
     '&tau;' =>     'tau',          # greek small letter tau            (&#964;)
     '&there4;' =>  'THEREFORE',    # therefore                        (&#8756;)
     '&theta;' =>   'theta',        # greek small letter theta          (&#952;)
     '&thetasym;' =>'theta',        # greek small letter theta symbol   (&#977;)
     '&thorn;' =>   'p',            # small thorn, Icelandic
     '&tild;' =>    '',		    # tilde above previous letter
     '&tilde;' =>   '~',            # small spacing tilde accent
     '&times;' =>   '*',            # times sign
     '&trade;' =>   '(TM)',         # trademark sign                   (&#8482;)
     '&uArr;' =>    '(UPARROW)',    # upwards double arrow             (&#8657;)
     '&uacute;' =>  'u',            # small u, acute accent
     '&uarr;' =>    '(UPARROW)',    # upwards arrow                    (&#8593;)
     '&ucirc;' =>   'u',            # small u, circumflex accent
     '&ugrave;' =>  'u',            # small u, grave accent
     '&uml;' =>     'e',	    # umlaut mark above previous letter
     '&upsi;' =>    'upsilon',      # greek small letter upsilon        (&#965;)
     '&upsih;' =>   'upsilon',      # greek upsilon with hook symbol    (&#978;)
     '&upsilon;' => 'upsilon',      # greek small letter upsilon        (&#965;)
     '&uuml;' =>    'ue',           # small u, dieresis or umlaut
     '&verbar;' =>  '|',            # vertical bar
     '&weierp;' =>  'P',            # script capital P                 (&#8472;)
     '&xi;' =>      'xi',           # greek small letter xi             (&#958;)
     '&yacute;' =>  'y',            # small y, acute accent
     '&yen;' =>     'Y',            # yen sign
     '&yuml;' =>    'y',            # small y, dieresis or umlaut
     '&zeta;' =>    'zeta');        # greek small letter zeta           (&#950;)

my %p_Articles = ('a' => 1,
                  'an' => 1,
                  'and' => 1,
                  'at' => 1,
                  'but' => 1,
                  'by' => 1,
                  'else' => 1,
                  'for' => 1,
                  'from' => 1,
                  'if' => 1,
                  'in' => 1,
                  'into' => 1,
                  'is' => 1,
                  'of' => 1,
                  'off' => 1,
                  'on' => 1,
                  'or' => 1,
                  'out' => 1,
                  'over' => 1,
                  'so' => 1,
                  'the' => 1,
                  'then' => 1,
                  'to' => 1,
                  'up' => 1,
                  'upon' => 1,
                  'when' => 1);

my %p_BinaryToHexStr =
    ("\x00" => '\x00',
     "\x01" => '\x01',
     "\x02" => '\x02',
     "\x03" => '\x03',
     "\x04" => '\x04',
     "\x05" => '\x05',
     "\x06" => '\x06',
     "\x07" => '\x07',
     "\x08" => '\x08',
     "\x09" => '\x09',
     "\x0A" => '\x0A',
     "\x0B" => '\x0B',
     "\x0C" => '\x0C',
     "\x0D" => '\x0D',
     "\x0E" => '\x0E',
     "\x0F" => '\x0F',
     "\x10" => '\x10',
     "\x11" => '\x11',
     "\x12" => '\x12',
     "\x13" => '\x13',
     "\x14" => '\x14',
     "\x15" => '\x15',
     "\x16" => '\x16',
     "\x17" => '\x17',
     "\x18" => '\x18',
     "\x19" => '\x19',
     "\x1A" => '\x1A',
     "\x1B" => '\x1B',
     "\x1C" => '\x1C',
     "\x1D" => '\x1D',
     "\x1E" => '\x1E',
     "\x1F" => '\x1F',
     "\x7F" => '\x7F',
     "\x80" => '\x80',
     "\x81" => '\x81',
     "\x82" => '\x82',
     "\x83" => '\x83',
     "\x84" => '\x84',
     "\x85" => '\x85',
     "\x86" => '\x86',
     "\x87" => '\x87',
     "\x88" => '\x88',
     "\x89" => '\x89',
     "\x8A" => '\x8A',
     "\x8B" => '\x8B',
     "\x8C" => '\x8C',
     "\x8D" => '\x8D',
     "\x8E" => '\x8E',
     "\x8F" => '\x8F',
     "\x90" => '\x90',
     "\x91" => '\x91',
     "\x92" => '\x92',
     "\x93" => '\x93',
     "\x94" => '\x94',
     "\x95" => '\x95',
     "\x96" => '\x96',
     "\x97" => '\x97',
     "\x98" => '\x98',
     "\x99" => '\x99',
     "\x9A" => '\x9A',
     "\x9B" => '\x9B',
     "\x9C" => '\x9C',
     "\x9D" => '\x9D',
     "\x9E" => '\x9E',
     "\x9F" => '\x9F',
     "\xA0" => '\xA0',
     "\xA1" => '\xA1',
     "\xA2" => '\xA2',
     "\xA3" => '\xA3',
     "\xA4" => '\xA4',
     "\xA5" => '\xA5',
     "\xA6" => '\xA6',
     "\xA7" => '\xA7',
     "\xA8" => '\xA8',
     "\xA9" => '\xA9',
     "\xAA" => '\xAA',
     "\xAB" => '\xAB',
     "\xAC" => '\xAC',
     "\xAD" => '\xAD',
     "\xAE" => '\xAE',
     "\xAF" => '\xAF',
     "\xB0" => '\xB0',
     "\xB1" => '\xB1',
     "\xB2" => '\xB2',
     "\xB3" => '\xB3',
     "\xB4" => '\xB4',
     "\xB5" => '\xB5',
     "\xB6" => '\xB6',
     "\xB7" => '\xB7',
     "\xB8" => '\xB8',
     "\xB9" => '\xB9',
     "\xBA" => '\xBA',
     "\xBB" => '\xBB',
     "\xBC" => '\xBC',
     "\xBD" => '\xBD',
     "\xBE" => '\xBE',
     "\xBF" => '\xBF',
     "\xC0" => '\xC0',
     "\xC1" => '\xC1',
     "\xC2" => '\xC2',
     "\xC3" => '\xC3',
     "\xC4" => '\xC4',
     "\xC5" => '\xC5',
     "\xC6" => '\xC6',
     "\xC7" => '\xC7',
     "\xC8" => '\xC8',
     "\xC9" => '\xC9',
     "\xCA" => '\xCA',
     "\xCB" => '\xCB',
     "\xCC" => '\xCC',
     "\xCD" => '\xCD',
     "\xCE" => '\xCE',
     "\xCF" => '\xCF',
     "\xD0" => '\xD0',
     "\xD1" => '\xD1',
     "\xD2" => '\xD2',
     "\xD3" => '\xD3',
     "\xD4" => '\xD4',
     "\xD5" => '\xD5',
     "\xD6" => '\xD6',
     "\xD7" => '\xD7',
     "\xD8" => '\xD8',
     "\xD9" => '\xD9',
     "\xDA" => '\xDA',
     "\xDB" => '\xDB',
     "\xDC" => '\xDC',
     "\xDD" => '\xDD',
     "\xDE" => '\xDE',
     "\xDF" => '\xDF',
     "\xE0" => '\xE0',
     "\xE1" => '\xE1',
     "\xE2" => '\xE2',
     "\xE3" => '\xE3',
     "\xE4" => '\xE4',
     "\xE5" => '\xE5',
     "\xE6" => '\xE6',
     "\xE7" => '\xE7',
     "\xE8" => '\xE8',
     "\xE9" => '\xE9',
     "\xEA" => '\xEA',
     "\xEB" => '\xEB',
     "\xEC" => '\xEC',
     "\xED" => '\xED',
     "\xEE" => '\xEE',
     "\xEF" => '\xEF',
     "\xF0" => '\xF0',
     "\xF1" => '\xF1',
     "\xF2" => '\xF2',
     "\xF3" => '\xF3',
     "\xF4" => '\xF4',
     "\xF5" => '\xF5',
     "\xF6" => '\xF6',
     "\xF7" => '\xF7',
     "\xF8" => '\xF8',
     "\xF9" => '\xF9',
     "\xFA" => '\xFA',
     "\xFB" => '\xFB',
     "\xFC" => '\xFC',
     "\xFD" => '\xFD',
     "\xFE" => '\xFE',
     "\xFF" => '\xFF');

my %p_DecodeAmpLtQuot = ('&amp;'  => '&',
                         '&lt;'   => '<',
                         '&quot;' => '"');
my %p_XMLField = ('&' => '&amp;',
                  '>' => '&gt;',
                  '<' => '&lt;',
                  '"' => '&quot;');

################################################################################
################################################################################
sub ASCIIfy {
    return join("",
                map({
                    if ($_ > 255) {
                        sprintf("\\x{%04X}", $_);            # Wide character...
                    } else {
                        my $Char = chr($_);
                        if (exists($p_BinaryToHexStr{$Char})) {
                            $p_BinaryToHexStr{$Char}
                        } else {
                            $Char;
                        }
                    }
                    } unpack("W*", $_[0])));         # unpack Unicode characters
}

################################################################################
# Name:
#   AddMonthsToMDY4SlashDate - Add months to a specified date.  If the resulting
#                              date is past the end of the result month (e.g.
#                              2/31/2016), the day is set to the end of the
#                              result month, ignoring leap years (e.g.
#                              2/28/2016).
# Synopsis:
#   AddMonthsToMDY4SlashDate(string $Date, int $Months);
# Example:
#   $StdDate = AddMonthsToMDY4SlashDate('10/9/2008', -7);
# Arguments:
#   $Date       Starting date.
#   $Months     Number of months to advance (negative value to subtract).
# Return:
#   Resulting date string or undef on error.
################################################################################
sub AddMonthsToMDY4SlashDate {
    my ($DateStr, $Months) = @_;

    unless ($DateStr =~ /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/) { return undef }
    my ($YYYY, $MM, $DD) = ($3, $1, $2);
    $MM += $Months;
    while ($MM > 12) { $MM -= 12; $YYYY += 1 }
    while ($MM <  1) { $MM += 12; $YYYY -= 1 }
    if ($DD > $MaxDayOfMonth[$MM]) { $DD = $MaxDayOfMonth[$MM] }
    return sprintf('%d/%d/%d', $MM, $DD, $YYYY);
}
        
################################################################################
# Name:
#   AddMonthsToStdDate - Add months to a specified date.  If the resulting date
#                        is past the end of the result month (e.g. 20160231),
#                        the day is set to the end of the result month, ignoring
#                        leap years (e.g. 20160228).
# Synopsis:
#   AddMonthsToStdDate(string $Date, int $Months);
# Example:
#   $StdDate = AddMonthsToStdDate('20081009', -7);
# Arguments:
#   $Date       Starting date.
#   $Months     Number of months to advance (negative value to subtract).
# Return:
#   Resulting date string or undef on error.
################################################################################
sub AddMonthsToStdDate {
    my ($DateStr, $Months) = @_;

    $DateStr =~ /^(\d{4})(\d{2})(\d{2})$/;
    my ($YYYY, $MM, $DD) = ($1, $2, $3);
    $MM += $Months;
    while ($MM > 12) { $MM -= 12; $YYYY += 1 }
    while ($MM <  1) { $MM += 12; $YYYY -= 1 }
    if ($DD > $MaxDayOfMonth[$MM]) { $DD = $MaxDayOfMonth[$MM] }
    return sprintf('%d%02d%02d', $YYYY, $MM, $DD);
}
    
################################################################################
# Name:
#   AddMonthsToY4MDDashDate - Add months to a specified date.  If the resulting
#                             date is past the end of the result month (e.g.
#                             2016-02-31), the day is set to the end of the
#                             result month, ignoring leap years (e.g.
#                             2016-02-28).
# Synopsis:
#   AddMonthsToY4MDDashDate(string $Date, int $Months);
# Example:
#   $StdDate = AddMonthsToY4MDDashDate('2008-10-09', -7);
# Arguments:
#   $Date       Starting date.
#   $Months     Number of months to advance (negative value to subtract).
# Return:
#   Resulting date string or undef on error.
################################################################################
sub AddMonthsToY4MDDashDate {
    my ($DateStr, $Months) = @_;

    $DateStr =~ /^(\d{4})-0?(\d+)-0?(\d+)$/;
    my ($YYYY, $MM, $DD) = ($1, $2, $3);
    $MM += $Months;
    while ($MM > 12) { $MM -= 12; $YYYY += 1 }
    while ($MM <  1) { $MM += 12; $YYYY -= 1 }
    if ($DD > $MaxDayOfMonth[$MM]) { $DD = $MaxDayOfMonth[$MM] }
    return sprintf('%d-%02d-%02d', $YYYY, $MM, $DD);
}
    
################################################################################
# Name:
#   AddToStdDate - Increment/decrement date in YYYYMMDD format.
# Synopsis:
#   AddToStdDate(string $Date, int $Days);
# Example:
#   $StdDate = AddToStdDate('20081009', -7);
# Arguments:
#   $Date       Starting date.
#   $Days       Number of days to advance (specify negative value to subtract).
# Return:
#   Standardized date string or undef on error.
# Notes:
#   Unix time is the number of seconds since January 1, 1970.
################################################################################
sub AddToStdDate {
    my ($DateStr, $Days) = @_;
    
    unless ($DateStr =~ /^(\d{4})(\d{2})(\d{2})$/) { return undef }
    my ($Year, $Month, $Day) = ($1, $2, $3);
    my $Date;
    eval { $Date = timegm(0, 0, 0, $Day, $Month - 1, $Year - 1900) };
    if ($@ || $Date < 0) { return undef }
    $Date += $Days * $SecondsPerDay;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        gmtime($Date);
    return sprintf('%04d%02d%02d', $year + 1900, $mon + 1, $mday);
}

################################################################################
# Name:
#   AddToY4MDDashDate - Increment/decrement date in YYYY-MM-DD format.
# Synopsis:
#   AddToY4MDDashDate(string $Date, int $Days);
# Example:
#   $Y4MDDashDate = AddToY4MDDashDate('2008-10-09', -7);
# Arguments:
#   $Date       Starting date.
#   $Days       Number of days to advance (specify negative value to subtract).
# Return:
#   Standardized date string or undef on error.
# Notes:
#   Unix time is the number of seconds since January 1, 1970.
################################################################################
sub AddToY4MDDashDate {
    my ($DateStr, $Days) = @_;
    
    unless ($DateStr =~ /^(\d{4})-(\d{2})-(\d{2})$/) { return undef }
    my ($Year, $Month, $Day) = ($1, $2, $3);
    my $Date;
    eval { $Date = timegm(0, 0, 0, $Day, $Month - 1, $Year - 1900) };
    if ($@ || $Date < 0) { return undef }
    $Date += $Days * $SecondsPerDay;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        gmtime($Date);
    return sprintf('%04d-%02d-%02d', $year + 1900, $mon + 1, $mday);
}

################################################################################
# Name:
#   AmpSemiToChar - Return ASCII string corresponding to the passed diacritic
#                   character in '&CODE;' format.
# Synopsis:
#   string AmpSemiToChar(string $Str);
# Example:
#   $Raw =~ s/(\&[\#\w]{2,8}?;)/&AmpSemiToChar($1)/ge;
# Arguments:
#   $Str        Input string to process.
# Return:
#   The transformed string or, if no substitution is known, the original string.
################################################################################
sub AmpSemiToChar {
    if (exists($p_AmpSemiToChar{$_[0]})) {
        return $p_AmpSemiToChar{$_[0]};
    } else {
        my $String = substr($_[0], 1, -1);
        return "&{$String};";
    }
}

################################################################################
# Name:
#   AmpSemiToChars - Replaces each diacritic character in '&CODE;' format in the
#                    input string with the corresponding ASCII character.  E.g.,
#                    each a-umlaut character is transformed to 'ae'.
# Synopsis:
#   string AmpSemiToChars(string $Str);
#   int AmpSemiToChars(string \$Str);
# Example:
#   $Clean = AmpSemiToChars($Raw);
# Arguments:
#   $Str        Input string or reference to the string to process.
# Return:
#   The transformed string or, if $Str is a reference to a string, the number of
#   replaced characters.
# Notes:
#   If $Str is a reference to a string, the operation is performed in-place.
################################################################################
sub AmpSemiToChars {
    if (ref($_[0])) {
        # String passed by reference -- modify in-place
        my $StrRef = $_[0];
        return $$StrRef =~ s/(\&[\#\w]{2,8}?;)/&AmpSemiToChar($1)/ge;
    } else {
        # Literal string passed -- modify and return a copy
        my $Str = $_[0];
        $Str =~ s/(\&[\#\w]{2,8}?;)/&AmpSemiToChar($1)/ge;
        return $Str;
    }
}

################################################################################
# Name:
#   BinaryToHexStr - Replaces each diacritic character in the input string with
#                    a string representation of the corresponding hex code.
# Synopsis:
#   string BinaryToHexStr(string $Str);
#   int BinaryToHexStr(string \$Str);
# Example:
#   $Clean = BinaryToHexStr($Raw);
# Arguments:
#   $Str        Input string or reference to the string to process.
# Return:
#   The transformed string or, if $Str is a reference to a string, the number of
#   replaced characters.
# Notes:
#   * If $Str is a reference to a string, the operation is performed in-place.
#   * Non-binary includes \x09 (\t), \x0A (\n), and \x0D (\r).
################################################################################
sub BinaryToHexStr {
    if (ref($_[0])) {
        my $StrRef = $_[0];
        my $Count = $$StrRef =~
            s/([\x00-\x08\x0B-\x0C\x0E-\x1F\x80-\xFF])/$p_BinaryToHexStr{$1}/g;
        return $Count;
    } else {
        my $Str = $_[0];                                           # Make a copy
        $Str =~
            s/([\x00-\x08\x0B-\x0C\x0E-\x1F\x80-\xFF])/$p_BinaryToHexStr{$1}/g;
        return $Str;
    }
}

################################################################################
# Name:
#   DateDMY4SlashToStd - Convert D/M/YYYY date to YYYYMMDD format.
# Synopsis:
#   DateDMY4SlashToStd(string $Date);
# Example:
#   $StdDate = DateDMY4SlashToStd('26/8/2008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateDMY4SlashToStd {
    unless ($_[0] =~ /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/) { return undef }
    my ($Day, $Month, $Year) = ($1, $2, $3);
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateDMYSlashToStd - Convert D/M/YY or D/M/YYYY date to YYYYMMDD format.
# Synopsis:
#   DateDMYSlashToStd(string $Date);
# Example:
#   $StdDate = DateDMYSlashToStd('26/08/08');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateDMYSlashToStd {
    unless ($_[0] =~ /^(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})$/) { return undef }
    my ($Day, $Month, $Year) = ($1, $2, $3);
    if ($Year < 25) { $Year += 2000 } elsif ($Year < 100) { $Year += 1900 }
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name: 
#   DateDMonY2DashToStd - Convert D-Mon-YY date to YYYYMMDD format.
# Synopsis:  
#   DateDMonY2DashToStd(string $Date);
# Example:  
#   $StdDate = DateDMonY2DashToStd('14-Nov-08')
# Arguments: 
#   $Date       Date string to process.
# Return: 
#   Standardized date string or undef on error.
################################################################################
sub DateDMonY2DashToStd {
    unless ($_[0] =~ /^(\d{1,2})-(\w+)-(\d{1,2})$/) { return undef }
    my ($Year, $Month, $Day) = ($3, $2, $1);
    return sprintf('%04d%02d%02d', $Year + 2000, $iMo{$Month}, $Day);
}

################################################################################
# Name: 
#   DateDMonY4ToStd - Convert "D Mon YYYY" date to YYYYMMDD format.
# Synopsis:  
#   DateDMonY4ToStd(string $Date);
# Example:  
#   $StdDate = DateDMonY4ToStd('14 Nov 2008')
# Arguments: 
#   $Date       Date string to process.
# Return: 
#   Standardized date string or undef on error.
################################################################################
sub DateDMonY4ToStd {
    unless ($_[0] =~ /^(\d{1,2}) (\w+) (\d{4})$/) { return undef }
    my ($Year, $Month, $Day) = ($3, $2, $1);
    return sprintf('%04d%02d%02d', $Year , $iMo{$Month}, $Day);
}

################################################################################
# Name:
#   DateExcelNumToStd - Convert Excel date number to YYYYMMDD format.
# Synopsis:
#   DateExcelNumToStd(string $Date);
# Example:
#   $StdDate = DateExcelNumToStd(39448);
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
# Notes:
#   * Excel stores dates as sequential serial numbers so that they can be used
#     in calculations. By default, January 1, 1900 is serial number 1, and
#     January 1, 2008 is serial number 39448 because it is 39,447 days after
#     January 1, 1900.
#   * Unix time is the number of seconds since January 1, 1970.
#   * 1/1/1970 = 25569 in Excel.
################################################################################
sub DateExcelNumToStd {
    unless ($_[0] =~ /^\d+$/) { return undef }
    my $DaysSince19700101 = $_[0] - 25569;
    if ($DaysSince19700101 < 0) { return undef }
    return AddToStdDate('19700101', $DaysSince19700101);
}

################################################################################
# Name:
#   DateMDY2DashToStd - Convert M-D-YY date to YYYYMMDD format.
# Synopsis:
#   DateMDY2DashToStd(string $Date);
# Example:
#   $StdDate = DateMDY2DashToStd('8-26-08');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMDY2DashToStd {
    unless ($_[0] =~ /^(\d{1,2})-(\d{1,2})-(\d{2})$/) { return undef }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    return sprintf('20%02d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateMDY2SlashToStd - Convert M/D/YY date to YYYYMMDD format.
# Synopsis:
#   DateMDY2SlashToStd(string $Date);
# Example:
#   $StdDate = DateMDY2SlashToStd('8/26/08');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMDY2SlashToStd {
    unless ($_[0] =~ /^(\d{1,2})\/(\d{1,2})\/(\d{2})$/) { return undef }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    if ($Year < 25) { $Year += 2000 } else { $Year += 1900 }
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateMDY4DashToStd - Convert M-D-YYYY date to YYYYMMDD format.
# Synopsis:
#   DateMDY4DashToStd(string $Date);
# Example:
#   $StdDate = DateMDY4DashToStd('8-26-2008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMDY4DashToStd {
    unless ($_[0] =~ /^(\d{1,2})-(\d{1,2})-(\d{4})$/) { return undef }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateMDY4SlashToStd - Convert M/D/YYYY date to YYYYMMDD format.
# Synopsis:
#   DateMDY4SlashToStd(string $Date);
# Example:
#   $StdDate = DateMDY4SlashToStd('8/26/2008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMDY4SlashToStd {
    unless ($_[0] =~ /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/) { return undef }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateMDY4SlashToY4MDDash - Convert M/D/YYYY date to YYYY-MM-DD format.
# Synopsis:
#   DateMDY4SlashToY4MDDash(string $Date);
# Example:
#   $StdDate = DateMDY4SlashToY4MDDash('8/26/2008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMDY4SlashToY4MDDash {
    unless ($_[0] =~ /^(\d{1,2})\/(\d{1,2})\/(\d{4})$/) { return undef }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    return sprintf('%04d-%02d-%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateMDY4ToStd - Convert MMDDYYYY date to YYYYMMDD format.
# Synopsis:
#   DateMDY4ToStd(string $Date);
# Example:
#   $StdDate = DateMDY4ToStd('08262008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMDY4ToStd {
    unless ($_[0] =~ /^(\d{2})(\d{2})(\d{4})$/) { return undef }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateMDYSlashToStd - Convert M/D/YY or M/D/YYYY date to YYYYMMDD format.
# Synopsis:
#   DateMDYSlashToStd(string $Date);
# Example:
#   $StdDate = DateMDYSlashToStd('8/26/08');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMDYSlashToStd {
    unless ($_[0] =~ /^(\d{1,2})\/(\d{1,2})\/(\d{2}|\d{4})$/) { return undef }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    if ($Year < 25) { $Year += 2000 } elsif ($Year < 100) { $Year += 1900 }
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateMonDY4ToStd - Convert date like 'Aug. 19, 2008' to YYYYMMDD format.
# Synopsis:
#   DateMonDY4ToStd(string $Date);
# Example:
#   $StdDate = DateMonDY4ToStd('May 19, 2008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateMonDY4ToStd {
    unless ($_[0] =~ /^([A-Z][a-z]{2})\.?\s+(\d{1,2})\,?\s+(20\d{2})$/) {
        return undef;
    }
    my ($Month, $Day, $Year) = ($1, $2, $3);
    $Month = $iMo{$Month} || return undef;
    $Day =~ s/^(\d)$/0$1/;
    return "$Year$Month$Day";
}

################################################################################
# Name:
#   DateWdayDMonY4ToStd - Convert date like 'Mon. 19 Aug. 2008' to YYYYMMDD
#                         format.
# Synopsis:
#   DateWdayDMonY4ToStd(string $Date);
# Example:
#   $StdDate = DateWdayDMonY4ToStd('Tue. 24 Jun. 2008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateWdayDMonY4ToStd {
    unless ($_[0] =~
            /^[A-Z][a-z]{2}\.\s+(\d{1,2})\s+([A-Z][a-z]{2})\.?\s+(\d{4})$/) {
        return undef;
    }
    my ($Day, $Month, $Year) = ($1, $2, $3);
    $Month = $iMo{$Month} || return undef;
    $Day =~ s/^(\d)$/0$1/;
    return "$Year$Month$Day";
}

################################################################################
# Name:
#   DateWdayMonDTimeY4ToStd - Convert date like 'Mon. 19 Aug. 2008' to YYYYMMDD
#                         format.
# Synopsis:
#   DateWdayMonDTimeY4ToStd(string $Date);
# Example:
#   $StdDate = DateWdayMonDTimeY4ToStd('Tue. 24 Jun. 2008');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateWdayMonDTimeY4ToStd {
    unless ($_[0] =~
            /^[A-Z][a-z]{2}\.?\s+([A-Z][a-z]{2})\.?\s+(\d{1,2})\s+\d{1,2}:\d{2}:\d{2}\s+(?:[-+]\d{4}\s+)?(\d{4})$/) {
        return undef;
    }
    my ($Day, $Month, $Year) = ($2, $1, $3);
    $Month = $iMo{$Month} || return undef;
    $Day =~ s/^(\d)$/0$1/;
    return "$Year$Month$Day";
}

################################################################################
# Name:
#   DateY4MDDashToMDY4Slash - Convert YYYY-MM-DD date to M/D/YYYY format.
# Synopsis:
#   DateY4MDDashToMDY4Slash(string $Date);
# Example:
#   $SlashDate = DateY4MDDashToMDY4Slash('2008-1-27');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Reformatted date string or undef on error.
################################################################################
sub DateY4MDDashToMDY4Slash {
    unless ($_[0] =~ /^(\d{4})-(\d{1,2})-(\d{1,2})$/) { return undef }
    my ($Year, $Month, $Day) = ($1, $2, $3);
    return sprintf('%d/%d/%d', $Month, $Day, $Year);
}

################################################################################
# Name:
#   DateY4MDDashToStd - Convert YYYY-MM-DD date to YYYYMMDD format.
# Synopsis:
#   DateY4MDDashToStd(string $Date);
# Example:
#   $StdDate = DateY4MDDashToStd('2008-1-27');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateY4MDDashToStd {
    unless ($_[0] =~ /^(\d{4})-(\d{1,2})-(\d{1,2})$/) { return undef }
    my ($Year, $Month, $Day) = ($1, $2, $3);
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DateY4MDTimeDashToStd - Convert YYYY-MM-DDT... date to YYYYMMDD format.
# Synopsis:
#   DateY4MDTimeDashToStd(string $Date);
# Example:
#   $StdDate = DateY4MDTimeDashToStd('2012-06-23T17:17:14Z');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub DateY4MDTimeDashToStd {
    unless ($_[0] =~ /^(\d{4})-(\d{1,2})-(\d{1,2})T\d{2}:\d{2}:\d{2}Z$/) {
        return undef;
    }
    my ($Year, $Month, $Day) = ($1, $2, $3);
    return sprintf('%04d%02d%02d', $Year, $Month, $Day);
}

################################################################################
# Name:
#   DecodeAmpLtQuot - Convert encoded '<', '&', and '"' to plain characters.
# Synopsis:
#   string DecodeAmpLtQuot(string $Str);
#   int DecodeAmpLtQuot(string \$Str);
# Example:
#   $Text = DecodeAmpLtQuot($Text);
# Arguments:
#   $Str        Input string or reference to the string to process.
# Return:
#   The transformed string or, if $Str is a reference to a string, the number of
#   replaced characters.
# Notes:
#   If $Str is a reference to a string, the operation is performed in-place.
################################################################################
sub DecodeAmpLtQuot ($) {
    if (ref($_[0])) {
        my $StrRef = $_[0];
        my $Count = $$StrRef =~ s/(\&(?:amp|lt|quot);)/$p_DecodeAmpLtQuot{$1}/g;
        return $Count;
    } else {
        my $Str = $_[0];                                           # Make a copy
        $Str =~ s/(\&(?:amp|lt|quot);)/$p_DecodeAmpLtQuot{$1}/g;
        return $Str;
    }
}

################################################################################
# Name:
#   EndOfMonthStd - Get last day of month in YYYYMMDD format.
# Synopsis:
#   EndOfMonthStd(string $Date);
# Example:
#   $StdDate = EndOfMonthStd('20081009');
# Arguments:
#   $Date       Any day in the month to process.
# Return:
#   Standardized date string or undef on error.
################################################################################
sub EndOfMonthStd {
    my $DateStr = $_[0];
    
    unless ($DateStr =~ /^(\d{4})(\d{2})(\d{2})$/) { return undef }
    my ($Year, $Month, $Day) = ($1, $2, $3);
    if ($Month eq '12') {
        # Easiest way to deal with end of year
        $Day = '31';
        return "$Year$Month$Day";
    }
    $Month = sprintf('%02d', $Month + 1);   # Correct if $Month is int or string
    $Day = '01';
    return AddToStdDate("$Year$Month$Day", -1);
}

################################################################################
# Name:
#   EndOfWeekStd - Get last day of week (Sun-Sat) in YYYYMMDD format.
# Synopsis:
#   EndOfWeekStd(string $Date, [int $EndDay]);
# Example:
#   $StdDate = EndOfWeekStd('20081009');
# Arguments:
#   $Date       Any day in the week to process.
#   $EndDay     Day of week defining the end of the week.
#               Default: 6 (Saturday).
# Return:
#   Standardized date string or undef on error.
################################################################################
sub EndOfWeekStd {
    my $DateStr = $_[0];
    
    unless ($DateStr =~ /^(\d{4})(\d{2})(\d{2})$/) { return undef }
    my ($Year, $Month, $Day) = ($1, $2, $3);
    my $Date;
    eval { $Date = timegm(0, 0, 0, $Day, $Month - 1, $Year - 1900) };
    if ($@ || $Date < 0) { return undef }
    my $wday = (gmtime($Date))[6];

    # gmtime's day of week ranges from 0 (Sun) through 6 (Sat)
    if (defined($_[1])) {
        my $EndDay = $_[1];
        my $DaysToEnd = $EndDay - $wday;
        if ($DaysToEnd < 0) { $DaysToEnd += 7 }
        return AddToStdDate("$Year$Month$Day", $DaysToEnd);
    } else {
        return AddToStdDate("$Year$Month$Day", 6 - $wday);
    }
}

################################################################################
# Name:
#   NormalizeAlphanum - Normalize punctuation & whitespace -- convert
#                       evertything other than numbers and ASCII letters to
#                       space.
# Synopsis:
#   NormalizeAlphanum(string $Query);
# Example:
#   NormalizeAlphanum($Query);
# Explicit arguments:
#   $Query      Query string to normalize.
# Return:
#   None -- normalization is carried out in place.
################################################################################
sub NormalizeAlphanum {
    $_[0] =~ s/[^a-zA-Z0-9]+/ /g;
    $_[0] = lc($_[0]);                                          # Normalize case
    Trim($_[0]);                                 # Remove surrounding whitespace
}

################################################################################
# Name:
#   NormalizeMinimal - Normalize punctuation & whitespace -- minimal.
# Synopsis:
#   NormalizeMinimal(string $Query);
# Example:
#   NormalizeMinimal($Query);
# Explicit arguments:
#   $Query      Query string to normalize.
# Return:
#   None -- normalization is carried out in place.
################################################################################
sub NormalizeMinimal {
    $_[0] = lc($_[0]);                                          # Normalize case
    # Non-printable ASCII, "Supplementary Private Use" UNICODE, and whitespace
    $_[0] =~ s/[\x00-\x1F\x{F0000}-\x{10FFFD}\s・]+/ /g;
    $_[0] =~ s/(^|\s)[\\]+/$1/g;                    # Punctuation after boundary
    $_[0] =~ s/[\\]+(?=(\s|\Z))//g;                # Punctuation before boundary
    Trim($_[0]);                                 # Remove surrounding whitespace
}

################################################################################
# Name:
#   NormalizeNone - Don't do anything
# Synopsis:
#   NormalizeNone(string $Query);
# Example:
#   NormalizeNone($Query);
# Explicit arguments:
#   $Query      Query string to normalize.
# Return:
#   None -- normalization is carried out in place.
################################################################################
sub NormalizeNone {
}

################################################################################
# Name:
#   NormalizeToGSQR - Normalize punctuation & whitespace to match Google Search
#                     Query report strings.
# Synopsis:
#   NormalizeToGSQR(string $Query);
# Example:
#   NormalizeToGSQR($Query);
# Explicit arguments:
#   $Query      Query string to normalize.
# Return:
#   None -- normalization is carried out in place.
################################################################################
sub NormalizeToGSQR {
    $_[0] = lc($_[0]);                                          # Normalize case
    $_[0] =~ s/(^|\D)\.+/$1 /g;             # Replace '.' unless following digit
    $_[0] =~ s/\.+(\D|\Z)/ $1/g;          # Replace '.' unless just before digit
    $_[0] =~ s/\'+([^s]|\Z)/ $1/g;          # Replace "'" unless just before 's'
    # Non-printable ASCII, whitespace, and other punctuation not handled above
    $_[0] =~ s/[\x00-\x1F\x{F0000}-\x{10FFFD}\-\^\[\]\/\\\$\"\`\s!%,;=?@|~<>(){}®™・]+/ /g;
    Trim($_[0]);                                 # Remove surrounding whitespace
}

################################################################################
# Name:
#   NormalizeToGoogleWebSearch - Normalize punctuation & whitespace to match
#                                what Google Web search does.
# Synopsis:
#   NormalizeToGoogleWebSearch(string $Query);
# Example:
#   NormalizeToGoogleWebSearch($Query);
# Explicit arguments:
#   $Query      Query string to normalize.
# Return:
#   None -- normalization is carried out in place.
################################################################################
sub NormalizeToGoogleWebSearch {
    $_[0] = lc($_[0]);                                          # Normalize case
    # Non-printable ASCII, "Supplementary Private Use" UNICODE, whitespace, ...
    $_[0] =~ s/[\x00-\x1F\x{F0000}-\x{10FFFD}\s®™・]+/ /g;
    $_[0] =~ s/(^|\s)[\\]+/$1/g;                    # Punctuation after boundary
    $_[0] =~ s/[\\]+(?=(\s|\Z))//g;                # Punctuation before boundary
    Trim($_[0]);                                 # Remove surrounding whitespace
}

################################################################################
# Name:
#   ParseDateRange - Parse a string consisting of two dates (YYYYMMDD format)
#                    separated by a hyphen into start and end time() values
# Synopsis:
#   ParseDateRange(string $Range);
# Example:
#   (Start, Length) = ParseDateRange($Range);
# Arguments:
#   $Range      String to parse.
# Return:
#   List of two Perl time integers (start and end) or undef on error.
################################################################################
sub ParseDateRange {
    my $Range = $_[0];
    my $Start = 0;
    my $End = 0;

    unless ($Range =~
            /^((?:19|20)\d{2})(\d{2})(\d{2})-((?:19|20)\d{2})(\d{2})(\d{2})$/) {
        return undef;
    }
    my ($sYear, $sMonth, $sDay, $eYear, $eMonth, $eDay) =
        ($1, $2, $3, $4, $5, $6);
    $sYear -= 1900;
    $sMonth -= 1;                                       # Index, January = 0
    $eYear -= 1900;
    $eMonth -= 1;                                       # Index, January = 0
    eval { $Start = timegm(0, 0, 0, $sDay, $sMonth, $sYear) };
    if ($@ || $Start < 0) { return undef }
    eval { $End = timegm(0, 0, 0, $eDay, $eMonth, $eYear) };
    if ($@ || $End < 0) { return undef }
    return ($Start, $End);
}

################################################################################
# Name:
#   ParseURL - Parse a URL into its components.
# Synopsis:
#   ParseURL(string $URL);
# Example:
#   $LinkComponents = ParseURL($Link);
# Arguments:
#   $URL        String to parse.
# Return:
#   Reference to a hash or undef on error.
################################################################################
sub ParseURL {
    my $URL = $_[0];

    my %Comps = ();
    if ($URL =~ s/^(\w+)\:\/\///) {
        $Comps{PROTOCOL} = $1;
    }
    if ($URL =~ s/\?(.*)$//) {
        $Comps{GETSTR} = $1;
    }
    if ($URL =~ s/\/(.*)$//) {
        my $Path = $1;
        $Comps{PATH} = $Path;
        if ($Path =~ /^(.*?)\/(.*)/) {
            my $Dir1 = $1;
            my $Rest = $2;
            $Rest =~ s/\/.*//;
            $Comps{PATH2} = "$Dir1/$Rest";
        }
        $Path =~ s/\/.*//;
        $Comps{PATH1} = $Path;
    }
    if ($URL =~ s/:(\d+)$//) {
        $Comps{PORT} = $1;            # E.g. hap1.ucweb.com.cn:8040/baidu_groups
    }
    $URL =~ s/\.+$//;         # E.g. www.google.com./search?hl=en&q=x server ibm
    if (defined($Comps{PROTOCOL}) && $Comps{PROTOCOL} eq 'ftp' &&
        $URL =~ s/^(.*?)\@//) {
        $Comps{USER} = $1;
    }
    if ($URL =~ /^\d+\.\d+\.\d+\.\d+$/) {
        $Comps{IP} = $URL;                                          # IP address
        return \%Comps;
    }
    # Internationalized URLs look like:
    #   http://xn--mgbe4fmfm.xn--mgbaam7a8h/en/news-updates/news/
    # The "xn--" indicates that the rest of the component is Punycode-encoded.
    my $UnicodeRootDomain = 0;
    if ($URL =~ /\.xn--[^.]+$/) { $UnicodeRootDomain = 1 }
    my @Transformed = ();
    foreach my $Component (split(/\./, $URL)) {
        if ($Component =~ s/^xn--//) {
            push(@Transformed, decode_punycode($Component));
        } else {
            # Lowercase (e.g. paid search display URLs)
            push(@Transformed, lc($Component));
        }
    }
    $Comps{DOMAIN} = $URL = join('.', @Transformed);
    
    # Parse DOMAIN into rest.D2.D1.D0
    if ($URL =~ s/\.([a-z]{2})$// ||
        ($UnicodeRootDomain && $URL =~ s/\.([^.]+)$//)) {
        # Recognize types in 2nd level domain names, e.g.
        # * com.au, com.co – commercial
        # * edu.au, edu.co, ac.cy, ac.il, k12.il, ac.uk – educational
        # * gov.au, gov.co, gob.gt, gov.il, muni.il – government
        # * id.au, nom.co, name.cy - individuals
        # * mil.co, mil.do, idf.il – military
        # * net.au, net.co – network infrastructure (or any commercial entity)
        # * org.au, org.co – organizations
        # Source of the above info is Wikipedia, e.g. en.wikipedia.org/wiki/.uk
        my $Country = $Comps{COUNTRY} = $1;            # Country code incl. "us"
        if (exists($TwoLevelTLDs{$Country}) &&
            $TwoLevelTLDs{$Country} eq 'TLDT') {
            if ($URL =~ s/\.([^.]+)$//) {
                my $L2 = $1;
                if (exists($TwoLevelDomainTypes{"$L2.$Country"})) {
                    $Comps{D0} = "$L2.$Country";
                    $Comps{TYPE} = $TwoLevelDomainTypes{"$L2.$Country"};
                } else {
                    $URL .= ".$L2";                           # Stick it back on
                    $Comps{D0} = $Country;
                }
            } else {
                $Comps{D0} = $Country;
            }
        } elsif ($TwoLevelTLDs{$Country} &&
                 $URL =~ s/\.(ac|com?|edu?|gov?|mil|net?)$//) {
            $Comps{D0} = "$1.$Country";
            $Comps{TYPE} = $DomainTypeAbbrs{$1};
        } else {
            $Comps{D0} = $Country;
        }
    } elsif ($URL =~ s/\.([a-z]+)$//) {
        $Comps{D0} = $1;
        $Comps{TYPE} = $1;
    } else {
        # Incorrect URL format, e.g. bad URL entered by paid search marketer
        $Comps{ERROR} = 1;
    }
    my @DomainComps = split(/\.+/, $URL);
    if (@DomainComps) {
        $Comps{D1} = $DomainComps[$#DomainComps];
    }
    if (@DomainComps > 1) {
        $Comps{D2} = $DomainComps[$#DomainComps - 1];
    }
    
    return \%Comps;
}

################################################################################
# Name:
#   StdDate - Return the YYYYMMDD date string corresponding to a Perl time.
# Synopsis:
#   string StdDate(int $Time);
# Example:
#   $StdDate = StdDate(time());
# Arguments:
#   $Time       The Perl time to convert.  Default: time().
# Return:
#   Standardized date string.
# Note:
#   The date string is based on the machine's local timezone.
################################################################################
sub StdDate {
    my $Time = $_[0];
    unless (defined($Time)) { $Time = time() }
    
    my ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        localtime($Time);
    return sprintf('%04d%02d%02d', $year + 1900, $mon + 1, $mday);
}

################################################################################
# Name:
#   StdDateToY4MDDash - Convert standard date format to YYYY-MM-DD format.
# Synopsis:
#   StdDateToY4MDDash(string $Date);
# Example:
#   $sDate = StdDateToY4MDDash('20080926');
# Arguments:
#   $Date       Date string to process.
# Return:
#   Reformatted date string or undef on error.
################################################################################
sub StdDateToY4MDDash {
    unless ($_[0] =~ /^(\d{4})(\d{2})(\d{2})$/) { return undef }
    return "$1-$2-$3";
}

sub StripBusinessType {
    my $Name = $_[0];

    while ($Name =~ s/ (co|corp|corporation|inc|incorporated|(?:irrevocable )?trust|limited|llc|l l c)$//) {
        # Do nothing
    }
    return $Name;
}

################################################################################
# Name:
#   SubtractStdDates - Subtract two dates in YYYYMMDD format.
# Synopsis:
#   SubtractStdDates(string $BiggerDate, string $SmallerDate);
# Example:
#   $Diff = SubtractStdDates('20081009', '20071009');
# Arguments:
#   $BiggerDate   Date to subtract from.
#   $SmallerDate  Date to subtract;
# Return:
#   Integer difference.
################################################################################
sub SubtractStdDates {
    my ($sDate1, $sDate2) = @_;

    my ($Date1, $Date2);
    unless ($sDate1 =~ /^(\d{4})(\d{2})(\d{2})$/) { return undef }
    my ($Year1, $Month1, $Day1) = ($1, $2, $3);
    eval { $Date1 = timegm(0, 0, 0, $Day1, $Month1 - 1, $Year1 - 1900) };
    if ($@ || $Date1 < 0) { return undef }
    unless ($sDate2 =~ /^(\d{4})(\d{2})(\d{2})$/) { return undef }
    my ($Year2, $Month2, $Day2) = ($1, $2, $3);
    eval { $Date2 = timegm(0, 0, 0, $Day2, $Month2 - 1, $Year2 - 1900) };
    if ($@ || $Date2 < 0) { return undef }
    return ($Date1 - $Date2) / $SecondsPerDay;
}

################################################################################
# Name:
#   SubtractY4MDDashDates - Subtract two dates in YYYY-MM-DD format.
# Synopsis:
#   SubtractY4MDDashDates(string $BiggerDate, string $SmallerDate);
# Example:
#   $Diff = SubtractY4MDDashDates('2008-10-09', '2007-10-09');
# Arguments:
#   $BiggerDate   Date to subtract from.
#   $SmallerDate  Date to subtract;
# Return:
#   Integer difference in days.
################################################################################
sub SubtractY4MDDashDates {
    my $sDate1 = DateY4MDDashToStd($_[0]);
    my $sDate2 = DateY4MDDashToStd($_[1]);

    return SubtractStdDates($sDate1, $sDate2);
}

################################################################################
# Name:
#   SubtractY4MDDashMonths - Determine the number of months difference between
#                            two dates in YYYY-MM-DD format.
# Synopsis:
#   SubtractY4MDDashMonths(string $BiggerDate, string $SmallerDate);
# Example:
#   $Diff = SubtractY4MDDashMonths('2008-10-09', '2007-10-09');
# Arguments:
#   $BiggerDate   Date to subtract from.
#   $SmallerDate  Date to subtract;
# Return:
#   Integer difference in months.  If dates are in same month, difference is 0.
################################################################################
sub SubtractY4MDDashMonths {
    $_[0] =~ /^(\d{4})-0?(\d+)-0?(\d+)$/;
    my ($YYYY0, $MM0, $DD0) = ($1, $2, $3);
    $_[1] =~ /^(\d{4})-0?(\d+)-0?(\d+)$/;
    my ($YYYY1, $MM1, $DD1) = ($1, $2, $3);
    return 12 * ($YYYY0 - $YYYY1) + $MM0 - $MM1;
}
    
################################################################################
# Name:
#   TitleCase - Convert English string to title case, returning result.
# Synopsis:
#   string TitleCase(string $String);
# Example:
#   $Shorter = TitleCase($String);
# Arguments:
#   $String     String to trim.
# Return:
#   TitleCase string.
# Notes:
#   * More-or-less adheres to the Chicago Manual of Style guideline
#     (http://www.press.uchicago.edu/Misc/Chicago/cmosfaq/cmosfaq.html)
#     to lowercase articles, conjunctions, and prepositions with the caveats
#     that:
#     + If a preposition, conjunction, or article is the first word or last word
#       in a title, the first letter should be in uppercase.
#     + If a preposition, conjunction, or article consists of five or more
#       letters, the first letter should be in uppercase.
#     + Last word in string is capitalized.
#   * This routine will mangle abbreviations, multi-sentence strings, and other
#     text that should retain its original case.
################################################################################
sub TitleCase ($) {
    my $Str = $_[0];

    my @Array =
        split(/([\ \t\r\n\"\,\.\!\?\;\:\'\`\-\+\&\/\\\(\)\[\]\{\}]+)/, $Str);
    my $i;
    my $iFirstWord = -1;
    my $iLastWord = -2;
    for ($i = 0; $i < @Array; ++$i) {
        if ($Array[$i] =~ /\w/) {
            unless ($iFirstWord >= 0) { $iFirstWord = $i }
            $iLastWord = $i;
        }
    }
    for ($i = $iFirstWord; $i <= $iLastWord; ++$i) {
        $Array[$i] = lc($Array[$i]);
        if ($p_Articles{$Array[$i]} &&
            $i != $iFirstWord && $i != $iLastWord) {
            next;    # Don't capitalize this article / conjunction / preposition
        }
        if ($Array[$i] eq 's' && $i > 0 && $Array[$i - 1] =~ /\'$/) {
            next;                     # Don't 's' after apostrophe, e.g. "Tom's"
        }

        $Array[$i] = ucfirst($Array[$i]);
    }
    return join('', @Array);
}

################################################################################
# Name:
#   Trim - Remove leading and trailing whitespace (in place).
# Synopsis:
#   Trim(string $String);
# Example:
#   Trim($String);
# Arguments:
#   $String     Variable to trim.
# Return:
#   None.
# Notes:
#   The operation is performed in-place (the argument itself is modified).
################################################################################
sub Trim ($) { $_[0] =~ s/^\s*(.*?)\s*$/$1/s }

################################################################################
# Name:
#   TrimLeft - Remove leading whitespace (in place).
# Synopsis:
#   TrimLeft(string $String);
# Example:
#   TrimLeft($String);
# Arguments:
#   $String     Variable to trim.
# Return:
#   None.
# Notes:
#   The operation is performed in-place (the argument itself is modified).
################################################################################
sub TrimLeft ($) { $_[0] =~ s/^\s*// }

################################################################################
# Name:
#   TrimRight - Remove trailing whitespace (in place).
# Synopsis:
#   TrimRight(string $String);
# Example:
#   TrimRight($String);
# Arguments:
#   $String     Variable to trim.
# Return:
#   None.
# Notes:
#   The operation is performed in-place (the argument itself is modified).
################################################################################
sub TrimRight ($) { $_[0] =~ s/\s*$// }

################################################################################
# Name:
#   Trimmed - Remove leading and trailing whitespace, returning result.
# Synopsis:
#   string Trimmed(string $String);
# Example:
#   $Shorter = Trimmed($String);
# Arguments:
#   $String     String to trim.
# Return:
#   Trimmed string.
################################################################################
sub Trimmed ($) {
    my $Str = $_[0];

    $Str =~ s/^\s*(.*?)\s*$/$1/;
    return $Str;
}

################################################################################
# Name:
#   TrimmedLeft - Remove leading whitespace, returning result.
# Synopsis:
#   string TrimmedLeft(string $String);
# Example:
#   $Shorter = TrimmedLeft($String);
# Arguments:
#   $String     String to trim.
# Return:
#   TrimmedLeft string.
################################################################################
sub TrimmedLeft ($) {
    my $Str = $_[0];

    $Str =~ s/^\s*//;
    return $Str;
}

################################################################################
# Name:
#   TrimmedRight - Remove trailing whitespace, returning result.
# Synopsis:
#   string TrimmedRight(string $String);
# Example:
#   $Shorter = TrimmedRight($String);
# Arguments:
#   $String     String to trim.
# Return:
#   TrimmedRight string.
################################################################################
sub TrimmedRight ($) {
    my $Str = $_[0];

    $Str =~ s/\s*$//;
    return $Str;
}

################################################################################
# Name:
#   UniqueChars - Compute a new string consisting of the unique characters of
#                 the input string
# Synopsis:
#   string UniqueChars(string $String);
# Example:
#   $Unique = UniqueChars($String);
# Arguments:
#   $String     String to process.
# Return:
#   Result string (sorted unique characters).
################################################################################
sub UniqueChars ($) {
    my $In = $_[0];

    my %Unique;
    @Unique{split(//, $In)} = ();                                   # Hash slice
    return join('', sort(keys(%Unique)));
}

################################################################################
# Name:
#   XMLField - Convert a string to an XML-safe string (delimiters '<', '>', '&',
#              and '"' replaced).
# Synopsis:
#   string XMLField(string $In);
# Example:
#   $Text = XMLField($Text);
# Arguments:
#   $In         String to process.
# Return:
#   Result string.
################################################################################
sub XMLField ($) {
    my $Text = shift;

    $Text =~ s/([\&\<\>\"])/$p_XMLField{$1}/g;
    return $Text;
}

################################################################################
# Name:
#   nOccurrences - Count number of occurrences of the query regexp in the target
#                  string.
# Synopsis:
#   int nOccurrences(string $Target, string $Query);
#   int nOccurrences(string \$Target, string $Query);
# Example:
#   $Count = nOccurrences($Target, $Query);
# Arguments:
#   $Target     Target string to process.
#   $Query      Query substring to count.
# Return:
#   Count of occurrences of the query.
################################################################################
sub nOccurrences ($$) {
    my $TargetRef;
    if (ref($_[0])) {
        $TargetRef = $_[0];
    } else {
        $TargetRef = \$_[0];
    }
    my $Query = $_[1];

    my $Count = 0;
    while ($$TargetRef =~ /$Query/gs) { ++$Count }
    return $Count;
}

1;
