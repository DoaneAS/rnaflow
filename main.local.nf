/*
 * Copyright (c) 2013-2017, Centre for Genomic Regulation (CRG) and the authors.
 *
 *   This file is part of 'RNASEQ-NF'.
 *
 *   RNASEQ-NF is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   RNASEQ-NF is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with RNASEQ-NF.  If not, see <http://www.gnu.org/licenses/>.
 */
 
 
/* 
 * Proof of concept of a RNAseq pipeline implemented with Nextflow
 * 
 * Authors:
 * - Paolo Di Tommaso <paolo.ditommaso@gmail.com>
 * - Emilio Palumbo <emiliopalumbo@gmail.com> 
 * - Evan Floden <evanfloden@gmail.com> 
 */ 

 
/*
 * Default pipeline parameters. They can be overriden on the command line eg. 
 * given `params.foo` specify on the run command line `--foo some_value`.  
 */


params.reads = "$baseDir/data/hemesrr/SRR*_{1,2}.fastq"

params.transcriptome = "$baseDir/data/hg38/ref-transcripts.fa"
//params.transcriptome = "/athena/elementolab/scratch/asd2007/reference/hg38/ensembl97/Homo_sapiens.GRCh38.cdna.all.fa.gz"
params.gtf = "/athena/elementolab/scratch/asd2007/reference/hg38/ensembl97/Homo_sapiens.GRCh38.97.gtf.gz"
params.genome = "/athena/elementolab/scratch/asd2007/reference/hg38/ensembl97/Homo_sapiens.GRCh38.dna.primary_assembly.fa.gz"
params.outdir = "results"
params.decoy = "/athena/elementolab/scratch/asd2007/projectshg38/datasets/rnaseq/quantifications/rnaseq-nf/data/hg38/decoys.txt"
params.gentrome = "/athena/elementolab/scratch/asd2007/projectshg38/datasets/rnaseq/quantifications/rnaseq-nf/data/hg38/gentrome.fa"
params.multiqc = "$baseDir/multiqc"



log.info """\
         R N A S E Q - N F   P I P E L I N E    
         ===================================
         transcriptome: ${params.transcriptome}
         reads        : ${params.reads}
         outdir       : ${params.outdir}
         """
         .stripIndent()


transcriptome_file = file(params.transcriptome)
multiqc_file = file(params.multiqc)
gentrome_file = file(params.gentrome)
decoy_file = file(params.decoy)

Channel
    .fromFilePairs( params.reads )
//.println { samp, files -> "Files with the name $samp are $files" }
    .ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    .into { read_pairs_ch; read_pairs2_ch } 
 

 

process index {
    tag "$transcriptome_file.simpleName"

    storeDir "$baseDir/db"
        //conda 'bioconda::salmon'
    //executor 'slurm'
    //memory '6 GB'
    //time '4h'
    cpus 16
    input:
    file gentrome from gentrome_file
    file decoy from decoy_file
    output:
    file 'index' into index_ch

    script:
    """
    salmon index --threads $task.cpus -t $gentrome -i index --decoys $decoy -k 25
    """
            }
 
process quant {
    tag "$pair_id"
    publishDir params.outdir, mode:'copy'
        //conda 'bioconda::salmon'

    //executor 'slurm'
    //memory '6 GB'
    //time '4h'
    cpus 8
    input:
    file index from index_ch
    set pair_id, file(reads) from read_pairs_ch
 
    output:
    file(pair_id) into quant_ch


    script:
    """
    callSalmon.sh $reads $pair_id

    """
}
  
process fastqc {
    tag "FASTQC on $sample_id"

    executor 'slurm'
    memory '6 GB'
    time '4h'
    cpus 1
    input:
    set sample_id, file(reads) from read_pairs2_ch

    output:
    file("fastqc_${sample_id}_logs") into fastqc_ch


    script:
    """
    mkdir fastqc_${sample_id}_logs
    fastqc -o fastqc_${sample_id}_logs -f fastq -q ${reads}
    """
}

process multiqc {
    publishDir params.outdir, mode:'copy'

    input:
    file('*') from quant_ch.mix(fastqc_ch).collect()
    file(config) from multiqc_file

    output:
    file('multiqc_report.html')

    script:
    """
    cp $config/* .
    ## echo "custom_logo: \$PWD/logo.png" >> multiqc_config.yaml
    multiqc . 
    """
}
 
workflow.onComplete { 
	println ( workflow.success ? "\nDone! Open the following report in your browser --> $params.outdir/multiqc_report.html\n" : "Oops .. something went wrong" )
}
