#' Split signals into  epochs according to an events dataframe or an epoch duration.
#'
#' @description Split long signals into a list of consecutive epochs according to an events dataframe or an epoch duration.
#' @param signals A list of numeric vectors containing signals, or a single vector containing one signal.
#' @param sRates A vector or list of integer values of the signals sample rates.
#' @param resample The sample rate to resample all signals. Defaults to to the max of the provided sample rates.
#' @param epoch Epochs reference. Can be an events dataframe or the number of seconds of each epoc Defaults to 30.
#' @param startTime The start timestamp of the signal, used to join events to epoch.
#' @param padding Number of previous and next epochs to pad the current epoch with. This functionnality is mostly used to enrich deep learning datasets. Defaults to 0.
#' @return A list of signal chunks
#' @examples
#' epochs(list(rep(c(1,2,3,4),100),rep(c(5,6,7,8),100)),4,4,1,padding = 2)
#' @export
epochs <- function(signals,
                   sRates,
                   resample = max(sRates),
                   epoch = 30,
                   startTime = 0,
                   padding = 0){


  if(!is.list(signals)){
    signals <- list(signals)
  }

  resampled_signals <- mapply(function(x,y){
    if(y != resample){
      signal::resample(x,resample,y)
    } else{
      x
    }
  }, x = signals,
  y = sRates)

  # Min norm, when sRtes 1
  if(is.list(resampled_signals)){
    max_length <- max(unlist(lapply(resampled_signals,function(x){length(x)})))
    resampled_signals <- lapply(resampled_signals, function(x){
      l <- length(x)
      if(l < max_length){
        c(x,rep(x[length(x)],max_length-l))
      } else x
    })
    resampled_signals <- matrix(
      unlist(resampled_signals),
      ncol = length(resampled_signals),
      byrow = TRUE)
  }

  if(is.numeric(epoch)){

    epochs <- lapply(
      split(resampled_signals,
            ceiling(seq_along(resampled_signals[,1])/(resample*epoch))),
      matrix,
      ncol = dim(resampled_signals)[2])

  } else if(is.data.frame(epoch)){

    epoch$begin <- as.numeric(epoch$begin)
    epoch$end <- as.numeric(epoch$end)

    epochs <- lapply(c(1:nrow(epoch)), function(x){
      sidx <- (epoch$begin[x] - startTime)*resample
      eidx <- (epoch$end[x] - startTime)*resample-1
      max <- dim(resampled_signals)[1]
      if((sidx <=  max) & (eidx <= max)){
        resampled_signals[sidx:eidx,]
      }
    })
    epochs[sapply(epochs, is.null)] <- NULL

  } else {

    stop("`epoch` parameter must be a numeric or a dataframe of events.")

  }

  # Apply padding
  if(padding > 0){

    epochs <- lapply(c(1:length(epochs)), function(i){

      epoch <-  epochs[[i]]

      for(j in c(1:padding)){

        if((i-1) %in% c(1:length(epochs))){
          prev <- epochs[[i-1]]
        } else {
          prev <- epochs[[1]]
        }

        if((i+1) %in%  c(1:length(epochs))){
          last <- epochs[[i+1]]
        } else {
          last <- epochs[[length(epochs)]]
        }

        epoch <-  abind::abind(prev, epoch, last, along = 1)

      }

      epoch

    })
  }

  epochs

}
