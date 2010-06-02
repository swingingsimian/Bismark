#!/usr/bin/perl
use warnings;
use strict;
$|++;
use Getopt::Long;


my @filenames;
my %counting;
my %fhs;
my ($ignore,$genomic_fasta,$single,$paired,$full,$report) = process_commandline();

process_Bismark_results_file($ignore,$single,$paired);

sub process_commandline{
  my $help;
  my $single_end;
  my $paired_end;
  my $ignore;
  my $genomic_fasta;
  my $full;
  my $report;

  my $command_line = GetOptions ('help|man' => \$help,
				 'p|paired-end' => \$paired_end,
				 's|single-end' => \$single_end,
				 'fasta' => \$genomic_fasta,
				 'ignore=i' => \$ignore,
				 'comprehensive' => \$full,
				 'report' => \$report,
				);

  ### EXIT ON ERROR if there were errors with any of the supplied options
  unless ($command_line){
    die "Please respecify command line options\n";
  }

  ### HELPFILE
  if ($help){
    print_helpfile();
    exit;
  }

  ### no files provided
  unless (@ARGV){
    die "You need to provide one or more files in Bismark format to create an individual C methylation output.\n";
  }
  @filenames = @ARGV;


  ### IGNORING <INT> bases at the start of the read when processing the methylation call string
  if ($ignore){
    warn "First $ignore bases will be disregarded when processing the methylation call string\n";
  }
  else {
    $ignore = 0;
  }
  sleep (2);
  unless ($report){
    $report = 0;
  }


  ### SINGLE END ALIGNMENTS
  if ($single_end){
    print "Bismark Single-End format specified\n";
    $paired_end = 0;
  }

  ### PAIRED-END ALIGNMENTS
  elsif ($paired_end){
    print "Bismark Paired-End format specified\n";
    $single_end = 0;
  }

  else{
    die "Please specify whether the supplied file(s) are in Bismark single-end or paired-end format\n\n";
  }

  if ($full){
    print "Strand-specific outputs will be skipped. Separate output files for Cs in CpG context or Cs in any other context will be generated (file sizes might become huge!)\n\n";

  }
  else{
    $full = 0;
  }

  return ($ignore,$genomic_fasta,$single_end,$paired_end,$full,$report);
}



