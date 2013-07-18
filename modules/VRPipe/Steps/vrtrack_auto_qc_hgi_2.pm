
=head1 NAME

VRPipe::Steps::vrtrack_auto_qc_hgi_2 - a step

=head1 DESCRIPTION

*** more documentation to come

=head1 AUTHORS

Sendu Bala <sb10@sanger.ac.uk>.
Joshua C. Randall <jcrandall@alum.mit.edu>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2012, 2013 Genome Research Limited.

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

use v5.10;
use Storable qw(dclone);
use VRPipe::Base;

# Max lengths for autoqc string in the vrtrack database
my $REASON_MAX = 200;
my $TEST_MAX = 50;

class VRPipe::Steps::vrtrack_auto_qc_hgi_2 extends VRPipe::Steps::vrtrack_update {
    use VRPipe::Parser;

    has 'qc_results' => ( 
	traits => ['Array'], 
	is => 'rw', 
	isa => 'ArrayRef[HashRef]', 
	default => sub { [] },
	handles => {
	    qc_results_add => 'push',
	    qc_results_elements => 'elements',
	}
	);
    
    around options_definition {
        return {
            %{ $self->$orig },
            auto_qc_settings_file => VRPipe::StepOption->create(
                description   => 'Path to file containing auto qc settings.',
                optional      => 0,
            ),
        };
    }
    
    method inputs_definition {
        return {
            bam_files => VRPipe::StepIODefinition->create(
                type        => 'bam',
                description => 'bam files',
                max_files   => -1,
                metadata    => { lane => 'lane name (a unique identifer for this sequencing run, aka read group)' }
            ),
            bamcheck_files => VRPipe::StepIODefinition->create(
                type        => 'txt',
                description => 'bamcheck files',
                max_files   => -1,
                metadata    => { lane => 'lane name (a unique identifer for this sequencing run, aka read group)' }
            )
        };
    }
    
    method body_sub {
        return sub {
            my $self = shift;
            my $opts = $self->options;
            my $db   = $opts->{vrtrack_db};
            my $req  = $self->new_requirements(memory => 500, time => 1);
            
            # group the bam file with its bamcheck file according to lane; the
            # bamcheck file might have been made for a different bam (eg.
            # imported bam, whilst the input bam is an improved bam), so we
            # can't use source_bam metadata here
            my %by_lane;
            foreach my $file (@{ $self->inputs->{bam_files} }, @{ $self->inputs->{bamcheck_files} }) {
                push(@{ $by_lane{ $file->metadata->{lane} } }, $file->path);
            }
            
            while (my ($lane, $files) = each %by_lane) {
                $self->throw("There was not exactly 1 bam file and 1 bamcheck file per lane for lane $lane (@$files)") unless @$files == 2;
                
                my $cmd = "use VRPipe::Steps::vrtrack_auto_qc_hgi_2; VRPipe::Steps::vrtrack_auto_qc_hgi_2->auto_qc(db => q[$opts->{vrtrack_db}], bam => q[$files->[0]], bamcheck => q[$files->[1]], lane => q[$lane], auto_qc_settings_file => q[$opts->{auto_qc_settings_file}] );";
                $self->dispatch_vrpipecode($cmd, $req);
            }
        };
    }
    
    method outputs_definition {
        return {};
    }
    
    method description {
        return "Considering the stats in the bamcheck file for a lane, and the metadata stored on the bam file and in the VRTrack database for the corresponding lane, automatically decide if the lane passes the quality check.";
    }

    method load_config (ClassName|Object $self: Str $auto_qc_settings_file) {
        #stolen from runner.pm
        my $opts = ();
	my %x = do "$auto_qc_settings_file";
        while (my ($key,$value) = each %x)
        {
            if ( !ref($value) )
            {
                $$opts{$key} = $value;
                next;
            }
            $$opts{$key} = Storable::dclone($value);
        }
        return $opts;
    }

    method auto_qc_bad_conf (ClassName|Object $self: Str $conf_err) {
	$self->throw("auto_qc had malformed configuration: $conf_err");
    }

