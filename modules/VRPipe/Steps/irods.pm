
=head1 NAME

VRPipe::Steps::irods - a step

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012,2014 Genome Research Limited.

This file is part of VRPipe.

VRPipe is free software: you can redistribute it and/or modify it under the
terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

use VRPipe::Base;

class VRPipe::Steps::irods with VRPipe::StepRole {
    has 'irods_exes' => (
        is      => 'ro',
        isa     => 'HashRef',
        lazy    => 1,
        builder => '_build_irods_exes'
    );
    
    method _build_irods_exes {
        return {};
    }
    
    method handle_exes (HashRef $options) {
        my $irods_exes = $self->irods_exes;
        foreach my $exe (keys %{$irods_exes}) {
            my $method = $exe . '_exe';
            next unless defined $options->{$method};
            $irods_exes->{$exe} = $options->{$method};
        }
    }
    
    method options_definition {
        my %opts;
        
        my $irods_exes = $self->irods_exes;
        foreach my $exe (keys %{$irods_exes}) {
            $opts{ $exe . '_exe' } = VRPipe::StepOption->create(description => "path to your irods '$exe' executable", optional => 1, default_value => $irods_exes->{$exe} || $exe);
        }
        
        return \%opts;
    }
    
    method inputs_definition {
        return {};
    }
    
    method body_sub {
        return sub { return 1; };
    }
    
    method outputs_definition {
        return {};
    }
    
    method post_process_sub {
        return sub { return 1; };
    }
    
    method description {
        return "Generic step for steps using irods";
    }
    
    method max_simultaneous {
        return 40;
    }
    
    method get_file_by_basename (ClassName|Object $self: Str :$basename!, Str|File :$dest!, Str :$zone = 'seq', Str|File :$iget!, Str|File :$iquest!, Str|File :$ichksum!) {
        my $dest_file = VRPipe::File->get(path => $dest);
        $dest_file->disconnect;
        
        my @cmd_output = $self->open_irods_command(qq[$iquest -z $zone "SELECT COLL_NAME, DATA_NAME WHERE DATA_NAME = '$basename'"]);
        my ($path, $filename);
        foreach (@cmd_output) {
            # output looks like:
            # Zone is seq
            # COLL_NAME = /seq/5150
            # DATA_NAME = 5150_1#1.bam
            # -------------------------
            #
            # or an error is thrown, and only:
            # Zone is seq
            # is output
            
            if (/^COLL_NAME = (.+)$/) {
                $path = $1;
            }
            if (/^DATA_NAME = (.+)$/) {
                $filename = $1;
            }
        }
        
        if ($path && $filename) {
            unless ($filename eq $basename) {
                $self->throw("$filename should be the same as $basename");
            }
            my $irods_file = join('/', ($path, $filename));
            
            $self->get_file(source => $irods_file, dest => $dest_file->path, iget => $iget, ichksum => $ichksum);
        }
        else {
            $self->throw("A file with basename $basename could not be found in iRods zone $zone");
        }
    }
    
    method get_file_md5 (ClassName|Object $self: Str :$file!, Str|File :$ichksum!) {
        my ($chksum) = $self->open_irods_command("$ichksum $file");
        my ($md5)    = $chksum =~ m/\b([0-9a-f]{32})\b/i;          # 32 char MD5 hex string
        unless ($md5) {
            $self->throw("Could not determine md5 of $file in IRODS ('$ichksum $file' returned '$chksum'; aborted");
        }
        return $md5;
    }
    