sub process_Bismark_results_file{
  my ($ignore,$single,$paired) = @_;

  if ($paired){
    print "paired-end: $paired\n";
  }
  if ($single){
    print "single-end: $single\n";
  }
  if ($ignore){
    print "ignore bases: $ignore\n";
  }
  if ($full){
    print "comprehensive output specified\n";
  }
  if ($genomic_fasta){
    print "Genomic equivalent sequences will be printed out in FastA format\n";
  }
  #  sleep (5);
  foreach my $filename (@filenames){
    %fhs = ();
    %counting =(
		total_meC_count => 0,
		total_meCpG_count => 0,
		total_unmethylated_C_count => 0,
		total_unmethylated_CpG_count => 0,
		sequences_count => 0,
	       );
    print "\nNow reading in Bismark result file $filename\n";
    open (IN,$filename) or die "Can't open file $!\n";

    ### OPENING OUT-FILEHANDLES
    if ($report){
      my $report_filename = $filename;
      $report_filename =~ s/^/Splitting_report_/;
      open (REPORT,'>',$report_filename) or die "Failed to write to file $report_filename $!\n";
    }
    if ($report){
      print REPORT "$filename\n\n";
      print REPORT "Parameters used to extract methylation information:\n";
      if ($paired){
	print REPORT "Bismark result file: paired-end\n";
      }
      if ($single){
	print REPORT "Bismark result file: single-end\n";
      }
      if ($ignore){
	print REPORT "Ignoring first $ignore bases\n";
      }
      if ($full){
	print REPORT "Output specified: comprehensive\n";
      }
      else{
	print REPORT "Output: strand-specific (default)\n";
      }
      if ($genomic_fasta){
	print REPORT "Genomic equivalent sequences will be printed out in FastA format\n";
      }
      print REPORT "\n";
    }


    ### if --comprehensive was specified we are only writing out one CpG-context and one Any-Other-context result file
    if ($full){
      my $cpg_output = my $other_c_output = $filename;
      ### C in CpG context
      $cpg_output =~ s/^/CpG_context_/;
      open ($fhs{CpG_context},'>',$cpg_output) or die "Failed to write to $cpg_output $! \n";
      print "Writing result file containing methylation information for C in CpG context to $cpg_output\n";

      ### C in any other context than CpG
      $other_c_output =~ s/^/Non_CpG-context_/;
      open ($fhs{other_context},'>',$other_c_output) or die "Failed to write to $other_c_output $!\n";
      print "Writing result file containing methylation information for C in any other context to $other_c_output\n";
    }

    ### else we will write out 8 different output files, depending on where the (first) unique best alignment has been found
    else{
      my $cpg_ot = my $cpg_ctot = my $cpg_ctob = my $cpg_ob = $filename;
      ### For cytosines in CpG context
      $cpg_ot =~ s/^/CpG_OT_/;
      open ($fhs{0}->{CpG},'>',$cpg_ot) or die "Failed to write to $cpg_ot $!\n";
      print "Writing result file containing methylation information for C in CpG context from the original forward strand to $cpg_ot\n";

      $cpg_ctot =~ s/^/CpG_CTOT_/;
      open ($fhs{1}->{CpG},'>',$cpg_ctot) or die "Failed to write to $cpg_ctot $!\n";
      print "Writing result file containing methylation information for C in CpG context from the complementary to original forward strand to $cpg_ctot\n";

      $cpg_ctob =~ s/^/CpG_CTOB_/;
      open ($fhs{2}->{CpG},'>',$cpg_ctob) or die "Failed to write to $cpg_ctob $!\n";
      print "Writing result file containing methylation information for C in CpG context from the complementary to original reverse strand to $cpg_ctob\n";

      $cpg_ob =~ s/^/CpG_OB_/;
      open ($fhs{3}->{CpG},'>',$cpg_ob) or die "Failed to write to $cpg_ob $!\n";
      print "Writing result file containing methylation information for C in CpG context from the original reverse strand to $cpg_ob\n";


      ### For cytosines in CC, CT or CA context
      my $other_c_ot = my $other_c_ctot = my $other_c_ctob = my $other_c_ob = $filename;
      $other_c_ot =~ s/^/Other_C_OT_/;
      open ($fhs{0}->{other_c},'>',$other_c_ot) or die "Failed to write to $other_c_ot $!\n";
      print "Writing result file containing methylation information for C in any other context from the original forward strand to $other_c_ot\n";

      $other_c_ctot =~ s/^/Other_C_CTOT_/;
      open ($fhs{1}->{other_c},'>',$other_c_ctot) or die "Failed to write to $other_c_ctot $!\n";
      print "Writing result file containing methylation information for C in any other context from the complementary to original forward strand to $other_c_ctot\n";

      $other_c_ctob =~ s/^/Other_C_CTOB_/;
      open ($fhs{2}->{other_c},'>',$other_c_ctob) or die "Failed to write to $other_c_ctob $!\n";
      print "Writing result file containing methylation information for C in any other context from the complementary to original reverse strand to $other_c_ctob\n";

      $other_c_ob =~ s/^/Other_C_OB_/;
      open ($fhs{3}->{other_c},'>',$other_c_ob) or die "Failed to write to $other_c_ob $!\n";
      print "Writing result file containing methylation information for C in any other context from the original reverse strand to $other_c_ob\n";
    }

    ### For repeat analyses or similar one can obtain a FastA output file with the genomic equivalent sequences for a bisulfite read position
    if ($genomic_fasta){
      my $fasta = $filename;
      $fasta =~ s/^/genomic_equivalents_fastA_/;
      open (FASTA,'>',$fasta) or die "Can't write to file $fasta: $!\n";
    }
    my $methylation_call_strings_processed = 0;
    my $line_count = 0;

    ### proceeding differently now for single-end or paired-end Bismark files

    ### PROCESSING SINGLE-END RESULT FILES
    if ($single){
      while (<IN>){
	++$line_count;
	print "processed lines: $line_count\n" if ($line_count%500000==0);
	
	### $seq here is the chromosomal sequence (to use for the repeat analysis for example)
	my ($id,$strand,$chrom,$start,$seq,$meth_call,$index,$conversion_info) = (split("\t"))[0,1,2,3,5,6,7,8];
	### we need to remove 1 bp of the genomic sequence as we were extracting 41 bp long fragments to make a methylation call at the first or
	### last position
	if ($meth_call){
	
	  ### We will need to discriminate between 1 extra base at the 5' end or at the 3' end
	  ### removing most 3' base
	  if ($conversion_info =~ /^CT/){
	    $seq = substr($seq,0,length($seq)-1);
	  }	
	  ### removing most 5' base
	  elsif ($conversion_info =~ /^GA/){
	    $seq = substr($seq,1,length($seq)-1);
	  }
	  else{
	    die "We need the read conversion info to proceed with extracting the correct part of the genomic sequence\n";
	  }

	  ### Clipping off the first <int> number of bases from the methylation call string as specified with --ignore <int>
	  if ($ignore){
	    $meth_call = substr($meth_call,$ignore,length($meth_call)-$ignore);	
	  }

	  ### printing out the methylation state of every C in the read
	  print_individual_C_methylation_states_single_end($meth_call,$chrom,$start,$id,$seq,$strand,$index);

	  ### if $genomic_fasta has been specified we print out a FastA file with genomic equivalent sequences
	  if ($genomic_fasta){
	    print FASTA ">$line_count\n";
	    print FASTA "$seq\n";
	  }
	  ++$methylation_call_strings_processed; # 1 per single-end result
	}
      }
    }

    ### PROCESSING PAIRED-END RESULT FILES
    elsif ($paired){
      while (<IN>){
	++$line_count;
	print "processed line: $line_count\n" if ($line_count%500000==0);
	my ($id,$chrom,$start_read_1,$end_read_2,$seq_1,$meth_call_1,$seq_2,$meth_call_2,$index) = (split("\t"))[0,2,3,4,6,7,9,10,11];
	### we need to remove the 1bpq base of the genomic sequence as we were extracting 41 bp long fragments to make a methylation call at the
	### first or last position

	
	### ~~~~~~~~~~~~ think through again
	##these substrings need to be thought through again, it depends on whether there is a leading or a trailing base (CT or GA conversion, respectively)
	$seq_1 = substr($seq_1,0,40);
	$seq_2 = substr($seq_2,0,40);
	$start_read_1 += 1; ### doing this because bowtie reports the index and not the base pair position of the the start sequence
	if ($meth_call_1 and $meth_call_2){
	  if ($index == 0 or $index == 1){
	    my $end_read_1 = $start_read_1+length($seq_1)-1;
	    my $start_read_2 = $end_read_2-length($seq_2)+1;
	    # print join ("\t",$id,$chrom,$start_read_1,$end_read_1,$seq_1,$meth_call_1),"\n";
	    # print join ("\t",$id,$chrom,$start_read_2,$end_read_2,$seq_2,$meth_call_2),"\n";
	    ### print_fastA_file_with_genomic_equivalent_sequences($id,$chrom,$start_read_1,$seq_1,$end_read_2,$seq_1);
	    # print join ("\t",$id,$chrom,$start_read_1,$end_read_2,$seq_1,$meth_call_1,$seq_2,$meth_call_2),"\n";
	    ## we first pass the first read of a paired-end alignment
	    print_individual_C_methylation_states_paired_end_files($meth_call_1,$chrom,$start_read_1,$id,'+',$index);
	    # we next pass the second read, which is always in - orientation on the reverse strand
	    print_individual_C_methylation_states_paired_end_files($meth_call_2,$chrom,$end_read_2,$id,'-',$index);
	    $counting{sequences_count}++;
	  }
	  elsif ($index == 2 or $index == 3){
	    my $end_read_1 = $start_read_1+length($seq_1)-1;
	    my $start_read_2 = $end_read_2-length($seq_2)+1;
	    # print join ("\t",$id,$chrom,$start_read_1,$end_read_1,$seq_1,$meth_call_1),"\n";
	    # print join ("\t",$id,$chrom,$start_read_2,$end_read_2,$seq_2,$meth_call_2),"\n";
	    ### print_fastA_file_with_genomic_equivalent_sequences($id,$chrom,$start_read_1,$seq_1,$end_read_2,$seq_1);
	    # print join ("\t",$id,$chrom,$start_read_1,$end_read_2,$seq_1,$meth_call_1,$seq_2,$meth_call_2),"\n";
	    ## we first pass the first read of a paired-end alignment
	    ### I AM JUST PASSING ON THE METHYLATION CALL FROM THE OTHER READ. ALTHOUGH THIS SHOULD FIX THE PROBLEM I NEED A MORE LONG TERM SOLUTION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	    print_individual_C_methylation_states_paired_end_files($meth_call_2,$chrom,$start_read_1,$id,'+',$index);
	    # we next pass the second read, which is always in - orientation on the reverse strand
	    print_individual_C_methylation_states_paired_end_files($meth_call_1,$chrom,$end_read_2,$id,'-',$index);
	    $counting{sequences_count}++;
	  }
	  else{
	    die "There can only be 4 different index numbers\n";
	  }
	  ++$methylation_call_strings_processed; # paired-end = 2 methylation calls
	}
      }
    }
    else{
      die "Single-end or paired-end reads not specified properly: $!\n";
    }

    print "Processed $line_count lines from $filename in total\n\n";
    print "Total number of methylation call strings processed: $methylation_call_strings_processed\n\n";

    print_splitting_report ();
  }
}


