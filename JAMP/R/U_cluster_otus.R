# U_cluster_otus v0.1

U_cluster_otus <- function(files="latest", minuniquesize=2, strand="plus", filter=0.01, filterN=1, unoise_min=NA){

Core(module="U_cluster_otus")
cat(file="../log.txt", c("Version v0.1", "\n"), append=T, sep="\n")
message(" ")

if (files[1]=="latest"){
source("robots.txt")
files <- list.files(paste("../", last_data, "/_data", sep=""), full.names=T)
}

# Dereplicate files using USEARCH
dir.create("_data/1_derep_inc_singletons")

new_names <- sub(".*(_data/.*)", "\\1", files)
new_names <- sub("_PE.*", "_PE_derep.fasta", new_names)
new_names <- sub("_data", "_data/1_derep_inc_singletons", new_names)

cmd <- paste("-fastx_uniques \"", files, "\" -fastaout \"", new_names, "\" -sizeout",  sep="")

temp <- paste(length(files), " files are dereplicated (incl. singletons!):", sep="")
cat(file="../log.txt", temp , append=T, sep="\n")
message(temp)


temp <- new_names
for (i in 1:length(cmd)){
A <- system2("usearch", cmd[i], stdout=T, stderr=T)
meep <- sub(".*_data/(.*)", "\\1", temp[i])
cat(file="../log.txt", meep, append=T, sep="\n")
cat(file="_stats/1_derep_logs.txt", meep, A, "\n", append=T, sep="\n")
message(meep)
}

# unoise filtering of individual samples
if (!is.na(unoise_min)){
dir.create("_data/1_derep_unoise2")

# change names
denoised_names <- new_names
denoised_names <- sub("1_derep_inc_singletons", "1_derep_unoise2", denoised_names)
denoised_names <- sub(".fasta", "_unoise2.fasta", denoised_names)

cmd <- paste("-unoise2 ", new_names, " -fastaout ", denoised_names, " -minampsize ", unoise_min, sep="")

temp <- paste("\nDenoising ", length(cmd), " files using unoise2 wiht a minimum cluster size of ", unoise_min, ":", sep="")
message(temp)
cat(file="../log.txt", "\n", temp, append=T, sep="")


for(i in 1:length(cmd)){
A <- system2("usearch", cmd[i], stdout=T, stderr=T)

A <- c(paste("usearch", cmd[i], sep=" "), A, "\n\n\n")
cat(A, file="_stats/1_unoise2_logs.txt", sep="\n", append=T)

temp <- paste(sub("_data/1_derep_unoise2/(.*)_PE_derep_unoise2.fasta", "\\1", denoised_names[i]), ": ", sub(".*100.0% (.*) good.*", "\\1 Amplicons keept", A[grep("100.0% .* good", A)]), sep="")
message(temp)
cat(file="../log.txt", "\n", temp, append=T, sep="")

}

new_names <- denoised_names # use denoised data for OTU clustering

} # end unoise


# 2 make OTUs!
# merge all files into one

dir.create("_data/2_OTU_clustering")

cmd <- paste(paste(new_names, collapse=" "), "> _data/2_OTU_clustering/A_all_files_united.fasta", collapse=" ")
A <- system2("cat", cmd, stdout=T, stderr=T)

#check <- readLines("_data/2_OTU_clustering/A_all_files_united.fasta")
#count <- as.numeric(sub(".*size=(.*);", "\\1", check))
#sum(count, na.rm=T)

# write logs

temp <- paste(length(files), " dereplicated files where merged (inc singleotns) into file:\n\"_data/2_OTU_clustering/A_all_files_united.fasta\"", sep="")
message("\n", temp)
cat(file="../log.txt", "\n", temp, append=T, sep="\n")


cat(file="_stats/2_OTU_clustering_log.txt", temp, "", paste("cat", cmd), append=T, sep="\n")

# dereplicate "A_all_files_united.fasta" using Vsearch!
cmd <- paste("-derep_fulllength _data/2_OTU_clustering/A_all_files_united.fasta -output _data/2_OTU_clustering/B_all_derep_min", minuniquesize, ".fasta -sizein -sizeout -minuniquesize ", minuniquesize, sep="")

filename_all_unique <- paste("B_all_derep_min", minuniquesize, ".fasta", sep="")

A <- system2("vsearch", cmd, stdout=T, stderr=T)

temp <- paste("Total number of sequences (not dereplicated): ", sub(".*nt in (.*) seqs.*", "\\1", A[grep("seqs, min", A)]), "\n", sep="")
message(temp)
cat(file="../log.txt", temp, append=T, sep="\n")

temp <- paste("United sequences are dereplicated with minuniquesize = ", minuniquesize , " into a total of ", sub("(.*) unique sequences.*", "\\1", A[grep(" unique sequences", A)]), " unique sequences.", "\n", "File prepared for OTU clustering: \"", filename_all_unique, "\"", sep="")
message(temp)
cat(file="../log.txt", temp, append=T, sep="\n")

# derep log
cat(file="_stats/2_OTU_clustering_log.txt", "\n", A, "", paste("cat", cmd), append=T, sep="\n")

# Actual clustering of dereplicated file 
OTU_file <- sub(".fasta", "_OTUs.fasta", filename_all_unique)
OTU_file <- sub("B_", "C_", filename_all_unique)

cmd <- paste(" -cluster_otus _data/2_OTU_clustering/", filename_all_unique, " -otus _data/2_OTU_clustering/", OTU_file, " -uparseout _data/2_OTU_clustering/", sub(".fasta", "_OTUtab.txt", OTU_file), " -relabel OTU_ -strand ", strand, sep="")

A <- system2("usearch", cmd, stdout=T, stderr=T) # cluster OTUs!

chimeras <- sub(".*OTUs, (.*) chimeras\r", "\\1", A[grep("chimeras\r", A)])
OTUs <- sub(".*100.0% (.*) OTUs, .* chimeras\r", "\\1", A[grep("chimeras\r", A)])

temp <- paste("\n", "Clustering reads from \"", filename_all_unique, "\nminuniquesize = ", minuniquesize, "\nstrand = ", strand, "\nChimeras discarded: ", chimeras, "\nOTUs written: ", OTUs, " -> file \"", OTU_file, "\"\n", sep="")
message(temp)
cat(file="../log.txt", temp, append=T, sep="\n")


# compare against refernce sequences (including singletons)

dir.create("_data/3_Compare_OTU_derep/")
dir.create("_stats/3_Compare_OTU_derep/")

blast_names <- sub("1_derep_inc_singletons", "3_Compare_OTU_derep", new_names)
blast_names <- sub("1_derep_unoise2", "3_Compare_OTU_derep", blast_names)
blast_names <- sub("_PE_derep.*.fasta", ".txt", blast_names)
log_names <- sub("_data", "_stats", blast_names)


cmd <- paste("-usearch_global ", new_names, " -db ", "\"_data/2_OTU_clustering/", OTU_file, "\"", " -strand plus -id 0.97 -blast6out \"", blast_names, "\" -maxhits 1", sep="")


temp <- paste("Comparing ", length(cmd)," files with dereplicated reads (incl. singletons) against OTUs \"", OTU_file, "\" using \"usearch_global\".\n", sep="")
message(temp)
cat(file="../log.txt", temp, append=T, sep="\n")

exp <- NULL
temp <- new_names
for (i in 1:length(cmd)){
A <- system2("usearch", cmd[i], stdout=T, stderr=T)
cat(file= log_names[i], paste("usearch ", cmd[i], sep=""), "\n", A, append=F, sep="\n")

meep <- sub("_data/.*/(.*)", "\\1", temp[i])
pass <- sub(".*, (.*)% matched\r", "\\1", A[grep("matched\r", A)])
exp <- rbind(exp, c(meep, pass))
glumanda <- paste(meep," - ", pass, "% reads matched", sep="")
cat(file="../log.txt", glumanda, append=T, sep="\n")
message(glumanda)
}


# Write raw data OTU table! incl OTU sequences
files <- blast_names

tab <- c("NULL")
tab <- as.data.frame(tab, stringsAsFactors=F)
names(tab) <- "ID"

for (i in 1:length(files)){
data <- read.csv(files[i], sep="\t", header=F, stringsAsFactors=F)

names(data) <- c("query", "otu", "ident", "length", "mism", "gap", "qstart", "qend", "target_s", "target_e", "e.value", "bitscore")

data <- data[,c(-11,-12)]

data <- cbind(data, "abund"=as.numeric(sub(".*size=(.*);", "\\1", data$query)), "otu_no"=sub("(.*);size.*", "\\1", data$otu), stringsAsFactors=F)

head(data)

temp <- aggregate(data$abund, by=list(data$otu_no), FUN="sum")
tab <- merge(tab , temp, by.x="ID", by.y="Group.1", all=T, sort=T)
names(tab)[i+1] <- sub(".*derep/(.*).txt", "\\1", files[i])
}

head(tab)

tab <- tab[-1,] # remove NULL entry in the beginning
tab[is.na(tab)] <- 0

mrew <- tab$ID
mrew <- as.numeric(gsub("OTU_(.*)", "\\1", mrew))
tab <- tab[order(as.numeric(mrew)),]

# add sequences!

sequ <- read.fasta(paste("_data/2_OTU_clustering/", OTU_file, sep=""), forceDNAtolower=F, as.string=T)

tab2 <- cbind("sort"=sub("OTU_", "", tab[,1]), tab, "sequ"=unlist(sequ))


write.csv(file="3_Raw_OTU_table.csv", tab2, row.names=F)

temp <- "\n\nOTU table generated (including OTU sequences): 3_Raw_OTU_table.csv"
message(temp)
cat(file="../log.txt", temp, append=T, sep="\n")

exp2 <- data.frame("ID"=exp[,1], "Abundance"=colSums(tab[-1]), "pct_pass"=exp[,2], row.names=1:length(exp[,1]))

write.csv(exp2, file="_stats/3_pct_matched.csv")

#### end raw data table

### make abundance filtering
if(!is.na(filter)){
#tab2 <- read.csv(file="3_Raw_OTU_table.csv", stringsAsFactors=F)

start <- which(names(tab2)=="ID")+1
stop <- which(names(tab2)=="sequ")-1

temp <- tab2[, start:stop]

meep <- paste("Discarding OTUs with below ", filter, "% abundance across at least ", filterN, " out of ", ncol(temp), " samples.", sep="")
message(meep)
cat(file="../log.txt", meep, append=T, sep="\n")

temp2 <- temp
sampleabundance <- colSums(temp)
for (i in 1:ncol(temp)){
temp2[i] <- temp[i]/sampleabundance[i]*100
}

# subset OTUs
subset <- rowSums(temp2>=filter)
subset2 <- subset >= filterN

# reporting
meep <- paste("Discarded OTUs: ", sum(!subset2)," out of ",  length(subset2), " discarded (", round(100-sum(subset2)/length(subset2)*100, 2), "%)", sep="")
message(meep)
cat(file="../log.txt", meep, append=T, sep="\n")

#write subsetted OTU table

exp <- tab2[subset2,]
exp <- rbind(exp, NA)

exp[nrow(exp), start:stop] <- colSums(tab2[!subset2, start:stop])
exp$ID[nrow(exp)] <- paste("below_", filter, sep="")
exp$sort[nrow(exp)] <- exp$sort[nrow(exp)-1]


# make folder 
dir.create("_data/5_subset/")


write.csv(exp, file=paste("_data/5_subset/5_OTU_sub_", filter, "_not_rematched.csv", sep=""), row.names=F)

OTU_sub_filename <- paste("_data/5_subset/5_OTU_sub_", filter, ".fasta", sep="")
write.fasta(as.list(exp$sequ[-nrow(exp)]), exp$ID[-nrow(exp)], file.out=OTU_sub_filename)

# remapping of reads against subsetted OTUs!
# compare against refernce sequences (including singletons)

dir.create("_data/5_subset/usearch_global")
dir.create("_stats/5_subset/")

#new_names <- list.files("_data/1_derep_inc_singletons", full.names=T)
blast_names <- sub("_PE_derep.*.fasta", ".txt", new_names)
blast_names <- sub("1_derep_inc_singletons", "5_subset/usearch_global", blast_names)
blast_names <- sub("1_derep_unoise2", "5_subset/usearch_global", blast_names)
log_names <- sub("_data/", "_stats/", blast_names)
log_names <- sub("/usearch_global", "", log_names)


cmd <- paste("-usearch_global ", new_names, " -db ", OTU_sub_filename, " -strand plus -id 0.97 -blast6out ", blast_names, " -maxhits 1", sep="")


temp <- paste("\n\nRemapping ", length(cmd)," files (incl. singletons) against subsetted OTUs \"", OTU_sub_filename, "\" using \"usearch_global\".\n", sep="")
message(temp)
cat(file="../log.txt", temp, append=T, sep="\n")

exp <- NULL
temp <- new_names
for (i in 1:length(cmd)){
A <- system2("usearch", cmd[i], stdout=T, stderr=T)
cat(file= log_names[i], paste("usearch ", cmd[i], sep=""), "\n", A, append=F, sep="\n")

meep <- sub(".*singletons/(.*)", "\\1", temp[i])
pass <- sub(".*, (.*)% matched\r", "\\1", A[grep("matched\r", A)])
exp <- rbind(exp, c(meep, pass))
glumanda <- paste(meep," - ", pass, "% reads matched", sep="")
cat(file="../log.txt", glumanda, append=T, sep="\n")
message(glumanda)
}

#Remapping end

# Writing subsetted & remapped OTU table!
# Write raw data OTU table! incl OTU sequences
files <- blast_names

tab <- c("NULL")
tab <- as.data.frame(tab, stringsAsFactors=F)
names(tab) <- "ID"

for (i in 1:length(files)){
data <- read.csv(files[i], sep="\t", header=F, stringsAsFactors=F)

names(data) <- c("query", "otu", "ident", "length", "mism", "gap", "qstart", "qend", "target_s", "target_e", "e.value", "bitscore")

data <- data[,c(-11,-12)]

data <- cbind(data, "abund"=as.numeric(sub(".*size=(.*);", "\\1", data$query)), "otu_no"=sub("(.*);size.*", "\\1", data$otu), stringsAsFactors=F)

head(data)

temp <- aggregate(data$abund, by=list(data$otu_no), FUN="sum")
tab <- merge(tab , temp, by.x="ID", by.y="Group.1", all=T, sort=T)
names(tab)[i+1] <- sub(".*/(.*)_PE.*", "\\1", files[i])
}

head(tab)

tab <- tab[-1,] # remove NULL entry in the beginning
tab[is.na(tab)] <- 0

mrew <- tab$ID
mrew <- as.numeric(gsub("OTU_(.*)", "\\1", mrew))
tab <- tab[order(as.numeric(mrew)),]

# add sequences!

sequ <- read.fasta(OTU_sub_filename, forceDNAtolower=F, as.string=T)

tab2 <- cbind("sort"=as.numeric(sub("OTU_", "", tab[,1])), tab, "sequ"=unlist(sequ))

names(tab2) <- sub("_data/5_subset/usearch_global/(.*).txt", "\\1", names(tab2)) # SUBSET HERE

# add below OTUs

subSums <- read.csv("3_Raw_OTU_table.csv")
subSums <- as.vector(c(subSums[nrow(subSums)-1, 1]+1, paste("below_", filter, sep=""), colSums(subSums[,-c(1,2, ncol(subSums))])-colSums(tab2[-c(1,2, ncol(tab2))]), NA))


tab3 <- rbind(tab2, subSums)

write.csv(file=paste("5_OTU_table_", filter,".csv", sep=""), tab3, row.names=F)


temp <- paste("\n\nSubsetted OTU table generated (", filter, "% abundance in at least ", filterN," sample): ", sub(OTU_sub_filename, "", "_data/5_subset/"), sep="")
message(temp)
cat(file="../log.txt", temp, append=T, sep="\n")

#exp2 <- data.frame("ID"=exp[,1], "Abundance"=colSums(tab[-1]), "pct_pass"=exp[,2], row.names=1:length(exp[,1]))
#write.csv(exp2, file="_stats/5_pct_subsetted_matched.csv")

#### end subsetted OTU table

} # end subsetting



temp <- "\nModule completed!"
message(temp)
cat(file="../log.txt", paste(Sys.time(), temp, "", sep="\n"), append=T, sep="\n")

setwd("../")
}

