
=head1 NAME

VRPipe::Pipelines::sequencing_qc_from_irods_and_update_vrtrack - a pipeline

=head1 DESCRIPTION

This pipeline is Sanger-specific.

It handles our QC needs without having to download anything. Use an irods
datasource with no local_root_dir option set.

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2015 Genome Research Limited.

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

class VRPipe::Pipelines::sequencing_qc_from_irods_and_update_vrtrack with VRPipe::PipelineRole {
    method name {
        return 'sequencing_qc_from_irods_and_update_vrtrack';
    }
    
    method description {
        return 'Parse cram qc files stored in irods by NPG. Update VRTrack MySQL database with the qc information.';
    }
    
    method step_names {
        (
            'samtools_fasta_gc_stats',       # 1
            'npg_cram_stats_parser',         # 2
            'plot_bamstats',                 # 3
            'vrtrack_populate_from_graph_db' # 4
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0, to_step => 2, to_key   => 'cram_files' },
            { from_step => 1, to_step => 3, from_key => 'fasta_gc_stats_file', to_key => 'fasta_gc_stats_file' },
            { from_step => 2, to_step => 3, from_key => 'stats_files', to_key => 'stats_files' },
            { from_step => 0, to_step => 4, to_key   => 'files' }
        );
    }
}

1;
