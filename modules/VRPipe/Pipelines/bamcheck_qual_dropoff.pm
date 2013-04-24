
=head1 NAME

VRPipe::Pipelines::bamcheck_qual_dropoff - a pipeline

=head1 DESCRIPTION

Considering the stats in the bamcheck file for a lanes indels, add summary stats to indicate if any position deviates excessively from the baseline.

=head1 AUTHOR

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

class VRPipe::Pipelines::bamcheck_qual_dropoff with VRPipe::PipelineRole {
    method name {
        return 'bamcheck_qual_dropoff';
    }
    
    method description {
        return 'Considering the stats in the bamcheck file for a lane\'s quality scores, mark those that dropoff too far.';
    }
    
    method step_names {
        ('bamcheck_qual_dropoff');
    }
    
    method adaptor_definitions {
        ({ from_step => 0, to_step => 1, to_key => 'bamcheck_files' });
    }
}

1;