sub print_splitting_report{
  if ($report){
     ### detailed information about Cs analysed
  print REPORT "Final Cytosine Methylation Report\n",'='x33,"\n";

  my $total_number_of_C = $counting{total_meC_count}+$counting{total_meCpG_count}+$counting{total_unmethylated_C_count}+$counting{total_unmethylated_CpG_count};
  print REPORT "Total number of C's analysed:\t$total_number_of_C\n";
  print REPORT "Total methylated C's in non-CpG context:\t$counting{total_meC_count}\n";
  print REPORT "Total methylated C's in CpG context:\t $counting{total_meCpG_count}\n";
  print REPORT "Total C to T conversions in non-CpG context:\t$counting{total_unmethylated_C_count}\n";
  print REPORT "Total C to T conversions in CpG context:\t$counting{total_unmethylated_CpG_count}\n\n";

  my $percent_meC;
  if (($counting{total_meC_count}+$counting{total_unmethylated_C_count}) > 0){
    $percent_meC = sprintf("%.1f",100*$counting{total_meC_count}/($counting{total_meC_count}+$counting{total_unmethylated_C_count}));
  }
  my $percent_meCpG;
  if (($counting{total_meCpG_count}+$counting{total_unmethylated_CpG_count}) > 0){
    $percent_meCpG = sprintf("%.1f",100*$counting{total_meCpG_count}/($counting{total_meCpG_count}+$counting{total_unmethylated_CpG_count}));
  }

  ### calculating methylated C percentage (non-CpG context) if applicable
  if ($percent_meC){
    print REPORT "C methylated but not in CpG context:\t${percent_meC}%\n";
  }
  else{
    print REPORT "Can't determine percentage of methylated Cs (not in CpG context) if value was 0\n";
  }

  ### calculating methylated CpG percentage if applicable
  if ($percent_meCpG){
    print REPORT "C methylated in CpG context:\t${percent_meCpG}%\n\n\n";
  }
  else{
    print REPORT "Can't determine percentage of methylated Cs (in CpG context) if value was 0\n\n\n";
  }


  }

  ### detailed information about Cs analysed
  print "Final Cytosine Methylation Report\n",'='x33,"\n";

  my $total_number_of_C = $counting{total_meC_count}+$counting{total_meCpG_count}+$counting{total_unmethylated_C_count}+$counting{total_unmethylated_CpG_count};
  print "Total number of C's analysed:\t$total_number_of_C\n";
  print "Total methylated C's in non-CpG context:\t$counting{total_meC_count}\n";
  print "Total methylated C's in CpG context:\t $counting{total_meCpG_count}\n";
  print "Total C to T conversions in non-CpG context:\t$counting{total_unmethylated_C_count}\n";
  print "Total C to T conversions in CpG context:\t$counting{total_unmethylated_CpG_count}\n\n";

  my $percent_meC;
  if (($counting{total_meC_count}+$counting{total_unmethylated_C_count}) > 0){
    $percent_meC = sprintf("%.1f",100*$counting{total_meC_count}/($counting{total_meC_count}+$counting{total_unmethylated_C_count}));
  }
  my $percent_meCpG;
  if (($counting{total_meCpG_count}+$counting{total_unmethylated_CpG_count}) > 0){
    $percent_meCpG = sprintf("%.1f",100*$counting{total_meCpG_count}/($counting{total_meCpG_count}+$counting{total_unmethylated_CpG_count}));
  }

  ### calculating methylated C percentage (non-CpG context) if applicable
  if ($percent_meC){
    print "C methylated but not in CpG context:\t${percent_meC}%\n";
  }
  else{
    print "Can't determine percentage of methylated Cs (not in CpG context) if value was 0\n";
  }

  ### calculating methylated CpG percentage if applicable
  if ($percent_meCpG){
    print "C methylated in CpG context:\t${percent_meCpG}%\n\n\n";
  }
  else{
    print "Can't determine percentage of methylated Cs (in CpG context) if value was 0\n\n\n";
  }
}



