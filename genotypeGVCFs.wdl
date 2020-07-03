version 1.0

workflow genotypeGVCFs {
  input {
    Array[File] vcfIndices
    Array[File] vcfs
    String outputFileNamePrefix = "output"
    String intervalsToParallelizeBy
  }
  parameter_meta {
    vcfIndices: "The indices for the vcf files to be used."
    vcfs: "The vcf files to be used."
    outputFileNamePrefix: "Prefix for output file."
    intervalsToParallelizeBy: "Comma separated list of intervals to split by (e.g. chr1,chr2,chr3,chr4)."
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
  output {
    File outputVcf = gatherVcfs.mergedVcf
    File outputVcfIndex = gatherVcfs.mergedVcfTbi
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
    Int timeout = 72
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
    String modules
    String outputFileNamePrefix
    Int jobMemory = 24
    Int overhead = 6
    Int cores = 1
    Int timeout = 72
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

  String outputName = "~{outputFileNamePrefix}.raw.vcf.gz"

  command <<<
    set -euo pipefail

    gatk --java-options "-Xmx~{jobMemory - overhead}G" GatherVcfs \
    -I ~{sep=" -I " vcfs} \
    -O ~{outputName} \
    ~{extraArgs}

    tabix -p vcf ~{outputName}

  >>>

  runtime {
    memory: "~{jobMemory} GB"
    cpu: "~{cores}"
    timeout: "~{timeout}"
    modules: "~{modules}"
  }

  output {
    File mergedVcf = "~{outputName}"
    File mergedVcfTbi = "~{outputName}.tbi"
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
      mergedVcf: "Merged vcf",
      mergedVcfTbi: "Merged vcf index"
    }
  }

}


