
=head1 NAME

VRPipe::Steps::illumina2bam_generic - a step

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Shane McCarthy <sm15@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011-2012 Genome Research Limited.

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

class VRPipe::Steps::illumina2bam_generic extends VRPipe::Steps::java {
    has 'illumina2bam_path' => (
        is     => 'rw',
        isa    => Dir,
        coerce => 1
    );
    
    has '+memory_multiplier' => (default => 0.9);
    
    around _build_standard_options {
        return [@{ $self->$orig }, 'illumina2bam_path'];
    }
    
    our %ILLUMINA2BAM_VERSIONS;
    has 'illumina2bam_version' => (
        is      => 'ro',
        isa     => 'Str',
        lazy    => 1,
        builder => 'determine_illumina2bam_version'
    );
    
    method determine_illumina2bam_version (ClassName|Object $self:) {
        my $illumina2bam_path = $self->illumina2bam_path->stringify;
        unless (defined $ILLUMINA2BAM_VERSIONS{$illumina2bam_path}) {
            my $version = 0;
            opendir(my $dh, $illumina2bam_path) || $self->throw("Could not open illumina2bam directory $illumina2bam_path");
            foreach (readdir $dh) {
                if (/^Illumina2bam-([\d\.]+)\.jar/) {
                    $version = $1;
                    last;
                }
            }
            closedir($dh);
            $ILLUMINA2BAM_VERSIONS{$illumina2bam_path} = $version;
        }
        return $ILLUMINA2BAM_VERSIONS{$illumina2bam_path};
    }
    
    method jar (ClassName|Object $self: Str $basename!) {
        return file($self->illumina2bam_path, $basename);
    }
    
    around options_definition {
        return { %{ $self->$orig }, illumina2bam_path => VRPipe::StepOption->create(description => 'path to Illumina2BAM jar files'), };
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
        return "Generic step for using Illumina2BAM";
    }
    
    method max_simultaneous {
        return 0;            # meaning unlimited
    }
}

1;