# sub process_paired_end_Bismark_results_file{
#   foreach my $filename (@filenames){
#     %fhs =();
#     %counting =(
# 		total_meC_count => 0,
# 		total_meCpG_count => 0,
# 		total_unmethylated_C_count => 0,
# 		total_unmethylated_CpG_count => 0,
# 		sequences_count => 0,
# 	       );
#     print "Now reading in paired-end BiSeq result file $filename\n";
#     open (IN,$filename) or die "Can't open file $!\n";
#     my $fasta = $filename;
#     # $fasta =~ s/^/genomic_equivalents_/;
#     # $fasta =~ s/txt$/fa/;
#     # open (FASTA,'>',$fasta) or die "Can't write to file $!\n";
#     my $count =0;
#     my $cpg_ot = my $cpg_ctot = my $cpg_ctob = my $cpg_ob = $filename;
#     ###creating a hash with CpG and non-CpG outout filehandles
#     $fhs{0}->{name} = 'OT';
#     $fhs{1}->{name} = 'CTOT';
#     $fhs{2}->{name} = 'CTOB';
#     $fhs{3}->{name} = 'OB';
#     if ($cpg_ot =~ s/^/CpG_OT_/){
#       open ($fhs{0}->{CpG},'>',$cpg_ot) or die "Failed to write to $cpg_ot $!\n";
#       print "Writing result file containing methylation information for C in CpG context from the original forward strand to $cpg_ot\n";
#     }
#     if ($cpg_ctot =~ s/^/CpG_CTOT_/){
#       open ($fhs{1}->{CpG},'>',$cpg_ctot) or die "Failed to write to $cpg_ctot $!\n";
#       print "Writing result file containing methylation information for C in CpG context from the complementary to original forward strand to $cpg_ctot\n";
#     }
#     if ($cpg_ctob =~ s/^/CpG_CTOB_/){
#       open ($fhs{2}->{CpG},'>',$cpg_ctob) or die "Failed to write to $cpg_ctob $!\n";
#       print "Writing result file containing methylation information for C in CpG context from the complementary to original reverse strand to $cpg_ctob\n";
#     }
#     if ($cpg_ob =~ s/^/CpG_OB_/){
#       open ($fhs{3}->{CpG},'>',$cpg_ob) or die "Failed to write to $cpg_ob $!\n";
#       print "Writing result file containing methylation information for C in CpG context from the original reverse strand to $cpg_ob\n";
#     }
#     my $other_c_ot = my $other_c_ctot = my $other_c_ctob = my $other_c_ob = $filename;
#     if ($other_c_ot =~ s/^/Other_C_OT_/){
#       open ($fhs{0}->{other_c},'>',$other_c_ot) or die "Failed to write to $other_c_ot $!\n";
#       print "Writing result file containing methylation information for C in any other context from the original forward strand to $other_c_ot\n";
#     }
#     if ($other_c_ctot =~ s/^/Other_C_CTOT_/){
#       open ($fhs{1}->{other_c},'>',$other_c_ctot) or die "Failed to write to $other_c_ctot $!\n";
#      print "Writing result file containing methylation information for C in any other context from the complementary to original forward strand to $other_c_ctot\n";
#     }
#     if ($other_c_ctob =~ s/^/Other_C_CTOB_/){
#       open ($fhs{2}->{other_c},'>',$other_c_ctob) or die "Failed to write to $other_c_ctob $!\n";
#       print "Writing result file containing methylation information for C in any other context from the complementary to original reverse strand to $other_c_ctob\n";
#     }
#     if ($other_c_ob =~ s/^/Other_C_OB_/){
#       open ($fhs{3}->{other_c},'>',$other_c_ob) or die "Failed to write to $other_c_ob $!\n";
#       print "Writing result file containing methylation information for C in any other context from the original reverse strand to $other_c_ob\n";
#     }
#     while (<IN>){
#       #  last if ($count == 10000);
#       print "processed $count lines\n" if ($count%500000==0);
#       my ($id,$chrom,$start_read_1,$end_read_2,$seq_1,$meth_call_1,$seq_2,$meth_call_2,$index) = (split("\t"))[0,2,3,4,6,7,9,10,11];
#       ### we need to remove the last base of the genomic sequence as we were extracting 41 bp long fragments to make a methylation call at the 40th position
#       ##these substrings need to be thought through again, it depends on whether there is a leading or a trailing base (CT or GA conversion, respectively)
#       $seq_1 = substr($seq_1,0,40);
#       $seq_2 = substr($seq_2,0,40);
#       $start_read_1 += 1; ### doing this because bowtie reports the index and not the base pair position of the the start sequence
#       if ($index == 0 or $index == 1){
# 	my $end_read_1 = $start_read_1+length($seq_1)-1;
# 	my $start_read_2 = $end_read_2-length($seq_2)+1;
# 	# print join ("\t",$id,$chrom,$start_read_1,$end_read_1,$seq_1,$meth_call_1),"\n";
# 	# print join ("\t",$id,$chrom,$start_read_2,$end_read_2,$seq_2,$meth_call_2),"\n";
# 	### print_fastA_file_with_genomic_equivalent_sequences($id,$chrom,$start_read_1,$seq_1,$end_read_2,$seq_1);
# 	# print join ("\t",$id,$chrom,$start_read_1,$end_read_2,$seq_1,$meth_call_1,$seq_2,$meth_call_2),"\n";
# 	## we first pass the first read of a paired-end alignment
# 	print_individual_C_methylation_states_paired_end_files($meth_call_1,$chrom,$start_read_1,$id,'+',$index);
# 	# we next pass the second read, which is always in - orientation on the reverse strand
# 	print_individual_C_methylation_states_paired_end_files($meth_call_2,$chrom,$end_read_2,$id,'-',$index);
# 	$count += 2; # paired-end = 2 sequences
# 	$counting{sequences_count}++;
#       }
#       elsif ($index == 2 or $index == 3){
# 	my $end_read_1 = $start_read_1+length($seq_1)-1;
# 	my $start_read_2 = $end_read_2-length($seq_2)+1;
# 	# print join ("\t",$id,$chrom,$start_read_1,$end_read_1,$seq_1,$meth_call_1),"\n";
# 	# print join ("\t",$id,$chrom,$start_read_2,$end_read_2,$seq_2,$meth_call_2),"\n";
# 	### print_fastA_file_with_genomic_equivalent_sequences($id,$chrom,$start_read_1,$seq_1,$end_read_2,$seq_1);
# 	# print join ("\t",$id,$chrom,$start_read_1,$end_read_2,$seq_1,$meth_call_1,$seq_2,$meth_call_2),"\n";
# 	## we first pass the first read of a paired-end alignment

