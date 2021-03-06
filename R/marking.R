#' Marking Data with Wearing Tags
#'
#' This function marks the dataset with wearing/non-wearing tags.
#'
#' @param dataset The source dataset, in dataframe format, which needs to be
#' marked.
#' @param frame The size of time interval to be considered.
#' @param cts The name of the counts column. The default is "axis1".
#' @param streamFrame The size of time interval that the program will look back
#' or forward if activity is detected. The default is the half of frame.
#' @param allowanceFrame The size of time interval that zero counts allowed.
#' The default is 2.
#' @param newcolname The wearing marking column name.  The default is "wearing".
#' After the data is processed, a new field will be added to the original
#' dataframe.  This new field is the wearing /nowwearing indicator.
#'
#' @return A dataframe with an extra wearing/non-wearing marking column.
#'
#' @template ref2011
#'
#' @templateVar author liu
#' @template auth
#'
#' @keywords internal

marking <- function(dataset,
                   frame,
                   cts = getOption('pa.cts'),
                   streamFrame = NULL,
                   allowanceFrame = 2,
                   newcolname = "wearing") {
    cat(sprintf("frame is %s\nstreamFrame is %s\nallowanceFrame is %s\n",
                frame, streamFrame, allowanceFrame))
    ct <- dataset[,cts]

    if(is.null(streamFrame)) {
        streamFrame <- round(0.5*frame)
    }

    #all the NA's in the original counts data will be treated as 0 counts
    ct1 <- ct
    ct[is.na(ct)] <- 0

    size <- nrow(dataset)
    wearing <- rep("nw", size)

    ct_bool <- ct > 0
    #getting section start and end positions
    startpos <- which(diff(c(0,ct_bool)) == 1)
    endpos <- which(diff(c(ct_bool,0)) == -1)

    #ele3 should be handled here on startpos/endpos level
    allowancewin <- endpos-startpos
    ix <- which(allowancewin < allowanceFrame)
    #upstream
    usStart <- pmax(startpos[ix] - streamFrame, 1)
    usEnd <- pmax(startpos[ix] - 1, 1)
    #downstream
    dsEnd <- pmin(endpos[ix] + streamFrame, size)
    dsStart <- pmin(endpos[ix] + 1, size)
    addseq <- function(start, stop) {
        if(start == stop) return(0)
        sum(ct_bool[seq(start, stop)])
    }
    upsum <- mapply(addseq, usStart, usEnd)
    downsum <- mapply(addseq, dsStart, dsEnd)
    badix <- ix[upsum == 0 & downsum == 0]
    if(length(badix)) {
        startpos <- startpos[-badix]
        endpos <- endpos[-badix]
    }
    #end of ele3

    #now get the non-wearing gap
    #frame is the gap allowed between time section.  ie if 90 minutes allowed
    #between two wearing sections, then frame = 90
    gaplen <- length(endpos)
    if(gaplen > 0) {
        endgap <- endpos[-gaplen]
        startgap <- startpos[-1]
        gap <- which((startgap - endgap) > frame)
        newstartpos <- c(startpos[1], startgap[gap])
        newendpos <- c(endgap[gap], endpos[gaplen])
        togWear <- mapply(seq, newstartpos, newendpos)
        wearing[unlist(togWear)] <- 'w'    
        wearing[size] <- wearing[size-1]
    }
    wearing[is.na(ct1)] <- NA
    dataset[,newcolname] <- as.factor(wearing)
    dataset
}
