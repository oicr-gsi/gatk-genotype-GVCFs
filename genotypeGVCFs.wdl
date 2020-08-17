version 1.0

workflow genotypeGVCFs {
  input {
    Array[File] vcfIndices
    Array[File] vcfs
    String outputFileNamePrefix = "output"
    String intervalsToParallelizeBy
    Boolean doHardFilter = false
    Boolean doVQSR = false
  }
  parameter_meta {
    vcfIndices: "The indices for the vcf files to be used."
    vcfs: "The vcf files to be used."
    outputFileNamePrefix: "Prefix for output file."
    intervalsToParallelizeBy: "Comma separated list of intervals to split by (e.g. chr1,chr2,chr3,chr4)."
    doHardFilter: "If true, do hard filtering."
    doVQSR: "If true, run VQSR."
  }

  meta {
      author: "Xuemei Luo"
      description: "Workflow to run GATK GenotypeGVCFs"
      dependencies: [
      { 
          name: "GATK4",
          url:"https://gatk.broadinstitute.org/hc/en-us/articles/360036194592-Getting-started-with-GATK4"

      },
      {
          name: "tabix/0.2.6",
          url: "https://github.com/samtools/tabix"
      
      }]
      output_meta: {
        outputVcf: "output vcf",
        outputVcfIndex: "output vcf index"
      }
  }

  call splitStringToArray {
    input:
      intervalsToParallelizeBy = intervalsToParallelizeBy
  }
  
  scatter (intervals in splitStringToArray.out) {
     call callGenomicsDBImport {
       input:
         vcfIndices = vcfIndices,
         vcfs = vcfs,
         interval = intervals[0],
         outputFileNamePrefix = outputFileNamePrefix
     }
     call callGenotypeGVCFs {
       input:
         workspace_tar = callGenomicsDBImport.output_genomicsdb,
         interval = intervals[0],
         outputFileNamePrefix = outputFileNamePrefix
     }
  }

  call gatherVcfs {
    input:
      outputFileNamePrefix = outputFileNamePrefix,
      vcfs = callGenotypeGVCFs.output_vcf
  }

  if (doHardFilter && doVQSR) {
    call hardFilter {
      input:
       outputFileNamePrefix = outputFileNamePrefix,
       inputVcf = gatherVcfs.mergedVcf,
       inputVcfIndex = gatherVcfs.mergedVcfIndex
    }
  }

  if (doVQSR) {
    call makeSitesOnlyVcf {
      input:
        outputFileNamePrefix = outputFileNamePrefix,
        inputVcf = select_first([hardFilter.variant_filtered_vcf, gatherVcfs.mergedVcf]),
        inputVcfIndex = select_first([hardFilter.variant_filtered_vcf_index, gatherVcfs.mergedVcfIndex]),
    }

    call indelsVariantRecalibrator {
      input:
      outputFileNamePrefix = outputFileNamePrefix,
      inputVcf = makeSitesOnlyVcf.sites_only_vcf,
      inputVcfIndex = makeSitesOnlyVcf.sites_only_vcf_index
    }

    call snpsVariantRecalibrator {
      input:
      outputFileNamePrefix = outputFileNamePrefix,
      inputVcf = makeSitesOnlyVcf.sites_only_vcf,
      inputVcfIndex = makeSitesOnlyVcf.sites_only_vcf_index
    }

    call applyRecalibration {
      input:
      outputFileNamePrefix = outputFileNamePrefix,
      inputVcf = select_first([hardFilter.variant_filtered_vcf, gatherVcfs.mergedVcf]),
      inputVcfIndex = select_first([hardFilter.variant_filtered_vcf_index, gatherVcfs.mergedVcfIndex]),
      indels_recalibration = indelsVariantRecalibrator.recalibration,
      indels_recalibration_index = indelsVariantRecalibrator.recalibration_index,
      indels_tranches = indelsVariantRecalibrator.tranches,
      snps_recalibration = snpsVariantRecalibrator.recalibration,
      snps_recalibration_index = snpsVariantRecalibrator.recalibration_index,
      snps_tranches = snpsVariantRecalibrator.tranches
    }

    call collectVariantCallingMetrics {
      input:
      outputFileNamePrefix = outputFileNamePrefix,
      inputVcf = applyRecalibration.recalibrated_vcf,
      inputVcfIndex = applyRecalibration.recalibrated_vcf_index
    }
  }

  output {
    File output_raw_vcf = gatherVcfs.mergedVcf
    File output_raw_vcf_index = gatherVcfs.mergedVcfIndex
    File? detail_metrics_file = collectVariantCallingMetrics.detail_metrics_file
    File? summary_metrics_file = collectVariantCallingMetrics.summary_metrics_file
    File? output_recalibrated_vcf = applyRecalibration.recalibrated_vcf
    File? output_recalibrated_vcf_index = applyRecalibration.recalibrated_vcf_index
  }

}