    method test_minmax (
	ClassName|Object $self: 
	Str :$test, 
	Str :$test_conf, 
	HashRef :$opts, 
	ArrayRef :$minmax,
	Maybe[Num] :$value, 
	Str :$below_min_reason_fmt = "Value below %.1f (%.2f)",
	Str :$above_max_reason_fmt = "Value above %.1f (%.2f)",
	Str :$between_min_max_reason_fmt = "Value between %.1f and %.1f (%.2f)",
	Str :$at_least_min_reason_fmt = "Value at least %.1f (%.2f)",
	Str :$up_to_max_reason_fmt = "Value not more than %.1f (%.2f)"
	) {
	
	if (exists $opts->{$test_conf}) {
	    my $status = 1;
	    my $reason = "Pass by default";
	    my $test_min = 0;
	    my $test_max = 0;
	    my ($min_threshold, $max_threshold);
	    
	    if (defined($value)) {
		my $config = $opts->{$test_conf};
		
		foreach my $mm (@{$minmax}) {
		    if (exists $config->{$mm}) {
			my ($failed_threshold, $warning_threshold) = (undef, undef);
			$failed_threshold = $config->{$mm}->{failed} if exists $config->{$mm}->{failed};
			$warning_threshold = $config->{$mm}->{warning} if exists $config->{$mm}->{warning};

			if (!defined($failed_threshold) && !defined($warning_threshold)) {
			    $self->auto_qc_bad_conf($test_conf.'->{'.$mm.'} missing at least one of failed or warning thresholds');
			}
			
			if ($mm eq 'min') {
			    $test_min = 1;
			    if (defined($failed_threshold) && $value < $failed_threshold) {
				# fail
				$status = 0;
				$reason = sprintf $below_min_reason_fmt, $failed_threshold, $value;
			    } elsif (defined($warning_threshold) && $value < $warning_threshold) {
				# warning
				$status = 2;
				$reason = sprintf $below_min_reason_fmt, $warning_threshold, $value;
			    } else {
				$min_threshold = $warning_threshold;
			    }
			} elsif ($mm eq 'max') {
			    $test_max = 1;
			    if (defined($failed_threshold) && $value > $failed_threshold) {
				# fail
				$status = 0;
				$reason = sprintf $above_max_reason_fmt, $failed_threshold, $value;
			    } elsif (defined($warning_threshold) && $value > $warning_threshold) {
				# warning
				$status = 2;
				$reason = sprintf $above_max_reason_fmt, $warning_threshold, $value;
			    } else {
				$max_threshold = $warning_threshold;
			    }
			} else {
			    $self->auto_qc_bad_conf("invalid minmax value $mm passed for test $test ($test_conf)");
			}



		    } else {
			$self->auto_qc_bad_conf("$test_conf missing required key $mm");
		    }
		}

		if ($status == 1) {
		    if ($test_min && $test_max) {
			$self->auto_qc_bad_conf("autoqc missing between_min_max_reason_fmt for $test") unless $between_min_max_reason_fmt;
			$reason = sprintf $between_min_max_reason_fmt, $min_threshold, $max_threshold, $value;
		    } elsif ($test_min) {
			$reason = sprintf $at_least_min_reason_fmt, $min_threshold, $value;
			
		    } elsif ($test_max) {
			$reason = sprintf $up_to_max_reason_fmt, $max_threshold, $value;
		    }
		}
	    } else { # if (defined($value))
		# value undefined
		$status = 2;
		$reason = "$test value undefined";
	    }
	    
	    $self->qc_results_add({ test => $test, status => $status, reason => $reason });
	} # if (exists $opts->{$test_conf})
    }
    
