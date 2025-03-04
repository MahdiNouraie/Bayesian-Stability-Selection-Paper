# This code generates synthetic data sets and 
# performs Bayesian Stability Selection using Elastic Net regression.
# n_dataset denotes the number of datasets generated.
# For reproducing the results reported in the manuscript,
# you need to set n_datasets = 100. It takes a few minutes to run.
# For faster results, you may set n_datasets = 10.

#################  Install and Load Necessary Libraries #################
# Install necessary libraries if not already installed
if(!require("MASS")){install.packages("MASS")}
if(!require("glmnet")){install.packages("glmnet")}
if(!require("ggplot2")){install.packages("ggplot2")}
if(!require("reshape2")){install.packages("reshape2")}
if(!require("latex2exp")){install.packages("latex2exp")}

# Load necessary libraries
library(MASS)  # For multivariate Normal sampling
library(glmnet)  # For Elastic Net regression
library(reshape2) # For data manipulation
library(ggplot2)  # For plotting
library(latex2exp) # For LaTeX expressions in plots
#sessionInfo()
#R version 4.4.2 (2024-10-31)
#Platform: x86_64-pc-linux-gnu
#Running under: Ubuntu 20.04.6 LTS

#Matrix products: default
#BLAS:   /usr/lib/x86_64-linux-gnu/openblas-pthread/libblas.so.3 
#LAPACK: /usr/lib/x86_64-linux-gnu/openblas-pthread/liblapack.so.3;  LAPACK version 3.9.0

#locale:
#  [1] LC_CTYPE=C.UTF-8       LC_NUMERIC=C           LC_TIME=C.UTF-8       
#[4] LC_COLLATE=C.UTF-8     LC_MONETARY=C.UTF-8    LC_MESSAGES=C.UTF-8   
#[7] LC_PAPER=C.UTF-8       LC_NAME=C              LC_ADDRESS=C          
#[10] LC_TELEPHONE=C         LC_MEASUREMENT=C.UTF-8 LC_IDENTIFICATION=C   

#time zone: UTC
#tzcode source: system (glibc)

#attached base packages:
#  [1] stats     graphics  grDevices utils     datasets  methods   base     

#other attached packages:
#  [1] latex2exp_0.9.6 reshape2_1.4.4  ggplot2_3.5.1   glmnet_4.1-8    Matrix_1.7-1   
#[6] MASS_7.3-64    

#loaded via a namespace (and not attached):
#  [1] vctrs_0.6.5      cli_3.6.4        rlang_1.1.5      stringi_1.8.4   
#[5] generics_0.1.3   glue_1.8.0       colorspace_2.1-1 plyr_1.8.9      
#[9] scales_1.3.0     grid_4.4.2       munsell_0.5.1    tibble_3.2.1    
#[13] foreach_1.5.2    lifecycle_1.0.4  stringr_1.5.1    compiler_4.4.2  
#[17] dplyr_1.1.4      codetools_0.2-20 Rcpp_1.0.14      pkgconfig_2.0.3 
#[21] lattice_0.22-6   R6_2.6.1         tidyselect_1.2.1 pillar_1.10.1   
#[25] splines_4.4.2    shape_1.4.6.1    magrittr_2.0.3   withr_3.0.2     
#[29] tools_4.4.2      gtable_0.3.6     iterators_1.0.14 survival_3.7-0  

################# Set Parameters #################
p <- 500 # Number of predictors
n <- 50 # Number of observations
b <- 100 # Number of subsamples
n_datasets <- 100 # Number of datasets

# Initialize matrix for selection frequencies over datasets
Selection_Frequency <- matrix(0, nrow = n_datasets, ncol = p)

# Create the decaying covariance matrix Σ
rho <- 0.9
Sigma <- rho^abs(row(diag(p)) - col(diag(p)))

# Define the coefficient vector
beta <- c(0.5, 0.4, 0.3, 0.2, rep(0, p - 4))  

################# Data Generation and Bayesian Stability Selection #################
# Generate synthetic datasets and loop through to calculate selection frequencies
for (i in 1:n_datasets) {
  set.seed(26 + i)  # Set a different seed for each dataset
  # Sample predictors X from multivariate normal distribution N(0, Σ)
  X <- mvrnorm(n = n, mu = rep(0, p), Sigma = Sigma)
  
  # Generate the response Y using the predictors and adding Gaussian noise
  epsilon <- rnorm(n, mean = 0, sd = 2)  # Gaussian noise with variance 4 (sd = 2)
  Y <- X %*% beta + epsilon
  
  # Combine predictors and response into a single data frame
  data <- data.frame(X, Y)
  
  set.seed(26)  # Set seed for reproducibility
  # Perform cross-validated Elastic Net
  cv_elastic <- cv.glmnet(X, Y, nfolds = 10, alpha = 0.2)
  
  # Get the optimal lambda value
  lambda <- cv_elastic$lambda.1se
  
  # Initialize matrix S for stability selection for current dataset
  S <- matrix(data = 0, nrow = b, ncol = p)  
  for (j in 1:b) {  # Number of subsamples
    # Sub-sampling
    model_data <- data[sample(1:nrow(data), nrow(data) / 2, replace = FALSE), ]
    
    # Prepare the predictor matrix x and response vector y for the subsample
    x_sub <- as.matrix(model_data[, 1:ncol(model_data) - 1])
    y_sub <- model_data$Y
    
    # Fit the final model with the optimal lambda value
    elastic_model <- glmnet(x_sub, y_sub, alpha = 0.2, lambda = lambda)
    
    # Determine significant predictors (excluding intercept)
    significant_predictors <- ifelse(coef(elastic_model) != 0, 1, 0)[-1]
    
    # Store significant predictors in matrix S
    S[j, ] <- significant_predictors
  }
  
  # Store selection frequency for the dataset in the corresponding row
  Selection_Frequency[i, ] <- colMeans(S)
}

