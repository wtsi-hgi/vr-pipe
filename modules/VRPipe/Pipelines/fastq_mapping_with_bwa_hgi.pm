
=head1 NAME

VRPipe::Pipelines::fastq_mapping_with_bwa - a pipeline

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHOR

Sendu Bala <sb10@sanger.ac.uk>.

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

class VRPipe::Pipelines::fastq_mapping_with_bwa_hgi with VRPipe::PipelineRole {
    method name {
        return 'fastq_mapping_with_bwa_hgi';
    }
    
    method description {
        return 'Map reads in fastq files to a reference genome with bwa';
    }
    
    method step_names {
        (
            'bwa_index',
            'bwa_aln_fastq',
            'bwa_sam',
            'sam_to_fixed_bam',
        );
    }
    
    method adaptor_definitions {
        (
            { from_step => 0, to_step => 2, to_key   => 'fastq_files' },
            { from_step => 0, to_step => 3, to_key   => 'fastq_files' },
            { from_step => 2, to_step => 3, from_key => 'bwa_sai_files', to_key => 'sai_files' },
            { from_step => 3, to_step => 4, from_key => 'bwa_sam_files', to_key => 'sam_files' },
        );
    }
    
    method behaviour_definitions {
        (
            { after_step => 3, behaviour => 'delete_outputs', act_on_steps => [2], regulated_by => 'cleanup', default_regulation => 1 },
            { after_step => 4, behaviour => 'delete_outputs', act_on_steps => [3], regulated_by => 'cleanup', default_regulation => 1 },
        );
    }
}

1;