task splitStringToArray {
  input {
    String intervalsToParallelizeBy
    String lineSeparator = ","
    Int jobMemory = 1
    Int cores = 1
    Int timeout = 1
  }

  command <<<
    echo "~{intervalsToParallelizeBy}" | tr '~{lineSeparator}' '\n'
  >>>

  output {
    Array[Array[String]] out = read_tsv(stdout())
  }

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
  }

  parameter_meta {
    intervalsToParallelizeBy: "Interval string to split (e.g. chr1,chr2,chr3,chr4)."
    lineSeparator: "line separator for intervalsToParallelizeBy. "
    jobMemory: "Memory allocated to job (in GB)."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }
}


task callGenomicsDBImport {
  input {
    Array[File] vcfIndices
    Array[File] vcfs
    String interval
    String outputFileNamePrefix
    String? extraArgs
    String modules = "gatk/4.1.7.0"
    Int jobMemory = 24
    Int overhead = 6
    Int cores = 1
    Int timeout = 48
  }
 
  String tmpDir = "tmp/"
  String workspace_dir_name = "~{outputFileNamePrefix}_~{interval}"

  command <<<
    set -euo pipefail
    rm -rf ~{workspace_dir_name}
    mkdir -p ~{tmpDir}

    gatk --java-options -Xmx~{jobMemory - overhead}G \
      GenomicsDBImport \
      --genomicsdb-workspace-path ~{workspace_dir_name} \
      -V ~{sep=" -V " vcfs} \
      -L ~{interval} \
      --tmp-dir=~{tmpDir} \
      ~{extraArgs}

      tar -cf ~{workspace_dir_name}.tar ~{workspace_dir_name}
  >>>

  output {
    File output_genomicsdb = "~{workspace_dir_name}.tar"
  }

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  parameter_meta {
    modules: "Required environment modules."
    vcfIndices: "The indices for the vcf files to be used."
    vcfs: "The vcf files to be used."
    interval: "The interval (chromosome) for this shard to work on."
    outputFileNamePrefix: "Prefix for output file."
    extraArgs: "Additional arguments to be passed directly to the command."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      output_genomicsdb: "GenomicsDB workspace tar file"
    }
  }
  
}

