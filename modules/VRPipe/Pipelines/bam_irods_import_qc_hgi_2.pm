
=head1 NAME

VRPipe::Pipelines::bam_irods_import_qc_hgi - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Martin Pollard <mp15@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012-2013 Genome Research Limited.

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

class VRPipe::Pipelines::bam_irods_import_qc_hgi with VRPipe::PipelineRole {
    method name {
        return 'bam_irods_import_qc_hgi';
    }
    
    method description {
        return 'Copy bam files stored in iRODs to local disc; generate QC stats and graphs; update the VRTrack db; and perform AutoQC.';
    }
    
    method step_names {
        (
            'irods_get_files_by_basename', #1
            'fasta_gc_stats',              #2
            'bamcheck',                    #3
            'plot_bamcheck',               #4
            'vrtrack_update_mapstats',     #5
            'bamcheck_detect_indel',       #6
            'bamcheck_qual_dropoff',       #7
            'vrtrack_auto_qc_hgi_2',       #8
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0, to_step => 1, to_key   => 'basenames' },
            { from_step => 1, to_step => 3, from_key => 'local_files', to_key => 'bam_files' },
            { from_step => 2, to_step => 4, from_key => 'fasta_gc_stats_file', to_key => 'fasta_gc_stats_file' },
            { from_step => 3, to_step => 4, from_key => 'bamcheck_files', to_key => 'bamcheck_files' },
            { from_step => 1, to_step => 5, from_key => 'local_files', to_key => 'bam_files' },
            { from_step => 4, to_step => 5, from_key => 'bamcheck_plots', to_key => 'bamcheck_plots' },
            { from_step => 3, to_step => 6, from_key => 'bamcheck_files', to_key => 'bamcheck_files' },
            { from_step => 6, to_step => 7, from_key => 'bamcheck_files', to_key => 'bamcheck_files' },
            { from_step => 7, to_step => 8, from_key => 'bamcheck_files', to_key => 'bamcheck_files' },
            { from_step => 1, to_step => 8, from_key => 'local_files', to_key   => 'bam_files' },
        );
    }
}

1;
