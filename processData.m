function epiDataCombined = processData(epiData, hospData, date0)

% Function to combine and pre-process main epidemiological dataset and hospital occupancy data
%
% USAGE: epiDataCombined = processData(epiData, hospData, date0)
%
% INPUTS: epiData - table of epi data as returned by getEpiData()
%         hospData - table of hospital occupancy data as returned by getHospData()
%         date0 - starting date for model simulartions
%
% OUPTUS: epiDataCombined - combined data table



% Retain hospital occupancy data up to date on which epi data was downloaded (this is typically epiSurv cases reported up to Sunday and hospital occupancy data published Monday meaning beds occupied Sunday night)
%hospData = hospData(hospData.t <= max(epiData.t)+1, :);      
%epiData = outerjoin(epiData, hospData, 'Keys', 't', 'MergeKeys', 1);   % outer join retains all data and if one table is missing data it is filled with NaN

epiData_tMax = epiData.t(find(~isnan(epiData.nCasesByAge(:, 1)), 1, 'last'));
hospData_tMax = hospData.t(find(~isnan(hospData.Hosp), 1, 'last'));
if epiData_tMax > hospData_tMax
    fprintf('\nWarning: epiData more recent that hospital occupancy data - you may need to refresh covid-cases-in-hospital-counts-location.xslx\n')
end

epiDataCombined = innerjoin(epiData, hospData, 'Keys', {'t', 'area'});    % innerjoin retains only dates for which there are records in both epiSurv and hospitalisation data. This has the effect of truncating the hospitalisation dataset at the latest date for which case data is available (or truncating the case data if the latest hospitalisation data hasn't been downloaded, in which case a warning will be issued)



% Calculate new variables aggregaed over ages and smoothed
epiDataCombined.nCases = sum(epiDataCombined.nCasesByAge, 2);
epiDataCombined.nHosp_DOR = sum(epiDataCombined.nHospByAge_DOR, 2);
epiDataCombined.nHosp_DOA = sum(epiDataCombined.nHospByAge_DOA, 2);

% Restrict data to date0 onwards
ind = epiDataCombined.t >= date0;
epiDataCombined = epiDataCombined(ind, :);

