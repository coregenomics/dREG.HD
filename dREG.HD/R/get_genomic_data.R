#read in the prediction bed file generated by dREG, and returns: the data.frame (chr,position) 

#@param randomON default is false, if turned on then randomly sample positions from the peak at a rate=rate
#@param the sampling rate, default=20% 
 
get_positions<-function (bed,chr, randomON, rate){
	chr.involved<-as.character(unique(bed[,1]))
	position_df<-data.frame(NA,ncol=2)
	colnames(position_df)<-c('V1','V2')
	
	for (chrom in chr.involved){
	bed.subset<-bed[bed[,1]==chrom,]	
	for (peak in (1:nrow(bed.subset))){
		peak_df<-cbind.data.frame(bed.subset[peak,]$V1,c(bed.subset[peak,]$V2:(bed.subset[peak,]$V3-1)))
		if (randomON==TRUE){
			#pick (uniform) random positions on a given peak
			get_indx<-sample(c(1:nrow(peak_df)), ceiling(nrow(peak_df)*rate),replace=FALSE)
			#get_indx<-sample(c(1:nrow(peak_df)), as.integer(nrow(peak_df)*rate),replace=FALSE)
			peak_df<-peak_df[get_indx,]
		}
		colnames(peak_df)<-c('V1','V2')
		position_df <-rbind(position_df,peak_df)
	}
	
	}
		return (position_df[2:nrow(position_df),])

}








#' Returns a data.frames representing the input/output of svm given the bed file (peak label,input,output)
#' @param bed_file the selected peaks to test and evaluate (chr, start, end).
#' @param chr chromosome number (character) e.g. 'chr21'
#' @param input_peaks the lines chosen from the original bed file
#' @param top the longest several dREG peaks  
#' @param bed Path to the bed file representing dREG peaks
#' @param bigwig_plus Path to bigwig file representing GRO-seq/ PRO-seq reads on the plus strand.
#' @param bigwig_minus Path to bigwig file representing GRO-seq/ PRO-seq reads on the minus strand.
#' @param dnase_bw Path to bigwig file representing DnaseI intensity.
#' @param as_matrix If true, returns a matrix object.
get_svm_io<-function(zoom, bed_file, chr, x,input_peaks, scaling.mode="hybrid", bigwig_plus, bigwig_minus, dnase_bw, as_matrix= TRUE, randomON, rate){
	  #make peak labels
	  
	  if(randomON==FALSE) labels<-unlist(mapply(rep, as.factor(input_peaks), bed_file$V3-bed_file$V2))
	  if(randomON==TRUE) labels<-unlist(mapply(rep, as.factor(input_peaks), as.integer((bed_file$V3-bed_file$V2)*rate)))
  

  
		positions<- get_positions(bed=bed_file,chr=chr, randomON=randomON, rate=rate)	#position is a data.frame
		
	if(scaling.mode=="scaled"){
	dat_scaled <- .Call("get_genomic_data_R", as.character(positions$V1), as.integer(positions$V2), as.character(bigwig_plus), as.character(bigwig_minus), zoom, as.numeric(x), PACKAGE= "dREG")
	dat<- cbind(rep(),t(matrix(unlist(dat_scaled), ncol=NROW(positions))))
	}
	
	if(scaling.mode=="unscaled"){
		dat_unscaled <- .Call("get_genomic_data_R", as.character(positions$V1), as.integer(positions$V2), as.character(bigwig_plus), as.character(bigwig_minus), zoom, -1, PACKAGE= "dREG")
		
	bw.plus <- load.bigWig(bigwig_plus)
	bw.minus <-  load.bigWig(bigwig_minus)
	total<-bw.plus$mean*bw.plus$basesCovered+bw.minus$mean*bw.minus$basesCovered
	unload.bigWig(bw.plus)
	unload.bigWig(bw.minus)
	dat<- cbind(rep(),t(matrix(unlist(dat_unscaled), ncol=NROW(positions))))
	dat<-dat/(total/1E6)
	}
	
	if(scaling.mode=="hybrid"){
		dat_scaled <- .Call("get_genomic_data_R", as.character(positions$V1), as.integer(positions$V2), as.character(bigwig_plus), as.character(bigwig_minus), zoom, as.numeric(x), PACKAGE= "dREG")
		dat_unscaled <- .Call("get_genomic_data_R", as.character(positions$V1), as.integer(positions$V2), as.character(bigwig_plus), as.character(bigwig_minus), zoom, -1, PACKAGE= "dREG")
	dat_scaled <- cbind(rep(),t(matrix(unlist(dat_scaled), ncol=NROW(positions))))
    dat_unscaled <- cbind(rep(),t(matrix(unlist(dat_unscaled), ncol=NROW(positions))))
    
    bw.plus <- load.bigWig(bigwig_plus)
	bw.minus <-  load.bigWig(bigwig_minus)
	total<-bw.plus$mean*bw.plus$basesCovered+bw.minus$mean*bw.minus$basesCovered
	unload.bigWig(bw.plus)
	unload.bigWig(bw.minus)
	dat_unscaled<-dat_unscaled/(total/1E6)
  
    dat<-cbind(dat_scaled, dat_unscaled)
	}
	

	
	#get the dnase info
	dnase<-load.bigWig(dnase_bw)
	
	if (randomON==FALSE)
	dnase.vector<-unlist(bed.step.bpQuery.bigWig(bw=dnase,bed= bed_file,step=1))
	
	if(randomON==TRUE){
	position.bed <-	cbind(positions, positions$V2+1)

	
	
	dnase.vector<-c()
	for (i in 1:nrow(position.bed)){
		dnase.vector<-c(dnase.vector,unlist(bed.step.bpQuery.bigWig(bw=dnase,bed= position.bed[i,],step=1)))
	}
	
	#dnase.vector<-apply(position.bed,MARGIN=1, FUN=bed.step.bpQuery.bigWig,bw=dnase,step=1)
	#dnase.vector<-(bed.step.bpQuery.bigWig(bw=dnase,bed= position.bed,step=1))	
	}
	
    unload.bigWig(dnase)
    browser()
	training.frame<-cbind.data.frame(labels,dat, dnase.vector)
	return(training.frame)
}