task callGenotypeGVCFs {
  input {
    File workspace_tar
    String dbsnpFilePath
    String? extraArgs
    String interval
    String refFasta
    Float standCallConf = 30.0
    String modules = "gatk/4.1.7.0"
    String outputFileNamePrefix
    Int jobMemory = 24
    Int overhead = 6
    Int cores = 1
    Int timeout = 48
  }
 
  String outputName = "~{outputFileNamePrefix}.~{interval}.raw.vcf.gz"

  command <<<
    set -euo pipefail

    tar -xf ~{workspace_tar}
    WORKSPACE=$(basename ~{workspace_tar} .tar)

    gatk --java-options -Xmx~{jobMemory - overhead}G \
      GenotypeGVCFs \
      -R ~{refFasta} \
      -V gendb://$WORKSPACE \
      -L ~{interval} \
      -D ~{dbsnpFilePath} \
      -stand-call-conf ~{standCallConf}  \
      -O "~{outputName}" \
      ~{extraArgs}
  >>>

  output {
    File output_vcf = "~{outputName}"
  }

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  parameter_meta {
    workspace_tar: "A GenomicsDB workspace tar file created by GenomicsDBImport"
    dbsnpFilePath: "The dbSNP VCF to call against."
    extraArgs: "Additional arguments to be passed directly to the command."
    interval: "The interval (chromosome) for this shard to work on."
    refFasta: "The file path to the reference genome."
    standCallConf: "The minimum phred-scaled confidence threshold at which variants should be called."
    modules: "Required environment modules."
    outputFileNamePrefix: "Prefix for output file."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }
  meta {
      output_meta: {
          output_vcf: "Output vcf file for this interval"
      }
  }
}

task gatherVcfs {
  input {
    String modules = "gatk/4.1.7.0 tabix/0.2.6"
    Array[File] vcfs
    String outputFileNamePrefix
    String? extraArgs
    Int jobMemory = 24
    Int overhead = 6
    Int cores = 1
    Int timeout = 24
  }

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" GatherVcfs \
    -I ~{sep=" -I " vcfs} \
    -O ~{outputFileNamePrefix}.raw.vcf.gz \
    ~{extraArgs}

    tabix -p vcf ~{outputFileNamePrefix}.raw.vcf.gz

  >>>

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File mergedVcf = "~{outputFileNamePrefix}.raw.vcf.gz"
    File mergedVcfIndex = "~{outputFileNamePrefix}.raw.vcf.gz.tbi"
  }

  parameter_meta {
    modules: "Required environment modules."
    vcfs: "Vcfs from scatter to merge together."
    outputFileNamePrefix: "Prefix for output file."
    extraArgs: "Additional arguments to be passed directly to the command."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      mergedVcf: "Merged raw vcf",
      mergedVcfIndex: "Merged raw vcf index"
    }
  }

}

task hardFilter {

  input {
    File inputVcf
    File inputVcfIndex
    Float excess_het_threshold = 54.69
    String outputFileNamePrefix
    String? extraArgs
    String modules = "gatk/4.1.7.0"
    Int jobMemory = 12
    Int overhead = 6
    Int cores = 1
    Int timeout = 48

  }

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" \
      VariantFiltration \
      --filter-expression "ExcessHet > ~{excess_het_threshold}" \
      --filter-name ExcessHet ~{extraArgs} \
      -O ~{outputFileNamePrefix}.excesshet.vcf.gz \
      -V ~{inputVcf}
  >>>

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File variant_filtered_vcf = "~{outputFileNamePrefix}.excesshet.vcf.gz"
    File variant_filtered_vcf_index = "~{outputFileNamePrefix}.excesshet.vcf.gz.tbi"
  }

  parameter_meta {
    modules: "Required environment modules."
    inputVcf: "input vcf."
    inputVcfIndex: "input vcf index."
    excess_het_threshold: "Filtering threshold on ExcessHet."
    outputFileNamePrefix: "Prefix for output file."
    extraArgs: "Additional arguments to be passed directly to the command."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      variant_filtered_vcf: "ExcessHet hard filtered vcf.",
      variant_filtered_vcf_index: "ExcessHet hard filtered vcf index."
    }
  }
}