# 	### I AM JUST PASSING ON THE METHYLATION CALL FROM THE OTHER READ. ALTHOUGH THIS SHOULD FIX THE PROBLEM I NEED A MORE LONG TERM SOLUTION!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# 	print_individual_C_methylation_states_paired_end_files($meth_call_2,$chrom,$start_read_1,$id,'+',$index);
# 	# we next pass the second read, which is always in - orientation on the reverse strand
# 	print_individual_C_methylation_states_paired_end_files($meth_call_1,$chrom,$end_read_2,$id,'-',$index);
# 	$count += 2; # paired-end = 2 sequences
# 	$counting{sequences_count}++;
# 	if ($genomic_fasta){	
# 	  print FASTA ">$id,$chrom,$start_read_1\n";
# 	  print FASTA "$seq_1\n";
# 	  print FASTA ">$id,$chrom,$end_read_2\n";
# 	  print FASTA "$seq_2\n";
# 	}
#       }
#       else{
# 	warn "There can only be 4 different index numbers\n";
#       }
#     }
#     print "Processed $count lines from $filename in total\n\n";
#     ### detailed information about Cs analysed
#     print "Final Cytosine Methylation Report\n",'='x33,"\n";
#     my $total_number_of_C = $counting{total_meC_count}+$counting{total_meCpG_count}+$counting{total_unmethylated_C_count}+$counting{total_unmethylated_CpG_count};
#     print "Total number of C's analysed:\t$total_number_of_C\n";
#     print "Total methylated C's in non-CpG context:\t$counting{total_meC_count}\n";
#     print "Total methylated C's in CpG context:\t $counting{total_meCpG_count}\n";
#     print "Total C to T conversions in non-CpG context:\t$counting{total_unmethylated_C_count}\n";
#     print "Total C to T conversions in CpG context:\t$counting{total_unmethylated_CpG_count}\n\n";
#     my $percent_meC;
#     if (($counting{total_meC_count}+$counting{total_unmethylated_C_count}) > 0){
#       $percent_meC = sprintf("%.1f",100*$counting{total_meC_count}/($counting{total_meC_count}+$counting{total_unmethylated_C_count}));
#     }
#     my $percent_meCpG;
#     if (($counting{total_meCpG_count}+$counting{total_unmethylated_CpG_count}) > 0){
#       $percent_meCpG = sprintf("%.1f",100*$counting{total_meCpG_count}/($counting{total_meCpG_count}+$counting{total_unmethylated_CpG_count}));
#     }
#     ### calculating methylated C percentage (non CpG context) if applicable
#     if ($percent_meC){
#       print "C methylated but not in CpG context:\t${percent_meC}%\n";
#     }
#     else{
#       print "Can't determine percentage of methylated Cs (not in CpG context) if value was 0\n";
#     }
#     ### calculating methylated CpG percentage if applicable
#     if ($percent_meCpG){
#       print "C methylated in CpG context:\t${percent_meCpG}%\n";
#     }
#     else{
#       print "Can't determine percentage of methylated Cs (in CpG context) if value was 0\n";
#     }
#     print "\n\n";
#   }
# }

