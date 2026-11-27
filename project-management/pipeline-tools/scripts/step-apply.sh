#!/usr/bin/env bash
# Applies a step's `apply` block — verbatim content the decomposer wrote once — to the
# files in a worktree, so no model retypes it. All operations are validated against the
# current files first; nothing is written unless every one of them can be applied.
#
# Usage: step-apply.sh --worktree <path> --step <step-file> [--check]
#
#   --check   validate and print the result lines, write nothing (the decomposer's dry run)
#
# The `apply` block (a step-file block field, lines indented four spaces) is a sequence of
# operations, ended by `@@ end`:
#
#   @@ replace <path>            the @old text occurs exactly once in the file (it may be
#   @old                           part of a line or span lines) and becomes the @new text
#   <text>
#   @new
#   <text>
#   @@ insert-after <path>       the @anchor line is found in exactly one line of the file
#   @anchor                        (it may be a fragment of that line); the @text lines go
#   <one line>                     directly after that line — or before it, for
#   @text                          `@@ insert-before`
#   <lines>
#   @@ append <path>             the @text lines go at the end of the file
#   @text
#   <lines>
#   @@ create <path> [eol=crlf]  a new file holding the @text lines; fails if it exists
#   @text
#   <lines>
#   @@ end
#
# Every line between two directives is content, exactly as written — blank lines included.
# A content line that itself starts with `@` is written `\@...`. An existing file keeps its
# line endings (CRLF stays CRLF); a created file is LF unless `eol=crlf` is given.
# Operations on one file apply in order, each to the result of the one before.
#
# Prints:
#   APPLIED <n> operation(s)           (or `CHECKED <n> operation(s)` with --check)
#   FILE <path> lines=<n> md5=<md5 of the result with LF line endings>
# or `FAIL: <n> defect(s)` and one `DEFECT <operation #> <path>: <why>` per defect (exit 1).
# Exit 2 on usage, a missing step file, or a step without an `apply` block.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

wt="" step="" check=0
usage="step-apply.sh --worktree <path> --step <step-file> [--check]"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --worktree) wt="$2"; shift 2 ;;
        --step) step="$2"; shift 2 ;;
        --check) check=1; shift ;;
        *) usage_error "$usage" ;;
    esac
done
[[ -n "$wt" && -n "$step" ]] || usage_error "$usage"
[[ -f "$step" ]] || { echo "step file not found: $step" >&2; exit 2; }
[[ -d "$wt" ]] || { echo "worktree not found: $wt" >&2; exit 2; }
command -v perl >/dev/null || { echo "step-apply.sh needs perl" >&2; exit 2; }

ops="$(mktemp)"
trap 'rm -f "$ops"' EXIT
step_block "$step" apply >"$ops"
[[ -s "$ops" ]] || { echo "no apply block in $step" >&2; exit 2; }