    method get_file (ClassName|Object $self: Str :$source!, Str|File :$dest!, Str|File :$iget!, Str|File :$ichksum!, Bool :$add_metadata?, Str|File :$imeta?) {
        my $dest_file = VRPipe::File->get(path => $dest);
        $dest_file->disconnect;

        # check we've not downloaded it already
        my $irodschksum = $self->get_file_md5(file => $source, ichksum => $ichksum);
        my $expected_md5 = $dest_file->metadata->{expected_md5} || $irodschksum;
        if ( -e $dest ) {
            my $already_got_it = $dest_file->verify_md5($dest, $expected_md5);
            if ( $already_got_it ) {
                $dest_file->update_stats_from_disc;
                chmod 0664, $dest;
                return;
            }
        }

        # before we go fetch a file, check the md5 matches what we're expecting
        unless ($irodschksum eq $expected_md5) {
            $dest_file->unlink;
            $self->throw("expected md5 checksum in metadata ($expected_md5) did not match md5 of $source in IRODS ($irodschksum); aborted");
        }
        
        # check we've not downloaded it already
        if ( -e $dest ) {
            my $already_got_it = $dest_file->verify_md5($dest, $expected_md5);
            if ( $already_got_it ) {
                $dest_file->update_stats_from_disc;
                chmod 0664, $dest;
                return;
            }
        }
        # -K: checksum
        # -Q: use UDP rather than TCP
        # -f: force overwrite
        my $failed = $self->run_irods_command("$iget -K -f $source $dest");
        
        $dest_file->update_stats_from_disc;
        if ($failed) {
            $dest_file->unlink;
            $self->throw("iget failed for $source -> $dest");
        }
        
        # correct permissions, just in case
        chmod 0664, $dest;
        
        # double-check the md5 (iget -K doesn't always work?)
        my $ok = $dest_file->verify_md5(file($dest), $expected_md5);
        unless ($ok) {
            $dest_file->unlink;
            $self->throw("we got $source -> $dest, but the md5 checksum did not match; deleted");
        }
        
        if ($add_metadata) {
            my $meta = $self->get_file_metadata($source, $imeta ? (imeta => $imeta) : ());
            $dest_file->add_metadata($meta, replace_data => 1);
        }
    }
    
    method get_file_metadata (ClassName|Object $self: Str $path!, Str|File :$imeta = 'imeta') {
        my @cmd_output = $self->open_irods_command("$imeta ls -d $path");
        my $meta       = {};
        my $attribute;
        foreach (@cmd_output) {
            if (/^attribute:\s+(\S+)/) {
                $attribute = $1;
                undef $attribute if $attribute =~ /^dcterms:/;
            }
            elsif ($attribute && /^value:\s+(.+)$/) {
                if (exists $meta->{$attribute}) {
                    my $previous = $meta->{$attribute};
                    if (ref($previous)) {
                        $meta->{$attribute} = [@$previous, $1];
                    }
                    else {
                        $meta->{$attribute} = [$previous, $1];
                    }
                }
                else {
                    $meta->{$attribute} = $1;
                }
            }
        }
        
        return $meta;
    }
    
    method search_by_metadata (ClassName|Object $self: HashRef :$metadata!, Str|File :$imeta!, Str :$zone = 'seq') {
        my @meta;
        while (my ($key, $val) = each %$metadata) {
            push(@meta, "$key = '$val'");
        }
        my $meta = join(' and ', @meta);
        $meta || $self->throw("No metadata supplied");
        
        my @cmd_output = $self->open_irods_command("$imeta -z $zone qu -d $meta");
        my (@results, $dir);
        foreach (@cmd_output) {
            # output looks like:
            # collection: /seq/fluidigm/multiplexes
            # dataObj: cgp_fluidigm_snp_info_1000Genomes.tsv
            # ----
            # collection: /seq/fluidigm/multiplexes
            # dataObj: ddd_fluidigm_snp_info_1000Genomes.tsv
            #
            # or nothing is found and:
            # No rows found
            
            if (/^collection: (.+)$/) {
                $dir = $1;
            }
            elsif (/^dataObj: (.+)$/) {
                push(@results, "$dir/$1");
            }
        }
        
        return @results;
    }
    
    method open_irods_command (ClassName|Object $self: Str $cmd) {
        my (@output, $error);
        foreach my $i (1 .. 3) {
            my $ok = open(my $irods, "$cmd |");
            unless ($ok) {
                $error = "Failed to open pipe to [$cmd]";
                warn $error, "\n";
                sleep($i);
                next;
            }
            
            while (<$irods>) {
                chomp;
                push(@output, $_);
            }
            
            $ok = close($irods);
            last if $ok;
            
            $error = "Failed to close pipe to [$cmd]";
            warn $error, "\n";
            sleep($i);
            @output = ();
        }
        
        $self->throw($error) if $error;
        return @output;
    }
    
    method run_irods_command (ClassName|Object $self: Str $cmd) {
        my $failed;
        foreach my $i (1 .. 3) {
            $failed = system($cmd);
            if ($failed) {
                sleep($i);
                next;
            }
            last;
        }
        return $failed;
    }
}

1;