    method auto_qc (ClassName|Object $self: Str :$db!, Str|File :$bam!, Str|File :$bamcheck!, Str :$lane!, Str|File :$auto_qc_settings_file ) {
        my $bam_file = VRPipe::File->get(path => $bam);
        my $meta     = $bam_file->metadata;
        my $bc       = VRPipe::Parser->create('bamcheck', { file => $bamcheck });
        $bam_file->disconnect;
        
        # get the lane object from VRTrack
        my $vrtrack = $self->get_vrtrack(db => $db);
        my $vrlane = VRTrack::Lane->new_by_hierarchy_name($vrtrack, $lane) || $self->throw("No lane named '$lane' in database '$db'");
        my $mapstats = $vrlane->latest_mapping || $self->throw("There were no mapstats for lane $lane");

	# load qc settings from file -- parameter keys will be deleted from %$opts as each test is run so that we can check for conf syntax errors at the end
        my $opts = $self->load_config($auto_qc_settings_file);        

        my ($test, $status, $reason);
        
	
        my $bam_has_seq = 1;
        # check to see if the bam file contains any reads as this crashes other
        # parts of auto_qc (test for $bam_has_seq to protect against this)
	{
	    $test = 'Empty bam file check';
	    if ($bc->sequences == 0 && $bc->total_length == 0) { # we use the bamcheck result, not $vrlane results, in case we're looking at unimproved exome bam which will have 0 reads and bases in VRTrack
		$bam_has_seq = 0;
		$status = 0;
		$reason = "The bam file provided for this lane contains no sequences.";
	    } else {
		$status = 1;
		$reason = "The bam file provided for this lane contains sequence.";
	    }
	    $self->qc_results_add({ test => $test, status => $status, reason => $reason });
        }
	
        
	# we'll always fail if the npg status is failed
	{
	    my $test = 'NPG QC status check';
	    my $npg_status = $vrlane->npg_qc_status;
	    if ($npg_status) {
		if ($npg_status eq 'fail') {
		    $status = 0;
		    $reason = 'The lane failed the NPG QC check, so we auto-fail as well since this data will not be auto-submitted to EGA/ENA.';
		} elsif ($npg_status eq 'pass') {
		    $status = 1;
		    $reason = 'The lane passed the NPG QC check.';
		} else {
		    $status = 2;
		    $reason = "The lane had unknown NPG QC status ($npg_status)";
		}
	    }
	    $self->qc_results_add({ test => $test, status => $status, reason => $reason });
	}
        
	
        # genotype check results
	my @gtype_results;
	{
	    if (exists $opts->{auto_qc_gtype_regex}) {
		$test = 'Genotype check';
		my $auto_qc_gtype_regex = $opts->{auto_qc_gtype_regex};
		# use gtype info from bam_genotype_checking pipeline, if present
		my $gstatus;
		my $gtype_analysis = $meta->{gtype_analysis};
		if ($gtype_analysis) {
		    ($gstatus) = $gtype_analysis =~ /status=(\S+) expected=(\S+) found=(\S+) ratio=(\S+)/;
		    @gtype_results = ($gstatus, $2, $3, $4);
		}
		else {
		    # look to see if there's a gtype status in VRTrack database for
		    # this lane
		    my $gt_found = $mapstats->genotype_found;
		    if ($gt_found) {
			my %lane_info = $vrtrack->lane_info($lane);
			if ($gt_found eq $mapstats->genotype_expected || $gt_found eq $lane_info{sample} || $gt_found eq $lane_info{individual} || $gt_found eq $lane_info{individual_acc}) {
			    $gstatus = 'confirmed';
			}
			else {
			    $gstatus = 'wrong';
			}
		    }
		}
		
		if ($gstatus) {
		    $status = 1;
		    $reason = qq[The status is '$gstatus'.];
		    if ($gstatus !~ /$auto_qc_gtype_regex/) {
			$status = 0;
			$reason = "The status ($gstatus) does not match the regex ($auto_qc_gtype_regex).";
		    }
		    $self->qc_results_add({ test => $test, status => $status, reason => $reason });
		}
		delete $opts->{auto_qc_gtype_regex};
	    }
	}
	
        
	{ # mapped bases
	    my $bases_mapped_pct = 0;
	    if ($bam_has_seq) {
		my $clip_bases     = $mapstats->clip_bases;
		my $bases_mapped_c = $mapstats->bases_mapped;
		$bases_mapped_pct  = 100 * $bases_mapped_c / $clip_bases;
	    }	    
	    $self->test_minmax(
		test      => 'Bases mapped',
		test_conf => 'auto_qc_mapped_base_percentage', 
		opts      => $opts, 
		minmax    => ['min'],
		value     => $bases_mapped_pct,
		below_min_reason_fmt => "Less than %.1f%% bases mapped after clipping (%.2f%%).",
		at_least_min_reason_fmt => "At least %.1f%% bases mapped after clipping (%.2f%%).",
		);
	    delete $opts->{auto_qc_mapped_base_percentage};
	}
	
	
	{ # duplicate reads
	    my $dup_reads_pct = 0;
	    if ($bam_has_seq) {
		my $mapped_reads = $mapstats->reads_mapped;
		my $dup_reads    = $mapped_reads - $mapstats->rmdup_reads_mapped;
		$dup_reads_pct   = 100 * $dup_reads / $mapped_reads;
	    }
	    $self->test_minmax(
		test      => 'Duplicate reads',
		test_conf => 'auto_qc_duplicate_read_percentage',
		opts      => $opts,
		minmax    => ['max'],
		value     => $dup_reads_pct,
		above_max_reason_fmt => "More than %.1f%% reads were duplicates (%.2f%%).",
		up_to_max_reason_fmt => "%.1f%% or less reads were duplicates (%.2f%%).",
		);
	    delete $opts->{auto_qc_duplicate_read_percentage};
	}

	
        { # properly paired mapped reads
	    my $paired_reads_pct = 0;
	    if ($bam_has_seq) {
		my $mapped_reads     = $mapstats->reads_mapped;
		my $paired_reads     = $mapstats->rmdup_reads_mapped;
		$paired_reads_pct = 100 * $paired_reads / $mapped_reads;
	    }
	    $self->test_minmax(
		test      => 'Reads mapped in a proper pair',
		test_conf => 'auto_qc_mapped_reads_properly_paired_percentage',
		opts      => $opts,
		minmax    => ['min'],
		value     => $paired_reads_pct,
		below_min_reason_fmt => "Less than %.1f%% reads that were mapped are in a proper pair (%.2f%%).",
		at_least_min_reason_fmt => "At least %.1f%% reads that were mapped are in a proper pair (%.2f%%).",
		);
	    delete $opts->{auto_qc_mapped_reads_properly_paired_percentage};
	}
	
        
	{ # error rate
	    my $error_rate = $mapstats->error_rate;
	    $self->test_minmax(
		test      => 'Error rate',
		test_conf => 'auto_qc_error_rate',
		opts      => $opts,
		minmax    => ['max'],
		value     => $error_rate,
		above_max_reason_fmt => "The error rate is higher than %.2f (%.2f).",
		up_to_max_reason_fmt => "The error rate is lower than %.2f (%.2f).",
		);
	    delete $opts->{auto_qc_error_rate};
	}
	
        
	{ # number of insertions vs deletions
            my ($inum, $dnum);
            my $counts = $bc->indel_dist();
            for my $row (@$counts) {
                $inum += $$row[1];
                $dnum += $$row[2];
            }
	    my $ins_to_del_ratio;
	    if ($dnum) {
		$ins_to_del_ratio = $inum / $dnum;
	    } else {
		# set to MAX_INT
		$ins_to_del_ratio = 0+sprintf('%u', -1);
	    }
	    $self->test_minmax(
		test      => 'InDel ratio',
		test_conf => 'auto_qc_ins_to_del_ratio',
		opts      => $opts,
		minmax    => ['min', 'max'],
		value     => $ins_to_del_ratio,
		below_min_reason_fmt => "The Ins/Del ratio is less than %.1f (%.2f).",
		above_max_reason_fmt => "The Ins/Del ratio is greater than %.1f (%.2f).",
		between_min_max_reason_fmt => "The Ins/Del ratio is between %.1f and %.1f (%.2f).",
		);
	    delete $opts->{auto_qc_ins_to_del_ratio};
	}
	
        
        # overlapping base duplicate percent
        # calculate the proportion of mapped bases duplicated e.g. if a fragment
        # is 160bp - then 40bp out of 200bp sequenced (or 20% of bases sequenced
        # in the fragment are duplicate sequence)
        #
        #------------->
        #          <------------
        #        160bp
        #|---------------------|
        #          |--|
        #          40bp
	$test = 'Overlap duplicate base percent';
	if ($bam_has_seq && $vrlane->is_paired()) {
	    my $lengths = $bc->read_lengths();
	    if (@$lengths == 1) {
		my $seqlen = $lengths->[0]->[0];
		my $is_lines = $bc->insert_size() || [];
		
		if (@$is_lines) {
		    my ($short_paired_reads, $normal_paired_reads, $total_paired_reads, $dup_mapped_bases, $tot_mapped_bases) = 0;
		    foreach my $is_line (@$is_lines) {
			my ($is, $pairs_total, $inward, $outward, $other) = @$is_line;
			next unless $pairs_total;
			
			if (($seqlen * 2) > $is) {
			    $short_paired_reads += $pairs_total;
			    $dup_mapped_bases += $pairs_total * (($seqlen * 2) - $is);
			}
			else {
			    $normal_paired_reads += $pairs_total;
			}
			$total_paired_reads += $pairs_total;
			$tot_mapped_bases += $pairs_total * ($seqlen * 2);
		    }
		    
		    my $overlap_dup_base_pct = sprintf("%0.1f", ($dup_mapped_bases * 100) / $tot_mapped_bases);
		    $self->test_minmax(
			test      => $test,
			test_conf => 'auto_qc_overlapping_base_duplicate_percent',
			opts      => $opts,
			minmax    => ['max'],
			value     => $overlap_dup_base_pct,
			above_max_reason_fmt => "The percent of bases duplicated due to reads of a pair overlapping is greater than %.2f%% (%.2f%%).",
			up_to_max_reason_fmt => "The percent of bases duplicated due to reads of a pair overlapping is less than or equal to %.2f%% (%.2f%%).",
			);
		} else {
		    # no insert-size lines in bamcheck?
		    $reason = "bamcheck file did not contain insert-size lines";
		    $status = 2;
		    $self->qc_results_add({ test => $test, status => $status, reason => $reason });
		}
	    } else {
		# multiple read lengths, cannot run this test
		$reason = "Multiple read lengths in study, cannot run test of bases duplicated due to read of a pair overlapping";
		$status = 2;
                $self->qc_results_add({ test => $test, status => $status, reason => $reason });
	    }
	}
	delete $opts->{auto_qc_overlapping_base_duplicate_percent} if exists $opts->{auto_qc_overlapping_base_duplicate_percent};
	

        # insert size 
        my $lib_to_update;
        my $lib_status;
        if ($vrlane->is_paired() && exists $opts->{auto_qc_insert_peak} && exists $opts->{auto_qc_insert_peak}->{window} && exists $opts->{auto_qc_insert_peak}->{reads} && $bam_has_seq) {
            my $auto_qc_insert_peak_window = $opts->{auto_qc_insert_peak}->{window};
            my $auto_qc_insert_peak_reads = $opts->{auto_qc_insert_peak}->{reads};
            $test = 'Insert size';
            
            if ($mapstats->reads_paired == 0) {
                $self->qc_results_add({ test => $test, status => 0, reason => 'Zero paired reads, yet flagged as paired' });
            }
            elsif ($mapstats->mean_insert == 0 || !$bc->insert_size()) {
                $self->qc_results_add({ test => $test, status => 0, reason => 'The insert size not available, yet flagged as paired' });
            }
            else {
                # only libraries can be failed based on wrong insert size. The
                # lanes are always passed as long as the insert size is
                # consistent with other lanes from the same library.
                my $peak_win    = $auto_qc_insert_peak_window;
                my $within_peak = $auto_qc_insert_peak_reads;
                
                $status = 1;
                my ($amount, $range) = $self->insert_size_allowed_amount_and_range($bc->insert_size(), $peak_win, $within_peak);
                
                $reason = sprintf "There are %.1f%% or more inserts within %.1f%% of max peak (%.2f%%).", $within_peak, $peak_win, $amount;
                if ($amount < $within_peak) {
                    $status = 0;
                    $reason = sprintf "Fail library, less than %.1f%% of the inserts are within %.1f%% of max peak (%.2f%%).", $within_peak, $peak_win, $amount;
                }
                $self->qc_results_add({ test => $test, status => 1, reason => $reason });
                
                $reason = sprintf "%.1f%% of inserts are contained within %.1f%% of the max peak (%.2f%%).", $within_peak, $peak_win, $range;
                if ($range > $peak_win) {
                    $status = 0;
                    $reason = sprintf "Fail library, %.1f%% of inserts are not within %.1f%% of the max peak (%.2f%%).", $within_peak, $peak_win, $range;
                }
                $self->qc_results_add({ test => 'Insert size (rev)', status => 1, reason => $reason });
                
                $lib_to_update = VRTrack::Library->new_by_field_value($vrtrack, 'library_id', $vrlane->library_id()) or $self->throw("No vrtrack library for lane $lane?");
                $lib_status = $status ? 'passed' : 'failed';
            }
        }
        delete $opts->{auto_qc_insert_peak} if exists $opts->{auto_qc_insert_peak};
	
	
        #######
        # HGI #
        #######

        # indel vs read cycle peak detection
	$self->test_minmax(
	    test      => 'Fwd insertions vs read cycle pct above baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->fwd_percent_insertions_above_baseline(),
	    above_max_reason_fmt => "Forward insertions deviate more than %.2f%% above the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Forward insertions are within %.2f%% of the baseline (%.2f%%).",
	    );

	$self->test_minmax(
	    test      => 'Fwd insertions vs read cycle pct below baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->fwd_percent_insertions_below_baseline(),
	    above_max_reason_fmt => "Forward insertions deviate more than %.2f%% below the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Forward insertions are within %.2f%% of the baseline (%.2f%%).",
	    );

	$self->test_minmax(
	    test      => 'Fwd deletions vs read cycle pct above baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->fwd_percent_deletions_above_baseline(),
	    above_max_reason_fmt => "Forward deletions deviate more than %.2f%% above the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Forward deletions are within %.2f%% of the baseline (%.2f%%).",
	    );

	$self->test_minmax(
	    test      => 'Fwd deletions vs read cycle pct below baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->fwd_percent_deletions_below_baseline(),
	    above_max_reason_fmt => "Forward deletions deviate more than %.2f%% below the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Forward deletions are within %.2f%% of the baseline (%.2f%%).",
	    );

	$self->test_minmax(
	    test      => 'Rev insertions vs read cycle pct above baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->rev_percent_insertions_above_baseline(),
	    above_max_reason_fmt => "Reverse insertions deviate more than %.2f%% above the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Reverse insertions are within %.2f%% of the baseline (%.2f%%).",
	    );

	$self->test_minmax(
	    test      => 'Rev insertions vs read cycle pct below baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->rev_percent_insertions_below_baseline(),
	    above_max_reason_fmt => "Reverse insertions deviate more than %.2f%% below the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Reverse insertions are within %.2f%% of the baseline (%.2f%%).",
	    );

	$self->test_minmax(
	    test      => 'Rev deletions vs read cycle pct above baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->rev_percent_deletions_above_baseline(),
	    above_max_reason_fmt => "Reverse deletions deviate more than %.2f%% above the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Reverse deletions are within %.2f%% of the baseline (%.2f%%).",
	    );

	$self->test_minmax(
	    test      => 'Rev deletions vs read cycle pct below baseline',
	    test_conf => 'auto_qc_indel_percentage_deviation',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->rev_percent_deletions_below_baseline(),
	    above_max_reason_fmt => "Reverse deletions deviate more than %.2f%% below the baseline model (%.2f%%).",
	    up_to_max_reason_fmt => "Reverse deletions are within %.2f%% of the baseline (%.2f%%).",
	    );

	delete $opts->{auto_qc_indel_percentage_deviation};


        # quality vs read cycle contiguous quality dropoff
	$self->test_minmax(
	    test      => 'Quality dropoff',
	    test_conf => 'auto_qc_qual_contig_cycle_dropoff',
	    opts      => $opts,
	    minmax    => ['max'],
	    value     => $bc->contiguous_cycle_dropoff_count(),
	    above_max_reason_fmt => "Quality drops for more than %d contiguous read cycles (%d).",
	    up_to_max_reason_fmt => "Quality does not drop for more than %d contiguous read cycles (%d).",
	    );
	delete $opts->{auto_qc_qual_contig_cycle_dropoff};



	# Finally, check if there are any keys left in opts
	# if so, there was an unrecognized option in the config file
	if (keys %{$opts}) {
	    $self->auto_qc_bad_conf("unrecognized options in config file ($auto_qc_settings_file): ".join(",", keys %{$opts})."\n");
	}

        
        # now output the results
        
        # Get overall autoqc result
        $status = 1;
        for my $stat ($self->qc_results_elements()) {
            if (!$stat->{status}) {
                $status = 0;
                last;
            } elsif ($stat->{status} == 2) {
                $status = 2;
            }
        }
        
        # write results to the VRTrack database
        my @objs_to_check = ($vrlane);
        push(@objs_to_check, $lib_to_update) if $lib_to_update;
        my $worked = $vrtrack->transaction(
            sub {
                if ($lib_to_update) {
                    # don't pass the library if another lane has previously set it
                    # to failed
                    my $do_update      = 1;
                    my $current_status = $lib_to_update->auto_qc_status;
                    if ($lib_status eq 'passed' && $current_status && $current_status eq 'failed') {
                        $do_update = 0;
                    }
                    
                    if ($do_update) {
                        $lib_to_update->auto_qc_status($lib_status);
                        $lib_to_update->update();
                    }
                }
                
                # output autoQC results to the mapping stats
                for my $stat ($self->qc_results_elements()) {
		    if (length($stat->{test}) > $TEST_MAX) {
			$self->auto_qc_bad_conf("Test string is too long for test ".$stat->{test}."\n");
		    }
		    if (length($stat->{reason}) > $REASON_MAX) {
			$self->auto_qc_bad_conf("Reason string is too long for test ".$stat->{test}.": ".$stat->{reason}."\n");
		    }
                    $mapstats->add_autoqc($stat->{test}, $stat->{status}, $stat->{reason});
                }
                $mapstats->update;
                
                given ($status)
                {
                    when(0) { $vrlane->auto_qc_status('failed'); }
                    when(1) { $vrlane->auto_qc_status('passed'); }
                    when(2) { $vrlane->auto_qc_status('warning'); }
                }
                
                # also, if we did our own genotype check, write those results back
                # to VRTrack now
                if (@gtype_results) {
                    my $mapstats = $vrlane->latest_mapping;
                    $mapstats->genotype_expected($gtype_results[1]);
                    $mapstats->genotype_found($gtype_results[2]);
                    $mapstats->genotype_ratio($gtype_results[3]);
                    $mapstats->update();
                    
                    $vrlane->genotype_status($gtype_results[0]);
                }
                
                $vrlane->update();
            },
            undef,
            [@objs_to_check]
        );
        
        # for some bizarre reason, at this point $lib_to_update->auto_qc_status
        # can report the desired status, yet the database has not actually been
        # updated. Check this
        if ($worked && $lib_to_update) {
            $vrtrack = $self->get_vrtrack(db => $db);
            my $lib_id            = $lib_to_update->id;
            my $check_lib         = VRTrack::Library->new($vrtrack, $lib_id);
            my $desired_qc_status = $lib_to_update->auto_qc_status;
            my $actual_qc_status  = $check_lib->auto_qc_status;
            $self->throw("the auto_qc_status we set ($desired_qc_status) does not match the one in the db ($actual_qc_status) for lane $lib_id") unless $actual_qc_status eq $desired_qc_status;
            
            # below commented section definitely solves the problem, but latest
            # VRTrack has a more generic solution (not yet confirmed effective)
            
            #my $max_retries = 10;
            #while ($check_lib->auto_qc_status ne $desired_qc_status) {
            #    warn "library auto_qc_status in the database was not $desired_qc_status, will try and set it again...\n";
            #    $vrtrack->transaction(sub {
            #        $check_lib->auto_qc_status($desired_qc_status);
            #        $check_lib->update;
            #    });
            #
            #    $max_retries--;
            #    if ($max_retries <= 0) {
            #        $self->throw("Could not get library auto_qc_status to update in the database for library $lib_id");
            #    }
            #
            #    $vrtrack = $self->get_vrtrack(db => $db);
            #    $check_lib = VRTrack::Library->new($vrtrack, $lib_id);
            #}
            #warn "Pretty sure that library auto_qc_status in the database is now $desired_qc_status\n";
        }
        
        if ($worked) {
            # also add the result as metadata on the bam file
            $bam_file->add_metadata({ auto_qc_status => $status ? 'passed' : 'failed' }, replace_data => 1);
        }
        else {
            $self->throw($vrtrack->{transaction_error});
        }
    }
    
