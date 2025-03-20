### ------------------------------------------------------------------------ ###
###                      EGM self-harm - Shiny preparation                   ###
### ------------------------------------------------------------------------ ###


## remove any existing objects from global environment
rm(list=ls()) 

## disable scientific notation printing
options(scipen=999)

### load packages and data --------

#install.packages("tidyverse")
#install.packages("janitor")
#install.packages("readxl")
#install.packages("snakecase")

## load packages
library(tidyverse)
library(janitor) # for tidying up variable names 
library(readxl) # to read in Excel packages
library(snakecase) # to reformat strings
library(here)

## Set working directory - only need to do this if you can't get into the R project
#setwd("/PHI_conf/PHSci/Catriona/EGM/self_harm_egm_full/")

## Load quantitative data and add review type column
df_quant <- read_xlsx(here("data/230320 SH Phase 2 full data extract.xlsx"))  %>%
  mutate(review_type = "Quantitative")

## Load qualitative data, and review type column
df_qual <- read_csv(here("data/230405 SH data_extract_qual.csv")) %>%
  mutate(review_type = "Qualitative")

## Bind quant and qual data together
df_source <- rbind(df_quant, df_qual)

## put names into a more R-friendly format
df_source <- df_source %>% 
  clean_names()

# Pivot to create a subdomain column from the current separate subdomain columns
# Drop rows where subdomain is NA and change domain to sentence case
# Create a column to code for exposure, intervention or Exposure and intervention
df_pivot <- df_source %>%
  pivot_longer(cols = individual:structural,
               names_to = "domain",
               values_to = "subdomain") %>%
  drop_na(subdomain) %>%
  mutate(domain = to_sentence_case(domain),
         intervention_exposure_short = case_when(str_detect(intervention_or_exposure, "exposures") & str_detect(intervention_or_exposure, "Intervention") ~ "Risk/protective factor; Intervention",
                                                 str_detect(intervention_or_exposure, "exposures") ~ "Risk/protective factor",
                                                 str_detect(intervention_or_exposure, "Intervention") ~ "Intervention",
                                                 intervention_or_exposure == "Attitudes" ~ "Attitudes"),
         # Remove 'Other:' from type of review description
         type_of_review = str_replace(type_of_review, "Other: ", ""),
         outcome_definition = str_replace(outcome_definition, "SITB", "self-injurous thoughts and behaviours"),
         sub_population_mental_health_characteristics = sub("\\s\\((.*)\\)\\?", "", sub_population_mental_health_characteristics)) # Take out text in brackets in one of the sub-population descriptions


# Create columns for each outcome definition,subdomain, study setting and intervention classification, since some studies have several
# Also shorten any subdomains that contain 'other' descriptions to just be 'other'
# The qualitative data has a subdomain of "Parental health (including mental health)", but the bit in brackets isn't there for the quantitative data. So, remove the brackets for consistency.
# Also create column for population type filter
# COME BACK TO TO SEE IF OTHER DEFINITIONS CAN BE KEPT IN TABLE
df_separated <- df_pivot %>%
  separate_longer_delim(outcome_definition, delim = "; ") %>%
  separate_longer_delim(subdomain, delim = "; ") %>%
  separate_longer_delim(intervention_exposure_short, delim = "; ") %>%
  separate_longer_delim(intervention_classification, delim = "; ") %>%
  separate_longer_delim(sub_population_mental_health_characteristics, delim = "; ") %>%
  separate_longer_delim(other_sub_population_characteristics, delim = "; ") %>%
  separate_longer_delim(study_setting, delim = "; ") %>%
  separate_longer_delim(design_of_reviewed_studies, delim = "; ") %>%
  separate_longer_delim(comparator_details, delim = "; ") %>%
  mutate(subdomain = case_when(str_detect(subdomain,"Other:") ~ paste0("Other (", domain, ")"),
                               subdomain == "Parental health (including mental health)" ~ "Parental health",
                               TRUE ~ subdomain),
         intervention_classification = if_else(str_detect(intervention_classification, "Other:"), "Other", intervention_classification),
         design_of_reviewed_studies = if_else(str_detect(design_of_reviewed_studies, "Other:"), "Other", design_of_reviewed_studies)) %>%
  mutate(overall_population = case_when(general_population == "Yes" ~ "General population",
                                        !is.na(sub_population_mental_health_characteristics) ~ "Sub-population mental health characteristics",
                                        !is.na(other_sub_population_characteristics) ~ "Other sub-population characteristics"),
         sub_population = case_when(!is.na(sub_population_mental_health_characteristics) ~ sub_population_mental_health_characteristics,
                                    !is.na(other_sub_population_characteristics) ~ other_sub_population_characteristics,
                                    TRUE ~ NA),
         sub_population = gsub("Other: ", "", sub_population)) # If the sub-population starts with 'Other', remove this

# Add in some dummy outcomes for display purposes
df_separated <- df_separated %>%
  mutate(overall_outcome = "Self-harm")

