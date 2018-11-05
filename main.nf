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
 
//params.reads = "$baseDir/data/*_R{1,2}_001.fastq.gz"
//params.transcriptome = "$baseDir/data/mm10/ref-transcripts.fa"
params.transcriptome = "/athena/elementolab/scratch/asd2007/reference/mm10/Mus_musculus.GRCm38.cdna.all.fa.gz"
params.outdir = "results"
params.multiqc = "$baseDir/multiqc"
params.sindex = 'sampleIndex.csv'


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
 

    sindex = file(params.sindex)

    //Channel
    //.fromFilePairs( params.reads )
//.println { samp, files -> "Files with the name $samp are $files" }
    //.ifEmpty { error "Cannot find any reads matching: ${params.reads}" }
    //.into { read_pairs_ch; read_pairs2_ch } 
 

fastq = Channel
    .from(sindex.readLines())
    .map { line ->
           def list = line.split(',')
           def Sample = list[0]
           def path = file(list[1])
           def reads = file("$path/*_{R1,R2}_001.fastq.gz")
           //def reads = file("$path/*.{R1,R2}.fastq.gz")
           // def readsp = "$path/*{R1,R2}.trim.fastq.gz"
           //  def R1 = file(list[2])
           //    def R2 = file(list[3])
           def message = '[INFO] '
           log.info message
           [ Sample, path, reads ]
    } 

process index {
    tag "$transcriptome_file.simpleName"

    cpus 8
    executor 'slurm'
    clusterOptions '--mem-per-cpu=3G --export=ALL'
    scratch true

    input:
    file genome from transcriptome_file
    output:
    file 'index' into index_ch

    script:       
    """
    salmon index --threads $task.cpus -t $genome -i index
    """
            }
 
process quant {
    tag "$pair_id"
    publishDir params.outdir, mode:'copy'


    cpus 16
    executor 'slurm'
    //memory '30 GB'
    time '18h'
    scratch true
    //penv 'smp'
    clusterOptions '--mem-per-cpu=3G --export=ALL'
        // cpus 12
    input:
    file index from index_ch
    set pair_id, file(path), file(reads) from fastq
        //set pair_id, file(reads) from read_pairs_ch

    output:
    file(pair_id) into quant_ch


    script:
    """
    callSalmon.sh $reads $pair_id

    """
}
  
 
workflow.onComplete { 
	println ( workflow.success ? "\nDone! Open the following report in your browser --> $params.outdir/multiqc_report.html\n" : "Oops .. something went wrong" )
}
