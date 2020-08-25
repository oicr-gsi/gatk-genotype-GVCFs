# genotypeGVCFs

Workflow to run GATK GenotypeGVCFs

## Overview

## Dependencies

* [GATK4](https://gatk.broadinstitute.org/hc/en-us/articles/360036194592-Getting-started-with-GATK4)
* [tabix 0.2.6](https://github.com/samtools/tabix)


## Usage

### Cromwell
```
java -jar cromwell.jar run genotypeGVCFs.wdl --inputs inputs.json
```

### Inputs

#### Required workflow parameters:
Parameter|Value|Description
---|---|---
`vcfIndices`|Array[File]|The indices for the vcf files to be used.
`vcfs`|Array[File]|The vcf files to be used.
`intervalsToParallelizeBy`|String|Comma separated list of intervals to split by (e.g. chr1,chr2,chr3,chr4).
`callGenotypeGVCFs.dbsnpFilePath`|String|The dbSNP VCF to call against.
`callGenotypeGVCFs.refFasta`|String|The file path to the reference genome.
`indelsVariantRecalibrator.modules`|String|Required environment modules.
`indelsVariantRecalibrator.mills_vcf`|String|Mills and 1000G indels vcf file.
`indelsVariantRecalibrator.mills_vcf_index`|String|Mills and 1000G indels vcf index file.
`indelsVariantRecalibrator.axiomPoly_vcf`|String|AxiomPoly vcf file.
`indelsVariantRecalibrator.axiomPoly_index`|String|AxiomPoly vcf index file
`indelsVariantRecalibrator.dbsnp_vcf`|String|dbsnp vcf.
`indelsVariantRecalibrator.dbsnp_vcf_index`|String|dbsnp vcf index file.
`snpsVariantRecalibrator.modules`|String|Required environment modules.
`snpsVariantRecalibrator.hapmap_vcf`|String|hapmap vcf file.
`snpsVariantRecalibrator.omni_vcf`|String|1000G omni vcf file.
`snpsVariantRecalibrator.one_thousand_genomes_vcf`|String|1000G snps vcf file.
`snpsVariantRecalibrator.dbsnp_vcf`|String|dbsnp vcf file.
`snpsVariantRecalibrator.hapmap_vcf_index`|String|hapmap vcf index file.
`snpsVariantRecalibrator.omni_vcf_index`|String|1000G omni vcf index file.
`snpsVariantRecalibrator.one_thousand_genomes_vcf_index`|String|1000G snps vcf index file.
`snpsVariantRecalibrator.dbsnp_vcf_index`|String|dbsnp vcf index file.
`collectVariantCallingMetrics.dbsnp_vcf`|String|The dbsnp vcf file.
`collectVariantCallingMetrics.dbsnp_vcf_index`|String|The dbsnp vcf index file.
`collectVariantCallingMetrics.ref_dict`|String|The sequence dictionary file for speed loading of the dbsnp file.
`collectVariantCallingMetrics.modules`|String|Required environment modules.


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`outputFileNamePrefix`|String|"output"|Prefix for output file.
`doHardFilter`|Boolean|false|If true, do hard filtering.
`doVQSR`|Boolean|false|If true, run VQSR.


#### Optional task parameters:
Parameter|Value|Default|Description
---|---|---|---
`splitStringToArray.lineSeparator`|String|","|line separator for intervalsToParallelizeBy. 
`splitStringToArray.jobMemory`|Int|1|Memory allocated to job (in GB).
`splitStringToArray.cores`|Int|1|The number of cores to allocate to the job.
`splitStringToArray.timeout`|Int|1|Maximum amount of time (in hours) the task can run for.
`callGenomicsDBImport.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`callGenomicsDBImport.modules`|String|"gatk/4.1.7.0"|Required environment modules.
`callGenomicsDBImport.jobMemory`|Int|24|Memory allocated to job (in GB).
`callGenomicsDBImport.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`callGenomicsDBImport.cores`|Int|1|The number of cores to allocate to the job.
`callGenomicsDBImport.timeout`|Int|48|Maximum amount of time (in hours) the task can run for.
`callGenotypeGVCFs.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`callGenotypeGVCFs.standCallConf`|Float|30.0|The minimum phred-scaled confidence threshold at which variants should be called.
`callGenotypeGVCFs.modules`|String|"gatk/4.1.7.0"|Required environment modules.
`callGenotypeGVCFs.jobMemory`|Int|24|Memory allocated to job (in GB).
`callGenotypeGVCFs.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`callGenotypeGVCFs.cores`|Int|1|The number of cores to allocate to the job.
`callGenotypeGVCFs.timeout`|Int|48|Maximum amount of time (in hours) the task can run for.
`gatherVcfs.modules`|String|"gatk/4.1.7.0 tabix/0.2.6"|Required environment modules.
`gatherVcfs.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`gatherVcfs.jobMemory`|Int|24|Memory allocated to job (in GB).
`gatherVcfs.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`gatherVcfs.cores`|Int|1|The number of cores to allocate to the job.
`gatherVcfs.timeout`|Int|24|Maximum amount of time (in hours) the task can run for.
`hardFilter.excess_het_threshold`|Float|54.69|Filtering threshold on ExcessHet.
`hardFilter.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`hardFilter.modules`|String|"gatk/4.1.7.0"|Required environment modules.
`hardFilter.jobMemory`|Int|12|Memory allocated to job (in GB).
`hardFilter.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`hardFilter.cores`|Int|1|The number of cores to allocate to the job.
`hardFilter.timeout`|Int|48|Maximum amount of time (in hours) the task can run for.
`makeSitesOnlyVcf.modules`|String|"gatk/4.1.7.0"|Required environment modules.
`makeSitesOnlyVcf.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`makeSitesOnlyVcf.jobMemory`|Int|12|Memory allocated to job (in GB).
`makeSitesOnlyVcf.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`makeSitesOnlyVcf.cores`|Int|1|The number of cores to allocate to the job.
`makeSitesOnlyVcf.timeout`|Int|48|Maximum amount of time (in hours) the task can run for.
`indelsVariantRecalibrator.recalibration_tranche_values`|Array[String]|["100.0", "99.95", "99.9", "99.5", "99.0", "97.0", "96.0", "95.0", "94.0", "93.5", "93.0", "92.0", "91.0", "90.0"]|The levels of truth sensitivity at which to slice the data. (in percent, that is 1.0 for 1 percent).
`indelsVariantRecalibrator.recalibration_annotation_values`|Array[String]|["FS", "ReadPosRankSum", "MQRankSum", "QD", "SOR", "DP"]|The names of the annotations which should used for calculations.
`indelsVariantRecalibrator.max_gaussians`|Int|4|the expected number of clusters in modeling.
`indelsVariantRecalibrator.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`indelsVariantRecalibrator.jobMemory`|Int|24|Memory allocated to job (in GB).
`indelsVariantRecalibrator.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`indelsVariantRecalibrator.cores`|Int|1|The number of cores to allocate to the job.
`indelsVariantRecalibrator.timeout`|Int|24|Maximum amount of time (in hours) the task can run for.
`snpsVariantRecalibrator.recalibration_tranche_values`|Array[String]|["100.0", "99.95", "99.9", "99.5", "99.0", "97.0", "96.0", "95.0", "94.0", "93.5", "93.0", "92.0", "91.0", "90.0"]|The levels of truth sensitivity at which to slice the data. (in percent, that is 1.0 for 1 percent).
`snpsVariantRecalibrator.recalibration_annotation_values`|Array[String]|["FS", "ReadPosRankSum", "MQRankSum", "QD", "SOR", "DP"]|The names of the annotations which should used for calculations.
`snpsVariantRecalibrator.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`snpsVariantRecalibrator.max_gaussians`|Int|6|the expected number of clusters in modeling.
`snpsVariantRecalibrator.jobMemory`|Int|24|Memory allocated to job (in GB).
`snpsVariantRecalibrator.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`snpsVariantRecalibrator.cores`|Int|1|The number of cores to allocate to the job.
`snpsVariantRecalibrator.timeout`|Int|48|Maximum amount of time (in hours) the task can run for.
`applyRecalibration.modules`|String|"gatk/4.1.7.0"|Required environment modules.
`applyRecalibration.indel_filter_level`|Float|99.7|The truth sensitivity level at which to start filtering indels.
`applyRecalibration.snp_filter_level`|Float|99.7|The truth sensitivity level at which to start filtering snps.
`applyRecalibration.extraArgsIndel`|String?|None|Additional arguments for the indel mode.
`applyRecalibration.extraArgsSNP`|String?|None|Additional arguments for the snp mode.
`applyRecalibration.jobMemory`|Int|24|Memory allocated to job (in GB).
`applyRecalibration.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`applyRecalibration.cores`|Int|1|The number of cores to allocate to the job.
`applyRecalibration.timeout`|Int|48|Maximum amount of time (in hours) the task can run for.
`collectVariantCallingMetrics.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`collectVariantCallingMetrics.jobMemory`|Int|12|Memory allocated to job (in GB).
`collectVariantCallingMetrics.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`collectVariantCallingMetrics.cores`|Int|1|The number of cores to allocate to the job.
`collectVariantCallingMetrics.timeout`|Int|24|Maximum amount of time (in hours) the task can run for.


### Outputs

Output | Type | Description
---|---|---
`output_raw_vcf`|File|Merged raw vcf
`output_raw_vcf_index`|File|Merged raw vcf index
`detail_metrics_file`|File?|The output detailed metrics report file
`summary_metrics_file`|File?|The output summary metrics report file.
`output_recalibrated_vcf`|File?|The output recalibrated VCF file in which each variant is annotated with its VQSLOD value
`output_recalibrated_vcf_index`|File?|The output recalibrated VCF index file


## Niassa + Cromwell

This WDL workflow is wrapped in a Niassa workflow (https://github.com/oicr-gsi/pipedev/tree/master/pipedev-niassa-cromwell-workflow) so that it can used with the Niassa metadata tracking system (https://github.com/oicr-gsi/niassa).

* Building
```
mvn clean install
```

* Testing
```
mvn clean verify \
-Djava_opts="-Xmx1g -XX:+UseG1GC -XX:+UseStringDeduplication" \
-DrunTestThreads=2 \
-DskipITs=false \
-DskipRunITs=false \
-DworkingDirectory=/path/to/tmp/ \
-DschedulingHost=niassa_oozie_host \
-DwebserviceUrl=http://niassa-url:8080 \
-DwebserviceUser=niassa_user \
-DwebservicePassword=niassa_user_password \
-Dcromwell-host=http://cromwell-url:8000
```

## Support

For support, please file an issue on the [Github project](https://github.com/oicr-gsi) or send an email to gsi@oicr.on.ca .

_Generated with generate-markdown-readme (https://github.com/oicr-gsi/gsi-wdl-tools/)_
