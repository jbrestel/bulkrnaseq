
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    PARAMS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
params.hisat2_build_memory = null
params.seq_center = null
params.save_unaligned = true


/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { FASTQC                                    } from '../modules/nf-core/fastqc/main'
include { FASTQCCHECK                               } from '../modules/local/fastqccheck.nf'

// NOTE: trimmomatic is an adapted nf-core module
include { TRIMMOMATIC                               } from '../modules/nf-core/trimmomatic/main'

include { HISAT2_BUILD                              } from '../modules/nf-core/hisat2/build/main'

// NOTE: hisat2 align is adapted from nf-core module
include { HISAT2_ALIGN                              } from '../modules/nf-core/hisat2/align/main'

include { SAMTOOLS_SORT as SAMTOOLS_SORT_DEFAULT    } from '../modules/nf-core/samtools/sort/main'

include { BAM_FILTER_AND_SORT_BY_NAME               } from '../subworkflows/local/bam_postprocessing'
include { HTSEQ_COUNTS_AND_TPM                      } from '../subworkflows/local/htseq_counting_and_tpm'

include { SPLIT_BAM_STATS_AND_BED                   } from '../subworkflows/local/split_bam_stats_and_bed'


include { SAMTOOLS_VIEW as SAMTOOLS_BAM_TO_SAM      } from '../modules/nf-core/samtools/view/main'

include { SPLICE_CROSS_READS                        } from '../modules/local/splicecorssreads.nf'

include { SAMTOOLS_FAIDX                            } from '../modules/nf-core/samtools/faidx/main'

// TODO Junctions

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow BULKRNASEQ {

    take:
    ch_samplesheet // channel: samplesheet read in from --input

    main:

    ch_versions = Channel.empty();
    ch_multiqc_files = Channel.empty();

    FASTQC(ch_samplesheet);
    FASTQCCHECK(FASTQC.out.zip);
    TRIMMOMATIC(ch_samplesheet.join(FASTQCCHECK.out.phred));	

    if(!params.useExistingIndex) {
        HISAT2_BUILD(tuple(params.genome, [params.fasta]),
                     tuple([], []),
                     tuple([], [])
        );

        HISAT2_ALIGN(TRIMMOMATIC.out.trimmed_reads,
                     HISAT2_BUILD.out.index,
                     tuple([], [])
        );
    }
    else {
        HISAT2_ALIGN(TRIMMOMATIC.out.trimmed_reads,
                     tuple(params.genome, params.hisatIndex),
                     tuple([], [])
        );
    }



    SAMTOOLS_SORT_DEFAULT(HISAT2_ALIGN.out.bam, tuple([], []))

    BAM_FILTER_AND_SORT_BY_NAME(SAMTOOLS_SORT_DEFAULT.out.bam)

    HTSEQ_COUNTS_AND_TPM(BAM_FILTER_AND_SORT_BY_NAME.out.bamSortedByName)

    SAMTOOLS_FAIDX(tuple([],params.fasta))
    SPLIT_BAM_STATS_AND_BED(SAMTOOLS_SORT_DEFAULT.out.bam,SAMTOOLS_FAIDX.out.fai)

    // MAKE SAM file and pass to perl script for junctions
    SAMTOOLS_BAM_TO_SAM(BAM_FILTER_AND_SORT_BY_NAME.out.bamSortedByDefaultWithIndex, tuple([], []), [])
    SPLICE_CROSS_READS(SAMTOOLS_BAM_TO_SAM.out.sam)

//TODO Deal with versions from subworkflows
    // ch_versions = ch_versions.mix(
    //     HISAT2_BUILD.out.versions.first(),
    //     // FASTQC.out.versions.first(),
    //     // FASTQCCHECK.out.versions.first(),
    //     // TRIMMOMATIC.out.versions.first(),
    //     // HISAT2_ALIGN.out.versions.first(),
    //     // SAMTOOLS_SORT_DEFAULT.out.versions.first()
    // )

    emit:
    versions       = ch_versions                 // channel: [ path(versions.yml) ]
}



/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