# The number of times the first 4 predictors were selected
n_j <- round(colMeans(Selection_Frequency)[1:4] * n_datasets)
# Using Priors for the first 6 predictors
# Assuming the answer to the first question is 50% for the first 6 predictors and,
# Assuming the perceived importance of the first 6 predictors is 70%
alpha_j <- rep(70, 4)
beta_j <- rep(30, 4)

# The average selection frequency of the first 4 predictors over all datasets
cat("Selection Frequency: ", round(colMeans(Selection_Frequency)[1:4], 3),'\n')
# Posterior Inclusion Probability
cat("Inclusion Probability: ", round((n_j + alpha_j) / (b + alpha_j + beta_j), 3))


################# Plot (Figure 5) #################
q1 <- seq(0, 0.5, 0.1)
q2 <- seq(0, 1, 0.1)
gamma_j = (q1 * b) / (1 - q1)
alpha_j <- floor(outer(q2, gamma_j, "*"))
gamma_j <- matrix(rep(gamma_j, length(q2)), nrow = length(q2), byrow = TRUE)
beta_j <- gamma_j - alpha_j
# Figure 5a
new_mat <- matrix(0, nrow = nrow(alpha_j), ncol = ncol(alpha_j))
rownames(new_mat) <- q2
colnames(new_mat) <- q1
for (i in 1:nrow(alpha_j)){
  for (j in 1:ncol(alpha_j)){
    for (k in n_j){
      prob <- round((k + alpha_j[i,j]) / (b + alpha_j[i,j] + beta_j[i,j]), 3)
      if (prob >= 0.6){
        new_mat[i,j] <- new_mat[i,j] + 1
      }
    }
  }
}

new_mat_melted <- melt(new_mat)

ggplot(new_mat_melted, aes(x = Var2, y = Var1, fill = as.factor(value))) +
  scale_x_continuous(breaks = seq(0, 0.5, 0.1)) +
  scale_y_continuous(breaks = seq(0, 1, 0.1)) +
  geom_tile() +
  scale_fill_manual(values = colorRampPalette(c("violetred", "lawngreen"))(length(unique(new_mat_melted$value)))) +
  guides(fill = guide_legend(reverse = TRUE)) +
  labs(x = TeX("$\\tilde{zeta}_{j}$"), y = TeX("$\\tilde{xi}_{j}$"), fill = "Count",
       title = TeX("Heatmap of Correct Selections vs $\\tilde{zeta}_{j}$ and $\\tilde{xi}_{j}$")) +
  theme_bw() +
  theme(plot.title = element_text(hjust = 0.5, size = 18),  
        axis.title = element_text(size = 20),              
        axis.text = element_text(size = 12))


# Figure 5b
new_mat2 <- matrix(0, nrow = nrow(alpha_j), ncol = ncol(alpha_j))
rownames(new_mat2) <- q2
colnames(new_mat2) <- q1
n_j2 <- round(colMeans(Selection_Frequency)[5:500] * n_datasets)
for (i in 1:nrow(alpha_j)){
  for (j in 1:ncol(alpha_j)){
    for (k in n_j2){
      prob <- round((k + alpha_j[i,j]) / (b + alpha_j[i,j] + beta_j[i,j]), 3)
      if (prob >= 0.6){
        new_mat2[i,j] <- new_mat2[i,j] + 1
      }
    }
  }
}

new_mat_melted2 <- melt(new_mat2)

# Plot heatmap
ggplot(new_mat_melted2, aes(x = Var2, y = Var1, fill = as.factor(value))) +
  scale_x_continuous(breaks = seq(0, 0.5, 0.1)) +
  scale_y_continuous(breaks = seq(0, 1, 0.1)) +
  geom_tile() +
  scale_fill_manual(values = c("lawngreen", "violetred", "mediumvioletred"))+
guides(fill = guide_legend(reverse = TRUE)) +
  labs(x = TeX("$\\tilde{zeta}_{j}$"), y = TeX("$\\tilde{xi}_{j}$"), fill = "Count",
       title = TeX("Heatmap of Incorrect Selections vs $\\tilde{zeta}_{j}$ and $\\tilde{xi}_{j}$")) +
  theme_bw() +
  theme(plot.title = element_text(hjust = 0.5, size = 18),  
        axis.title = element_text(size = 20),              
        axis.text = element_text(size = 12))
