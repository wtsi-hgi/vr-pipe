use VRPipe::Base;

class VRPipe::Steps::manual_lane_qc_to_meta extends VRPipe::Steps::vrtrack_update {
    
    method inputs_definition {
        return { bam_files => VRPipe::StepIODefinition->get(type => 'bam', 
            description => 'bam files', 
            max_files => -1,
            metadata => {lane => 'lane name (a unique identifer for this sequencing run, aka read group)'})};
    }
    method body_sub {
        return sub {
            my $self = shift;
            my $opts = $self->options;
            my $db = $opts->{vrtrack_db};
            my $req = $self->new_requirements(memory => 500, time => 1);
                        
            foreach my $bam_file (@{$self->inputs->{bam_files}}) {
                my $bam_path = $bam_file->path;
                my $lane = $bam_file->metadata->{lane};
                my $cmd = "use VRPipe::Steps::manual_lane_qc_to_meta; VRPipe::Steps::manual_lane_qc_to_meta->write_back(db => q[$db], bam => q[$bam_path], lane => q[$lane]);";
                $self->dispatch_vrpipecode($cmd, $req);
            }
        }
    }
    method description {
        return "Writes back manual qc data from a vrtrack database to bam file metadata.";
    }


    method write_back(ClassName|Object $self: Str :$db!, Str|File :$bam!, Str :$lane!) {
        my $bam_file = VRPipe::File->get(path => $bam);
        $bam_file->disconnect;
        
        my $vrtrack = $self->get_vrtrack(db => $db);
        my $vrlane = VRTrack::Lane->new_by_hierarchy_name($vrtrack, $lane) || $self->throw("No lane named '$lane' in database '$db'");

        $bam_file->add_metadata({lane_qc_status => $vrlane->qc_status}, replace_data => 1);
    }
}

1;