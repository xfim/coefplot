### Functions for plotting multiple coefplots at once
#' Plot multiple coefplots
#'
#' Plot the coeffcients from multiple models
#'
#' Plots a graph similar to \code{\link{coefplot}} but for multiple plots at once.
#'
#' For now, if \code{names} is provided the plots will appear in alphabetical order of the names.  This wil be adjusted in future iterations.  When setting \code{by} to "Model" and specifying exactly one variable in \code{variables} that one coefficient will be plotted repeatedly with the axis labeled by model.  This is Andy Gelman's secret weapon.
#'
#' @export multiplot
#' @seealso \code{link{coefplot}}
#' @param \dots Models to be plotted
#' @param title  The name of the plot, if NULL then no name is given
#' @param xlab The x label
#' @param ylab The y label
#' @param innerCI How wide the inner confidence interval should be, normally 1 standard deviation.  If 0, then there will be no inner confidence interval.
#' @param outerCI How wide the outer confidence interval should be, normally 2 standard deviations.  If 0, then there will be no outer confidence interval.
#' @param lwdInner The thickness of the inner confidence interval
#' @param lwdOuter The thickness of the outer confidence interval
#' @param pointSize Size of coefficient point
#' @param dodgeHeight Amount of vertical dodging
#' @param color The color of the points and lines
#' @param cex The text size multiplier, currently not used
#' @param textAngle The angle for the coefficient labels, 0 is horizontal
#' @param numberAngle The angle for the value labels, 0 is horizontal
#' @param zeroColor The color of the line indicating 0
#' @param zeroLWD The thickness of the 0 line
#' @param zeroType The type of 0 line, 0 will mean no line
## @param facet logical; If the coefficients should be faceted by the variables, numeric coefficients (including the intercept) will be one facet
#' @param single logical; If TRUE there will be one plot with the points and bars stacked, otherwise the models will be displayed in seperate facets
#' @param scales The way the axes should be treated in a faceted plot.  Can be c("fixed", "free", "free_x", "free_y")
#' @param ncol The number of columns that the models should be plotted in
#' @param sort Determines the sort order of the coefficients.  Possible values are c("natural", "normal", "magnitude", "size", "alphabetical")
#' @param decreasing logical; Whether the coefficients should be ascending or descending
#' @param names Names for models, if NULL then they will be named after their inputs
#' @param numeric logical; If true and factors has exactly one value, then it is displayed in a horizontal graph with constinuous confidence bounds.
#' @param fillColor The color of the confidence bounds for a numeric factor
#' @param alpha The transparency level of the numeric factor's confidence bound
#' @param horizontal logical; If the plot should be displayed horizontally
#' @param intercept logical; Whether the Intercept coefficient should be plotted
#' @param interceptName Specifies name of intercept it case it is not the default of "(Intercept").
#' @param variables A character vector specifying which variables to keep.  Each individual variable has to be specfied, so individual levels of factors must be specified.  We are working on making this easier to implement, but this is the only option for now.
#' @param newNames Named character vector of new names for coefficients
#' @param plot logical; If the plot should be drawn, if false then a data.frame of the values will be returned
#' @param factors Vector of factor variables that will be the only ones shown
#' @param only logical; If factors has a value this determines how interactions are treated.  True means just that variable will be shown and not its interactions.  False means interactions will be included.
#' @param shorten logical or character; If \code{FALSE} then coefficients for factor levels will include their variable name.  If \code{TRUE} coefficients for factor levels will be stripped of their variable names.  If a character vector of variables only coefficients for factor levels associated with those variables will the variable names stripped.
#' @param drop logical; if TRUE then models without valid coeffiecients to show will not be plotted
#' @param by If "Coefficient" then anormal multiplot is plotted, if "Model" then the coefficients are plotted along the axis with one for each model.  If plotting by model only one coefficient at a time can be selected.  This is called the secret weapon by Andy Gelman.
#' @return A ggplot object
#' @examples
#'
#'\dontrun{
#' data(diamonds)
#' model1 <- lm(price ~ carat + cut, data=diamonds)
#' model2 <- lm(price ~ carat + cut + color, data=diamonds)
#' model3 <- lm(price ~ carat + color, data=diamonds)
#' multiplot(model1, model2, model3)
#' multiplot(model1, model2, model3, single=FALSE)
#' multiplot(model1, model2, model3, plot=FALSE)
#' }
#'
multiplot <- function(..., title="Coefficient Plot", xlab="Value", ylab="Coefficient", 
    					innerCI=1, outerCI=2, lwdInner=1, lwdOuter=0, pointSize=3, dodgeHeight=1,  color="blue",
						cex=.8, textAngle=0, numberAngle=90,
						zeroColor="grey", zeroLWD=1, zeroType=2,
						#facet=FALSE,
                        single=TRUE,
                        scales="fixed", ncol=length(unique(modelCI$Model)),
						sort=c("natural", "normal", "magnitude", "size", "alphabetical"), decreasing=FALSE, names=NULL,
						numeric=FALSE, fillColor="grey", alpha=1/2,
						horizontal=FALSE, factors=NULL, only=NULL, shorten=TRUE,
						intercept=TRUE, interceptName="(Intercept)", variables=NULL, newNames=NULL, plot=TRUE, drop=FALSE,
                      by=c("Coefficient", "Model"))
{
    ## if ... is already a list just grab the dots, otherwise force it into a list
    if(tryCatch(is.list(...), error = function(e) FALSE))
    {
        # grab the models
        theDots <- list(...)[[1]]
        # since theDots came in as a list it might have names, if so, leave them, if not, assign them names
        if(is.null(names(theDots)))
        {
            names(theDots) <- sprintf("Model%s", 1:length(theDots))
        }
    }else
    {
        # grab the models
        theDots <- list(...)
    }
    
    # get the inputs, anything in the dots is blank or ""
    theArgs <- unlist(structure(as.list(match.call()[-1]), class = "uneval"))
    # if names(theArgs) is null, only dots were passed, treat them all as model
    # otherwise find args that are "" and treat them as model
    #print(theArgs[names(theArgs) == ""])
    if(is.null(names(theArgs)))
    {
        # if names(theArgs) is null, only dots were passed, treat them all as model
        theNames <- theArgs
    }else
    {
        theNames <- theArgs[names(theArgs) == ""]
    }
    
    # if theDots doesn't already have names apply what we just created
    if(is.null(names(theDots)))
    {
        names(theDots) <- theNames
    }
 
    # get variables that have multiple options
    sort <- match.arg(sort)
    by <- match.arg(by)
    
    if(by == "Model" & length(variables) != 1)
    {
        stop("If plotting the model along the axis then exactly one variable must be specified for plotting")
    }
    
#    return(theDots)
    # need to change getModelInfo and buildModelCI and coefplot.lm so that shorten, factors and only are normal arguments and not part of ..., that way it will work better for this
    # get the modelCI for each model and make one big data.frame
    modelCI <- ldply(theDots, .fun=buildModelCI, outerCI=outerCI, innerCI=innerCI, intercept=intercept, numeric=numeric, 
                     sort=sort, decreasing=decreasing, factors=factors, only=only, shorten=shorten, variables=variables, newNames=newNames)
    
    # Turn the Call into a unique identifier for each model
    #modelCI$Model <- as.factor(as.numeric(factor(modelCI$Model, levels=unique(modelCI$Model))))
    modelCI$Model <- modelCI$.id
    modelCI$.id <- NULL
    
    # if names are provided use those instead of the numbers
    if(!is.null(names))
    {
        names(names) <- theNames
        modelCI$Model <- names[modelCI$Model]
        #modNames <- structure(as.list(match.call()[-1]), class = "uneval")
    }
    
    ## if we are not plotting return modelCI right away
    if(!plot)
    {
        return(modelCI)
    }
    
    ## if drop is true get rid of models without valid coefficients
    if(drop)
    {
        notNA <- daply(modelCI, .variables="Model", function(x) { !all(is.na(x$Coef)) })
        #return(which(notNA == TRUE))
        modelCI <- modelCI[modelCI$Model %in% names(which(notNA == TRUE)), ]
    }
    
    if(!plot)
    {
        return(modelCI)
    }
    
    # which columns will be kept in the melted data.frame
#    keepCols <- c("LowOuter", "HighOuter", "LowInner", "HighInner", "Coefficient", "Model")
    
#     modelMelting <- meltModelCI(modelCI=modelCI, keepCols=keepCols, id.vars=c("Coefficient", "Model"), 
#                                 variable.name="Type", value.name="Value", outerCols=c("LowOuter", "HighOuter"), 
#                                 innerCols=c("LowInner", "HighInner")) 
#  
# 
#     modelMelt <- modelMelting$modelMelt 
#     modelMeltInner <- modelMelting$modelMeltInner 
#     modelMeltOuter <- modelMelting$modelMeltOuter 
#     rm(modelMelting);      # housekeeping 

    p <- buildPlotting.default(modelCI=modelCI, 
                        #modelMeltInner=modelMeltInner, modelMeltOuter=modelMeltOuter,
                       title=title, xlab=xlab, ylab=ylab,
                       lwdInner=lwdInner, lwdOuter=lwdOuter, pointSize=pointSize, dodgeHeight=dodgeHeight, 
                        color=color, cex=cex, textAngle=textAngle, 
                       numberAngle=numberAngle, zeroColor=zeroColor, zeroLWD=zeroLWD, outerCI=outerCI, innerCI=innerCI,# single=single,
                       zeroType=zeroType, numeric=numeric, fillColor=fillColor, alpha=alpha, multi=TRUE,
                               value="Value", coefficient=by,
                       horizontal=horizontal, facet=FALSE, scales="fixed")
    #return(p)
    
    theColorScale <- list("Coefficient"=scale_colour_discrete("Model"), 
                          "Model"=scale_color_manual(values=rep(color, length(unique(modelCI$Model))), guide=FALSE))
    
    p + theColorScale[[by]] +  if(!single) facet_wrap(~Model, scales=scales, ncol=ncol)
}
