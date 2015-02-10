
=head1 NAME

VRPipe::Pipelines::vrtrack_qc_graphs_and_auto_qc_hgi_2_with_gt - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHORS

Martin Pollard <mp15@sanger.ac.uk>
Joshua Randall <jcrandall@alum.mit.edu>

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

class VRPipe::Pipelines::vrtrack_qc_graphs_and_auto_qc_hgi_2_with_gt with VRPipe::PipelineRole {
    method name {
        return 'vrtrack_qc_graphs_and_auto_qc_hgi_2_with_gt';
    }
    
    method description {
        return 'Generate QC stats and graphs; update the VRTrack db; and perform AutoQC.';
    }
    
    method step_names {
        (
            'fasta_gc_stats',              #1
            'bin2hapmap_sites',            #2
            'bam_index',                   #3
            'mpileup_bcf_hapmap',          #4
            'glf_check_genotype',          #5
            'gtypex_genotype_analysis',    #6
            'bamcheck',                    #7
            'bamcheck_augment_summary',    #8
            'plot_bamcheck',               #9
            'vrtrack_update_mapstats',     #10
            'vrtrack_auto_qc_hgi_3',       #11
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0, to_step => 3, to_key => 'bam_files' },
            { from_step => 0, to_step => 7, to_key => 'bam_files' },
            { from_step => 0, to_step => 4, to_key => 'bam_files' },
            { from_step => 0, to_step => 10, to_key => 'bam_files' },
            { from_step => 1, to_step => 9, from_key => 'fasta_gc_stats_file', to_key => 'fasta_gc_stats_file' },
            { from_step => 0, to_step => 11, to_key => 'bam_files' },
            { from_step => 9, to_step => 10, from_key => 'bamcheck_plots', to_key => 'bamcheck_plots' },
            { from_step => 7, to_step => 8, from_key => 'bamcheck_files', to_key => 'bamcheck_files' },
            { from_step => 8, to_step => 9, from_key => 'bamcheck_files', to_key => 'bamcheck_files' },
            { from_step => 8, to_step => 11, from_key => 'bamcheck_files', to_key => 'bamcheck_files' },
            { from_step => 2, to_step => 4, from_key => 'hapmap_file', to_key => 'hapmap_file' },
            { from_step => 4, to_step => 5, from_key => 'bcf_files_with_metadata', to_key => 'bcf_files' },
            { from_step => 5, to_step => 6, from_key => 'gtypex_files_with_metadata', to_key => 'gtypex_files' },
        );
    }
}

1;
