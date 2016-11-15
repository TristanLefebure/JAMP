# U_merge_PE v0.1

U_merge_PE <- function(files="latest", file1=NA, file2=NA, fastq_maxdiffs=99, fastq_maxdiffpct=99, fastq=T){

Core(module="U_merge_PE")
cat(file="../log.txt", c("\n", "Version v0.1", "\n"), append=T, sep="\n")


if (files=="latest"){
source("robots.txt")
file1 <- list.files(paste("../", last_data, "/_data", sep=""), full.names=T, pattern="_r1.txt")
file2 <- list.files(paste("../", last_data, "/_data", sep=""), full.names=T, pattern="_r2.txt")
}

merge_identical <- sub(".*_data/(.*)_r1.txt", "\\1", file1)==sub(".*_data/(.*)_r2.txt", "\\1",file2)
# merging not identical reads
if(!sum(merge_identical)==length(merge_identical)){
warning("There is a problem with the files you want to merge. Not all fastq files have a matchign pair with identical name. Please check. Package stopped.")
setwd("../")
stop()
}

if(length(grep(".*N_debris_r1.txt", file1))==1){message("N_debris are excluded and not merged.")}

file1 <- file1[-grep(".*N_debris_r1.txt", file1)] # remove debres from list
file2 <- file2[-grep(".*N_debris_r2.txt", file2)] # remove debres from list

message(paste("Starting to PE merge ", length(file1), " samples.", sep=""))
message(" ")

# new file names

new_names <- sub(".*(_data/.*)", "\\1", file1)
if(fastq){new_names <- sub("r1.txt", "PE.fastq", new_names)} else {new_names <- sub("r1.txt", "PE.fasta", new_names)}


dir.create("_stats/merge_stats")
log_names <- sub("_data", "_stats/merge_stats", new_names)
log_names <- sub("_PE.fast[aq]", "_PE_log.txt", log_names)

cmd <- paste(" -fastq_mergepairs \"", file1, "\" -reverse \"", file2,  "\" ", if(fastq){"-fastqout"} else {"-fastaout"}, " \"", new_names, "\"", " -report ", log_names, " -fastq_maxdiffs ", fastq_maxdiffs , " -fastq_maxdiffpct ", fastq_maxdiffpct , sep="")


for (i in 1:length(cmd)){
system2("usearch", cmd[i], stdout=F, stderr=F)
message(i)
}

}