perl - "$wt" "$ops" "$check" <<'PERL'
use strict; use warnings; use Digest::MD5 qw(md5_hex);
my ($wt, $opsfile, $check) = @ARGV;
open my $in, '<:raw', $opsfile or die "open ops\n";
my @lines = map { s/\r?\n\z//; $_ } <$in>; close $in;

my (@ops, $op, $part, $ended);
for my $l (@lines) {
    if ($l =~ /^@@ end\s*$/) { $ended = 1; last; }
    if ($l =~ /^@@ (replace|insert-after|insert-before|append|create) (.+?)\s*$/) {
        my ($kind, $path) = ($1, $2); my $eol = '';
        $eol = 'crlf' if $kind eq 'create' && $path =~ s/\s+eol=crlf$//;
        $op = { kind => $kind, path => $path, eol => $eol, n => scalar(@ops) + 1 };
        push @ops, $op; $part = undef; next;
    }
    if ($l =~ /^@(old|new|anchor|text)\s*$/ && $op) { $part = $1; $op->{$part} = []; next; }
    if ($l =~ /^@/) { push @ops, { kind => 'bad', path => '-', n => scalar(@ops) + 1, why => "unknown directive: $l" }; $op = undef; $part = undef; next; }
    next unless $op && defined $part;
    $l =~ s/^\\@/@/;
    push @{ $op->{$part} }, $l;
}

my (@defects, %content, %crlf, %order, @paths);
my $defect = sub { my ($o, $why) = @_; push @defects, "DEFECT $o->{n} $o->{path}: $why"; };
push @defects, "DEFECT 0 -: the apply block does not end with `\@\@ end`" unless $ended;
push @defects, "DEFECT 0 -: the apply block holds no operation" unless @ops;

my %need = (replace => [qw(old new)], 'insert-after' => [qw(anchor text)],
            'insert-before' => [qw(anchor text)], append => ['text'], create => ['text']);
my $count = sub { my ($hay, $needle) = @_; my ($c, $p) = (0, 0);
    while (($p = index($hay, $needle, $p)) >= 0) { $c++; $p += length($needle) || 1; } $c };

for my $o (@ops) {
    if ($o->{kind} eq 'bad') { $defect->($o, $o->{why}); next; }
    my $p = $o->{path};
    if ($p =~ m{^/} || $p =~ m{^[A-Za-z]:} || $p =~ m{(^|/)\.\.(/|$)} || $p =~ /\\/) { $defect->($o, 'path must be repo-relative with forward slashes'); next; }
    my @missing = grep { !defined $o->{$_} } @{ $need{ $o->{kind} } };
    if (@missing) { $defect->($o, 'missing @' . join(', @', @missing)); next; }
    my $full = "$wt/$p";
    if (!exists $content{$p}) {
        if ($o->{kind} eq 'create') {
            if (-e $full) { $defect->($o, 'file already exists'); next; }
            $content{$p} = ''; $crlf{$p} = $o->{eol} eq 'crlf'; push @paths, $p;
            $content{$p} = join("\n", @{ $o->{text} }) . "\n"; next;
        }
        if (!-f $full) { $defect->($o, 'file not found'); next; }
        open my $fh, '<:raw', $full or do { $defect->($o, 'cannot read'); next; };
        local $/; my $c = <$fh>; close $fh;
        $crlf{$p} = ($c =~ /\r\n/) ? 1 : 0; $c =~ s/\r\n/\n/g;
        $content{$p} = $c; push @paths, $p;
    } elsif ($o->{kind} eq 'create') { $defect->($o, 'create must be the first operation on its file'); next; }
    my $c = $content{$p};
    if ($o->{kind} eq 'replace') {
        my $old = join("\n", @{ $o->{old} }); my $new = join("\n", @{ $o->{new} });
        if ($old eq '') { $defect->($o, '@old is empty'); next; }
        my $k = $count->($c, $old);
        if ($k != 1) { $defect->($o, "\@old occurs $k times, must occur exactly once"); next; }
        my $i = index($c, $old); substr($c, $i, length($old)) = $new;
    } elsif ($o->{kind} =~ /^insert/) {
        my @a = @{ $o->{anchor} };
        if (@a != 1 || $a[0] eq '') { $defect->($o, '@anchor must be exactly one non-empty line'); next; }
        my @fl = split /\n/, $c, -1; my $trail = (@fl && $fl[-1] eq '') ? 1 : 0; pop @fl if $trail;
        my @hit = grep { index($fl[$_], $a[0]) >= 0 } 0 .. $#fl;
        if (@hit != 1) { $defect->($o, '@anchor is found in ' . scalar(@hit) . ' lines, must be exactly one'); next; }
        my $at = $o->{kind} eq 'insert-after' ? $hit[0] + 1 : $hit[0];
        splice @fl, $at, 0, @{ $o->{text} };
        $c = join("\n", @fl) . ($trail ? "\n" : '');
    } elsif ($o->{kind} eq 'append') {
        $c .= "\n" if $c ne '' && $c !~ /\n\z/;
        $c .= join("\n", @{ $o->{text} }) . "\n";
    }
    $content{$p} = $c;
}

if (@defects) { print "FAIL: " . scalar(@defects) . " defect(s)\n"; print "$_\n" for @defects; exit 1; }

print(($check ? 'CHECKED ' : 'APPLIED ') . scalar(@ops) . " operation(s)\n");
for my $p (@paths) {
    my $c = $content{$p};
    my $n = () = $c =~ /\n/g;
    print "FILE $p lines=$n md5=" . md5_hex($c) . "\n";
    next if $check;
    my $out = $c; $out =~ s/\n/\r\n/g if $crlf{$p};
    my $full = "$wt/$p";
    if ($full =~ m{^(.*)/[^/]+$} && !-d $1) { require File::Path; File::Path::make_path($1); }
    open my $fh, '>:raw', $full or die "cannot write $full\n";
    print $fh $out; close $fh;
}
PERL
