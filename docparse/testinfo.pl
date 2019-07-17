#!/usr/bin/perl
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Copyright (c) 2019 Cyril Hrubis <chrubis@suse.cz>
#

use strict;
use warnings;

use JSON;

sub load_json
{
	my ($fname) = @_;
	local $/;

	open(my $fh, '<', $fname) or die("Can't open $fname $!");

	return <$fh>;
}

sub cve_to_link
{
	my ($cve) = @_;

	return "https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-$cve";
}

sub git_to_link
{
	my ($hash) = @_;

	return "https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/commit/?id=$hash";
}

sub source_link
{
	my ($fname) = @_;

	return "https://github.com/linux-test-project/ltp/tree/master/$fname";
}

sub tags_have_tag
{
	my ($tags, $needle) = @_;

	for my $tag (@$tags) {
		return 1 if ($tag->[0] eq $needle);
	}

	return 0;
}

sub keys_by_tag
{
	my ($json, $tag) = @_;
	my @cve_keys;

	foreach my $key (keys %$json) {
		push(@cve_keys, $key) if tags_have_tag($json->{$key}->{'tags'}, $tag);
	}

	return \@cve_keys;
}

sub test_tags
{
	my ($test, $filter) = @_;
	my @tags;

	foreach my $tag (@{$test->{'tags'}}) {
		push(@tags, $tag->[1]) if ($tag->[0] eq $filter);
	}

	return \@tags;
}

sub by_cve
{
	my ($json) = @_;

	printf("  <table>\n");

	printf("   <tr>\n");
	printf("    <th>CVE</th>\n");
	printf("    <th>Test name</th>\n");
	printf("   </tr>\n");

	foreach my $key (sort(@{keys_by_tag($json, "CVE")})) {
		my $source_link = source_link($json->{$key}->{'fname'});
		for my $cve (@{test_tags($json->{$key}, "CVE")}) {
			my $link = cve_to_link("CVE-$cve");
			print("   <tr>\n");
			print("    <td><a href=\"$link\">CVE-$cve</a></td>\n");
			print("    <td><a href=\"$source_link\">$key</a></td>\n");
			print("   <tr>\n");
		}
	}

	printf("  </table>\n");
}

sub by_git
{
	my ($json) = @_;

	printf("  <table>\n");

	printf("   <tr>\n");
	printf("    <th>Linux commit</th>\n");
	printf("    <th>Test name</th>\n");
	printf("   </tr>\n");

	foreach my $key (sort(@{keys_by_tag($json, "linux-git")})) {
		my $source_link = source_link($json->{$key}->{'fname'});
		for my $hash (@{test_tags($json->{$key}, "linux-git")}) {
			my $link = git_to_link($hash);
			print("   <tr>\n");
			print("    <td><a href=\"$link\">$hash</a></td>\n");
			print("    <td><a href=\"$source_link\">$key</a></td>\n");
			print("   <tr>\n");
		}
	}

	printf("  </table>\n");
}

sub to_html
{
	my ($json) = @_;

	printf("<html>\n");
	printf(" <head>\n");
	printf("  <style>\n");
	printf("   td.yes {\n");
	printf("    background-color: #ffb;\n");
	printf("   }\n");
	printf("   td.cve {\n");
	printf("    background-color: #fbb;\n");
	printf("   }\n");
	printf("   tr:nth-child(odd) {\n");
	printf("    background-color: #eee;\n");
	printf("   }\n");
	printf("   tr:nth-child(even) {\n");
	printf("    background-color: #ddd;\n");
	printf("   }\n");
	printf("   th, td {\n");
	printf("    padding: .2em;\n");
	printf("   }\n");
	printf("   table, th, td {\n");
	printf("    border: 1px solid black;\n");
	printf("    border-collapse: collapse;\n");
	printf("   }\n");
	printf("  </style>\n");
	printf(" </head>\n");
	printf(" <body>\n");
	printf("  <table>\n");

	printf("   <tr>\n");
	printf("    <th>Test name</th>\n");
	printf("    <th>Needs root</th>\n");
	printf("    <th>Needs tmpdir</th>\n");
	printf("    <th>Needs device</th>\n");
	printf("    <th>All filesystems</th>\n");
	printf("    <th>CVE</td>\n");
	printf("    <th>Linux commit</th>\n");
	printf("   </tr>\n");

	foreach my $key (sort(keys %$json)) {
		my $source_link = source_link($json->{$key}->{'fname'});

		print("   <tr>\n");
		print("    <td><a href=\"$source_link\">$key</a></td>\n");

		if ($json->{$key}->{'needs_root'}) {
			print("    <td class=\"yes\">Yes</td>\n");
		} else {
			print("    <td></td>\n");
		}

		if ($json->{$key}->{'needs_tmpdir'}) {
			print("    <td class=\"yes\">Yes</td>\n");
		} else {
			print("    <td></td>\n");
		}

		if ($json->{$key}->{'needs_device'}) {
			print("    <td class=\"yes\">Yes</td>\n");
		} else {
			print("    <td></td>\n");
		}

		if ($json->{$key}->{'all_filesystems'}) {
			print("    <td class=\"yes\">Yes</td>\n");
		} else {
			print("    <td></td>\n");
		}

		my $tags = $json->{$key}->{'tags'};
		my @cve;
		my @git;
		if ($tags) {
			for my $tag (@$tags) {
				push(@cve, "CVE-$tag->[1]") if ($tag->[0] eq 'CVE');
				push(@git, "$tag->[1]") if ($tag->[0] eq 'linux-git');
			}
		}

		if (@cve) {
			print("    <td class=\"cve\">");
			for my $c (@cve) {
				my $link = cve_to_link($c);
				print("<a href=\"$link\">$c</a> ");
			}
			print("</td>\n");
		} else {
			print("    <td></td>\n");
		}

		if (@git) {
			print("    <td class=\"cve\">");
			for my $h (@git) {
				my $link = git_to_link($h);
				print("<a href=\"$link\">$h</a> ");
			}
			print("</td>\n");
		} else {
			print("    <td></td>\n");
		}

		print("   </tr>\n");
	}

	printf("  </table>\n");

	printf("  <br>\n");
	by_cve($json);

	printf("  <br>\n");
	by_git($json);

	printf(" </body>\n");
	printf("</html>\n");
}

sub query_flag
{
	my ($json, $flag) = @_;

	foreach my $key (sort(keys %$json)) {
		if ($json->{$key}->{$flag}) {
			if ($json->{$key}->{$flag} eq "1") {
				print("$key\n");
			} else {
				print("$key = $json->{$key}->{$flag}\n");
			}
		}
	}
}

my $json = decode_json(load_json($ARGV[0]));

if ($ARGV[1] eq "html") {
	to_html($json);
} else {
	query_flag($json, $ARGV[1]);
}
