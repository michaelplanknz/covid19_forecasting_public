function [epiData, ageBreaks, LOS_array, LOS_freq, RtoA_array, RtoA_freq, OtoR_array, OtoR_freq] = getEpiData(readDate)

% Function to read in epidemiological data 
% 
% USAGE: [epiData, ageBreaks, LOS_array, LOS_freq, RtoA_array, RtoA_freq, OtoR_array, OtoR_freq] = getEpiData(readDate)
%
% INPUTS: readDate - datestamp on the epi data file to read in 
%
% OUTPUTS: epiData - table with the following fields
%            - t - column of dates
%            - nCasesByAge - array with columns representing number of reported daily cases in 10-year age groups
%            - nHospByAge_DOR - array with columns representing number of daily admissions in 10-year age groups by date of case report
%            - nHospByAge_DOA - array with columns representing number of daily admissions in 10-year age groups by date of admission
%            - nDiscByAge - array with columns representing number of daily pseudo-discharges in 10-year age groups
%          ageBreaks - array of bin edges for age groups
%          LOS_array - array of Covid-related length of stay values (days)
%          LOS_freq - array of frequencies of those length of stay values in 10-year age groups
%          RtoA_array - array of report to admission values (days)
%          RtoA_freq - array of frequencies of those report to admission values
%          OtoR_array - array of onset to report values (days)
%          OtoR_freq - array of frequencies of those onset to report values


fName = sprintf('data/allData_%s.mat', datetime(readDate, 'Format', "yyyy-MM-dd"));

load(fName, 'epiData', 'ageBreaks', 'LOS_array', 'LOS_freq', 'RtoA_array', 'RtoA_freq', 'OtoR_array', 'OtoR_freq');