task makeSitesOnlyVcf {

  input {
    File inputVcf
    File inputVcfIndex
    String outputFileNamePrefix
    String modules = "gatk/4.1.7.0"
    String? extraArgs
    Int jobMemory = 12
    Int overhead = 6
    Int cores = 1
    Int timeout = 48

  }

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" \
      MakeSitesOnlyVcf \
      -I ~{inputVcf} ~{extraArgs} \
      -O ~{outputFileNamePrefix}.sitesonly.vcf.gz 
  >>>

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File sites_only_vcf = "~{outputFileNamePrefix}.sitesonly.vcf.gz"
    File sites_only_vcf_index = "~{outputFileNamePrefix}.sitesonly.vcf.gz.tbi"
  }

  parameter_meta {
    modules: "Required environment modules."
    inputVcf: "input vcf"
    inputVcfIndex: "input vcf index"
    outputFileNamePrefix: "Prefix for output file."
    extraArgs: "Additional arguments to be passed directly to the command."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      sites_only_vcf: "Sites only vcf",
      sites_only_vcf_index: "Sites only vcf index"
    }
  }
}


task indelsVariantRecalibrator {

  input {
    File inputVcf
    File inputVcfIndex
    String outputFileNamePrefix
    String modules
    Array[String] recalibration_tranche_values = ["100.0", "99.95", "99.9", "99.5", "99.0", "97.0", "96.0", "95.0", "94.0", "93.5", "93.0", "92.0", "91.0", "90.0"]
    Array[String] recalibration_annotation_values = ["FS", "ReadPosRankSum", "MQRankSum", "QD", "SOR", "DP"]
    String mills_vcf
    String mills_vcf_index   
    String axiomPoly_vcf
    String axiomPoly_index
    String dbsnp_vcf
    String dbsnp_vcf_index
    Int max_gaussians = 4
    String? extraArgs
    Int jobMemory = 24
    Int overhead = 6
    Int cores = 1
    Int timeout = 24

  }

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" \
      VariantRecalibrator \
      -V ~{inputVcf} \
      --trust-all-polymorphic \
      -tranche ~{sep=' -tranche ' recalibration_tranche_values} \
      -an ~{sep=' -an ' recalibration_annotation_values} \
      -mode INDEL \
      --max-gaussians ~{max_gaussians} \
      -resource:mills,known=false,training=true,truth=true,prior=12 ~{mills_vcf} \
      -resource:axiomPoly,known=false,training=true,truth=false,prior=10 ~{axiomPoly_vcf} \
      -resource:dbsnp,known=true,training=false,truth=false,prior=2 ~{dbsnp_vcf} \
      ~{extraArgs} -O ~{outputFileNamePrefix}.indels.recal \
      --tranches-file ~{outputFileNamePrefix}.indels.tranches
  >>>

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File recalibration = "~{outputFileNamePrefix}.indels.recal"
    File recalibration_index = "~{outputFileNamePrefix}.indels.recal.idx"
    File tranches = "~{outputFileNamePrefix}.indels.tranches"
  }

  parameter_meta {
    modules: "Required environment modules."
    inputVcf: "Input vcf"
    inputVcfIndex: "Input vcf index"
    outputFileNamePrefix: "Prefix for output file."
    recalibration_tranche_values: "The levels of truth sensitivity at which to slice the data. (in percent, that is 1.0 for 1 percent)."
    recalibration_annotation_values: "The names of the annotations which should used for calculations."
    mills_vcf: "Mills and 1000G indels vcf file."
    mills_vcf_index: "Mills and 1000G indels vcf index file."   
    axiomPoly_vcf: "AxiomPoly vcf file."
    axiomPoly_index: "AxiomPoly vcf index file"
    dbsnp_vcf: "dbsnp vcf."
    dbsnp_vcf_index: "dbsnp vcf index file."
    max_gaussians: "the expected number of clusters in modeling."
    extraArgs: "Additional arguments to be passed directly to the command."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      recalibration: "The output indel recalibration file used by ApplyRecalibration",
      recalibration_index: "The output indel recalibration index file.",
      tranches: "The output indel tranches file used by ApplyRecalibration."
    }
  }
}

