#' Generate a single calibration plot with error bars showing 95 percent
#' confidence intervals
#'
#' This code builds off of code written by Darren Dahly, PhD in this blog post:
#' \url{https://darrendahly.github.io/post/homr/}.
#'
#' @param df The df as a data.frame.
#' @param outcome A character string containing the name of the column
#'   containing the outcomes (expressed as 0/1s).
#' @param positive A character string containing the value of outcome that is the positive class.
#' @param prediction A character string containing the name of the column
#'   containing the predictions.
#' @param n_bins Number of bins. Defaults to 10. Set to 0 to hide binned
#'   calibration.
#' @param show_loess Whether to show loess smoothed calibration estimates.
#'   Defaults to FALSE. You can either display a binned calibration plot or a loess curve.
#'   These options are mutually exclusive.
#' @param plot_title A character string containing the title for the resulting
#'   plot.
#' @return A ggplot containing the calibration plot
#' @examples
#' data(single_model_dataset)
#' cal_plot(single_model_dataset, outcome = 'outcomes', positive = '1', prediction = 'predictions', n_bins = 5)
#' @export
cal_plot <- function(df, outcome, positive, prediction, n_bins = 10, show_loess = FALSE, plot_title = '', ...){

if((n_bins > 0 && show_loess == TRUE) || (n_bins == 0 && show_loess == FALSE)) {
    stop('You must either set n_bins > 0 and show_loess to FALSE or set n_bins to 0 and show_loess to TRUE. Both cannot be displayed.')
  }

  # Converts outcome to be 0s and 1s
  df[[outcome]] = ifelse(positive == df[[outcome]], 1, 0)

  # The calibration plot
  if (n_bins > 0) {
  df <- dplyr::mutate(df, bin = dplyr::ntile(!!rlang::parse_expr(prediction), n_bins)) %>%
    # Bin prediction into n_bins
    dplyr::group_by(bin) %>%
    dplyr::mutate(n = dplyr::n(), # Get ests and CIs
           bin_pred = mean(!!rlang::parse_expr(prediction), na.rm = TRUE),
           bin_prob = mean(as.numeric(as.character(!!rlang::parse_expr(outcome))), na.rm = TRUE),
           se = sqrt((bin_prob * (1 - bin_prob)) / n),
           ul = bin_prob + 1.96 * se,
           ll = bin_prob - 1.96 * se) %>%
    dplyr::mutate_at(dplyr::vars(ul, ll), . %>% scales::oob_squish(range = c(0,1))) %>%
    dplyr::ungroup()
  }

  g1 = ggplot2::ggplot(df) +
    ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, by = 0.1)) +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, by = 0.1)) +
    ggplot2::geom_abline(linetype = 'dashed') # 45 degree line indicating perfect calibration

    # geom_smooth(method = "lm", se = FALSE, linetype = "dashed",
    #             color = "black", formula = y~-1 + x) +
    # straight line fit through estimates

  if (show_loess) {
    g1 = g1 +
    ggplot2::geom_smooth(ggplot2::aes(x = !!rlang::parse_expr(prediction), y = as.numeric(!!rlang::parse_expr(outcome))),
               color = "black", se = TRUE, method = "loess")
    # loess fit through estimates
  } else { # we already checked at the top to ensure these options are mutually exclusive
    g1 = g1  +
      ggplot2::geom_point(ggplot2::aes(x = bin_pred, y = bin_prob, ymin = ll, ymax = ul),
                        size = 2, color = 'black') +
      ggplot2::geom_errorbar(ggplot2::aes(x = bin_pred, y = bin_prob, ymin = ll, ymax = ul),
                           size = 0.5, color = "black", width = 0.02)
  }

  g1 = g1 +
    ggplot2::xlab("Predicted Probability") +
    ggplot2::ylab("Observed Risk") +
    ggplot2::theme_minimal() +
    ggplot2::theme(aspect.ratio = 1) +
    ggplot2::ggtitle(plot_title)

  # The distribution plot
  g2 <- ggplot2::ggplot(df, ggplot2::aes(x = !!rlang::parse_expr(prediction))) +
    ggplot2::geom_histogram(fill = "black", bins = 100) +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, by = 0.1)) +
    ggplot2::xlab("") +
    ggplot2::ylab("") +
    ggplot2::theme_minimal() +
    ggeasy::easy_remove_y_axis() +
    ggeasy::easy_remove_x_axis() +
    ggplot2::theme_void() +
    ggplot2::theme(aspect.ratio = 0.1)

  # g2 / g1 + patchwork::plot_layout(heights = c(1,10))
  layout = c(patchwork::area(t = 1, b = 10, l = 1, r = 10),
             patchwork::area(t = 11, b = 12, l = 1, r = 10))

  g1 / g2

}


