#!/usr/bin/perl -w
# This file is part of LibParserUtils.
# Licensed under the MIT License,
#                http://www.opensource.org/licenses/mit-license.php
# Copyright 2010 Daniel Silverstone <dsilvers@netsurf-browser.org>
#                John-Mark Bell <jmb@netsurf-browser.org>

use strict;

use constant ALIAS_FILE => 'build/Aliases';
use constant ALIAS_INC  => 'src/charset/aliases.inc';

use constant UNICODE_CHARSETS => 
  [
   qr'^ISO-10646-UCS-[24]$',
   qr'^UTF-16',
   qr'^UTF-8$',
   qr'^UTF-32'
  ];

open(INFILE, "<", ALIAS_FILE) || die "Unable to open " . ALIAS_FILE;

my %charsets;

while (my $line = <INFILE>) {
   last unless (defined $line);
   next if ($line =~ /^#/);
   chomp $line;
   next if ($line eq '');
   my @elements = split /\s+/, $line;
   my $canon = shift @elements;
   my $mibenum = shift @elements;
   $charsets{$canon} = [$mibenum, \@elements];
}

close(INFILE);

my $unicodeexp = "";

my $output = <<'EOH';
/*
 * This file is part of LibParserUtils.
 * Licensed under the MIT License,
 *                http://www.opensource.org/licenses/mit-license.php
 * Copyright 2010 The NetSurf Project.
 *
 * Note: This file is automatically generated by make-aliases.pl
 *
 * Do not edit file file, changes will be overwritten during build.
 */

static parserutils_charset_aliases_canon canonical_charset_names[] = {
EOH

my %aliases;
my $canonnr = 0;
my $mibenum = 0;
foreach my $canon (sort keys %charsets) {
   my ($mibenum, $elements) = @{$charsets{$canon}};
   # If $mibenum is undefined, set it to 0
   $mibenum = 0 unless defined $mibenum;
   # Ordering must match struct in src/charset/aliases.h
   $output .= "\t{ " . $mibenum . ", " . length($canon) . ', "' . $canon . '" },' . "\n";
   my $isunicode = 0;
   foreach my $unirexp (@{UNICODE_CHARSETS()}) {
      $isunicode = 1 if ($canon =~ $unirexp);
   }
   if ($isunicode == 1) {
      $unicodeexp .= "((x) == $mibenum) || ";
   }
   $canon =~ y/A-Z/a-z/;
   $canon =~ s/[^a-z0-9]//g;
   $aliases{$canon} = $canonnr;
   foreach my $alias (@$elements) {
      $alias =~ y/A-Z/a-z/;
      $alias =~ s/[^a-z0-9]//g;
      $aliases{$alias} = $canonnr;
   }
   $canonnr += 1;
}

$output .= "};\n\nstatic const uint16_t charset_aliases_canon_count = ${canonnr};\n\n";

$output .= <<'EOT';
typedef struct {
	uint16_t name_len;
	const char *name;
	parserutils_charset_aliases_canon *canon;
} parserutils_charset_aliases_alias;

static parserutils_charset_aliases_alias charset_aliases[] = {
EOT

my $aliascount = 0;

foreach my $alias (sort keys %aliases) {
   my $canonnr = $aliases{$alias};
   $output .= "\t{ " . length($alias) . ', "' . $alias . '", &canonical_charset_names[' . $canonnr . "] },\n";
   $aliascount += 1;
}

$output .= "};\n\n";

# Drop the final " || "
chop $unicodeexp;
chop $unicodeexp;
chop $unicodeexp;
chop $unicodeexp;

$output .= <<"EOS";
static const uint16_t charset_aliases_count = ${aliascount};

#define MIBENUM_IS_UNICODE(x) ($unicodeexp)
EOS

if (open(EXISTING, "<", ALIAS_INC)) {
   local $/ = undef();
   my $now = <EXISTING>;
   undef($output) if ($output eq $now);
   close(EXISTING);
}

if (defined($output)) {
   open(OUTF, ">", ALIAS_INC);
   print OUTF $output;
   close(OUTF);
}