task snpsVariantRecalibrator {

  input {
    File inputVcf
    File inputVcfIndex
    String outputFileNamePrefix
    String modules
    Array[String] recalibration_tranche_values = ["100.0", "99.95", "99.9", "99.5", "99.0", "97.0", "96.0", "95.0", "94.0", "93.5", "93.0", "92.0", "91.0", "90.0"]
    Array[String] recalibration_annotation_values = ["FS", "ReadPosRankSum", "MQRankSum", "QD", "SOR", "DP"]
    String hapmap_vcf
    String omni_vcf
    String one_thousand_genomes_vcf
    String dbsnp_vcf
    String hapmap_vcf_index
    String omni_vcf_index
    String one_thousand_genomes_vcf_index
    String dbsnp_vcf_index
    String? extraArgs
    Int max_gaussians = 6
    Int jobMemory = 24
    Int overhead = 6
    Int cores = 1
    Int timeout = 48
  }

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" \
      VariantRecalibrator \
      -V ~{inputVcf} \
      --trust-all-polymorphic \
      -tranche ~{sep=' -tranche ' recalibration_tranche_values} \
      -an ~{sep=' -an ' recalibration_annotation_values} \
      -mode SNP \
      --max-gaussians ~{max_gaussians} \
      -resource:hapmap,known=false,training=true,truth=true,prior=15 ~{hapmap_vcf} \
      -resource:omni,known=false,training=true,truth=true,prior=12 ~{omni_vcf} \
      -resource:1000G,known=false,training=true,truth=false,prior=10 ~{one_thousand_genomes_vcf} \
      -resource:dbsnp,known=true,training=false,truth=false,prior=7 ~{dbsnp_vcf} \
      ~{extraArgs} -O ~{outputFileNamePrefix}.snps.recal \
      --tranches-file ~{outputFileNamePrefix}.snps.tranches
  >>>

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File recalibration = "~{outputFileNamePrefix}.snps.recal"
    File recalibration_index = "~{outputFileNamePrefix}.snps.recal.idx"
    File tranches = "~{outputFileNamePrefix}.snps.tranches"
  }
  parameter_meta {
    modules: "Required environment modules."
    inputVcf: "Input vcf"
    inputVcfIndex: "Input vcf index"
    outputFileNamePrefix: "Prefix for output file."
    recalibration_tranche_values: "The levels of truth sensitivity at which to slice the data. (in percent, that is 1.0 for 1 percent)."
    recalibration_annotation_values: "The names of the annotations which should used for calculations."
    hapmap_vcf: "hapmap vcf file."
    omni_vcf: "1000G omni vcf file."
    one_thousand_genomes_vcf: "1000G snps vcf file."
    dbsnp_vcf: "dbsnp vcf file."
    hapmap_vcf_index: "hapmap vcf index file." 
    omni_vcf_index: "1000G omni vcf index file."
    one_thousand_genomes_vcf_index: "1000G snps vcf index file."
    dbsnp_vcf_index: "dbsnp vcf index file."
    max_gaussians: "the expected number of clusters in modeling."
    extraArgs: "Additional arguments to be passed directly to the command."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      recalibration: "The output snps recalibration file used by ApplyRecalibration",
      recalibration_index: "The output snps recalibration index",
      tranches: "The output snps tranches file used by ApplyRecalibration."
    }
  }

}

