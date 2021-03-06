# U_max_ee v0.1

U_fastq_2_fasta <- function(files="latest"){

Core(module="U_fastq_2_fasta")
cat(file="../log.txt", c("\n","Version v0.1", "\n"), append=T, sep="\n")
message(" ")

if (files=="latest"){
source("robots.txt")
files <- list.files(paste("../", last_data, "/_data", sep=""), full.names=T)
}

temp <- paste("Starting to convert ", length(files), " fastq files into fasta files (Phred quality scores will get lost!.", sep="")
message(temp)
message(" ")
cat(file="../log.txt", temp, append=T, sep="\n")

# new file names
new_names <- sub(".*(_data/.*)", "\\1", files)
new_names <- sub(".fastq", ".fasta", new_names) # keep fastq


#dir.create("_stats")
log_names <- sub("_data", "_stats", new_names)
log_names <- sub(".fasta", "_logs.txt", log_names)

# cmd max EE
cmd <- paste("-fastq_filter \"", files, "\" -fastaout \"", new_names, "\"", sep="")


tab_exp <- NULL

for (i in 1:length(cmd)){
A <- system2("usearch", cmd[i], stdout=T, stderr=T)
cat(A, file=log_names[i], sep="\n")


imput <- A[grep("Filtered reads", A)]
imput <- sub("(.*) Filtered reads.*", "\\1", imput)
imput <- as.numeric(imput)


short_name <- sub("_data/(.*)_PE.*", "\\1", new_names[i])

tab_exp <- rbind(tab_exp, c(short_name, imput))

meep <- paste(short_name, " converted to fasta! (", imput, " Reads)", sep="")
message(meep)
cat(file="../log.txt", meep, append=T, sep="\n")
}
cat(file="../log.txt", "\n", append=T, sep="\n")


tab_exp <- data.frame(tab_exp)
names(tab_exp) <- c("Sample", "Sequ_count")

write.csv(tab_exp, "_stats/max_ee_stats.csv")


message(" ")
message("Module completed!")

cat(file="../log.txt", paste(Sys.time(), "Module completed!", "", sep="\n"), append=T, sep="\n")

setwd("../")
}

