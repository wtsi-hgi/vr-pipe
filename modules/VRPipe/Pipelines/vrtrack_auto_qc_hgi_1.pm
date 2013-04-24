
=head1 NAME

VRPipe::Pipelines::vrtrack_auto_qc_hgi_a - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.
Martin Pollard <mp15@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012 Genome Research Limited.

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

class VRPipe::Pipelines::vrtrack_auto_qc_hgi_1 with VRPipe::PipelineRole {
    method name {
        return 'vrtrack_auto_qc_hgi_1';
    }
    
    method description {
        return 'Adds additional stats to the bamcheck file for a lane.  Next considering the stats in the bamcheck file for a lane, and the metadata stored on the bam file and in the VRTrack database for the corresponding lane, automatically decide if the lane passes the quality check.';
    }
    
    method step_names {
        (
            'bamcheck_detect_indel', #1
            'bamcheck_qual_dropoff', #2
            'vrtrack_auto_qc_hgi', #3
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0, to_step => 1, to_key => 'bamcheck_files' },
            { from_step => 1, to_step => 2, to_key => 'bamcheck_files', from_key => 'bamcheck_files' },
            { from_step => 0, to_step => 3, to_key => 'bam_files' },
            { from_step => 2, to_step => 3, to_key => 'bamcheck_files', from_key => 'bamcheck_files' }
        );
    }

    method behaviour_definitions {
        (
            { after_step => 2, behaviour => 'delete_outputs',  act_on_steps => [1], regulated_by => 'cleanup', default_regulation => 1 },
        );
    }

}

1;