sub print_individual_C_methylation_states_paired_end_files{
  my ($meth_call,$chrom,$start,$id,$strand,$filehandle_index) = @_;
  my @methylation_calls = split(//,$meth_call);
  ############################################################
  ### . for bases not involving cytosines                  ###
  ### C for methylated C (was protected)                   ###
  ### c for not methylated C (was converted)               ###
  ### Z for methylated C in CpG context (was protected)    ###
  ### z for not methylated C in CpG context (was converted)###
  ############################################################
  my @match =();
  my $methyl_C_count = 0;
  my $methyl_CpG_count = 0;
  my $unmethylated_C_count = 0;
  my $unmethylated_CpG_count = 0;

  if ($strand eq '+') {
    for my $index (0..$#methylation_calls) {
      if ($methylation_calls[$index] eq 'C') {
 	$counting{total_meC_count}++;
 	print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'+',$chrom,$start+$index,$methylation_calls[$index]),"\n";
      } elsif ($methylation_calls[$index] eq 'c') {
 	$counting{total_unmethylated_C_count}++;
 	print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'-',$chrom,$start+$index,$methylation_calls[$index]),"\n";
      } elsif ($methylation_calls[$index] eq 'Z') {
 	$counting{total_meCpG_count}++;
 	print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'+',$chrom,$start+$index,$methylation_calls[$index]),"\n";
      } elsif ($methylation_calls[$index] eq 'z') {
 	$counting{total_unmethylated_CpG_count}++;
 	print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'-',$chrom,$start+$index,$methylation_calls[$index]),"\n";
      }
    }
  }
  elsif ($strand eq '-') {
    for my $index (0..$#methylation_calls) {
      if ($methylation_calls[$index] eq 'C') {
 	$counting{total_meC_count}++;
 	print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'+',$chrom,$start-$index,$methylation_calls[$index]),"\n";
      }
      elsif ($methylation_calls[$index] eq 'c') {
 	$counting{total_unmethylated_C_count}++;
 	print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'-',$chrom,$start-$index,$methylation_calls[$index]),"\n";
      }
      elsif ($methylation_calls[$index] eq 'Z') {
 	$counting{total_meCpG_count}++;
 	print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'+',$chrom,$start-$index,$methylation_calls[$index]),"\n";
      }
      elsif ($methylation_calls[$index] eq 'z') {
 	$counting{total_unmethylated_CpG_count}++;
 	print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'-',$chrom,$start-$index,$methylation_calls[$index]),"\n";
      }
    }
  }
  else {
    die "This cannot happen $!\n";
  }
}