#' Generate multiple calibration plots with colored/shaded 95 percent confidence intervals
#'
#' This code builds off of code written by Darren Dahly, PhD in this blog post:
#' \url{https://darrendahly.github.io/post/homr/}.
#'
#' @param df The df as a data.frame.
#' @param outcome A character string containing the name of the column containing
#' the outcomes (expressed as 0/1s).
#' @param positive A character string containing the value of outcome that is the positive class.
#' @param prediction A character string containing the name of the column containing
#' the predictions.
#' @param model A character string containing the name of the column containing
#' the model names
#' @param n_bins Number of bins. Defaults to 10. Set to 0 to hide binned calibration.
#' @param show_loess Whether to show loess smoothed calibration estimates.
#'   Defaults to FALSE. You can either display a binned calibration plot or a loess curve.
#'   These options are mutually exclusive.
#' @param plot_title A character string containing the title for the resulting plot.
#' @return A ggplot containing the calibration plot
#' @examples
#' data(multi_model_dataset)
#' cal_plot_multi(multi_model_dataset, outcome = 'outcomes', positive = '1', prediction = 'predictions', model = 'model_name', n_bins = 5)
#' @export
cal_plot_multi <- function(df, outcome, positive, prediction, model, n_bins = 10, show_loess = FALSE, plot_title = '', ...){

  if((n_bins > 0 && show_loess == TRUE) || (n_bins == 0 && show_loess == FALSE)) {
    stop('You must either set n_bins > 0 and show_loess to FALSE or set n_bins to 0 and show_loess to TRUE. Both cannot be displayed.')
  }

  how_many_models = df[[model]] %>% unique() %>% length()

  # Converts outcome to be 0s and 1s
  df[[outcome]] = ifelse(positive == df[[outcome]], 1, 0)

  # The calibration plot
  if (n_bins > 0) {
  df <- df %>%
    dplyr::group_by(!!rlang::parse_expr(model)) %>%
    dplyr::mutate(bin = dplyr::ntile(!!rlang::parse_expr(prediction), n_bins)) %>%
    # Bin prediction
    dplyr::group_by(!!rlang::parse_expr(model), bin) %>%
    dplyr::mutate(n = dplyr::n(), # Get ests and CIs
           bin_pred = mean(!!rlang::parse_expr(prediction), na.rm = TRUE),
           bin_prob = mean(as.numeric(as.character(!!rlang::parse_expr(outcome))), na.rm = TRUE),
           se = sqrt((bin_prob * (1 - bin_prob)) / n),
           ul = bin_prob + 1.96 * se,
           ll = bin_prob - 1.96 * se) %>%
    dplyr::mutate_at(dplyr::vars(ul, ll), . %>% scales::oob_squish(range = c(0,1))) %>%
    dplyr::ungroup()
  }
  g1 = ggplot2::ggplot(df) +
    # geom_errorbar(size = 0.5, width = 0.02) +
    ggplot2::scale_y_continuous(limits = c(0, 1), breaks = seq(0, 1, by = 0.1)) +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, by = 0.1)) +
    ggplot2::geom_abline(linetype = 'dashed') # 45 degree line indicating perfect calibration
    # geom_smooth(method = "lm", se = FALSE, linetype = "dashed",
    #            color = "black", formula = y~-1 + x) +
    # straight line fit through estimates
    # geom_smooth(ggplot2::aes(x = get(prediction), y = as.numeric(outcome)),
    #            color = "red", se = FALSE, method = "loess") +
    # loess fit through estimates
    # scale_color_viridis(discrete = TRUE, option = 'cividis', begin = 0.5) +
    # scale_fill_viridis(discrete = TRUE, option = 'cividis', begin = 0.5) +


    if (show_loess == TRUE) {
      g1 = g1 +
        ggplot2::stat_smooth(ggplot2::aes(x = !!rlang::parse_expr(prediction), y = as.numeric(!!rlang::parse_expr(outcome)),
                                          color = !!rlang::parse_expr(model), fill = !!rlang::parse_expr(model)),
                            #              alpha = 1/how_many_models), # currently ignored by geom_smooth
                             se = TRUE, method = "loess")
      # loess fit through estimates
    } else {
      g1 = g1 + ggplot2::aes(x = bin_pred,
                   y = bin_prob,
                   color = !!rlang::parse_expr(model),
                   fill = !!rlang::parse_expr(model)) +
        ggplot2::geom_ribbon(ggplot2::aes(ymin = ll,
                                          ymax = ul,),
                             alpha = 1/how_many_models) +
        ggplot2::geom_point(size = 2) +
        ggplot2::geom_line(size = 1, alpha = 1/how_many_models)
    }

  g1 = g1 +
    ggplot2::xlab("Predicted Probability") +
    ggplot2::ylab("Observed Risk") +
    ggplot2::scale_color_brewer(name = 'Models', palette = 'Set1') +
    ggplot2::scale_fill_brewer(name = 'Models', palette = 'Set1') +
    ggplot2::theme_minimal() +
    ggplot2::theme(aspect.ratio = 1) +
    ggplot2::ggtitle(plot_title)


  # The distribution plot
  g2 <- ggplot2::ggplot(df, ggplot2::aes(x = !!rlang::parse_expr(prediction))) +
    ggplot2::geom_density(alpha = 1/how_many_models, ggplot2::aes(fill = !!rlang::parse_expr(model), color = !!rlang::parse_expr(model))) +
    ggplot2::scale_x_continuous(limits = c(0, 1), breaks = seq(0, 1, by = 0.1)) +
    ggplot2::coord_fixed() +
    # scale_color_viridis(discrete = TRUE, option = 'cividis', begin = 0.5) +
    # scale_fill_viridis(discrete = TRUE, option = 'cividis', begin = 0.5) +
    ggplot2::xlab("") +
    ggplot2::ylab("") +
    ggplot2::scale_color_brewer(palette = 'Set1') +
    ggplot2::scale_fill_brewer(palette = 'Set1') +
    ggplot2::theme_minimal() +
    ggeasy::easy_remove_y_axis() +
    #  easy_remove_x_axis(what = c('ticks','line')) +
    ggeasy::easy_remove_legend(fill, color) +
    ggplot2::theme_void() +
    ggplot2::theme(aspect.ratio = 0.1)

  layout = c(patchwork::area(t = 1, b = 10, l = 1, r = 10),
             patchwork::area(t = 11, b = 12, l = 1, r = 10))

  g1 / g2

}

