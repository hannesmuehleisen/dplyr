#' A grouped data frame.
#'
#' The easiest way to create a grouped data frame is to call the \code{group_by}
#' method on a data frame or tbl: this will take care of capturing
#' the unevalated expressions for you.
#'
#' @keywords internal
#' @param data a tbl or data frame.
#' @param vars a list of quoted variables.
#' @param lazy if \code{TRUE}, index will be computed lazily every time it
#'   is needed. If \code{FALSE}, index will be computed up front on object
#'   creation.
#' @param drop if \code{TRUE} preserve all factor levels, even those without
#'   data.
grouped_df <- function(data, vars, lazy = TRUE, drop = TRUE) {
  if (length(vars) == 0) {
    return(tbl_df(data))
  }

  assert_that(is.data.frame(data), is.list(vars), is.flag(lazy), is.flag(drop))
  
  attr(data, "vars") <- vars
  attr(data, "drop") <- drop
  if (!lazy) {
    data <- build_index(data)
  }

  class(data) <- unique(c("grouped_df", "tbl_df", "tbl", class(data)))
  data
}

#' A grouped data frame with cpp backend.
#'
#' The easiest way to create a grouped data frame is to call the \code{group_by}
#' method on a data frame or tbl: this will take care of capturing
#' the unevalated expressions for you.
#'
#' @keywords internal
#' @param data a tbl or data frame.
#' @param vars a list of quoted variables.
#' @param lazy if \code{TRUE}, index will be computed lazily every time it
#'   is needed. If \code{FALSE}, index will be computed up front on object
#'   creation.
#' @param drop if \code{TRUE} preserve all factor levels, even those without
#'   data.
grouped_cpp <- function(data, vars, lazy = TRUE, drop = TRUE) {
  if (length(vars) == 0) {
    return(tbl_cpp(data))
  }

  assert_that(is.data.frame(data), is.list(vars), is.flag(lazy), is.flag(drop))
  
  attr(data, "vars") <- vars
  attr(data, "drop") <- drop
  if (!lazy) {
    data <- build_index_cpp(data)
  }
  classes <- c("grouped_cpp", "tbl_cpp", "tbl")
  class(data) <- c(classes, setdiff( class(data), classes ) )
  data
}

#' @S3method groups data.frame
groups.data.frame <- function(x) {
  attr(x, "vars")
}

#' @rdname grouped_df
#' @method is.lazy grouped_df
#' @export
is.lazy.grouped_df <- function(x) {
  is.null(attr(x, "index")) || is.null(attr(x, "labels"))
}

#' @rdname grouped_cpp
#' @method is.lazy grouped_cpp
#' @export
is.lazy.grouped_cpp <- function(x) {
  is.null(attr(x, "index")) || is.null(attr(x, "labels"))
}

#' @rdname grouped_df
#' @export
is.grouped_df <- function(x) inherits(x, "grouped_df")

#' @rdname grouped_df
#' @export
is.grouped_cpp <- function(x) inherits(x, "grouped_cpp")

#' @S3method print grouped_df
print.grouped_df <- function(x, ...) {
  cat("Source: local data frame ", dim_desc(x), "\n", sep = "")
  cat("Groups: ", commas(deparse_all(groups(x))), "\n", sep = "")
  cat("\n")
  trunc_mat(x)
}

#' @S3method print grouped_cpp
print.grouped_cpp <- function(x, ...) {
  cat("Source: local data frame ", dim_desc(x), "\n", sep = "")
  cat("Groups: ", commas(deparse_all(groups(x))), "\n", sep = "")
  cat("\n")
  trunc_mat(x)
}

#' @S3method group_size grouped_df
group_size.grouped_df <- function(x) {
  if (is.lazy(x)) x <- build_index(x)
  vapply(attr(x, "index"), length, integer(1))
}

#' @S3method group_size grouped_cpp
group_size.grouped_cpp <- function(x) {
  group_size_grouped_cpp(x)
}

#' @export
"groups<-.data.frame" <- function(x, value) {
  grouped_df(x, value, lazy = FALSE)
}

#' @export
"groups<-.tbl_cpp" <- function(x, value) {
  grouped_cpp(x, value, lazy = FALSE)
}

#' @S3method as.data.frame grouped_df
as.data.frame.grouped_df <- function(x, row.names = NULL,
                                            optional = FALSE, ...) {
#   if (!is.null(row.names)) warning("row.names argument ignored", call. = FALSE)
#   if (!identical(optional, FALSE)) warning("optional argument ignored", call. = FALSE)

  attr(x, "vars") <- NULL
  attr(x, "index") <- NULL
  attr(x, "labels") <- NULL
  attr(x, "drop") <- NULL

  class(x) <- setdiff(class(x), c("grouped_df", "tbl_df", "tbl"))
  x
}

#' @S3method as.data.frame grouped_cpp
as.data.frame.grouped_cpp <- function(x, row.names = NULL,
                                            optional = FALSE, ...) {
#   if (!is.null(row.names)) warning("row.names argument ignored", call. = FALSE)
#   if (!identical(optional, FALSE)) warning("optional argument ignored", call. = FALSE)

  attr(x, "vars") <- NULL
  attr(x, "index") <- NULL
  attr(x, "labels") <- NULL
  attr(x, "drop") <- NULL

  class(x) <- setdiff(class(x), c("grouped_cpp", "tbl_cpp", "tbl"))
  x
}

#' @S3method ungroup grouped_df
ungroup.grouped_df <- function(x) {
  attr(x, "vars") <- NULL
  attr(x, "index") <- NULL
  attr(x, "labels") <- NULL
  attr(x, "drop") <- NULL

  class(x) <- setdiff(class(x), "grouped_df")
  x
}

#' @S3method ungroup grouped_cpp
ungroup.grouped_cpp <- function(x) {
  attr(x, "vars") <- NULL
  attr(x, "index") <- NULL
  attr(x, "labels") <- NULL
  attr(x, "drop") <- NULL

  class(x) <- setdiff(class(x), "grouped_cpp")
  x
}

#' @export
ungroup.data.frame <- function(x) x
#' @export
ungroup.tbl_cpp <- function(x) x
#' @export
ungroup.tbl_df <- function(x) x




make_view <- function(x, env = parent.frame()) {
  if (is.lazy(x)) stop("No index present", call. = FALSE)
  view(x, attr(x, "index"), parent.frame())
}

build_index <- function(x) {
  splits <- lapply(groups(x), eval, x, parent.frame())
  split_id <- id(splits, drop = attr(x, "drop"))
  
  assert_that(length(split_id) == nrow(x))

  attr(x, "labels") <- split_labels(splits, drop = attr(x, "drop"),
    id = split_id)
  attr(x, "index") <- split_indices(split_id, attr(split_id, "n"))

  x
}

split_labels <- function(splits, drop, id = plyr::id(splits, drop = TRUE)) {
  if (length(splits) == 0) return(data.frame())

  if (drop) {
    # Need levels which occur in data
    representative <- which(!duplicated(id))[order(unique(id))]
    as_df(lapply(splits, function(x) x[representative]))
  } else {
    unique_values <- lapply(splits, ulevels)
    names(unique_values) <- names(splits)
    rev(expand.grid(rev(unique_values), stringsAsFactors = FALSE))
  }
}

ulevels <- function(x) {
  if (is.factor(x)) {
    levs <- levels(x)
    factor(levs, levels = levs)
  } else {
    sort(unique(x))
  }
}
