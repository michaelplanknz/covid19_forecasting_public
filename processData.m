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

epiData_tMax = max(epiData.t);
hospData_tMax = max(hospData.t);
if epiData_tMax > hospData_tMax
    fprintf('\nWarning: epiData (%s) more recent that hospital occupancy data (%s) - padding occupancy data with NaNs - you may need to refresh covid-cases-in-hospital-counts-location.xslx\n', epiData_tMax, hospData_tMax)
    % Pad hospData table prior to merging
    tMaxFlag = hospData.t == max(hospData.t);        % flag for entries in hospData corresponding to the last day of data 
    tbl = repmat(  hospData(tMaxFlag, :),  days(epiData_tMax - hospData_tMax), 1 );
    tbl.t = repelem(  (hospData_tMax+1:epiData_tMax)', sum(tMaxFlag) );
    tbl.Hosp = nan(height(tbl), 1);
    hospData = [hospData; tbl];
end

epiDataCombined = innerjoin(epiData, hospData, 'Keys', {'t', 'area'});    % innerjoin retains only dates for which there are records in both epiSurv and hospitalisation data. This has the effect of truncating the hospitalisation dataset at the latest date for which case data is available (or truncating the case data if the latest hospitalisation data hasn't been downloaded, in which case a warning will be issued)



% Calculate new variables aggregaed over ages and smoothed
epiDataCombined.nCases = sum(epiDataCombined.nCasesByAge, 2);
epiDataCombined.nHosp_DOR = sum(epiDataCombined.nHospByAge_DOR, 2);
epiDataCombined.nHosp_DOA = sum(epiDataCombined.nHospByAge_DOA, 2);

% Restrict data to date0 onwards
ind = epiDataCombined.t >= date0;
epiDataCombined = epiDataCombined(ind, :);

