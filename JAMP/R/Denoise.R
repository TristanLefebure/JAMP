# Haplotyping v0.1

Denoise <- function(files="latest",  strategy="unoise", unoise_alpha=5, minsize=10, minrelsize=0.001){



Core(module="Denoising")
cat(file="../log.txt", c("Version v0.1", "\n"), append=T, sep="\n")
message(" ")

if (files[1]=="latest"){
source("robots.txt")
files <- list.files(paste("../", last_data, "/_data", sep=""), full.names=T)
}



# count sequences in each file
counts <- Count_sequences(files, fastq=F)
size <- round(counts* minrelsize/100) # get nim abundance
size[size<minsize] <- minsize # min size!



# Dereplicate files using Usearch
dir.create("_data/1_derep")


new_names <- sub(".*(_data/.*)", "\\1", files)
new_names <- sub("_PE.*", "_PE_derep", new_names)
new_names <- paste(new_names, "_size_", size, ".txt", sep="")
new_names <- sub("_data", "_data/1_derep", new_names)

cmd <- paste("-fastx_uniques \"", files, "\" -fastaout \"", new_names, "\" -sizeout", " -minuniquesize ", size,  sep="")

temp <- paste(length(files), " files are dereplicated and sequences in each sample below ", minrelsize, "% (or minuniqesize of ", minsize,")  are beeing discarded:", sep="")
cat(file="../log.txt", temp , append=T, sep="\n")
message(temp)


temp <- new_names
for (i in 1:length(cmd)){
A <- system2("usearch", cmd[i], stdout=T, stderr=T)
meep <- sub(".*_data/(.*)", "\\1", temp[i])
cat(file="_stats/1_derep_logs.txt", paste("usearch ", cmd[i], sep="") , append=T, sep="\n")
cat(file="_stats/1_derep_logs.txt", meep, A, "\n", append=T, sep="\n")


log_count <- Count_sequences(new_names[i], count_size=T)
log <- paste(sub(".*_data/1_derep/(.*)", "\\1", temp[i]), ": ", log_count, " of ", counts[i], " keept (", round((log_count/counts[i])*100, digits=4), "%, min size: ", size[i],")", sep="")
cat(file="../log.txt", log , append=T, sep="\n")
message(log)
}


# merge all files into one!


cat(file="_stats/1_derep_logs.txt", paste("\nCombining all files in a single file (samples_pooled.txt):\n", paste("cmd", cmd, collapse="", sep=""), collapse="", sep="") , append=T, sep="\n")
cat(file="../log.txt", "\nCombining all files in a single file (samples_pooled.txt)\n", append=T, sep="\n")

# dereplicating pooled file
message("\nCombining all files in a single file (samples_pooled.txt)")
cmd <- paste(paste(new_names, collapse=" "), "> _data/1_derep/samples_pooled.txt")
system2("cat", cmd)

# dereplicating files
info <- "Dereplicating pooled sequences! (no min size)"
message(info)
cat(file="../log.txt", info, append=T, sep="\n")

cmd <- "-fastx_uniques \"_data/1_derep/samples_pooled.txt\" -fastaout \"_data/1_derep/samples_pooled_derep.txt\" -sizein -sizeout"
A <- system2("usearch", cmd, stdout=T, stderr=T)

cat(file="_stats/1_derep_logs.txt", paste("usearch", cmd, sep=""), append=T, sep="\n")
cat(file="_stats/1_derep_logs.txt", A, append=T, sep="\n")

# renaming all sequences!
info <- "Renaming pooled sequences, and applying same names to the dereplicated files.\n"
message(info)
cat(file="../log.txt", info, append=T, sep="\n")


haplo <- read.fasta("_data/1_derep/samples_pooled_derep.txt", forceDNAtolower=F, as.string=T)

temp <- sub(".*(;size=.*;)", "\\1", names(haplo))
temp2 <- paste("haplo_", 1:length(haplo), temp, sep="")

write.fasta(haplo, temp2, "_data/1_derep/samples_pooled_derep_renamed.txt")


# rename single files!
dir.create("_data/2_renamed")
renamed <- sub(".txt", "_renamed.txt", new_names)
renamed <- sub("/1_derep/", "/2_renamed/", renamed)


for (i in 1:length(new_names)){
sample <- read.fasta(new_names[i], as.string=T, forceDNAtolower=F)
matched <- match(sample, haplo)

new_sample <- haplo[matched] # DNA sequences
new_haplo_seque_names <- paste("haplo_", matched, sub(".*(;size=.*;)", "\\1", names(sample)), sep="") # sizes

write.fasta(new_sample, new_haplo_seque_names, renamed[i])
}

# UNOISE3
# Apply denoising on the POOLED dereplicated renamed file!

info <- paste("\nDenoising the file 1_derep/samples_pooled_derep_renamed.txt (containing", length(renamed), "samples).")
message(info)
cat(file="../log.txt", info, append=T, sep="\n")

cmd <- paste("-unoise3 \"_data/1_derep/samples_pooled_derep_renamed.txt\" -zotus \"_data/1_derep/samples_pooled_+_denoised.txt\" -unoise_alpha ", unoise_alpha,  sep="")

A <- system2("usearch", cmd, stdout=T, stderr=T)
cat(file="_stats/2_unoise.txt", c(info, "", paste("usearch", cmd), "", A), append=T, sep="\n")

info <- paste("Denoising compelte! ", Count_sequences("_data/1_derep/samples_pooled_derep_renamed.txt", fastq=F), " sequences were denoised using ", strategy, ".", "\nA total of ", sub(".*100.0% (.*) good, .* chimeras\r", "\\1", A[length(A)-1]), " haplotypes remained after denoising!\n", sep="")
message(info)
cat(file="../log.txt", info, append=T, sep="\n")



#Zotus, get old names back (original haplotypes)!

Zotus <- read.fasta("_data/1_derep/samples_pooled_+_denoised.txt", as.string=T, forceDNAtolower=F)
renamed_sequ <- read.fasta("_data/1_derep/samples_pooled_derep_renamed.txt", as.string=T, forceDNAtolower=F)

matched <- match(Zotus, renamed_sequ)
new_sample <- renamed_sequ[matched] # DNA sequences

write.fasta(new_sample, names(new_sample), "_data/1_derep/samples_pooled_+_denoised_renamed.txt")


names(new_sample) <- sub(";size(.*);", "", names(new_sample))
haplotypes <- new_sample

dir.create("_data/3_unoise")

denoised_sequences <- sub("2_renamed", "3_unoise", renamed)
denoised_sequences <- sub("PE_derep_size_", "", denoised_sequences)
denoised_sequences <- sub("_renamed.txt", "_denoised.txt", denoised_sequences)


# check dereplicated files agains the list of haplotypes (unoise3 all files)
for (i in 1:length(denoised_sequences)){

sample <- read.fasta(renamed[i], as.string=T, forceDNAtolower=F)
sample_keep <- sample[sample%in%haplotypes]

write.fasta(sample_keep, names(sample_keep), denoised_sequences[i])


info <- paste(sub("_data/3_unoise/(.*)_denoised.txt", "\\1", denoised_sequences[i]), ": ", length(sample_keep), " of ", length(sample), " sequences remained after denoising (", round(length(sample_keep)/length(sample)*100, 2), "%)", sep="")
message(info)
cat(file="../log.txt", info, append=T, sep="\n")

}


# Cluster into OTUs (for OTU table information)

cmd <- paste(" -cluster_otus _data/1_derep/samples_pooled_+_denoised_renamed.txt -otus _data/1_derep/samples_pooled_+_denoised_renamed_OTUsequ.txt -uparseout _data/1_derep/samples_pooled_+_denoised_renamed_OTUtable.txt -relabel OTU_ -strand plus", sep="")

A <- system2("usearch", cmd, stdout=T, stderr=T) # cluster OTUs!

cat(file="_stats/2_unoise.txt", c("Clustering haplotypes into OTUs for OTU table!", "", paste("usearch", cmd), "", A), append=T, sep="\n")

chimeras <- as.numeric(sub(".*100.0% .* OTUs, (.*) chimeras\r", "\\1", A[grep("chimeras\r", A)]))
OTUs <- as.numeric(sub(".*100.0% (.*) OTUs, .* chimeras\r", "\\1", A[grep("chimeras\r", A)]))
if(is.na(chimeras)){chimeras<-0}

info <- paste("Clustered ", length(haplotypes), " haplotype sequences (cluster_otus, 3% simmilarity) into ", OTUs, " OTUs (+", chimeras, " chimeras).\nOTUs and (potentially) chimeric sequences will be included in the Haplotype table!\n", sep="" )
message(info)
cat(file="../log.txt", info, append=T, sep="\n")


# generate one united haplotype table!

OTUs <- read.csv("_data/1_derep/samples_pooled_+_denoised_renamed_OTUtable.txt", stringsAsFactors=F, sep="\t", header=F)

k <- 1
OTU_list <- NULL
for (i in 1:nrow(OTUs)){

if(OTUs$V2[i]=="OTU"){OTU_list[i] <- paste("OTU_", k, sep="")
k <- k+1} else
if(OTUs$V2[i]=="match"){OTU_list[i] <- sub(".*;top=(OTU_.*)\\(.*", "\\1", OTUs$V3[i])} else {OTU_list[i] <- OTUs$V2[i]}

}


data <- data.frame("haplotype"=names(haplotypes), "OTU"=OTU_list, stringsAsFactors=F)

for (i in 1:length(denoised_sequences)){
sample <- names(read.fasta(denoised_sequences[i]))
matched <- match(sub(";size=.*;", "", sample), data$haplotype)
abundance <- rep(0, nrow(data))
abundance[matched] <- as.numeric(sub(".*;size=(.*);", "\\1", sample))

data <- cbind(data, abundance)
names(data)[i+2] <- sub("_data/3_unoise/(.*)_denoised.txt", "\\1", denoised_sequences[i])
}

data <- cbind(data, "sequences"=unlist(haplotypes), stringsAsFactors=F)
# sort by OTUs
data <- data[order(as.numeric(sub("OTU_", "", data$OTU))),]
data <- cbind("sort"=1:nrow(data), data)

data <- rbind(data, c(nrow(data)+1, NA, "rm_bydenoising",  counts, NA))

dir.create("_data/4_denoised")

write.csv(file="_data/4_denoised/Raw_haplotable.csv", data, row.names=F)

write.fasta(as.list(data$sequences[-nrow(data)]), paste(data$OTU[-nrow(data)], data$haplotype[-nrow(data)], sep="__"), "_data/4_denoised/Raw_haplo_sequ_byOTU.txt")




head(data)


temp <- "\nModule completed!"
message(temp)
cat(file="../log.txt", paste(Sys.time(), temp, "", sep="\n"), append=T, sep="\n")

setwd("../")


}