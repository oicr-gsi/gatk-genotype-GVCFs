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
`callGenotypeGVCFs.modules`|String|Required environment modules.


#### Optional workflow parameters:
Parameter|Value|Default|Description
---|---|---|---
`outputFileNamePrefix`|String|"output"|Prefix for output file.


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
`callGenomicsDBImport.timeout`|Int|72|Maximum amount of time (in hours) the task can run for.
`callGenotypeGVCFs.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`callGenotypeGVCFs.standCallConf`|Float|30.0|The minimum phred-scaled confidence threshold at which variants should be called.
`callGenotypeGVCFs.jobMemory`|Int|24|Memory allocated to job (in GB).
`callGenotypeGVCFs.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`callGenotypeGVCFs.cores`|Int|1|The number of cores to allocate to the job.
`callGenotypeGVCFs.timeout`|Int|72|Maximum amount of time (in hours) the task can run for.
`gatherVcfs.modules`|String|"gatk/4.1.7.0 tabix/0.2.6"|Required environment modules.
`gatherVcfs.extraArgs`|String?|None|Additional arguments to be passed directly to the command.
`gatherVcfs.jobMemory`|Int|24|Memory allocated to job (in GB).
`gatherVcfs.overhead`|Int|6|Java overhead memory (in GB). jobMemory - overhead == java Xmx/heap memory.
`gatherVcfs.cores`|Int|1|The number of cores to allocate to the job.
`gatherVcfs.timeout`|Int|24|Maximum amount of time (in hours) the task can run for.


### Outputs

Output | Type | Description
---|---|---
`outputVcf`|File|output vcf
`outputVcfIndex`|File|output vcf index


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