# Comment these out - don't need dummy categories for publication
# %>%
#   add_row(overall_outcome = "Outcome category 2", domain = "Individual", subdomain = "Mental health", intervention_exposure_short = "Intervention", review_type = "Quantitative") %>%
#   add_row(overall_outcome = "Outcome category 2", domain = "Family and friends", subdomain = "Family relations", intervention_exposure_short = "Intervention", review_type = "Qualitative") %>%
#   add_row(overall_outcome = "Outcome category 2", domain = "Structural", subdomain = "Exposure to harm", intervention_exposure_short = "Risk/protective factor", review_type = "Quantitative") %>%
#   add_row(overall_outcome = "Outcome category 3", domain = "Individual", subdomain = "Mental health", intervention_exposure_short = "Intervention", review_type = "Qualitative") %>%
#   add_row(overall_outcome = "Outcome category 3", domain = "Family and friends", subdomain = "Family relations", intervention_exposure_short = "Intervention", review_type = "Quantitative") %>%
#   add_row(overall_outcome = "Outcome category 3", domain = "Structural", subdomain = "Exposure to harm", intervention_exposure_short = "Risk/protective factor", review_type = "Quantitative")

# Add in other subdomains that aren't in the data, to account for data gaps
# Include a flag that these are dummy records, so they're not included in the map
df_separated <- df_separated %>%
  mutate(dummy = 0) %>%
  add_row(domain = "Individual", subdomain = "Health behaviours", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Individual", subdomain = "Physical health", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Individual", subdomain = "Mental health", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Individual", subdomain = "Social media use", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Individual", subdomain = "Body image", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Individual", subdomain = "Perinatal environment", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Individual", subdomain = "Early development", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Individual", subdomain = "Intrinsic characteristics", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Family and friends", subdomain = "Family relations", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Family and friends", subdomain = "Parental health", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Family and friends", subdomain = "Peer and friend relationships", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Learning environment", subdomain = "Engagement with learning", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Learning environment", subdomain = "Educational environment", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Learning environment", subdomain = "Pressure and expectations", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Community", subdomain = "Respect of young people", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Community", subdomain = "Engagement in local activities", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Community", subdomain = "Social support", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Community", subdomain = "Safety", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Community", subdomain = "Belonging", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Structural", subdomain = "Equality", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Structural", subdomain = "Poverty and material deprivation", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Structural", subdomain = "Social inclusion", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Structural", subdomain = "Stigma and discrimination", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Structural", subdomain = "Physical environment", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Structural", subdomain = "Societal optimism", overall_outcome = "Self-harm", dummy = 1) %>%
  add_row(domain = "Structural", subdomain = "Exposure to harm", overall_outcome = "Self-harm", dummy = 1) %>%
  mutate(overall_outcome = factor(overall_outcome, levels = c("Self-harm", "Outcome category 2", "Outcome category 3")),
         domain = factor(domain, levels = c("Individual", "Family and friends", "Learning environment", "Community", "Structural")),
         subdomain = factor(subdomain, levels = c("Health behaviours", "Physical health", "Mental health", "Social media use", "Body image", "Perinatal environment", "Early development", "Intrinsic characteristics", "Family relations", "Parental health", "Peer and friend relationships", "Engagement with learning", "Educational environment", "Pressure and expectations", "Respect of young people", "Engagement in local activities", "Social support", "Safety", "Belonging", "Equality", "Poverty and material deprivation", "Social inclusion", "Stigma and discrimination", "Physical environment", "Societal optimism", "Exposure to harm", "Other (Individual)", "Other (Family and friends)", "Other (Learning environment)", "Other (Community)", "Other (Structural)")))

# Filter out qualitative reviews, because these will be displayed separately
df_separated <- df_separated %>%
  filter(review_type == "Quantitative" | is.na(review_type))
  
# Gather data to show in table
# Filter out dummy rows
df_table <- df_separated %>%
  group_by(across(c(-outcome_definition, -domain, -subdomain, -intervention_exposure_short, -intervention_classification, -sub_population, -other_sub_population_characteristics, -sub_population_mental_health_characteristics, -study_setting, -design_of_reviewed_studies, -comparator_details))) %>%
  summarise(outcome_definition = paste(unique(outcome_definition), collapse = "; "),
            subdomain= paste(unique(subdomain), collapse="; "),
            intervention_or_exposure = paste(unique(intervention_exposure_short), collapse = "; "),
            intervention_classification = paste(unique(intervention_classification), collapse = "; "),
            sub_population = paste(unique(sub_population), collapse = "; "),
            other_sub_population_characteristics = paste(unique(other_sub_population_characteristics), collapse = "; "),
            sub_population_mental_health_characteristics = paste(unique(sub_population_mental_health_characteristics), collapse = "; "),
            study_setting = paste(unique(study_setting), collapse = "; "),
            design_of_reviewed_studies = paste(unique(design_of_reviewed_studies), collapse = "; "),
            comparator_details = paste(unique(comparator_details), collapse = "; ")) %>%
  filter(dummy == 0) %>%
  ungroup()

# Read in data with hyperlinks to papers
# Select relevant columns and remove hash in covidence number column
df_links <- read_csv(here("data/SH data for hyperlinks.csv")) %>%
  select(covidence_number = "Covidence #", DOI) %>%
  mutate(covidence_number = str_replace(covidence_number, "#", ""))

# Merge with df table dataframe
df_table_with_links <- merge(df_table, df_links, by = "covidence_number", all = TRUE)

# Save file for use in Shiny app
saveRDS(df_separated, "data/self-harm_egm_chart_data.rds")

# Save data that has been gathered back together into a separate file for the dashboard table
saveRDS(df_table_with_links, "data/self-harm_egm_table_data.rds")