sub print_individual_C_methylation_states_single_end{

  my ($meth_call,$chrom,$start,$id,$seq,$strand,$filehandle_index) = @_;
  my @methylation_calls = split(//,$meth_call);
  ############################################################
  ### . for bases not involving cytosines                  ###
  ### C for methylated C (was protected)                   ###
  ### c for not methylated C (was converted)               ###
  ### Z for methylated C in CpG context (was protected)    ###
  ### z for not methylated C in CpG context (was converted)###
  ############################################################
  my @match =();
  my $methyl_C_count = 0;
  my $methyl_CpG_count = 0;
  my $unmethylated_C_count = 0;
  my $unmethylated_CpG_count = 0;

  ### single-file CpG and other-context output
  if ($full){
    if ($strand eq '+'){
      $start +=1;
      for my $index (0..$#methylation_calls) {
	### methylated Cs (any context) will receive a forward (+) orientation
	### not methylated Cs (any context) will receive a reverse (-) orientation
	if ($methylation_calls[$index] eq 'C'){
	  $counting{total_meC_count}++;
	  print {$fhs{other_context}} join ("\t",$id,'+',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'c') {
	  $counting{total_unmethylated_C_count}++;
	  print {$fhs{other_context}} join ("\t",$id,'-',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'Z') {
	  $counting{total_meCpG_count}++;
	  print {$fhs{CpG_context}} join ("\t",$id,'+',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'z') {
	  $counting{total_unmethylated_CpG_count}++;
	  print {$fhs{CpG_context}} join ("\t",$id,'-',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
      }
    }
    elsif($strand eq '-'){
      $start += length($seq);
      for my $index (0..$#methylation_calls) {
	### methylated Cs (any context) will receive a forward (+) orientation
	### not methylated Cs (any context) will receive a reverse (-) orientation
	if ($methylation_calls[$index] eq 'C'){
	  $counting{total_meC_count}++;
	  print {$fhs{other_context}} join ("\t",$id,'+',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'c') {
	  $counting{total_unmethylated_C_count}++;
	  print {$fhs{other_context}} join ("\t",$id,'-',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'Z') {
	  $counting{total_meCpG_count}++;
	  print {$fhs{CpG_context}} join ("\t",$id,'+',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'z') {
	  $counting{total_unmethylated_CpG_count}++;
	  print {$fhs{CpG_context}} join ("\t",$id,'-',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
      }
    }
    else{
      die "This cannot happen (or it shouldn't....$!\n";
    }
  }

  ### strand-specific methylation output
  else{
    if ($strand eq '+'){
      $start +=1;
      for my $index (0..$#methylation_calls) {
	### methylated Cs (any context) will receive a forward (+) orientation
	### not methylated Cs (any context) will receive a reverse (-) orientation
	if ($methylation_calls[$index] eq 'C'){
	  $counting{total_meC_count}++;
	  print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'+',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'c') {
	  $counting{total_unmethylated_C_count}++;
	  print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'-',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'Z') {
	  $counting{total_meCpG_count}++;
	  print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'+',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'z') {
	  $counting{total_unmethylated_CpG_count}++;
	  print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'-',$chrom,$start+$index,$methylation_calls[$index]),"\n";
	}
      }
    }
    elsif($strand eq '-'){
      $start += length($seq);
      for my $index (0..$#methylation_calls) {
	### methylated Cs (any context) will receive a forward (+) orientation
	### not methylated Cs (any context) will receive a reverse (-) orientation
	if ($methylation_calls[$index] eq 'C'){
	  $counting{total_meC_count}++;
	  print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'+',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'c') {
	  $counting{total_unmethylated_C_count}++;
	  print {$fhs{$filehandle_index}->{other_c}} join ("\t",$id,'-',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'Z') {
	  $counting{total_meCpG_count}++;
	  print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'+',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
	elsif ($methylation_calls[$index] eq 'z') {
	  $counting{total_unmethylated_CpG_count}++;
	  print {$fhs{$filehandle_index}->{CpG}} join ("\t",$id,'-',$chrom,$start-$index,$methylation_calls[$index]),"\n";
	}
      }
    }
    else{
      die "This cannot happen (or it shouldn't....$!\n";
    }
  }
}

sub print_helpfile{

 print << 'HOW_TO';


DESCRIPTION

The following is a brief description of all options to control the script: 
"strand_specific_C_methylation.pl". The script reads in a bisulfite read alignment
results file produced by the Bismark bisulfite mapper and extracts the methylation
information for individual cytocines. This information is found in the methylation
call field which looks like this:

       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
       ~~~   C   for methylated C (was protected)                    ~~~
       ~~~   c   for not methylated C (was converted)                ~~~
       ~~~   Z   for methylated C in CpG context (was protected)     ~~~
       ~~~   z   for not methylated C in CpG context (was converted) ~~~
       ~~~   .   for bases not involving cytosines                   ~~~
       ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

The current version will create one output for cytosines in CpG-context and a second
output for cytosines in any other context (this distinction is actually already made
in Bismark.pl). As the methylation information for every C analysed can easily reach
files with tens or even hundreds of millions of lines, file sizes can become very
large and more difficult to handle. The C methylation info is therefore additionally
split up into one of the four possible strands a given bisulfite read aligned against:

             OT      original top strand
             CTOT    complementary to original top strand

             OB      original bottom strand
             CTOB    complementary to original bottom strand

Thus, eight individual output files are being generated per input file (depending on
CpG or any other context). These can be imported into a genome viewing program, e.g.
SeqMonk, and recombined into a single data group (in fact unless the bisulfite reads
were generated preserving directionality it doesn't make any sense to look at the data
in a strand-specific manner). Strand-specific oupput files can optionally be skipped,
in which case only two output files for CpG context or C in any other context will be
generated. The output files are in the following format (tab delimited):

<sequence_id>     <strand>      <chromosome>     <position>     <methylation call>


USAGE: strand_specific_C_methylation.pl [options] <filenames>


ARGUMENTS:

<filenames>              A space-separated list of result files in Bismark format from 
                         which methylation information is extracted for every cytosine in 
                         the read.

OPTIONS:

-s/--single-end          Input file(s) are Bismark result file(s) generated from single-end
                         read data. Specifying either --single-end or --paired-end is
                         mandatory.

-p/--paired-end          Input file(s) are Bismark result file(s) generated from paired-end
                         read data. Specifying either --paired-end or --single-end is
                         mandatory.

--fasta                  Chosing this option will print out the genomic sequences that
                         correspond to the bisulfite mapped reads in FastA format.
                         This might be useful for certain applications where the
                         bisulfite read cannot be used (such as repeat analyses).

--ignore <int>           Ignore the first <int> bp when processing the methylation call
                         string. As all reads are sorted in a forward direction this can
                         remove e.g. a restriction enzyme site at the start of each read.

--comprehensive          This will produce only two comprehensive output files for Cs in
                         (i)  CpG context
                         (ii) CA, CT or CC context
                         (Depending on the C content of the Bismark result file, the output
                         file size might reach 10-30GB!).

--report                 Prints out a short methylation summary and the paramaters used to run
                         this script.

-h/--help                Displays this help file and exits.


This script was last edited on 27 May 2010.

HOW_TO
}