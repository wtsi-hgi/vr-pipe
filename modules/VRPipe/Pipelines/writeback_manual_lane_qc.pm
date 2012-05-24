use VRPipe::Base;

class VRPipe::Pipelines::writeback_manual_lane_qc with VRPipe::PipelineRole {
    method name {
        return 'writeback_manual_lane_qc';
    }
    method _num_steps {
        return 1;
    }
    method description {
        return 'Writes back qc data from vrtrack database to bam file metadata for filtering.';
    }
    method steps {
        $self->throw("steps cannot be called on this non-persistent object");
    }
    
    method _step_list {
        return ([ VRPipe::Step->get(name => 'manual_lane_qc_to_meta') ],
        [ VRPipe::StepAdaptorDefiner->new(from_step => 0, to_step => 1, to_key => 'bam_files'),
        [ ]);
    }
}

1;