task applyRecalibration {

  input {
    String outputFileNamePrefix
    File inputVcf
    File inputVcfIndex
    String modules = "gatk/4.1.7.0"
    String indels_recalibration
    String indels_recalibration_index
    String indels_tranches
    String snps_recalibration
    String snps_recalibration_index
    String snps_tranches
    Float indel_filter_level = 99.7
    Float snp_filter_level = 99.7
    String? extraArgsIndel
    String? extraArgsSNP
    Int jobMemory = 24
    Int overhead = 6
    Int cores = 1
    Int timeout = 48

  }

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" \
      ApplyVQSR \
      -V ~{inputVcf} \
      --recal-file ~{indels_recalibration} \
      --tranches-file ~{indels_tranches} \
      --truth-sensitivity-filter-level ~{indel_filter_level} \
      --create-output-variant-index true \
      -mode INDEL ~{extraArgsIndel} \
      -O ~{outputFileNamePrefix}.indels.recalibrated.vcf.gz \

    gatk --java-options "-Xmx~{jobMemory - overhead}G" \
      ApplyVQSR \
      -V ~{outputFileNamePrefix}.indels.recalibrated.vcf.gz \
      --recal-file ~{snps_recalibration} \
      --tranches-file ~{snps_tranches} \
      --truth-sensitivity-filter-level ~{snp_filter_level} \
      --create-output-variant-index true \
      -mode SNP ~{extraArgsSNP} \
      -O ~{outputFileNamePrefix}.indels.snps.recalibrated.vcf.gz \
  >>>


  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File recalibrated_vcf = "~{outputFileNamePrefix}.indels.snps.recalibrated.vcf.gz"
    File recalibrated_vcf_index = "~{outputFileNamePrefix}.indels.snps.recalibrated.vcf.gz.tbi"
  }
  
  parameter_meta {
    modules: "Required environment modules."
    inputVcf: "Input vcf"
    inputVcfIndex: "Input vcf index"
    outputFileNamePrefix: "Prefix for output file."
    indels_recalibration: "The input indel recalibration."
    indels_recalibration_index: "The input indel recalibration index file."
    indels_tranches: "The input indel tranches file describing where to cut the data."
    snps_recalibration: "The input snp recalibration."
    snps_recalibration_index: "The input snp recalibration index file."
    snps_tranches: "The input snp tranches file describing where to cut the data."
    indel_filter_level: "The truth sensitivity level at which to start filtering indels."
    snp_filter_level: "The truth sensitivity level at which to start filtering snps."
    extraArgsIndel: "Additional arguments for the indel mode."
    extraArgsSNP: "Additional arguments for the snp mode."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      recalibrated_vcf: "The output recalibrated VCF file in which each variant is annotated with its VQSLOD value",
      recalibrated_vcf_index: "The output recalibrated VCF index file"
    }
  }
}


task collectVariantCallingMetrics {

  input {
    File inputVcf
    File inputVcfIndex
    String outputFileNamePrefix
    String dbsnp_vcf
    String dbsnp_vcf_index
    String ref_dict
    String? extraArgs
    String modules
    Int jobMemory = 12
    Int overhead = 6
    Int cores = 1
    Int timeout = 24
  }

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" \
      CollectVariantCallingMetrics \
      --INPUT ~{inputVcf} \
      --DBSNP ~{dbsnp_vcf} \
      --SEQUENCE_DICTIONARY ~{ref_dict} ~{extraArgs} \
      --OUTPUT ~{outputFileNamePrefix} 

  >>>

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File detail_metrics_file = "~{outputFileNamePrefix}.variant_calling_detail_metrics"
    File summary_metrics_file = "~{outputFileNamePrefix}.variant_calling_summary_metrics"
  }

  parameter_meta {
    modules: "Required environment modules."
    inputVcf: "Input vcf"
    inputVcfIndex: "Input vcf index"
    outputFileNamePrefix: "Prefix for output file."
    dbsnp_vcf: "The dbsnp vcf file."
    dbsnp_vcf_index: "The dbsnp vcf index file."
    ref_dict: "The sequence dictionary file for speed loading of the dbsnp file."
    extraArgs: "Additional arguments to be passed directly to the command."
    jobMemory:  "Memory allocated to job (in GB)."
    overhead: "Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory."
    cores: "The number of cores to allocate to the job."
    timeout: "Maximum amount of time (in hours) the task can run for."
  }

  meta {
    output_meta: {
      recalibrated_vcf: "The output recalibrated VCF file in which each variant is annotated with its VQSLOD value",
      recalibrated_vcf_index: "The output recalibrated VCF index file"
    }
  }

}