    # 1) what percentage of the data lies within the allowed range from the max
    #    peak (e.g. [mpeak*(1-0.25),mpeak*(1+0.25)])
    # 2) how wide is the distribution - how wide has to be the range to
    #    accomodate the given amount of data (e.g. 80% of the reads)
    method insert_size_allowed_amount_and_range (ClassName|Object $self: ArrayRef $vals, Num $maxpeak_range, Num $data_amount) {
        # determine the max peak
        my $count       = 0;
        my $imaxpeak    = 0;
        my $ndata       = scalar @$vals;
        my $total_count = 0;
        my $max         = 0;
        for (my $i = 1; $i < $ndata; $i++) {   # skip IS=0
            my $xval = $$vals[$i][0];
            my $yval = $$vals[$i][1];
            
            $total_count += $yval;
            if ($max < $yval) {
                $imaxpeak = $i;
                $max      = $yval;
            }
        }
        
        # see how many reads are within the max peak range
        $maxpeak_range *= 0.01;
        $count = 0;
        for (my $i = 1; $i < $ndata; $i++) { # skip IS=0
            my $xval = $$vals[$i][0];
            my $yval = $$vals[$i][1];
            
            if ($xval < $$vals[$imaxpeak][0] * (1 - $maxpeak_range)) { next; }
            if ($xval > $$vals[$imaxpeak][0] * (1 + $maxpeak_range)) { next; }
            $count += $yval;
        }
        my $out_amount = 100 * $count / $total_count;
        
        # how big must be the range in order to accommodate the requested amount
        # of data
        $data_amount *= 0.01;
        my $idiff = 0;
        $count = $$vals[$imaxpeak][1];
        while ($count / $total_count < $data_amount) {
            $idiff++;
            if ($idiff < $imaxpeak)          { $count += $$vals[$imaxpeak - $idiff][1]; } # skip IS=0
            if ($idiff + $imaxpeak < $ndata) { $count += $$vals[$imaxpeak + $idiff][1]; }
            
            # this should never happen, unless $data_range is bigger than 100%
            if ($idiff > $imaxpeak && $idiff + $imaxpeak >= $ndata) { last; }
        }
        my $out_range  = $idiff <= $imaxpeak         ? $$vals[$imaxpeak][0] - $$vals[$imaxpeak - $idiff][0] : $$vals[$imaxpeak][0];
        my $out_range2 = $idiff + $imaxpeak < $ndata ? $$vals[$imaxpeak + $idiff][0] - $$vals[$imaxpeak][0] : $$vals[-1][0] - $$vals[$imaxpeak][0];
        if ($out_range2 > $out_range) { $out_range = $out_range2; }
        $out_range = 100 * $out_range / $$vals[$imaxpeak][0];
        return ($out_amount, $out_range);
    }
}

1;
